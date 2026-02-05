import AsyncViewModel
import Foundation
import Observation
import SwiftUIRender

@MainActor
@Observable
final class ChatHarnessViewModel: AsyncViewModel {
    enum Action: Sendable {
        case composerChanged(String)
        case sendPrompt(String)
        case cancelStream
        case clearSession
        case dismissTakeover
        case submitTakeoverFromComposer
        case switchMode(StreamMode)
        case selectReplayScenario(ReplayScenario)
        case receiveEvent(streamID: UUID, event: ChatStreamEvent)
        case receiveDiagnostics(renderID: String, issues: [GuardrailIssue])
        case handleRenderAction(renderID: String, action: RenderAction)
    }

    enum Mutation: Sendable {
        case composerChanged(String)
        case modeChanged(StreamMode, cancelledStream: Bool)
        case replayScenarioChanged(ReplayScenario)
        case streamStarted(
            streamID: UUID,
            userMessage: ChatMessage,
            assistantTextMessage: ChatMessage,
            cancelledPrevious: Bool,
            replayScenario: ReplayScenario?
        )
        case streamCancelled(reason: String)
        case streamEvent(streamID: UUID, event: ChatStreamEvent)
        case diagnostics(renderID: String, issues: [GuardrailIssue])
        case actionResult(String)
        case takeoverDismissed(renderID: String, status: AssistantRenderStatus)
        case takeoverSubmitted(renderID: String, payload: [String: JSONValue], assistantFollowup: String?)
        case sessionCleared
    }

    let initialState: ChatHarnessState

    @ObservationIgnored
    private let replayClientFactory: (ReplayScenario) -> ChatStreamClient

    @ObservationIgnored
    private let localSSEClient: ChatStreamClient

    @ObservationIgnored
    private let debugControlsEnabled: Bool

    @ObservationIgnored
    private var streamTask: Task<Void, Never>?

    @ObservationIgnored
    private var renderPayloads: [String: AssistantRenderPayload] = [:]

    init(
        replayClientFactory: @escaping (ReplayScenario) -> ChatStreamClient = { scenario in
            ReplayChatStreamClient(scenario: scenario)
        },
        localSSEClient: ChatStreamClient = LocalSSEChatStreamClient(),
        debugControlsEnabled: Bool = ProcessInfo.processInfo.environment["RENDERCHAT_DEBUG_CONTROLS"] == "1",
        initialState: ChatHarnessState = ChatHarnessState(),
        initialRenderPayloads: [String: AssistantRenderPayload] = [:]
    ) {
        self.initialState = initialState
        self.replayClientFactory = replayClientFactory
        self.localSSEClient = localSSEClient
        self.debugControlsEnabled = debugControlsEnabled
        renderPayloads = initialRenderPayloads
    }

    deinit {
        streamTask?.cancel()
    }

    func mutate(action: Action) async -> MutationStream {
        switch action {
        case let .composerChanged(text):
            return .just(.composerChanged(text))

        case let .switchMode(mode):
            guard mode != currentState.mode else {
                return .empty()
            }

            let cancelledStream = currentState.isStreaming
            if cancelledStream {
                streamTask?.cancel()
                if let renderID = currentState.activeRenderID {
                    renderPayloads[renderID]?.finishStream()
                }
            }

            return .just(.modeChanged(mode, cancelledStream: cancelledStream))

        case let .selectReplayScenario(scenario):
            return .just(.replayScenarioChanged(scenario))

        case .cancelStream:
            guard currentState.isStreaming else {
                return .empty()
            }

            streamTask?.cancel()
            if let renderID = currentState.activeRenderID {
                renderPayloads[renderID]?.finishStream()
            }

            return .just(.streamCancelled(reason: "Cancelled current stream."))

        case .clearSession:
            streamTask?.cancel()
            for payload in renderPayloads.values {
                payload.finishStream()
            }
            renderPayloads.removeAll()
            return .just(.sessionCleared)

        case .dismissTakeover:
            guard case let .takeover(takeover) = currentState.composerMode else {
                return .empty()
            }

            return .just(
                .takeoverDismissed(
                    renderID: takeover.renderID,
                    status: takeover.status
                )
            )

        case .submitTakeoverFromComposer:
            guard case let .takeover(takeover) = currentState.composerMode else {
                return .empty()
            }

            guard let submitTarget = takeover.singleSubmitTarget else {
                return .just(.actionResult("Takeover requires exactly one submit action."))
            }

            renderPayloads[takeover.renderID]?.recordSubmit(payload: submitTarget.payload)
            let scenario = renderPayloads[takeover.renderID]?.replayScenario ?? takeover.replayScenario

            return .just(
                .takeoverSubmitted(
                    renderID: takeover.renderID,
                    payload: submitTarget.payload,
                    assistantFollowup: Self.followupText(for: scenario)
                )
            )

        case let .sendPrompt(rawPrompt):
            let prompt = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prompt.isEmpty else {
                return .empty()
            }

            let cancelledPrevious = currentState.isStreaming
            if cancelledPrevious {
                streamTask?.cancel()
                if let renderID = currentState.activeRenderID {
                    renderPayloads[renderID]?.finishStream()
                }
            }

            let replayScenario: ReplayScenario?
            if currentState.mode == .replay {
                replayScenario = Self.resolveReplayScenario(
                    for: prompt,
                    fallback: currentState.selectedReplayScenario
                )
            } else {
                replayScenario = nil
            }

            let streamID = UUID()
            let userMessage = ChatMessage.userText(prompt)
            let assistantTextMessage = ChatMessage.assistantText()
            startStream(prompt: prompt, streamID: streamID, replayScenario: replayScenario)

            return .just(
                .streamStarted(
                    streamID: streamID,
                    userMessage: userMessage,
                    assistantTextMessage: assistantTextMessage,
                    cancelledPrevious: cancelledPrevious,
                    replayScenario: replayScenario
                )
            )

        case let .receiveEvent(streamID, event):
            return .just(.streamEvent(streamID: streamID, event: event))

        case let .receiveDiagnostics(renderID, issues):
            return .just(.diagnostics(renderID: renderID, issues: issues))

        case let .handleRenderAction(renderID, action):
            switch action {
            case let .submit(payload):
                renderPayloads[renderID]?.recordSubmit(payload: payload)

                if case let .takeover(takeover) = currentState.composerMode,
                   takeover.renderID == renderID {
                    let scenario = renderPayloads[renderID]?.replayScenario ?? takeover.replayScenario
                    return .just(
                        .takeoverSubmitted(
                            renderID: renderID,
                            payload: payload,
                            assistantFollowup: Self.followupText(for: scenario)
                        )
                    )
                }

                return .just(.actionResult(Self.describe(action: action)))

            default:
                return .just(.actionResult(Self.describe(action: action)))
            }
        }
    }

    func reduce(state: ChatHarnessState, mutation: Mutation) -> ChatHarnessState {
        var state = state

        switch mutation {
        case let .composerChanged(text):
            state.composerText = text

        case let .modeChanged(mode, cancelledStream):
            state.mode = mode
            state.composerMode = .text

            if cancelledStream {
                if let renderID = state.activeRenderID {
                    state = updateRenderStatus(for: renderID, status: .failed, in: state)
                    state = updateTakeoverStatus(for: renderID, status: .failed, in: state)
                }
                state = stopStream(in: state)
                state.messages.append(ChatMessage.system("Cancelled current stream due to mode switch."))
            }

        case let .replayScenarioChanged(scenario):
            state.selectedReplayScenario = scenario

        case let .streamStarted(streamID, userMessage, assistantTextMessage, cancelledPrevious, replayScenario):
            if cancelledPrevious {
                state.messages.append(ChatMessage.system("Cancelled previous stream before starting a new one."))
            }

            state.messages.append(userMessage)
            state.messages.append(assistantTextMessage)

            state.composerText = ""
            state.composerMode = .text
            state.isStreaming = true
            state.activeStreamID = streamID
            state.activeAssistantTextMessageID = assistantTextMessage.id
            state.activeRenderID = nil
            state.activeReplayScenario = replayScenario

        case let .streamCancelled(reason):
            if let renderID = state.activeRenderID {
                state = updateRenderStatus(for: renderID, status: .failed, in: state)
                state = updateTakeoverStatus(for: renderID, status: .failed, in: state)
            }
            state.messages.append(ChatMessage.system(reason))
            state = stopStream(in: state)

        case let .streamEvent(streamID, event):
            guard streamID == state.activeStreamID else {
                return state
            }

            switch event {
            case let .assistantTextDelta(_, delta):
                guard let messageID = state.activeAssistantTextMessageID,
                      let index = state.messages.firstIndex(where: { $0.id == messageID }),
                      case let .text(existing) = state.messages[index].content
                else {
                    return state
                }

                state.messages[index].content = .text(existing + delta)

            case .assistantTextDone:
                break

            case let .renderStarted(renderID, initialSpec, initialData):
                if renderPayloads[renderID] == nil {
                    let submitTargets = SubmitActionInspector.inspect(spec: initialSpec)

                    renderPayloads[renderID] = AssistantRenderPayload(
                        renderID: renderID,
                        initialSpec: initialSpec,
                        initialData: initialData,
                        submitTargets: submitTargets,
                        replayScenario: state.activeReplayScenario,
                        onAction: { [weak self] callbackRenderID, action in
                            Task { @MainActor [weak self] in
                                guard let self else { return }
                                self.send(.handleRenderAction(renderID: callbackRenderID, action: action))
                            }
                        }
                    )
                }

                renderPayloads[renderID]?.appendRawEvent(event)
                state.activeRenderID = renderID

                let submitTargets = renderPayloads[renderID]?.submitTargets ?? []
                if submitTargets.count == 1 {
                    state.composerMode = .takeover(
                        TakeoverComposerState(
                            renderID: renderID,
                            submitTargets: submitTargets,
                            status: .streaming,
                            replayScenario: state.activeReplayScenario
                        )
                    )
                } else {
                    state = ensureAssistantRenderMessage(
                        for: renderID,
                        status: .streaming,
                        in: state
                    )
                }

                state = appendEventLog(event, toAssistantRenderMessage: renderID, in: state)

            case let .renderPatch(renderID, patch):
                renderPayloads[renderID]?.append(patch: patch)
                renderPayloads[renderID]?.appendRawEvent(event)
                state = appendEventLog(event, toAssistantRenderMessage: renderID, in: state)

                if patch.path == "/root" {
                    state.messages.append(ChatMessage.system("Render root changed by patch stream."))
                }

            case let .renderDone(renderID):
                renderPayloads[renderID]?.appendRawEvent(event)
                renderPayloads[renderID]?.finishStream()
                state = appendEventLog(event, toAssistantRenderMessage: renderID, in: state)
                state = updateRenderStatus(for: renderID, status: .complete, in: state)
                state = updateTakeoverStatus(for: renderID, status: .complete, in: state)

            case let .guardrail(issue):
                state = appendIssue(issue, in: state)

            case let .error(message):
                state.messages.append(ChatMessage.system(message, level: .error))
                if let renderID = state.activeRenderID {
                    renderPayloads[renderID]?.finishStream()
                    state = updateRenderStatus(for: renderID, status: .failed, in: state)
                    state = updateTakeoverStatus(for: renderID, status: .failed, in: state)
                }
                if state.mode == .localLive {
                    state.messages.append(
                        ChatMessage.system(
                            "Local live stream failed. Switch to Replay mode to continue deterministic testing.",
                            level: .warning
                        )
                    )
                }

            case .done:
                if let renderID = state.activeRenderID {
                    renderPayloads[renderID]?.finishStream()
                    state = updateRenderStatus(for: renderID, status: .complete, in: state)
                    state = updateTakeoverStatus(for: renderID, status: .complete, in: state)
                }
                state = stopStream(in: state)
            }

        case let .diagnostics(_, issues):
            for issue in issues {
                state = appendIssue(issue, in: state)
            }

        case let .actionResult(result):
            state.messages.append(ChatMessage.system(result))

        case let .takeoverDismissed(renderID, status):
            state = ensureAssistantRenderMessage(for: renderID, status: status, in: state)
            state.composerMode = .text

        case let .takeoverSubmitted(renderID, _, assistantFollowup):
            state.messages.append(ChatMessage.userRender(renderID: renderID, status: .complete))
            state.composerMode = .text

            if let assistantFollowup,
               !assistantFollowup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                state.messages.append(ChatMessage.assistantText(assistantFollowup))
            }

        case .sessionCleared:
            state = ChatHarnessState()
        }

        return state
    }

    var messages: [ChatMessage] {
        currentState.messages
    }

    var composerText: String {
        currentState.composerText
    }

    var composerMode: ComposerMode {
        currentState.composerMode
    }

    var takeoverComposerState: TakeoverComposerState? {
        if case let .takeover(takeover) = currentState.composerMode {
            return takeover
        }

        return nil
    }

    var canSubmitTakeoverFromComposer: Bool {
        takeoverComposerState?.hasSingleSubmitTarget == true
    }

    var streamMode: StreamMode {
        currentState.mode
    }

    var selectedReplayScenario: ReplayScenario {
        currentState.selectedReplayScenario
    }

    var isStreaming: Bool {
        currentState.isStreaming
    }

    var showsDebugControls: Bool {
        debugControlsEnabled
    }

    func payload(for renderID: String) -> AssistantRenderPayload? {
        renderPayloads[renderID]
    }

    func updateComposer(_ text: String) {
        currentState.composerText = text
        send(.composerChanged(text))
    }

    func switchMode(_ mode: StreamMode) {
        send(.switchMode(mode))
    }

    func selectReplayScenario(_ scenario: ReplayScenario) {
        send(.selectReplayScenario(scenario))
    }

    func sendPrompt() {
        send(.sendPrompt(currentState.composerText))
    }

    func cancelStream() {
        send(.cancelStream)
    }

    func clearSession() {
        send(.clearSession)
    }

    func dismissTakeover() {
        send(.dismissTakeover)
    }

    func submitTakeoverFromComposer() {
        send(.submitTakeoverFromComposer)
    }

    func receiveDiagnostics(renderID: String, issues: [GuardrailIssue]) {
        send(.receiveDiagnostics(renderID: renderID, issues: issues))
    }

    private func startStream(
        prompt: String,
        streamID: UUID,
        replayScenario: ReplayScenario?
    ) {
        let mode = currentState.mode
        let client: ChatStreamClient

        switch mode {
        case .replay:
            client = replayClientFactory(replayScenario ?? currentState.selectedReplayScenario)
        case .localLive:
            client = localSSEClient
        }

        streamTask?.cancel()
        streamTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                let stream = client.stream(prompt: prompt, sessionID: streamID)
                for try await event in stream {
                    if Task.isCancelled { break }
                    self.send(.receiveEvent(streamID: streamID, event: event))
                }
            } catch {
                self.send(.receiveEvent(streamID: streamID, event: .error(message: error.localizedDescription)))
                self.send(.receiveEvent(streamID: streamID, event: .done))
            }
        }
    }

    private func stopStream(in state: ChatHarnessState) -> ChatHarnessState {
        var state = state
        state.isStreaming = false
        state.activeStreamID = nil
        state.activeAssistantTextMessageID = nil
        state.activeRenderID = nil
        state.activeReplayScenario = nil
        return state
    }

    private func ensureAssistantRenderMessage(
        for renderID: String,
        status: AssistantRenderStatus,
        in state: ChatHarnessState
    ) -> ChatHarnessState {
        var state = state

        guard !state.messages.contains(where: { message in
            guard message.kind == .assistantRender,
                  case let .render(content) = message.content
            else {
                return false
            }

            return content.renderID == renderID
        }) else {
            return state
        }

        var message = ChatMessage.assistantRender(renderID: renderID, status: status)
        if case var .render(content) = message.content {
            content.rawEvents = renderPayloads[renderID]?.rawEvents ?? []
            message.content = .render(content)
        }

        state.messages.append(message)
        return state
    }

    private func appendEventLog(
        _ event: ChatStreamEvent,
        toAssistantRenderMessage renderID: String,
        in state: ChatHarnessState
    ) -> ChatHarnessState {
        var state = state

        guard let index = state.messages.firstIndex(where: { message in
            guard message.kind == .assistantRender,
                  case let .render(content) = message.content
            else {
                return false
            }
            return content.renderID == renderID
        }), case var .render(content) = state.messages[index].content else {
            return state
        }

        content.rawEvents.append(ChatStreamEventLogEntry(summary: event.logSummary))
        state.messages[index].content = .render(content)
        return state
    }

    private func updateRenderStatus(
        for renderID: String,
        status: AssistantRenderStatus,
        in state: ChatHarnessState
    ) -> ChatHarnessState {
        var state = state

        guard let index = state.messages.firstIndex(where: { message in
            guard message.kind == .assistantRender,
                  case let .render(content) = message.content
            else {
                return false
            }
            return content.renderID == renderID
        }), case var .render(content) = state.messages[index].content else {
            return state
        }

        content.status = status
        state.messages[index].content = .render(content)
        return state
    }

    private func updateTakeoverStatus(
        for renderID: String,
        status: AssistantRenderStatus,
        in state: ChatHarnessState
    ) -> ChatHarnessState {
        var state = state

        guard case var .takeover(takeover) = state.composerMode,
              takeover.renderID == renderID
        else {
            return state
        }

        takeover.status = status
        state.composerMode = .takeover(takeover)
        return state
    }

    private func appendIssue(_ issue: GuardrailIssue, in state: ChatHarnessState) -> ChatHarnessState {
        var state = state

        // Keep action narration in transcript via action handler callbacks.
        // Diagnostics are reserved for guardrails and actionable warnings/errors.
        if issue.severity == .info {
            return state
        }

        let fingerprint = Self.issueFingerprint(issue)

        guard !state.reportedIssueFingerprints.contains(fingerprint) else {
            return state
        }

        state.reportedIssueFingerprints.insert(fingerprint)
        let level = Self.level(for: issue.severity)
        let pathSuffix = issue.path.map { " (\($0))" } ?? ""
        state.messages.append(ChatMessage.system("\(issue.message)\(pathSuffix)", level: level))

        return state
    }

    private static func issueFingerprint(_ issue: GuardrailIssue) -> String {
        "\(issue.severity.rawValue)|\(issue.path ?? "")|\(issue.message)"
    }

    private static func level(for severity: GuardrailSeverity) -> SystemMessageLevel {
        switch severity {
        case .info:
            return .info
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }

    private static func resolveReplayScenario(
        for prompt: String,
        fallback: ReplayScenario
    ) -> ReplayScenario {
        let normalized = prompt.lowercased()

        if normalized.contains("guardrail") ||
            normalized.contains("unsupported") ||
            normalized.contains("invalid") {
            return .guardrail
        }

        if normalized.contains("form") ||
            normalized.contains("submit") ||
            normalized.contains("checkout") ||
            normalized.contains("profile") ||
            normalized.contains("intake") {
            return .generatedForm
        }

        if normalized.contains("support") ||
            normalized.contains("ticket") ||
            normalized.contains("dashboard") ||
            normalized.contains("customer") {
            return .supportDashboard
        }

        return fallback
    }

    private static func followupText(for scenario: ReplayScenario?) -> String? {
        guard let scenario else {
            return nil
        }

        switch scenario {
        case .generatedForm:
            return "Thanks. I captured your submitted UI and queued a deterministic follow-up render for the next turn."
        case .supportDashboard:
            return "Saved. I can stream another deterministic dashboard revision whenever you're ready."
        case .guardrail:
            return "Submission captured. Guardrail diagnostics remain available in the transcript."
        }
    }

    private static func describe(action: RenderAction) -> String {
        switch action {
        case let .openURL(url):
            return "Action: open_url -> \(url)"

        case let .logEvent(name, payload):
            let keys = payload.keys.sorted().joined(separator: ",")
            return "Action: log_event -> \(name) [\(keys)]"

        case let .setData(path, value):
            return "Action: set_data -> \(path.canonicalPointer) = \(value.debugDescription)"

        case let .submit(payload):
            let keys = payload.keys.sorted().joined(separator: ",")
            return "Action: submit -> [\(keys)]"
        }
    }
}

private extension JSONValue {
    var debugDescription: String {
        switch self {
        case let .string(value):
            return value
        case let .number(value):
            return String(value)
        case let .bool(value):
            return String(value)
        case let .object(value):
            return "object(\(value.keys.sorted().joined(separator: ",")))"
        case let .array(value):
            return "array(\(value.count))"
        case .null:
            return "null"
        }
    }
}

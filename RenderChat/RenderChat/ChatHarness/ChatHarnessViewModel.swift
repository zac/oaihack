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
        case switchMode(StreamMode)
        case selectReplayScenario(ReplayScenario)
        case receiveEvent(streamID: UUID, event: ChatStreamEvent)
        case receiveDiagnostics(renderID: String, issues: [GuardrailIssue])
        case recordActionResult(String)
    }

    enum Mutation: Sendable {
        case composerChanged(String)
        case modeChanged(StreamMode, cancelledStream: Bool)
        case replayScenarioChanged(ReplayScenario)
        case streamStarted(
            streamID: UUID,
            userMessage: ChatMessage,
            assistantTextMessage: ChatMessage,
            cancelledPrevious: Bool
        )
        case streamCancelled(reason: String)
        case streamEvent(streamID: UUID, event: ChatStreamEvent)
        case diagnostics(renderID: String, issues: [GuardrailIssue])
        case actionResult(String)
    }

    let initialState = ChatHarnessState()

    @ObservationIgnored
    private let replayClientFactory: (ReplayScenario) -> ChatStreamClient

    @ObservationIgnored
    private let localSSEClient: ChatStreamClient

    @ObservationIgnored
    private var streamTask: Task<Void, Never>?

    @ObservationIgnored
    private var renderPayloads: [String: AssistantRenderPayload] = [:]

    init(
        replayClientFactory: @escaping (ReplayScenario) -> ChatStreamClient = { scenario in
            ReplayChatStreamClient(scenario: scenario)
        },
        localSSEClient: ChatStreamClient = LocalSSEChatStreamClient()
    ) {
        self.replayClientFactory = replayClientFactory
        self.localSSEClient = localSSEClient
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

            let streamID = UUID()
            let userMessage = ChatMessage.userText(prompt)
            let assistantTextMessage = ChatMessage.assistantText()
            startStream(prompt: prompt, streamID: streamID)

            return .just(
                .streamStarted(
                    streamID: streamID,
                    userMessage: userMessage,
                    assistantTextMessage: assistantTextMessage,
                    cancelledPrevious: cancelledPrevious
                )
            )

        case let .receiveEvent(streamID, event):
            return .just(.streamEvent(streamID: streamID, event: event))

        case let .receiveDiagnostics(renderID, issues):
            return .just(.diagnostics(renderID: renderID, issues: issues))

        case let .recordActionResult(result):
            return .just(.actionResult(result))
        }
    }

    func reduce(state: ChatHarnessState, mutation: Mutation) -> ChatHarnessState {
        var state = state

        switch mutation {
        case let .composerChanged(text):
            state.composerText = text

        case let .modeChanged(mode, cancelledStream):
            state.mode = mode

            if cancelledStream {
                state = stopStream(in: state)
                state.messages.append(ChatMessage.system("Cancelled current stream due to mode switch."))
            }

        case let .replayScenarioChanged(scenario):
            state.selectedReplayScenario = scenario

        case let .streamStarted(streamID, userMessage, assistantTextMessage, cancelledPrevious):
            if cancelledPrevious {
                state.messages.append(ChatMessage.system("Cancelled previous stream before starting a new one."))
            }

            state.messages.append(userMessage)
            state.messages.append(assistantTextMessage)

            state.composerText = ""
            state.isStreaming = true
            state.activeStreamID = streamID
            state.activeAssistantTextMessageID = assistantTextMessage.id
            state.activeRenderID = nil

        case let .streamCancelled(reason):
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
                    renderPayloads[renderID] = AssistantRenderPayload(
                        renderID: renderID,
                        initialSpec: initialSpec,
                        initialData: initialData,
                        onAction: { [weak self] action in
                            Task { @MainActor [weak self] in
                                guard let self else { return }
                                self.send(.recordActionResult(Self.describe(action: action)))
                            }
                        }
                    )
                }

                renderPayloads[renderID]?.appendRawEvent(event)
                state = ensureRenderMessage(for: renderID, in: state)
                state = appendEventLog(event, toRenderMessage: renderID, in: state)
                state.activeRenderID = renderID

            case let .renderPatch(renderID, patch):
                renderPayloads[renderID]?.append(patch: patch)
                renderPayloads[renderID]?.appendRawEvent(event)
                state = appendEventLog(event, toRenderMessage: renderID, in: state)

                if patch.path == "/root" {
                    state.messages.append(ChatMessage.system("Render root changed by patch stream."))
                }

            case let .renderDone(renderID):
                renderPayloads[renderID]?.appendRawEvent(event)
                renderPayloads[renderID]?.finishStream()
                state = appendEventLog(event, toRenderMessage: renderID, in: state)
                state = updateRenderStatus(for: renderID, status: .complete, in: state)

            case let .guardrail(issue):
                state = appendIssue(issue, in: state)

            case let .error(message):
                state.messages.append(ChatMessage.system(message, level: .error))
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
                }
                state = stopStream(in: state)
            }

        case let .diagnostics(_, issues):
            for issue in issues {
                state = appendIssue(issue, in: state)
            }

        case let .actionResult(result):
            state.messages.append(ChatMessage.system(result))
        }

        return state
    }

    var messages: [ChatMessage] {
        currentState.messages
    }

    var composerText: String {
        currentState.composerText
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

    func receiveDiagnostics(renderID: String, issues: [GuardrailIssue]) {
        send(.receiveDiagnostics(renderID: renderID, issues: issues))
    }

    func recordActionResult(_ result: String) {
        send(.recordActionResult(result))
    }

    private func startStream(prompt: String, streamID: UUID) {
        let mode = currentState.mode
        let scenario = currentState.selectedReplayScenario
        let client: ChatStreamClient

        switch mode {
        case .replay:
            client = replayClientFactory(scenario)
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
        return state
    }

    private func ensureRenderMessage(for renderID: String, in state: ChatHarnessState) -> ChatHarnessState {
        var state = state
        let exists = state.messages.contains { message in
            guard case let .render(content) = message.content else { return false }
            return content.renderID == renderID
        }

        if !exists {
            state.messages.append(ChatMessage.assistantRender(renderID: renderID))
        }

        return state
    }

    private func appendEventLog(
        _ event: ChatStreamEvent,
        toRenderMessage renderID: String,
        in state: ChatHarnessState
    ) -> ChatHarnessState {
        var state = state

        guard let index = state.messages.firstIndex(where: { message in
            guard case let .render(content) = message.content else { return false }
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
            guard case let .render(content) = message.content else { return false }
            return content.renderID == renderID
        }), case var .render(content) = state.messages[index].content else {
            return state
        }

        content.status = status
        state.messages[index].content = .render(content)
        return state
    }

    private func appendIssue(_ issue: GuardrailIssue, in state: ChatHarnessState) -> ChatHarnessState {
        var state = state
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

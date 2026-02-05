import SwiftUI
import SwiftUIRender

struct ChatHarnessView: View {
    @State private var viewModel: ChatHarnessViewModel
    @State private var composerDraft: String
    @State private var didHandleUITestBootstrap = false

    init(viewModel: ChatHarnessViewModel) {
        _viewModel = State(initialValue: viewModel)
        _composerDraft = State(initialValue: viewModel.composerText)
    }

    @MainActor
    init() {
        self.init(viewModel: ChatHarnessViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.showsDebugControls {
                controls
                Divider()
            }

            transcript
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("RenderChat")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    viewModel.clearSession()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .accessibilityIdentifier("chat-clear-button")
            }
        }
        .safeAreaBar(edge: .bottom) {
            composer
        }
        .onAppear {
            guard didHandleUITestBootstrap == false else {
                return
            }

            didHandleUITestBootstrap = true
            applyUITestBootstrapIfNeeded()
        }
        .onChange(of: composerDraft) { _, newValue in
            guard newValue != viewModel.composerText else {
                return
            }

            viewModel.updateComposer(newValue)
        }
        .onChange(of: viewModel.composerText) { _, newValue in
            guard newValue != composerDraft else {
                return
            }

            composerDraft = newValue
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Picker(
                "Mode",
                selection: Binding(
                    get: { viewModel.streamMode },
                    set: { viewModel.switchMode($0) }
                )
            ) {
                ForEach(StreamMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("chat-mode-picker")

            if viewModel.streamMode == .replay {
                Picker(
                    "Scenario",
                    selection: Binding(
                        get: { viewModel.selectedReplayScenario },
                        set: { viewModel.selectReplayScenario($0) }
                    )
                ) {
                    ForEach(ReplayScenario.allCases) { scenario in
                        Text(scenario.title).tag(scenario)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("chat-replay-picker")
            }
        }
        .padding(12)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        messageRow(message)
                            .id(message.id)
                    }
                }
                .safeAreaPadding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count) {
                guard let lastID = viewModel.messages.last?.id else {
                    return
                }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private func messageRow(_ message: ChatMessage) -> some View {
        switch message.content {
        case let .text(text):
            if message.kind == .userText {
                HStack {
                    Spacer(minLength: 24)
                    TextBubble(text: text, role: .user)
                }
                .accessibilityIdentifier("message-user-\(message.id.uuidString)")
            } else {
                HStack {
                    TextBubble(text: text, role: .assistant)
                    Spacer(minLength: 24)
                }
                .accessibilityIdentifier("message-assistant-text-\(message.id.uuidString)")
            }

        case let .render(content):
            switch message.kind {
            case .userRender:
                HStack {
                    Spacer(minLength: 24)

                    if let payload = viewModel.payload(for: content.renderID) {
                        AssistantRenderBubble(
                            payload: payload,
                            status: content.status,
                            role: .user,
                            onDiagnostics: nil
                        )
                    } else {
                        TextBubble(text: "Render payload unavailable.", role: .system)
                    }
                }
                .accessibilityIdentifier("message-user-render-\(message.id.uuidString)")

            case .assistantRender:
                HStack {
                    if let payload = viewModel.payload(for: content.renderID) {
                        AssistantRenderBubble(
                            payload: payload,
                            status: content.status,
                            role: .assistant,
                            onDiagnostics: { issues in
                                viewModel.receiveDiagnostics(renderID: content.renderID, issues: issues)
                            }
                        )
                    } else {
                        TextBubble(text: "Render payload unavailable.", role: .system)
                    }

                    Spacer(minLength: 24)
                }
                .accessibilityIdentifier("message-assistant-render-\(message.id.uuidString)")

            default:
                EmptyView()
            }

        case let .system(system):
            HStack {
                TextBubble(
                    text: system.text,
                    role: .system,
                    level: system.level
                )
                Spacer(minLength: 24)
            }
            .accessibilityIdentifier("message-system-\(message.id.uuidString)")
        }
    }

    @ViewBuilder
    private var composer: some View {
        switch viewModel.composerMode {
        case .text:
            textComposer

        case let .takeover(takeover):
            takeoverComposer(takeover)
        }
    }

    private var textComposer: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField(
                "Prompt the assistant for a render",
                text: $composerDraft,
                axis: .vertical
            )
            .padding(12)
            .textFieldStyle(.plain)
            .glassEffect(.regular, in: .containerRelative)
            .lineLimit(1 ... 4)
            .accessibilityIdentifier("chat-composer-input")

            if viewModel.isStreaming {
                iconButton(
                    systemName: "stop.fill",
                    accessibilityID: "chat-stop-button",
                    action: viewModel.cancelStream
                )
            } else {
                let canSend = !composerDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                iconButton(
                    systemName: "arrow.up",
                    accessibilityID: "chat-send-button",
                    disabled: !canSend,
                    action: { viewModel.sendPrompt(composerDraft) }
                )
            }
        }
        .padding(.horizontal)
    }

    private func takeoverComposer(_ takeover: TakeoverComposerState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Generated UI Composer")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Button {
                    viewModel.dismissTakeover()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chat-takeover-close-button")
            }

            if let payload = viewModel.payload(for: takeover.renderID) {
                CappedScrollContainer(maxHeight: 360) {
                    AssistantRenderBubble(
                        payload: payload,
                        status: takeover.status,
                        role: .composer,
                        onDiagnostics: { issues in
                            viewModel.receiveDiagnostics(renderID: takeover.renderID, issues: issues)
                        }
                    )
                    .accessibilityIdentifier("chat-takeover-render")
                }
            } else {
                TextBubble(text: "Render payload unavailable.", role: .system)
            }

            if viewModel.canSubmitTakeoverFromComposer {
                HStack {
                    Spacer(minLength: 0)
                    iconButton(
                        systemName: "arrow.up",
                        accessibilityID: "chat-takeover-submit-button",
                        action: viewModel.submitTakeoverFromComposer
                    )
                }
            }
        }
        .padding(.horizontal)
    }

    private func iconButton(
        systemName: String,
        accessibilityID: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.black)
                .frame(width: 36, height: 36)
                .background(Color.white, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.14), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .opacity(disabled ? 0.4 : 1.0)
        .disabled(disabled)
        .accessibilityIdentifier(accessibilityID)
    }

    private func applyUITestBootstrapIfNeeded() {
        let environment = ProcessInfo.processInfo.environment

        if let modeRaw = environment["UITEST_MODE"],
           let mode = StreamMode(rawValue: modeRaw) {
            viewModel.switchMode(mode)
        }

        if let scenarioRaw = environment["UITEST_REPLAY_SCENARIO"],
           let scenario = ReplayScenario(rawValue: scenarioRaw) {
            viewModel.selectReplayScenario(scenario)
        }

        if let prompt = environment["UITEST_AUTOSEND_PROMPT"],
           !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            composerDraft = prompt
            viewModel.updateComposer(prompt)
            viewModel.sendPrompt(prompt)
        }
    }
}

private enum BubbleRole {
    case user
    case assistant
    case system
}

private struct TextBubble: View {
    let text: String
    let role: BubbleRole
    var level: SystemMessageLevel = .info

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(strokeColor, lineWidth: role == .system ? 1 : 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var background: some ShapeStyle {
        switch role {
        case .user:
            return AnyShapeStyle(.tint)
        case .assistant:
            return AnyShapeStyle(.thinMaterial)
        case .system:
            switch level {
            case .info:
                return AnyShapeStyle(Color.blue.opacity(0.12))
            case .warning:
                return AnyShapeStyle(Color.orange.opacity(0.16))
            case .error:
                return AnyShapeStyle(Color.red.opacity(0.16))
            }
        }
    }

    private var strokeColor: Color {
        switch level {
        case .info:
            return .blue.opacity(0.35)
        case .warning:
            return .orange.opacity(0.45)
        case .error:
            return .red.opacity(0.45)
        }
    }

    private var foregroundColor: Color {
        switch role {
        case .user:
            return .white
        case .assistant:
            return .primary
        case .system:
            switch level {
            case .info:
                return .blue
            case .warning:
                return .orange
            case .error:
                return .red
            }
        }
    }
}

private struct CappedScrollContainer<Content: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder let content: () -> Content

    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            content()
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: CappedScrollHeightPreferenceKey.self,
                            value: proxy.size.height
                        )
                    }
                )
        }
        .scrollIndicators(.visible)
        .scrollDisabled(contentHeight <= maxHeight)
        .frame(height: effectiveHeight)
        .onPreferenceChange(CappedScrollHeightPreferenceKey.self) { contentHeight = $0 }
    }

    private var effectiveHeight: CGFloat {
        let measured = contentHeight > 0 ? contentHeight : 220
        return min(measured, maxHeight)
    }
}

private struct CappedScrollHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview("Chat Harness") {
    NavigationStack {
        ChatHarnessView()
    }
    .frame(minWidth: 420, minHeight: 780)
}

#Preview("Chat Harness - Completed Replay") {
    NavigationStack {
        ChatHarnessView(viewModel: ChatHarnessPreviewFactory.completedReplay())
    }
    .frame(minWidth: 420, minHeight: 780)
}

#Preview("Chat Harness - Streaming Replay") {
    NavigationStack {
        ChatHarnessView(viewModel: ChatHarnessPreviewFactory.streamingReplay())
    }
    .frame(minWidth: 420, minHeight: 780)
}

#Preview("Chat Harness - Local Live Error") {
    NavigationStack {
        ChatHarnessView(viewModel: ChatHarnessPreviewFactory.localLiveError())
    }
    .frame(minWidth: 420, minHeight: 780)
}

@MainActor
private enum ChatHarnessPreviewFactory {
    static func completedReplay() -> ChatHarnessViewModel {
        let renderID = "preview-render-complete"
        let payload = makeSupportPayload(renderID: renderID, streaming: false)

        var state = ChatHarnessState()
        state.mode = .replay
        state.selectedReplayScenario = .supportDashboard
        state.composerText = "Show me guardrail behavior next."
        state.messages = [
            ChatMessage.system("Replay mode loaded deterministic stream fixtures."),
            ChatMessage.userText("Show me a support dashboard."),
            ChatMessage.assistantText(
                "I rendered a support dashboard from deterministic JSON patches. You can edit the customer name or press Save."
            ),
            makeRenderMessage(
                renderID: renderID,
                kind: .assistantRender,
                status: .complete,
                summaries: [
                    "render_started(\(renderID))",
                    "render_patch(\(renderID)) replace /elements/subtitle/props/text",
                    "render_done(\(renderID))",
                ]
            ),
            ChatMessage.system("Action: set_data -> /customer/saved = true"),
        ]

        return ChatHarnessViewModel(
            initialState: state,
            initialRenderPayloads: [renderID: payload]
        )
    }

    static func streamingReplay() -> ChatHarnessViewModel {
        let renderID = "preview-render-streaming"
        let payload = makeSupportPayload(renderID: renderID, streaming: true)

        let user = ChatMessage.userText("Build a ticket triage UI for this customer.")
        let assistant = ChatMessage.assistantText("Streaming response: I started with profile fields and quick actions.")
        let render = makeRenderMessage(
            renderID: renderID,
            kind: .assistantRender,
            status: .streaming,
            summaries: [
                "render_started(\(renderID))",
                "render_patch(\(renderID)) replace /elements/subtitle/props/text",
            ]
        )

        var state = ChatHarnessState()
        state.mode = .replay
        state.selectedReplayScenario = .supportDashboard
        state.messages = [
            user,
            assistant,
            render,
            ChatMessage.system("Streaming deterministic patch sequence..."),
        ]
        state.composerText = "Add ticket timeline and escalation button"
        state.isStreaming = true
        state.activeStreamID = UUID()
        state.activeAssistantTextMessageID = assistant.id
        state.activeRenderID = renderID

        return ChatHarnessViewModel(
            initialState: state,
            initialRenderPayloads: [renderID: payload]
        )
    }

    static func localLiveError() -> ChatHarnessViewModel {
        let renderID = "preview-render-failed"
        let payload = makeSupportPayload(renderID: renderID, streaming: false)

        var state = ChatHarnessState()
        state.mode = .localLive
        state.messages = [
            ChatMessage.userText("Connect to local stream and generate a billing summary."),
            ChatMessage.assistantText("Attempting local SSE connection and render setup."),
            makeRenderMessage(
                renderID: renderID,
                kind: .assistantRender,
                status: .failed,
                summaries: [
                    "render_started(\(renderID))",
                    "error: Failed to decode SSE event: missing key 'initialSpec'",
                ]
            ),
            ChatMessage.system("Failed to decode SSE event: missing key 'initialSpec'", level: .error),
            ChatMessage.system(
                "Local live stream failed. Switch to Replay mode to continue deterministic testing.",
                level: .warning
            ),
        ]
        state.composerText = "Use replay mode fallback"

        return ChatHarnessViewModel(
            initialState: state,
            initialRenderPayloads: [renderID: payload]
        )
    }

    private static func makeRenderMessage(
        renderID: String,
        kind: ChatMessageKind,
        status: AssistantRenderStatus,
        summaries: [String]
    ) -> ChatMessage {
        var message: ChatMessage

        switch kind {
        case .assistantRender:
            message = ChatMessage.assistantRender(renderID: renderID, status: status)
        case .userRender:
            message = ChatMessage.userRender(renderID: renderID, status: status)
        default:
            message = ChatMessage.assistantRender(renderID: renderID, status: status)
        }

        guard case var .render(content) = message.content else {
            return message
        }

        content.status = status
        content.rawEvents = summaries.map { ChatStreamEventLogEntry(summary: $0) }
        message.content = .render(content)
        return message
    }

    private static func makeSupportPayload(
        renderID: String,
        streaming: Bool
    ) -> AssistantRenderPayload {
        let initialData: JSONValue = .object([
            "customer": .object([
                "name": .string("Ava"),
                "saved": .bool(false),
            ]),
        ])
        let initialSpec = supportSpec()
        let payload = AssistantRenderPayload(
            renderID: renderID,
            initialSpec: initialSpec,
            initialData: initialData,
            submitTargets: SubmitActionInspector.inspect(spec: initialSpec),
            onAction: { _, _ in }
        )

        let subtitlePatch = SpecPatch(
            op: .replace,
            path: "/elements/subtitle/props/text",
            value: .string("Ticket #1842 - Resolved")
        )

        payload.appendRawEvent(
            .renderStarted(messageID: renderID, initialSpec: initialSpec, initialData: initialData)
        )
        payload.append(patch: subtitlePatch)
        payload.appendRawEvent(.renderPatch(messageID: renderID, patch: subtitlePatch))

        if streaming == false {
            payload.appendRawEvent(.renderDone(messageID: renderID))
            payload.finishStream()
        }

        return payload
    }

    private static func supportSpec() -> UISpec {
        UISpec(
            root: "root",
            elements: [
                "root": UIElement(
                    type: "root",
                    children: ["children": ["title", "subtitle", "nameField", "saveButton"]]
                ),
                "title": UIElement(
                    type: "text",
                    parentKey: "root",
                    props: ["text": .string("Support Dashboard")],
                    styles: [
                        "font-size": .number(24),
                        "font-weight": .string("bold"),
                    ]
                ),
                "subtitle": UIElement(
                    type: "text",
                    parentKey: "root",
                    props: ["text": .string("Ticket #1842 - Pending")],
                    styles: ["color": .string("secondary")]
                ),
                "nameField": UIElement(
                    type: "text-field",
                    parentKey: "root",
                    props: [
                        "placeholder": .string("Customer name"),
                        "binding": .string("$data.customer.name"),
                    ]
                ),
                "saveButton": UIElement(
                    type: "button",
                    parentKey: "root",
                    props: [
                        "text": .string("Save Customer"),
                        "action": .object([
                            "name": .string("set_data"),
                            "params": .object([
                                "path": .string("$data.customer.saved"),
                                "value": .bool(true),
                            ]),
                        ]),
                    ]
                ),
            ]
        )
    }
}

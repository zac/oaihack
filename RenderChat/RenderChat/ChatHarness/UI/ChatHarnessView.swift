import SwiftUI
import SwiftUIRender

struct ChatHarnessView: View {
    @State private var viewModel: ChatHarnessViewModel
    @State private var didHandleUITestBootstrap = false

    init(viewModel: ChatHarnessViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    @MainActor
    init() {
        self.init(viewModel: ChatHarnessViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            transcript
        }
        .navigationTitle("RenderChat")
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
            HStack {
                if let payload = viewModel.payload(for: content.renderID) {
                    AssistantRenderBubble(
                        payload: payload,
                        status: content.status,
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

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField(
                "Prompt the assistant for a render",
                text: Binding(
                    get: { viewModel.composerText },
                    set: { viewModel.updateComposer($0) }
                ),
                axis: .vertical
            )
            .padding()
            .textFieldStyle(.plain)
            .glassEffect(.regular, in: .containerRelative)
            .lineLimit(1 ... 4)
            .accessibilityIdentifier("chat-composer-input")

            if viewModel.isStreaming {
                Button("Cancel") {
                    viewModel.cancelStream()
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("chat-cancel-button")
            }

            Button("Send") {
                viewModel.sendPrompt()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("chat-send-button")
        }
        .padding(.horizontal)
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
            viewModel.updateComposer(prompt)
            viewModel.sendPrompt()
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

struct MessageEntryView: View {
    @Binding var message: String

    var body: some View {
        TextField(text: $message, prompt: Text("Enter your message...")) {
            Text("HI")
        }
        .padding()
        .glassEffect(.regular, in: .capsule)
        .padding()
    }
}

struct ChatView: View {
    @State private var text: String = ""
    var body: some View {
        ScrollView {
            VStack {
                Spacer()
                Text("HI")
            }
        }
        .safeAreaBar(edge: .bottom) {
            MessageEntryView(message: $text)
        }
    }
}

#Preview("Simplified Harness") {
    NavigationStack {
        ChatView()
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
        status: AssistantRenderStatus,
        summaries: [String]
    ) -> ChatMessage {
        var message = ChatMessage.assistantRender(renderID: renderID)
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
            onAction: { _ in }
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

import SwiftUI

struct ChatHarnessView: View {
    @State private var viewModel = ChatHarnessViewModel()
    @State private var didHandleUITestBootstrap = false

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            transcript
            Divider()
            composer
        }
        .navigationTitle("RenderChat")
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
                .padding(12)
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
            .textFieldStyle(.roundedBorder)
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
        .padding(12)
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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(strokeColor, lineWidth: role == .system ? 1 : 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

#Preview("Chat Harness") {
    NavigationStack {
        ChatHarnessView()
    }
    .frame(minWidth: 420, minHeight: 780)
}

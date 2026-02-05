import SwiftUI
import SwiftUIRender

enum RenderBubbleRole {
    case assistant
    case user
    case composer
}

struct AssistantRenderBubble: View {
    let payload: AssistantRenderPayload
    let status: AssistantRenderStatus
    let role: RenderBubbleRole
    var onDiagnostics: (([GuardrailIssue]) -> Void)?

    @State private var showDebugJSON = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(roleLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())

                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(statusColor)

                Spacer(minLength: 0)

                Button(showDebugJSON ? "Hide Debug" : "Debug JSON") {
                    showDebugJSON.toggle()
                }
                .font(.caption)
                .buttonStyle(.plain)
                .accessibilityIdentifier("render-debug-toggle-\(payload.renderID)")
            }

            RenderView(
                source: payload.source,
                configuration: payload.configuration,
                diagnostics: payload.diagnostics
            )
            .frame(minHeight: 160)

            if showDebugJSON {
                VStack(alignment: .leading, spacing: 10) {
                    debugSection(title: "Initial Spec", content: payload.debugInitialSpecJSON)
                    debugSection(title: "Initial Data", content: payload.debugInitialDataJSON)
                    debugSection(title: "Patch Sequence", content: payload.debugPatchSequenceJSON)
                    debugSection(title: "Submit Payload", content: payload.debugLatestSubmitPayloadJSON)
                    debugEvents
                }
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .accessibilityIdentifier("render-bubble-\(roleAccessibility)-\(payload.renderID)")
        .onAppear {
            emitNewDiagnostics()
        }
        .onChange(of: payload.diagnostics.issues.count) {
            emitNewDiagnostics()
        }
    }

    private var roleLabel: String {
        switch role {
        case .assistant:
            return "Assistant Render"
        case .user:
            return "Submitted View"
        case .composer:
            return "Composer Render"
        }
    }

    private var roleAccessibility: String {
        switch role {
        case .assistant:
            return "assistant"
        case .user:
            return "user"
        case .composer:
            return "composer"
        }
    }

    private var backgroundStyle: AnyShapeStyle {
        switch role {
        case .assistant, .composer:
            return AnyShapeStyle(.ultraThinMaterial)
        case .user:
            return AnyShapeStyle(Color.accentColor.opacity(0.12))
        }
    }

    private var borderColor: Color {
        switch role {
        case .assistant, .composer:
            return .secondary.opacity(0.2)
        case .user:
            return .accentColor.opacity(0.4)
        }
    }

    private var statusLabel: String {
        switch status {
        case .streaming:
            return "Streaming"
        case .complete:
            return "Complete"
        case .failed:
            return "Failed"
        }
    }

    private var statusColor: Color {
        switch status {
        case .streaming:
            return .secondary
        case .complete:
            return .green
        case .failed:
            return .red
        }
    }

    @ViewBuilder
    private func debugSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal) {
                Text(content)
                    .font(.caption2.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
        }
    }

    private var debugEvents: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Stream Events")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(payload.rawEvents) { event in
                    Text(event.summary)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func emitNewDiagnostics() {
        guard let onDiagnostics else {
            return
        }

        let issues = payload.consumeNewIssues()
        guard !issues.isEmpty else {
            return
        }

        onDiagnostics(issues)
    }
}

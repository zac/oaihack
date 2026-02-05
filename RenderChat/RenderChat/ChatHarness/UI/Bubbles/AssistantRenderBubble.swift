import SwiftUI
import SwiftUIRender

struct AssistantRenderBubble: View {
    let payload: AssistantRenderPayload
    let status: AssistantRenderStatus
    let onDiagnostics: ([GuardrailIssue]) -> Void

    @State private var showRawEvents = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Render")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())

                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            RenderView(
                source: payload.source,
                configuration: payload.configuration,
                diagnostics: payload.diagnostics
            )
            .frame(minHeight: 160)

            Button(showRawEvents ? "Hide Stream Events" : "Show Stream Events") {
                showRawEvents.toggle()
            }
            .font(.caption)
            .buttonStyle(.plain)

            if showRawEvents {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(payload.rawEvents) { event in
                        Text(event.summary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
        .accessibilityIdentifier("assistant-render-bubble-\(payload.renderID)")
        .onAppear {
            emitNewDiagnostics()
        }
        .onChange(of: payload.diagnostics.issues.count) {
            emitNewDiagnostics()
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

    private func emitNewDiagnostics() {
        let issues = payload.consumeNewIssues()
        guard !issues.isEmpty else {
            return
        }

        onDiagnostics(issues)
    }
}

import Foundation

enum StreamMode: String, CaseIterable, Sendable, Identifiable {
    case replay
    case localLive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .replay:
            return "Replay"
        case .localLive:
            return "Local Live"
        }
    }
}

enum ReplayScenario: String, CaseIterable, Sendable, Identifiable {
    case supportDashboard
    case guardrail

    var id: String { rawValue }

    var title: String {
        switch self {
        case .supportDashboard:
            return "Support Dashboard"
        case .guardrail:
            return "Guardrail"
        }
    }
}

struct ChatHarnessState: Sendable {
    var messages: [ChatMessage] = []
    var composerText: String = ""

    var mode: StreamMode = .replay
    var selectedReplayScenario: ReplayScenario = .supportDashboard

    var isStreaming: Bool = false
    var activeStreamID: UUID?
    var activeAssistantTextMessageID: UUID?
    var activeRenderID: String?

    var reportedIssueFingerprints: Set<String> = []
}

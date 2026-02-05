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
    case generatedForm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .supportDashboard:
            return "Support Dashboard"
        case .guardrail:
            return "Guardrail"
        case .generatedForm:
            return "Generated Form"
        }
    }
}

enum ComposerMode: Sendable, Equatable {
    case text
    case takeover(TakeoverComposerState)
}

struct TakeoverComposerState: Sendable, Equatable {
    var renderID: String
    var submitTargets: [SubmitActionTarget]
    var status: AssistantRenderStatus
    var replayScenario: ReplayScenario?

    var hasSingleSubmitTarget: Bool {
        submitTargets.count == 1
    }

    var singleSubmitTarget: SubmitActionTarget? {
        hasSingleSubmitTarget ? submitTargets.first : nil
    }
}

@Observable
class ChatHarnessState: Sendable {
    var messages: [ChatMessage] = []
    var composerText: String = ""
    var composerMode: ComposerMode = .text

    var mode: StreamMode = .replay
    var selectedReplayScenario: ReplayScenario = .supportDashboard

    var isStreaming: Bool = false
    var activeStreamID: UUID?
    var activeAssistantTextMessageID: UUID?
    var activeRenderID: String?
    var activeReplayScenario: ReplayScenario?

    var reportedIssueFingerprints: Set<String> = []
}

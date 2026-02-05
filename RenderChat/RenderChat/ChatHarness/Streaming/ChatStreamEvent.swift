import Foundation
import SwiftUIRender

enum ChatStreamEvent: Sendable, Equatable {
    case assistantTextDelta(messageID: String, delta: String)
    case assistantTextDone(messageID: String)
    case renderStarted(messageID: String, initialSpec: UISpec, initialData: JSONValue)
    case renderPatch(messageID: String, patch: SpecPatch)
    case renderDone(messageID: String)
    case guardrail(GuardrailIssue)
    case error(message: String)
    case done
}

struct ChatStreamEventLogEntry: Identifiable, Sendable, Equatable {
    let id: UUID
    let timestamp: Date
    let summary: String

    init(id: UUID = UUID(), timestamp: Date = Date(), summary: String) {
        self.id = id
        self.timestamp = timestamp
        self.summary = summary
    }
}

extension ChatStreamEvent {
    var logSummary: String {
        switch self {
        case let .assistantTextDelta(messageID, delta):
            return "assistant_text_delta(\(messageID)): \(delta)"
        case let .assistantTextDone(messageID):
            return "assistant_text_done(\(messageID))"
        case let .renderStarted(messageID, _, _):
            return "render_started(\(messageID))"
        case let .renderPatch(messageID, patch):
            return "render_patch(\(messageID)) \(patch.op.rawValue) \(patch.path)"
        case let .renderDone(messageID):
            return "render_done(\(messageID))"
        case let .guardrail(issue):
            return "guardrail(\(issue.severity.rawValue)): \(issue.message)"
        case let .error(message):
            return "error: \(message)"
        case .done:
            return "done"
        }
    }
}

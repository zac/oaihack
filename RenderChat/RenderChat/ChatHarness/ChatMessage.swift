import Foundation
import Observation
import SwiftUIRender

enum ChatMessageKind: String, Sendable {
    case userText
    case assistantText
    case assistantRender
    case system
}

enum SystemMessageLevel: String, Sendable {
    case info
    case warning
    case error
}

enum AssistantRenderStatus: String, Sendable {
    case streaming
    case complete
    case failed
}

struct SystemMessageContent: Sendable, Equatable {
    var level: SystemMessageLevel
    var text: String
}

struct AssistantRenderMessageContent: Sendable, Equatable {
    var renderID: String
    var status: AssistantRenderStatus
    var rawEvents: [ChatStreamEventLogEntry]
}

enum ChatMessageContent: Sendable, Equatable {
    case text(String)
    case render(AssistantRenderMessageContent)
    case system(SystemMessageContent)
}

struct ChatMessage: Identifiable, Sendable, Equatable {
    let id: UUID
    let createdAt: Date
    let kind: ChatMessageKind
    var content: ChatMessageContent

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        kind: ChatMessageKind,
        content: ChatMessageContent
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.content = content
    }

    static func userText(_ text: String) -> ChatMessage {
        ChatMessage(kind: .userText, content: .text(text))
    }

    static func assistantText(_ text: String = "") -> ChatMessage {
        ChatMessage(kind: .assistantText, content: .text(text))
    }

    static func assistantRender(renderID: String) -> ChatMessage {
        ChatMessage(
            kind: .assistantRender,
            content: .render(
                AssistantRenderMessageContent(
                    renderID: renderID,
                    status: .streaming,
                    rawEvents: []
                )
            )
        )
    }

    static func system(_ text: String, level: SystemMessageLevel = .info) -> ChatMessage {
        ChatMessage(kind: .system, content: .system(SystemMessageContent(level: level, text: text)))
    }
}

@MainActor
@Observable
final class AssistantRenderPayload: Identifiable {
    let id: String
    let renderID: String
    let diagnostics: RenderDiagnostics
    let source: RenderSource
    let configuration: RenderConfiguration

    private let patchContinuation: AsyncStream<SpecPatch>.Continuation
    private var emittedIssueIDs: Set<String> = []

    var rawEvents: [ChatStreamEventLogEntry] = []

    init(
        renderID: String,
        initialSpec: UISpec,
        initialData: JSONValue,
        onAction: @escaping @Sendable (RenderAction) -> Void
    ) {
        self.id = renderID
        self.renderID = renderID

        let patchStream = AsyncStream<SpecPatch>.makeStream()
        patchContinuation = patchStream.continuation
        source = .patchStream(initial: initialSpec, patches: AnySpecPatchSequence(patchStream.stream))
        diagnostics = RenderDiagnostics()
        configuration = RenderConfiguration(
            initialData: initialData,
            actionHandler: TranscriptActionRelay(onAction: onAction)
        )
    }

    func append(patch: SpecPatch) {
        patchContinuation.yield(patch)
    }

    func finishStream() {
        patchContinuation.finish()
    }

    func appendRawEvent(_ event: ChatStreamEvent) {
        rawEvents.append(ChatStreamEventLogEntry(summary: event.logSummary))
    }

    func consumeNewIssues() -> [GuardrailIssue] {
        diagnostics.issues.filter { issue in
            emittedIssueIDs.insert(issue.id).inserted
        }
    }
}

private final class TranscriptActionRelay: RenderActionHandler, @unchecked Sendable {
    private let onAction: @Sendable (RenderAction) -> Void

    init(onAction: @escaping @Sendable (RenderAction) -> Void) {
        self.onAction = onAction
    }

    func handle(action: RenderAction, context: RenderActionContext) async {
        _ = context
        await MainActor.run {
            onAction(action)
        }
    }
}

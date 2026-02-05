import Foundation

struct GraphDelta: Sendable {
    var rootKey: String
    var updatedNodes: [String: RenderNode]
    var removedKeys: Set<String>
    var issues: [GuardrailIssue]
}

struct PatchApplyOutcome: Sendable {
    var delta: GraphDelta?
    var issues: [GuardrailIssue]
}

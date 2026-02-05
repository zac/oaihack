import Foundation

struct RenderGraph: Sendable, Equatable {
    var rootKey: String
    var nodes: [String: RenderNode]
}

struct GraphCompileOutput: Sendable {
    var graph: RenderGraph
    var issues: [GuardrailIssue]
}

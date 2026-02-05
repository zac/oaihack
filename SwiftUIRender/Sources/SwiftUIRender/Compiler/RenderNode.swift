import Foundation

struct NodeMeta: Sendable, Equatable {
    var key: String
    var parentKey: String?
    var type: String
    var children: [String: [String]]
}

enum RenderNodeKind: Sendable, Equatable {
    case root(children: [String])
    case vStack(children: [String])
    case hStack(children: [String])
    case text(content: String)
    case badge(content: String)
    case card(children: [String])
    case divider
    case button(title: String, action: RenderAction?)
    case textField(placeholder: String, binding: BindingPath?)
    case list(children: [String])
    case guardrail(message: String)
}

struct RenderNode: Sendable, Equatable, Identifiable {
    var key: String
    var meta: NodeMeta
    var style: ResolvedStyle
    var kind: RenderNodeKind

    var id: String { key }
}

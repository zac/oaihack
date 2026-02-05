import Foundation

struct NodeMeta: Sendable, Equatable {
    var key: String
    var parentKey: String?
    var type: String
    var children: [String: [String]]
}

enum TextFieldKind: String, Sendable, Equatable, Codable {
    case plain
    case email
    case url
    case phone
    case number
    case name
    case username
    case password
    case search
}

struct TextFieldNode: Sendable, Equatable {
    var placeholder: String
    var binding: BindingPath?
    var kind: TextFieldKind
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
    case textField(TextFieldNode)
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

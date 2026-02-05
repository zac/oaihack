import Foundation

enum BuiltinComponent: String, CaseIterable, Sendable {
    case root
    case vStack = "v-stack"
    case hStack = "h-stack"
    case text
    case badge
    case card
    case divider
    case button
    case textField = "text-field"
    case list
}

struct ComponentDefinition: Sendable {
    var requiredProps: Set<String>
    var defaultChildSlot: String?
    var defaultStyles: [String: JSONValue]

    static let root = ComponentDefinition(
        requiredProps: [],
        defaultChildSlot: "children",
        defaultStyles: [:]
    )
}

enum BuiltinCatalog {
    static func component(for type: String) -> BuiltinComponent? {
        BuiltinComponent(rawValue: type)
    }

    static func definition(for component: BuiltinComponent) -> ComponentDefinition {
        switch component {
        case .root:
            return .root
        case .vStack:
            return ComponentDefinition(requiredProps: [], defaultChildSlot: "children", defaultStyles: ["gap": .number(12)])
        case .hStack:
            return ComponentDefinition(requiredProps: [], defaultChildSlot: "children", defaultStyles: ["gap": .number(12)])
        case .text:
            return ComponentDefinition(requiredProps: ["text"], defaultChildSlot: nil, defaultStyles: [:])
        case .badge:
            return ComponentDefinition(requiredProps: ["text"], defaultChildSlot: nil, defaultStyles: [
                "padding": .number(8),
                "border-radius": .number(999),
            ])
        case .card:
            return ComponentDefinition(requiredProps: [], defaultChildSlot: "children", defaultStyles: [
                "padding": .number(12),
                "border-radius": .number(12),
            ])
        case .divider:
            return ComponentDefinition(requiredProps: [], defaultChildSlot: nil, defaultStyles: [:])
        case .button:
            return ComponentDefinition(requiredProps: ["text"], defaultChildSlot: nil, defaultStyles: [:])
        case .textField:
            return ComponentDefinition(requiredProps: ["binding"], defaultChildSlot: nil, defaultStyles: [:])
        case .list:
            return ComponentDefinition(requiredProps: [], defaultChildSlot: "children", defaultStyles: ["gap": .number(8)])
        }
    }

    static func validate(element: UIElement, key: String) -> [GuardrailIssue] {
        guard let component = component(for: element.type) else {
            return [
                GuardrailIssue(
                    severity: .error,
                    message: "Unknown component type '\(element.type)'",
                    path: "/elements/\(key)/type"
                )
            ]
        }

        let definition = definition(for: component)
        var issues: [GuardrailIssue] = []

        for required in definition.requiredProps where element.props[required] == nil {
            issues.append(
                GuardrailIssue(
                    severity: .error,
                    message: "Missing required prop '\(required)' for component '\(element.type)'",
                    path: "/elements/\(key)/props/\(required)"
                )
            )
        }

        return issues
    }
}

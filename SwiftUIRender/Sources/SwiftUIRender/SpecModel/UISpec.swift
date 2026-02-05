import Foundation

public struct UISpec: Sendable, Equatable, Codable {
    public var root: String
    public var elements: [String: UIElement]

    public init(root: String, elements: [String: UIElement]) {
        self.root = root
        self.elements = elements
    }
}

public struct UIElement: Sendable, Equatable, Codable {
    public var type: String
    public var parentKey: String?
    public var children: [String: [String]]
    public var props: [String: JSONValue]
    public var styles: [String: JSONValue]
    public var classNames: [String]

    enum CodingKeys: String, CodingKey {
        case type
        case parentKey
        case children
        case props
        case styles
        case className
        case classNames
        case classes
    }

    public init(
        type: String,
        parentKey: String? = nil,
        children: [String: [String]] = [:],
        props: [String: JSONValue] = [:],
        styles: [String: JSONValue] = [:],
        classNames: [String] = []
    ) {
        self.type = type
        self.parentKey = parentKey
        self.children = children
        self.props = props
        self.styles = styles
        self.classNames = classNames
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        parentKey = try container.decodeIfPresent(String.self, forKey: .parentKey)
        children = try container.decodeIfPresent([String: [String]].self, forKey: .children) ?? [:]
        props = try container.decodeIfPresent([String: JSONValue].self, forKey: .props) ?? [:]
        styles = try container.decodeIfPresent([String: JSONValue].self, forKey: .styles) ?? [:]

        if let classNamesValue = try container.decodeIfPresent([String].self, forKey: .classNames) {
            classNames = classNamesValue
        } else if let classesValue = try container.decodeIfPresent([String].self, forKey: .classes) {
            classNames = classesValue
        } else if let className = try container.decodeIfPresent(String.self, forKey: .className) {
            classNames = className
                .split(separator: " ")
                .map { String($0) }
                .filter { !$0.isEmpty }
        } else {
            classNames = []
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(parentKey, forKey: .parentKey)
        if !children.isEmpty {
            try container.encode(children, forKey: .children)
        }
        if !props.isEmpty {
            try container.encode(props, forKey: .props)
        }
        if !styles.isEmpty {
            try container.encode(styles, forKey: .styles)
        }
        if !classNames.isEmpty {
            try container.encode(classNames, forKey: .classNames)
        }
    }
}

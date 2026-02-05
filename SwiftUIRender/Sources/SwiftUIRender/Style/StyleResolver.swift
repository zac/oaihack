import Foundation

struct StyleResolver {
    let configuration: RenderConfiguration

    func resolve(
        element: UIElement,
        componentDefaults: [String: JSONValue],
        path: String
    ) -> (ResolvedStyle, [GuardrailIssue]) {
        var issues: [GuardrailIssue] = []
        var merged = componentDefaults

        for className in allClassNames(for: element) {
            if let classStyles = configuration.styleClasses[className] {
                merged.merge(classStyles) { _, new in new }
            }
        }

        merged.merge(element.styles) { _, new in new }

        var style = ResolvedStyle()

        for rawKey in orderedKeys(from: merged) {
            guard let rawValue = merged[rawKey] else { continue }
            let normalizedKey = normalizeKey(rawKey)
            let value = resolveVariable(in: rawValue)
            if !apply(value: value, to: &style, key: normalizedKey) {
                if configuration.emitUnsupportedStyleWarnings {
                    issues.append(
                        GuardrailIssue(
                            severity: .warning,
                            message: "Unsupported style key '\(rawKey)'",
                            path: path
                        )
                    )
                }
            }
        }

        return (style, issues)
    }

    private func orderedKeys(from styles: [String: JSONValue]) -> [String] {
        styles.keys.sorted { lhs, rhs in
            let lhsPriority = priority(for: normalizeKey(lhs))
            let rhsPriority = priority(for: normalizeKey(rhs))
            if lhsPriority == rhsPriority {
                return lhs < rhs
            }
            return lhsPriority < rhsPriority
        }
    }

    private func priority(for key: String) -> Int {
        switch key {
        case "padding", "margin":
            return 0
        case "padding-top", "padding-right", "padding-bottom", "padding-left",
            "margin-top", "margin-right", "margin-bottom", "margin-left":
            return 1
        default:
            return 0
        }
    }

    private func allClassNames(for element: UIElement) -> [String] {
        var names = element.classNames

        if let className = element.props["className"]?.stringValue {
            names.append(contentsOf: className.split(separator: " ").map { String($0) })
        }

        if let classNames = element.props["classNames"]?.arrayValue {
            names.append(contentsOf: classNames.compactMap(\.stringValue))
        }

        return names
    }

    private func normalizeKey(_ raw: String) -> String {
        let withHyphens = raw
            .map { char -> String in
                if char.isUppercase {
                    return "-\(char.lowercased())"
                }
                return String(char)
            }
            .joined()
        return withHyphens.lowercased()
    }

    private func resolveVariable(in value: JSONValue) -> JSONValue {
        guard case let .string(raw) = value else {
            return value
        }

        guard raw.hasPrefix("var(--"), raw.hasSuffix(")") else {
            return value
        }

        let start = raw.index(raw.startIndex, offsetBy: 6)
        let end = raw.index(before: raw.endIndex)
        let name = String(raw[start..<end])
        if let variable = configuration.styleVariables[name] {
            return variable
        }

        return value
    }

    private func apply(value: JSONValue, to style: inout ResolvedStyle, key: String) -> Bool {
        switch key {
        case "color":
            style.color = value.stringValue
            return true
        case "font-size":
            style.fontSize = asDouble(value)
            return true
        case "font-weight":
            style.fontWeight = value.stringValue
            return true
        case "line-height":
            style.lineHeight = asDouble(value)
            return true
        case "text-align":
            style.textAlign = value.stringValue
            return true

        case "padding":
            applyEdgeShorthand(value, to: &style.padding)
            return true
        case "padding-top":
            style.padding.top = asDouble(value)
            return true
        case "padding-right":
            style.padding.trailing = asDouble(value)
            return true
        case "padding-bottom":
            style.padding.bottom = asDouble(value)
            return true
        case "padding-left":
            style.padding.leading = asDouble(value)
            return true

        case "margin":
            applyEdgeShorthand(value, to: &style.margin)
            return true
        case "margin-top":
            style.margin.top = asDouble(value)
            return true
        case "margin-right":
            style.margin.trailing = asDouble(value)
            return true
        case "margin-bottom":
            style.margin.bottom = asDouble(value)
            return true
        case "margin-left":
            style.margin.leading = asDouble(value)
            return true

        case "gap":
            style.gap = asDouble(value)
            return true

        case "width":
            style.width = asDouble(value)
            return true
        case "height":
            style.height = asDouble(value)
            return true
        case "min-width":
            style.minWidth = asDouble(value)
            return true
        case "max-width":
            style.maxWidth = asDouble(value)
            return true
        case "min-height":
            style.minHeight = asDouble(value)
            return true
        case "max-height":
            style.maxHeight = asDouble(value)
            return true
        case "opacity":
            style.opacity = asDouble(value)
            return true

        case "background-color":
            style.backgroundColor = value.stringValue
            return true
        case "border-width":
            style.borderWidth = asDouble(value)
            return true
        case "border-color":
            style.borderColor = value.stringValue
            return true
        case "border-radius":
            style.borderRadius = asDouble(value)
            return true

        default:
            return false
        }
    }

    private func applyEdgeShorthand(_ value: JSONValue, to edge: inout EdgeValueSet) {
        guard let number = asDouble(value) else { return }
        edge.top = number
        edge.leading = number
        edge.bottom = number
        edge.trailing = number
    }

    private func asDouble(_ value: JSONValue) -> Double? {
        if let number = value.numberValue {
            return number
        }
        if let string = value.stringValue {
            return Double(string)
        }
        return nil
    }
}

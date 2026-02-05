import Foundation

struct GraphCompiler {
    let configuration: RenderConfiguration

    func compile(spec: UISpec) -> GraphCompileOutput {
        let keys = reachableKeys(in: spec)
        let partial = compile(keys: keys, in: spec)
        return GraphCompileOutput(
            graph: RenderGraph(rootKey: spec.root, nodes: partial.nodes),
            issues: partial.issues
        )
    }

    func compile(keys: Set<String>, in spec: UISpec) -> (nodes: [String: RenderNode], issues: [GuardrailIssue]) {
        var nodes: [String: RenderNode] = [:]
        var issues: [GuardrailIssue] = []

        for key in keys {
            let result = compileNode(key: key, in: spec)
            nodes[key] = result.node
            issues.append(contentsOf: result.issues)
        }

        return (nodes, issues)
    }

    func reachableKeys(in spec: UISpec) -> Set<String> {
        var visited: Set<String> = []
        var queue: [String] = [spec.root]

        while let key = queue.first {
            queue.removeFirst()

            guard !visited.contains(key) else { continue }
            visited.insert(key)

            guard let element = spec.elements[key] else { continue }
            for children in element.children.values {
                queue.append(contentsOf: children)
            }
        }

        return visited
    }

    func descendants(of keys: Set<String>, in spec: UISpec) -> Set<String> {
        var visited: Set<String> = []
        var queue = Array(keys)

        while let key = queue.first {
            queue.removeFirst()

            guard !visited.contains(key) else { continue }
            visited.insert(key)

            guard let element = spec.elements[key] else { continue }
            for children in element.children.values {
                queue.append(contentsOf: children)
            }
        }

        return visited
    }

    private func compileNode(key: String, in spec: UISpec) -> (node: RenderNode, issues: [GuardrailIssue]) {
        guard let element = spec.elements[key] else {
            let issue = GuardrailIssue(
                severity: .error,
                message: "Element '\(key)' is missing from elements map",
                path: "/elements/\(key)"
            )
            return (
                RenderNode(
                    key: key,
                    meta: NodeMeta(key: key, parentKey: nil, type: "guardrail", children: [:]),
                    style: ResolvedStyle(),
                    kind: .guardrail(message: issue.message)
                ),
                [issue]
            )
        }

        let validationIssues = BuiltinCatalog.validate(element: element, key: key)

        let defaultStyles: [String: JSONValue]
        if let component = BuiltinCatalog.component(for: element.type) {
            defaultStyles = BuiltinCatalog.definition(for: component).defaultStyles
        } else {
            defaultStyles = [:]
        }

        let styleResolver = StyleResolver(configuration: configuration)
        let (resolvedStyle, styleIssues) = styleResolver.resolve(
            element: element,
            componentDefaults: defaultStyles,
            path: "/elements/\(key)/styles"
        )

        var issues = validationIssues + styleIssues

        let meta = NodeMeta(
            key: key,
            parentKey: element.parentKey,
            type: element.type,
            children: element.children
        )

        guard let component = BuiltinCatalog.component(for: element.type) else {
            let message = "Unsupported component '\(element.type)'"
            return (
                RenderNode(key: key, meta: meta, style: resolvedStyle, kind: .guardrail(message: message)),
                issues
            )
        }

        let defaultChildren = element.children[BuiltinCatalog.definition(for: component).defaultChildSlot ?? "children"] ?? []

        let nodeKind: RenderNodeKind

        switch component {
        case .root:
            nodeKind = .root(children: defaultChildren)

        case .vStack:
            nodeKind = .vStack(children: defaultChildren)

        case .hStack:
            nodeKind = .hStack(children: defaultChildren)

        case .text:
            let text = element.props["text"]?.stringValue ?? ""
            nodeKind = .text(content: text)

        case .badge:
            let text = element.props["text"]?.stringValue
                ?? element.props["label"]?.stringValue
                ?? element.props["title"]?.stringValue
                ?? ""
            nodeKind = .badge(content: text)

        case .card:
            nodeKind = .card(children: defaultChildren)

        case .divider:
            nodeKind = .divider

        case .button:
            let text = element.props["text"]?.stringValue ?? "Button"
            let actionResult = ActionResolver.resolve(
                from: element.props["action"],
                path: "/elements/\(key)/props/action"
            )
            issues.append(contentsOf: actionResult.1)
            nodeKind = .button(title: text, action: actionResult.0)

        case .textField:
            let placeholder = element.props["placeholder"]?.stringValue ?? ""
            var bindingPath: BindingPath?

            if let bindingValue = element.props["binding"]?.stringValue {
                do {
                    bindingPath = try BindingPathParser.parse(bindingValue)
                } catch {
                    issues.append(
                        GuardrailIssue(
                            severity: .error,
                            message: "Invalid text-field binding '\(bindingValue)'",
                            path: "/elements/\(key)/props/binding"
                        )
                    )
                }
            }

            nodeKind = .textField(
                TextFieldNode(
                    placeholder: placeholder,
                    binding: bindingPath,
                    kind: inferTextFieldKind(
                        element: element,
                        bindingPath: bindingPath,
                        placeholder: placeholder
                    )
                )
            )

        case .list:
            nodeKind = .list(children: defaultChildren)
        }

        let hasErrors = issues.contains(where: { $0.severity == .error })
        let finalNode: RenderNode

        if hasErrors {
            let message = issues
                .filter { $0.severity == .error }
                .map(\.message)
                .joined(separator: "\n")
            finalNode = RenderNode(key: key, meta: meta, style: resolvedStyle, kind: .guardrail(message: message))
        } else {
            finalNode = RenderNode(key: key, meta: meta, style: resolvedStyle, kind: nodeKind)
        }

        return (finalNode, issues)
    }

    private func inferTextFieldKind(
        element: UIElement,
        bindingPath: BindingPath?,
        placeholder: String
    ) -> TextFieldKind {
        let explicitHintKeys = [
            "fieldType",
            "inputType",
            "type",
            "keyboardType",
            "textContentType",
            "autocomplete",
            "autoComplete",
        ]

        for key in explicitHintKeys {
            if let value = element.props[key]?.stringValue,
               let kind = textFieldKind(from: value) {
                return kind
            }
        }

        let heuristicHints: [String?] = [
            bindingPath?.tokens.joined(separator: "."),
            element.props["name"]?.stringValue,
            element.props["id"]?.stringValue,
            element.props["label"]?.stringValue,
            placeholder,
        ]

        for hint in heuristicHints {
            guard let hint,
                  let kind = textFieldKind(from: hint) else {
                continue
            }
            return kind
        }

        return .plain
    }

    private func textFieldKind(from hint: String) -> TextFieldKind? {
        let direct = normalizedIdentifier(hint)
        if let kind = mapTextFieldKindToken(direct) {
            return kind
        }

        let tokens = hint
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map { normalizedIdentifier(String($0)) }

        for token in tokens {
            if let kind = mapTextFieldKindToken(token) {
                return kind
            }
        }

        return nil
    }

    private func normalizedIdentifier(_ raw: String) -> String {
        raw.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func mapTextFieldKindToken(_ token: String) -> TextFieldKind? {
        switch token {
        case "email", "emailaddress", "mail":
            return .email
        case "url", "website", "link", "uri", "web":
            return .url
        case "phone", "phonenumber", "telephone", "tel", "mobile":
            return .phone
        case "number", "numeric", "decimal", "integer", "int":
            return .number
        case "name", "fullname", "firstname", "lastname", "givenname", "familyname":
            return .name
        case "username", "userid", "handle":
            return .username
        case "password", "passcode", "pin", "newpassword", "currentpassword":
            return .password
        case "search", "query":
            return .search
        default:
            return nil
        }
    }
}

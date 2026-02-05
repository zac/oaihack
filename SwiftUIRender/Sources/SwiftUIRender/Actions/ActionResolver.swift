import Foundation

enum ActionResolver {
    static func resolve(
        from value: JSONValue?,
        path: String
    ) -> (RenderAction?, [GuardrailIssue]) {
        guard let value else {
            return (nil, [])
        }

        if let actionName = value.stringValue {
            return resolve(name: actionName, params: [:], path: path)
        }

        guard case let .object(raw) = value else {
            return (
                nil,
                [GuardrailIssue(severity: .error, message: "Action must be a string or object", path: path)]
            )
        }

        let name = raw["name"]?.stringValue ?? raw["type"]?.stringValue
        let params = raw["params"]?.objectValue ?? [:]

        guard let name else {
            return (
                nil,
                [GuardrailIssue(severity: .error, message: "Action object missing 'name'", path: path)]
            )
        }

        return resolve(name: name, params: params, path: path)
    }

    private static func resolve(
        name: String,
        params: [String: JSONValue],
        path: String
    ) -> (RenderAction?, [GuardrailIssue]) {
        switch name {
        case "open_url":
            guard let url = params["url"]?.stringValue else {
                return (
                    nil,
                    [GuardrailIssue(severity: .error, message: "open_url requires params.url", path: path)]
                )
            }
            return (.openURL(url), [])

        case "log_event":
            guard let eventName = params["name"]?.stringValue else {
                return (
                    nil,
                    [GuardrailIssue(severity: .error, message: "log_event requires params.name", path: path)]
                )
            }
            let payload = params["payload"]?.objectValue ?? [:]
            return (.logEvent(name: eventName, payload: payload), [])

        case "set_data":
            guard let pathString = params["path"]?.stringValue else {
                return (
                    nil,
                    [GuardrailIssue(severity: .error, message: "set_data requires params.path", path: path)]
                )
            }
            guard let value = params["value"] else {
                return (
                    nil,
                    [GuardrailIssue(severity: .error, message: "set_data requires params.value", path: path)]
                )
            }
            do {
                let bindingPath = try BindingPathParser.parse(pathString)
                return (.setData(path: bindingPath, value: value), [])
            } catch {
                return (
                    nil,
                    [GuardrailIssue(severity: .error, message: "Invalid set_data path: \(pathString)", path: path)]
                )
            }

        case "submit":
            let payload = params["payload"]?.objectValue ?? [:]
            return (.submit(payload: payload), [])

        default:
            return (
                nil,
                [GuardrailIssue(severity: .error, message: "Unsupported action '\(name)'", path: path)]
            )
        }
    }
}

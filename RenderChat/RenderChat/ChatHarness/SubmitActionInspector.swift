import Foundation
import SwiftUIRender

struct SubmitActionTarget: Sendable, Equatable {
    let elementKey: String
    let actionPath: String
    let payload: [String: JSONValue]
}

enum SubmitActionInspector {
    static func inspect(spec: UISpec) -> [SubmitActionTarget] {
        spec.elements
            .keys
            .sorted()
            .compactMap { key in
                guard let element = spec.elements[key] else {
                    return nil
                }

                let path = "/elements/\(key)/props/action"
                return parseSubmitTarget(from: element.props["action"], elementKey: key, actionPath: path)
            }
    }

    private static func parseSubmitTarget(
        from value: JSONValue?,
        elementKey: String,
        actionPath: String
    ) -> SubmitActionTarget? {
        guard let value else {
            return nil
        }

        switch value {
        case let .string(name):
            guard name == "submit" else {
                return nil
            }
            return SubmitActionTarget(elementKey: elementKey, actionPath: actionPath, payload: [:])

        case let .object(rawAction):
            let actionName = rawAction["name"]?.stringValue ?? rawAction["type"]?.stringValue
            guard actionName == "submit" else {
                return nil
            }

            let params = rawAction["params"]?.objectValue ?? [:]
            let payload = params["payload"]?.objectValue ?? [:]

            return SubmitActionTarget(
                elementKey: elementKey,
                actionPath: actionPath,
                payload: payload
            )

        default:
            return nil
        }
    }
}

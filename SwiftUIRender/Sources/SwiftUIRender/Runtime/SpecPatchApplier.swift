import Foundation

enum SpecPatchError: Error, Equatable, CustomStringConvertible {
    case invalidPath(String)
    case missingValue(String)
    case invalidValue(String)
    case missingElement(String)

    var description: String {
        switch self {
        case let .invalidPath(path):
            return "Invalid spec patch path: \(path)"
        case let .missingValue(path):
            return "Patch is missing required value for path: \(path)"
        case let .invalidValue(reason):
            return "Patch value is invalid: \(reason)"
        case let .missingElement(key):
            return "Element '\(key)' not found"
        }
    }
}

struct SpecPatchApplier {
    static func apply(_ patch: SpecPatch, to spec: inout UISpec) throws -> Set<String> {
        let path = try BindingPathParser.parse(patch.path)
        let tokens = path.tokens

        guard let first = tokens.first else {
            guard let value = patch.value else {
                throw SpecPatchError.missingValue(patch.path)
            }
            spec = try JSONValueCodableBridge.decode(value, as: UISpec.self)
            return Set(spec.elements.keys).union([spec.root])
        }

        switch first {
        case "root":
            return try patchRoot(patch, tokens: tokens, spec: &spec)

        case "elements":
            return try patchElements(patch, tokens: tokens, spec: &spec)

        default:
            throw SpecPatchError.invalidPath(patch.path)
        }
    }

    private static func patchRoot(_ patch: SpecPatch, tokens: [String], spec: inout UISpec) throws -> Set<String> {
        guard tokens.count == 1 else {
            throw SpecPatchError.invalidPath(patch.path)
        }

        switch patch.op {
        case .remove:
            throw SpecPatchError.invalidPath(patch.path)

        case .set, .replace, .add:
            guard let value = patch.value?.stringValue else {
                throw SpecPatchError.missingValue(patch.path)
            }
            spec.root = value
            return Set(spec.elements.keys).union([value])
        }
    }

    private static func patchElements(_ patch: SpecPatch, tokens: [String], spec: inout UISpec) throws -> Set<String> {
        guard tokens.count >= 2 else {
            throw SpecPatchError.invalidPath(patch.path)
        }

        let key = tokens[1]

        if tokens.count == 2 {
            switch patch.op {
            case .remove:
                spec.elements.removeValue(forKey: key)
                return [key]

            case .set, .add, .replace:
                guard let rawValue = patch.value else {
                    throw SpecPatchError.missingValue(patch.path)
                }
                let element = try JSONValueCodableBridge.decode(rawValue, as: UIElement.self)
                spec.elements[key] = element
                return [key]
            }
        }

        guard var element = spec.elements[key] else {
            throw SpecPatchError.missingElement(key)
        }

        let field = tokens[2]
        let remainder = Array(tokens.dropFirst(3))

        switch field {
        case "type":
            guard let value = patch.value?.stringValue else {
                throw SpecPatchError.missingValue(patch.path)
            }
            if patch.op == .remove {
                throw SpecPatchError.invalidPath(patch.path)
            }
            element.type = value

        case "parentKey":
            switch patch.op {
            case .remove:
                element.parentKey = nil
            case .set, .add, .replace:
                guard let value = patch.value?.stringValue else {
                    throw SpecPatchError.missingValue(patch.path)
                }
                element.parentKey = value
            }

        case "props":
            if remainder.isEmpty, patch.op == .remove {
                element.props = [:]
                break
            }
            var propsValue = JSONValue.object(element.props)
            try mutate(value: &propsValue, op: patch.op, remainder: remainder, patchPath: patch.path, value: patch.value)
            guard let props = propsValue.objectValue else {
                throw SpecPatchError.invalidValue("props must be object")
            }
            element.props = props

        case "children":
            if remainder.isEmpty, patch.op == .remove {
                element.children = [:]
                break
            }
            var childrenValue = try JSONValueCodableBridge.encode(element.children)
            try mutate(value: &childrenValue, op: patch.op, remainder: remainder, patchPath: patch.path, value: patch.value)
            element.children = try JSONValueCodableBridge.decode(childrenValue, as: [String: [String]].self)

        case "styles":
            if remainder.isEmpty, patch.op == .remove {
                element.styles = [:]
                break
            }
            var stylesValue = JSONValue.object(element.styles)
            try mutate(value: &stylesValue, op: patch.op, remainder: remainder, patchPath: patch.path, value: patch.value)
            guard let styles = stylesValue.objectValue else {
                throw SpecPatchError.invalidValue("styles must be object")
            }
            element.styles = styles

        case "classNames", "classes":
            if remainder.isEmpty, patch.op == .remove {
                element.classNames = []
                break
            }
            var classesValue = try JSONValueCodableBridge.encode(element.classNames)
            try mutate(value: &classesValue, op: patch.op, remainder: remainder, patchPath: patch.path, value: patch.value)
            element.classNames = try JSONValueCodableBridge.decode(classesValue, as: [String].self)

        case "className":
            if patch.op == .remove {
                element.classNames = []
            } else {
                guard let className = patch.value?.stringValue else {
                    throw SpecPatchError.missingValue(patch.path)
                }
                element.classNames = className
                    .split(separator: " ")
                    .map { String($0) }
                    .filter { !$0.isEmpty }
            }

        default:
            throw SpecPatchError.invalidPath(patch.path)
        }

        spec.elements[key] = element
        return [key]
    }

    private static func mutate(
        value: inout JSONValue,
        op: PatchOp,
        remainder: [String],
        patchPath: String,
        value patchValue: JSONValue?
    ) throws {
        let pointer = BindingPath(tokens: remainder)

        switch op {
        case .set:
            guard let patchValue else {
                throw SpecPatchError.missingValue(patchPath)
            }
            try value.apply(.set(patchValue), at: pointer)

        case .add:
            guard let patchValue else {
                throw SpecPatchError.missingValue(patchPath)
            }
            try value.apply(.add(patchValue), at: pointer)

        case .replace:
            guard let patchValue else {
                throw SpecPatchError.missingValue(patchPath)
            }
            try value.apply(.replace(patchValue), at: pointer)

        case .remove:
            try value.apply(.remove, at: pointer)
        }
    }
}

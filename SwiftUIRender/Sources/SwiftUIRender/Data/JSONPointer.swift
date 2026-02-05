import Foundation

enum JSONPointerMutation {
    case set(JSONValue)
    case add(JSONValue)
    case replace(JSONValue)
    case remove
}

enum JSONPointerError: Error, Equatable, CustomStringConvertible {
    case missingValue(String)
    case invalidContainer(String)
    case invalidIndex(String)
    case outOfBounds(String)

    var description: String {
        switch self {
        case let .missingValue(path):
            return "Missing value at path: \(path)"
        case let .invalidContainer(path):
            return "Invalid container at path: \(path)"
        case let .invalidIndex(index):
            return "Invalid array index: \(index)"
        case let .outOfBounds(path):
            return "Index out of bounds at path: \(path)"
        }
    }
}

extension JSONValue {
    func value(at path: BindingPath) -> JSONValue? {
        var cursor = self

        for token in path.tokens {
            switch cursor {
            case let .object(object):
                guard let next = object[token] else { return nil }
                cursor = next
            case let .array(array):
                guard let index = Int(token), array.indices.contains(index) else { return nil }
                cursor = array[index]
            default:
                return nil
            }
        }

        return cursor
    }

    mutating func apply(_ mutation: JSONPointerMutation, at path: BindingPath) throws {
        try apply(mutation, tokens: ArraySlice(path.tokens), fullPath: path.canonicalPointer)
    }

    private mutating func apply(_ mutation: JSONPointerMutation, tokens: ArraySlice<String>, fullPath: String) throws {
        guard let token = tokens.first else {
            switch mutation {
            case let .set(value), let .add(value), let .replace(value):
                self = value
            case .remove:
                self = .null
            }
            return
        }

        let isLeaf = tokens.count == 1

        switch self {
        case var .object(object):
            if isLeaf {
                switch mutation {
                case let .set(value):
                    object[token] = value
                case let .add(value):
                    object[token] = value
                case let .replace(value):
                    guard object[token] != nil else {
                        throw JSONPointerError.missingValue(fullPath)
                    }
                    object[token] = value
                case .remove:
                    guard object.removeValue(forKey: token) != nil else {
                        throw JSONPointerError.missingValue(fullPath)
                    }
                }
                self = .object(object)
                return
            }

            let nextTokens = tokens.dropFirst()
            var child = object[token] ?? .object([:])
            if object[token] == nil, case .replace = mutation {
                throw JSONPointerError.missingValue(fullPath)
            }
            try child.apply(mutation, tokens: nextTokens, fullPath: fullPath)
            object[token] = child
            self = .object(object)

        case var .array(array):
            if token == "-" {
                if isLeaf {
                    switch mutation {
                    case let .add(value), let .set(value):
                        array.append(value)
                        self = .array(array)
                        return
                    default:
                        throw JSONPointerError.invalidIndex(token)
                    }
                }

                var appended: JSONValue = .object([:])
                try appended.apply(mutation, tokens: tokens.dropFirst(), fullPath: fullPath)
                array.append(appended)
                self = .array(array)
                return
            }

            guard let index = Int(token) else {
                throw JSONPointerError.invalidIndex(token)
            }

            if isLeaf {
                switch mutation {
                case let .set(value):
                    if index == array.count {
                        array.append(value)
                    } else if array.indices.contains(index) {
                        array[index] = value
                    } else {
                        throw JSONPointerError.outOfBounds(fullPath)
                    }
                case let .add(value):
                    if index <= array.count {
                        array.insert(value, at: index)
                    } else {
                        throw JSONPointerError.outOfBounds(fullPath)
                    }
                case let .replace(value):
                    guard array.indices.contains(index) else {
                        throw JSONPointerError.outOfBounds(fullPath)
                    }
                    array[index] = value
                case .remove:
                    guard array.indices.contains(index) else {
                        throw JSONPointerError.outOfBounds(fullPath)
                    }
                    array.remove(at: index)
                }

                self = .array(array)
                return
            }

            if index == array.count {
                array.append(.object([:]))
            }
            guard array.indices.contains(index) else {
                throw JSONPointerError.outOfBounds(fullPath)
            }

            var child = array[index]
            try child.apply(mutation, tokens: tokens.dropFirst(), fullPath: fullPath)
            array[index] = child
            self = .array(array)

        default:
            throw JSONPointerError.invalidContainer(fullPath)
        }
    }
}

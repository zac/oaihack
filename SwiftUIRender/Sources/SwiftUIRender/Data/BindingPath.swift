import Foundation

public struct BindingPath: Sendable, Hashable, Codable, Equatable, CustomStringConvertible {
    public let tokens: [String]

    public init(tokens: [String]) {
        self.tokens = tokens
    }

    public init(pointer: String) throws {
        self = try BindingPathParser.parse(pointer)
    }

    public static func parse(_ raw: String) throws -> BindingPath {
        try BindingPathParser.parse(raw)
    }

    public var description: String {
        canonicalPointer
    }

    public var canonicalPointer: String {
        guard !tokens.isEmpty else { return "/" }
        return "/" + tokens.map(Self.escape).joined(separator: "/")
    }

    private static func escape(_ raw: String) -> String {
        raw.replacingOccurrences(of: "~", with: "~0")
            .replacingOccurrences(of: "/", with: "~1")
    }
}

public enum BindingPathError: Error, Equatable, CustomStringConvertible {
    case invalidPath(String)
    case invalidArrayIndex(String)

    public var description: String {
        switch self {
        case let .invalidPath(path):
            return "Invalid binding path: \(path)"
        case let .invalidArrayIndex(index):
            return "Invalid array index: \(index)"
        }
    }
}

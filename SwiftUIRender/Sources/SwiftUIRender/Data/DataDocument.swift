import Foundation

public struct DataDocument: Sendable, Equatable {
    public var root: JSONValue

    public init(root: JSONValue = .object([:])) {
        self.root = root
    }

    public func read(path: BindingPath) -> JSONValue? {
        root.value(at: path)
    }

    public mutating func write(value: JSONValue, path: BindingPath) throws {
        try root.apply(.set(value), at: path)
    }

    public mutating func remove(path: BindingPath) throws {
        try root.apply(.remove, at: path)
    }
}

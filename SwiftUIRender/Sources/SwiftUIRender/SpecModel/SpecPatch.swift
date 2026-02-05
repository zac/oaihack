import Foundation

public enum PatchOp: String, Sendable, Codable, Equatable, CaseIterable {
    case set
    case add
    case replace
    case remove
}

public struct SpecPatch: Sendable, Codable, Equatable {
    public var op: PatchOp
    public var path: String
    public var value: JSONValue?

    public init(op: PatchOp, path: String, value: JSONValue? = nil) {
        self.op = op
        self.path = path
        self.value = value
    }
}

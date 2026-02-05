import Foundation

public enum RenderAction: Sendable, Equatable {
    case openURL(String)
    case logEvent(name: String, payload: [String: JSONValue])
    case setData(path: BindingPath, value: JSONValue)
    case submit(payload: [String: JSONValue])
}

public struct RenderActionContext: Sendable {
    public var setData: @Sendable (BindingPath, JSONValue) async -> Void
    public var readData: @Sendable (BindingPath) async -> JSONValue?
    public var reportIssue: @Sendable (GuardrailIssue) async -> Void

    public init(
        setData: @escaping @Sendable (BindingPath, JSONValue) async -> Void,
        readData: @escaping @Sendable (BindingPath) async -> JSONValue?,
        reportIssue: @escaping @Sendable (GuardrailIssue) async -> Void
    ) {
        self.setData = setData
        self.readData = readData
        self.reportIssue = reportIssue
    }
}

public protocol RenderActionHandler: Sendable {
    func handle(action: RenderAction, context: RenderActionContext) async
}

public struct NoopRenderActionHandler: RenderActionHandler {
    public init() {}

    public func handle(action: RenderAction, context: RenderActionContext) async {
        _ = context
    }
}

import Foundation

public struct RenderConfiguration: Sendable {
    public var styleClasses: [String: [String: JSONValue]]
    public var styleVariables: [String: JSONValue]
    public var initialData: JSONValue
    public var actionHandler: any RenderActionHandler
    public var emitUnsupportedStyleWarnings: Bool

    public init(
        styleClasses: [String: [String: JSONValue]] = [:],
        styleVariables: [String: JSONValue] = [:],
        initialData: JSONValue = .object([:]),
        actionHandler: any RenderActionHandler = NoopRenderActionHandler(),
        emitUnsupportedStyleWarnings: Bool = true
    ) {
        self.styleClasses = styleClasses
        self.styleVariables = styleVariables
        self.initialData = initialData
        self.actionHandler = actionHandler
        self.emitUnsupportedStyleWarnings = emitUnsupportedStyleWarnings
    }

    public static var `default`: RenderConfiguration {
        RenderConfiguration()
    }
}

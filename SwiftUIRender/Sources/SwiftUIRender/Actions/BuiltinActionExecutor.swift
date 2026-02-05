import Foundation

enum BuiltinActionExecutor {
    static func execute(
        _ action: RenderAction,
        handler: any RenderActionHandler,
        context: RenderActionContext
    ) async {
        switch action {
        case let .setData(path, value):
            await context.setData(path, value)

        case let .openURL(url):
            await context.reportIssue(
                GuardrailIssue(
                    severity: .info,
                    message: "open_url requested for '\(url)' (stubbed in v1)",
                    path: nil
                )
            )

        case let .logEvent(name, payload):
            let metadata = payload.keys.sorted().joined(separator: ",")
            await context.reportIssue(
                GuardrailIssue(
                    severity: .info,
                    message: "log_event '\(name)' captured (payload keys: \(metadata))",
                    path: nil
                )
            )

        case let .submit(payload):
            await context.reportIssue(
                GuardrailIssue(
                    severity: .info,
                    message: "submit requested (payload keys: \(payload.keys.sorted().joined(separator: ",")))",
                    path: nil
                )
            )
        }

        await handler.handle(action: action, context: context)
    }
}

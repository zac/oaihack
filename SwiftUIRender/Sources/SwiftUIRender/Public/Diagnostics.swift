import Foundation
import Observation

public enum GuardrailSeverity: String, Sendable, Equatable, Codable {
    case info
    case warning
    case error
}

public struct GuardrailIssue: Sendable, Equatable, Codable, Identifiable {
    public var id: String
    public var severity: GuardrailSeverity
    public var message: String
    public var path: String?

    public init(
        id: String = UUID().uuidString,
        severity: GuardrailSeverity,
        message: String,
        path: String? = nil
    ) {
        self.id = id
        self.severity = severity
        self.message = message
        self.path = path
    }
}

@MainActor
@Observable
public final class RenderDiagnostics {
    public private(set) var issues: [GuardrailIssue] = []

    public init(issues: [GuardrailIssue] = []) {
        self.issues = issues
    }

    public func append(_ issue: GuardrailIssue) {
        issues.append(issue)
    }

    public func append(contentsOf newIssues: [GuardrailIssue]) {
        issues.append(contentsOf: newIssues)
    }

    public func clear() {
        issues.removeAll()
    }
}

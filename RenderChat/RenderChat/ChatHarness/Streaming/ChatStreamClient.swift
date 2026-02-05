import AsyncServerSentEvents
import Endpoints
import Foundation
import SwiftUIRender

protocol ChatStreamClient {
    func stream(prompt: String, sessionID: UUID) -> AsyncThrowingStream<ChatStreamEvent, Error>
}

struct ReplayChatStreamClient: ChatStreamClient {
    let scenario: ReplayScenario
    let textChunkDelayNanoseconds: UInt64
    let patchDelayNanoseconds: UInt64

    init(
        scenario: ReplayScenario,
        textChunkDelayNanoseconds: UInt64 = 45_000_000,
        patchDelayNanoseconds: UInt64 = 120_000_000
    ) {
        self.scenario = scenario
        self.textChunkDelayNanoseconds = textChunkDelayNanoseconds
        self.patchDelayNanoseconds = patchDelayNanoseconds
    }

    func stream(prompt: String, sessionID: UUID) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let renderMessageID = "render-\(sessionID.uuidString)"
                    let assistantTextMessageID = "assistant-\(sessionID.uuidString)"

                    let script = try ReplayScenarioScript.load(scenario: scenario)

                    for chunk in script.assistantTextChunks {
                        if Task.isCancelled { break }
                        continuation.yield(.assistantTextDelta(messageID: assistantTextMessageID, delta: chunk))
                        try await Task.sleep(nanoseconds: textChunkDelayNanoseconds)
                    }

                    continuation.yield(.assistantTextDone(messageID: assistantTextMessageID))
                    continuation.yield(
                        .renderStarted(
                            messageID: renderMessageID,
                            initialSpec: script.initialSpec,
                            initialData: script.initialData
                        )
                    )

                    for patch in script.patches {
                        if Task.isCancelled { break }
                        continuation.yield(.renderPatch(messageID: renderMessageID, patch: patch))
                        try await Task.sleep(nanoseconds: patchDelayNanoseconds)
                    }

                    if case .guardrail = scenario {
                        continuation.yield(
                            .guardrail(
                                GuardrailIssue(
                                    severity: .warning,
                                    message: "Replay scenario intentionally includes an unsupported component.",
                                    path: "/elements/bad/type"
                                )
                            )
                        )
                    }

                    continuation.yield(.renderDone(messageID: renderMessageID))
                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

struct LocalSSEChatStreamClient: ChatStreamClient {
    let session: URLSession
    let endpointBaseURL: URL

    init(
        session: URLSession = .shared,
        endpointBaseURL: URL = URL(string: "http://127.0.0.1:8080")!
    ) {
        self.session = session
        self.endpointBaseURL = endpointBaseURL
    }

    func stream(prompt: String, sessionID: UUID) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    RenderChatStreamServer.baseURL = endpointBaseURL
                    RenderChatStreamServer.environment = .local

                    let endpoint = RenderChatStreamEndpoint(
                        body: .init(
                            prompt: prompt,
                            sessionID: sessionID.uuidString,
                            catalogID: "builtin",
                            seed: 1
                        )
                    )

                    let request = try endpoint.urlRequest()
                    let (events, response) = try await session.serverSentEvents(for: request)

                    if let httpResponse = response as? HTTPURLResponse,
                       !(200 ..< 300).contains(httpResponse.statusCode) {
                        continuation.finish(throwing: StreamClientError.httpStatus(httpResponse.statusCode))
                        return
                    }

                    for try await event in events {
                        if Task.isCancelled { break }

                        do {
                            if let mapped = try map(event: event) {
                                continuation.yield(mapped)
                            }
                        } catch {
                            continuation.yield(.error(message: "Failed to decode SSE event: \(error.localizedDescription)"))
                        }
                    }

                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func map(event: AsyncServerSentEvents.Event) throws -> ChatStreamEvent? {
        let name = (event.name ?? "message").lowercased()

        switch name {
        case "assistant_text_delta", "assistanttextdelta", "text_delta":
            let payload = try decode(AssistantTextDeltaPayload.self, from: event.data)
            return .assistantTextDelta(messageID: payload.messageID, delta: payload.delta)

        case "assistant_text_done", "assistanttextdone", "text_done":
            let payload = try decode(MessageIDPayload.self, from: event.data)
            return .assistantTextDone(messageID: payload.messageID)

        case "render_started", "renderstarted":
            let payload = try decode(RenderStartedPayload.self, from: event.data)
            return .renderStarted(
                messageID: payload.messageID,
                initialSpec: payload.initialSpec,
                initialData: payload.initialData ?? .object([:])
            )

        case "render_patch", "renderpatch", "patch":
            let payload = try decode(RenderPatchPayload.self, from: event.data)
            return .renderPatch(messageID: payload.messageID, patch: payload.patch)

        case "render_done", "renderdone":
            let payload = try decode(MessageIDPayload.self, from: event.data)
            return .renderDone(messageID: payload.messageID)

        case "guardrail":
            let payload = try decode(GuardrailPayload.self, from: event.data)
            return .guardrail(payload.issue)

        case "error":
            let payload = try decode(ErrorPayload.self, from: event.data)
            return .error(message: payload.message)

        case "done", "stream_done":
            return .done

        default:
            return nil
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from dataString: String) throws -> T {
        let data = Data(dataString.utf8)
        return try JSONDecoder().decode(type, from: data)
    }
}

private enum StreamClientError: LocalizedError {
    case fixtureNotFound(String)
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case let .fixtureNotFound(name):
            return "Missing fixture: \(name)"
        case let .httpStatus(code):
            return "SSE server returned HTTP \(code)"
        }
    }
}

private struct ReplayScenarioScript {
    let assistantTextChunks: [String]
    let initialSpec: UISpec
    let patches: [SpecPatch]
    let initialData: JSONValue

    static func load(scenario: ReplayScenario) throws -> ReplayScenarioScript {
        switch scenario {
        case .supportDashboard:
            let initialSpecData = try FixtureLocator.data(
                named: "support-dashboard.spec",
                ext: "json",
                fallback: EmbeddedFixtures.supportDashboardSpec
            )
            let patchLines = try FixtureLocator.lines(
                named: "support-dashboard.patches",
                ext: "jsonl",
                fallback: EmbeddedFixtures.supportDashboardPatches
            )

            let initialSpec = try JSONDecoder().decode(UISpec.self, from: initialSpecData)
            let patches = try patchLines.map { line in
                try JSONDecoder().decode(SpecPatch.self, from: Data(line.utf8))
            }

            let assistantText = "I rendered a support dashboard from a deterministic stream. Edit the name field and tap Save to trigger actions."

            return ReplayScenarioScript(
                assistantTextChunks: assistantText.wordChunks,
                initialSpec: initialSpec,
                patches: patches,
                initialData: .object([
                    "customer": .object([
                        "name": .string("Ava"),
                        "saved": .bool(false),
                    ]),
                ])
            )

        case .guardrail:
            let initialSpecData = try FixtureLocator.data(
                named: "guardrail.spec",
                ext: "json",
                fallback: EmbeddedFixtures.guardrailSpec
            )
            let initialSpec = try JSONDecoder().decode(UISpec.self, from: initialSpecData)

            let assistantText = "This scenario intentionally triggers guardrails to verify inline system diagnostics in the transcript."

            return ReplayScenarioScript(
                assistantTextChunks: assistantText.wordChunks,
                initialSpec: initialSpec,
                patches: [],
                initialData: .object([:])
            )

        case .generatedForm:
            let initialSpecData = try FixtureLocator.data(
                named: "generated-form.spec",
                ext: "json",
                fallback: EmbeddedFixtures.generatedFormSpec
            )
            let patchLines = try FixtureLocator.lines(
                named: "generated-form.patches",
                ext: "jsonl",
                fallback: EmbeddedFixtures.generatedFormPatches
            )
            let initialSpec = try JSONDecoder().decode(UISpec.self, from: initialSpecData)
            let patches = try patchLines.map { line in
                try JSONDecoder().decode(SpecPatch.self, from: Data(line.utf8))
            }

            let assistantText =
                "I generated a profile intake form. Update the fields below and submit to place the rendered UI into the transcript."

            return ReplayScenarioScript(
                assistantTextChunks: assistantText.wordChunks,
                initialSpec: initialSpec,
                patches: patches,
                initialData: .object([
                    "profile": .object([
                        "fullName": .string("Ava Stone"),
                        "email": .string("ava@example.com"),
                    ]),
                ])
            )
        }
    }
}

private enum FixtureLocator {
    private static let searchDirectories: [String?] = [
        "ChatHarness/Resources/Streams",
        "Fixtures",
        nil,
    ]

    static func data(named name: String, ext: String, fallback: String) throws -> Data {
        for directory in searchDirectories {
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: directory) {
                return try Data(contentsOf: url)
            }
        }

        return Data(fallback.utf8)
    }

    static func lines(named name: String, ext: String, fallback: [String]) throws -> [String] {
        let raw = try String(decoding: data(named: name, ext: ext, fallback: fallback.joined(separator: "\n")), as: UTF8.self)
        return raw
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

private enum EmbeddedFixtures {
    static let supportDashboardSpec = #"""
    {
      "root": "root",
      "elements": {
        "root": {
          "type": "root",
          "children": {
            "children": ["title", "subtitle", "nameField", "saveButton"]
          }
        },
        "title": {
          "type": "text",
          "parentKey": "root",
          "props": {
            "text": "Support Dashboard"
          },
          "styles": {
            "font-size": 24,
            "font-weight": "bold"
          }
        },
        "subtitle": {
          "type": "text",
          "parentKey": "root",
          "props": {
            "text": "Ticket #1842 · Pending"
          },
          "styles": {
            "color": "#666666"
          }
        },
        "nameField": {
          "type": "text-field",
          "parentKey": "root",
          "props": {
            "placeholder": "Customer name",
            "binding": "$data.customer.name"
          }
        },
        "saveButton": {
          "type": "button",
          "parentKey": "root",
          "props": {
            "text": "Save",
            "action": {
              "name": "set_data",
              "params": {
                "path": "$data.customer.saved",
                "value": true
              }
            }
          }
        }
      }
    }
    """#

    static let supportDashboardPatches = [
        "{\"op\":\"replace\",\"path\":\"/elements/subtitle/props/text\",\"value\":\"Ticket #1842 · Assigned to Ava\"}",
        "{\"op\":\"set\",\"path\":\"/elements/badge\",\"value\":{\"type\":\"badge\",\"parentKey\":\"root\",\"props\":{\"text\":\"PRO\"},\"styles\":{\"background-color\":\"#DFF5E1\",\"color\":\"#147A2E\"}}}",
        "{\"op\":\"add\",\"path\":\"/elements/root/children/children/2\",\"value\":\"badge\"}",
        "{\"op\":\"replace\",\"path\":\"/elements/saveButton/props/text\",\"value\":\"Saved\"}",
    ]

    static let guardrailSpec = #"""
    {
      "root": "root",
      "elements": {
        "root": {
          "type": "root",
          "children": {
            "children": ["bad"]
          }
        },
        "bad": {
          "type": "unknown-widget",
          "parentKey": "root",
          "props": {
            "text": "This should trigger a guardrail"
          }
        }
      }
    }
    """#

    static let generatedFormSpec = #"""
    {
      "root": "root",
      "elements": {
        "root": {
          "type": "root",
          "children": {
            "children": ["title", "subtitle", "nameField", "emailField", "submitButton"]
          }
        },
        "title": {
          "type": "text",
          "parentKey": "root",
          "props": {
            "text": "Profile Intake"
          },
          "styles": {
            "font-size": 24,
            "font-weight": "bold"
          }
        },
        "subtitle": {
          "type": "text",
          "parentKey": "root",
          "props": {
            "text": "Review and submit your details"
          },
          "styles": {
            "color": "#666666"
          }
        },
        "nameField": {
          "type": "text-field",
          "parentKey": "root",
          "props": {
            "placeholder": "Full name",
            "binding": "$data.profile.fullName"
          }
        },
        "emailField": {
          "type": "text-field",
          "parentKey": "root",
          "props": {
            "placeholder": "Email address",
            "binding": "$data.profile.email"
          }
        },
        "submitButton": {
          "type": "button",
          "parentKey": "root",
          "props": {
            "text": "Submit",
            "action": {
              "name": "submit",
              "params": {
                "payload": {
                  "intent": "profile_intake",
                  "version": "v1"
                }
              }
            }
          }
        }
      }
    }
    """#

    static let generatedFormPatches = [
        "{\"op\":\"replace\",\"path\":\"/elements/subtitle/props/text\",\"value\":\"Edit the fields, then submit the generated view\"}",
        "{\"op\":\"set\",\"path\":\"/elements/badge\",\"value\":{\"type\":\"badge\",\"parentKey\":\"root\",\"props\":{\"text\":\"Generated UI\"},\"styles\":{\"background-color\":\"#E9F2FF\",\"color\":\"#1C4DA1\"}}}",
        "{\"op\":\"add\",\"path\":\"/elements/root/children/children/2\",\"value\":\"badge\"}",
    ]
}

private struct RenderChatStreamServer: ServerDefinition {
    enum Environments: Hashable {
        case local
    }

    nonisolated(unsafe) static var baseURL: URL = URL(string: "http://127.0.0.1:8080")!

    init() {}

    var baseUrls: [Environments: URL] {
        [.local: Self.baseURL]
    }

    static var defaultEnvironment: Environments {
        .local
    }
}

private struct RenderChatStreamEndpoint: Endpoint {
    typealias Server = RenderChatStreamServer
    typealias Response = Data

    static let definition: Definition<RenderChatStreamEndpoint> = Definition(
        method: .post,
        path: "/render-chat/stream",
        headers: [
            .accept: .fieldValue(value: "text/event-stream"),
        ]
    )

    struct Body: Encodable, Sendable {
        let prompt: String
        let sessionID: String
        let catalogID: String
        let seed: Int

        enum CodingKeys: String, CodingKey {
            case prompt
            case sessionID = "session_id"
            case catalogID = "catalog_id"
            case seed
        }
    }

    let body: Body
}

private struct MessageIDPayload: Decodable {
    let messageID: String

    enum CodingKeys: String, CodingKey {
        case messageID
        case messageId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messageID = try container.decodeIfPresent(String.self, forKey: .messageID)
            ?? container.decode(String.self, forKey: .messageId)
    }
}

private struct AssistantTextDeltaPayload: Decodable {
    let messageID: String
    let delta: String

    enum CodingKeys: String, CodingKey {
        case messageID
        case messageId
        case delta
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messageID = try container.decodeIfPresent(String.self, forKey: .messageID)
            ?? container.decode(String.self, forKey: .messageId)
        delta = try container.decode(String.self, forKey: .delta)
    }
}

private struct RenderStartedPayload: Decodable {
    let messageID: String
    let initialSpec: UISpec
    let initialData: JSONValue?

    enum CodingKeys: String, CodingKey {
        case messageID
        case messageId
        case initialSpec
        case spec
        case initialData
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messageID = try container.decodeIfPresent(String.self, forKey: .messageID)
            ?? container.decode(String.self, forKey: .messageId)

        initialSpec = try container.decodeIfPresent(UISpec.self, forKey: .initialSpec)
            ?? container.decode(UISpec.self, forKey: .spec)

        initialData = try container.decodeIfPresent(JSONValue.self, forKey: .initialData)
            ?? container.decodeIfPresent(JSONValue.self, forKey: .data)
    }
}

private struct RenderPatchPayload: Decodable {
    let messageID: String
    let patch: SpecPatch

    enum CodingKeys: String, CodingKey {
        case messageID
        case messageId
        case patch
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messageID = try container.decodeIfPresent(String.self, forKey: .messageID)
            ?? container.decode(String.self, forKey: .messageId)
        patch = try container.decode(SpecPatch.self, forKey: .patch)
    }
}

private struct GuardrailPayload: Decodable {
    let issue: GuardrailIssue

    enum CodingKeys: String, CodingKey {
        case severity
        case message
        case path
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        issue = GuardrailIssue(
            severity: try container.decode(GuardrailSeverity.self, forKey: .severity),
            message: try container.decode(String.self, forKey: .message),
            path: try container.decodeIfPresent(String.self, forKey: .path)
        )
    }
}

private struct ErrorPayload: Decodable {
    let message: String
}

private extension String {
    var wordChunks: [String] {
        split(separator: " ")
            .map(String.init)
            .map { $0 + " " }
    }
}

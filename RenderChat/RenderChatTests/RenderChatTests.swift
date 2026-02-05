import Testing
import SwiftUIRender
import Foundation
@testable import RenderChat

@MainActor
struct RenderChatTests {
    @Test
    func transcriptOrdering_userAssistantRender() async {
        let viewModel = makeViewModel()

        viewModel.updateComposer("Build support dashboard")
        viewModel.sendPrompt()

        let rendered = await waitUntil {
            viewModel.messages.contains { message in
                if case .render = message.content {
                    return true
                }
                return false
            }
        }

        #expect(rendered)

        let kinds = viewModel.messages.map(\.kind)
        #expect(kinds.first == .userText)
        #expect(kinds.dropFirst().first == .assistantText)

        let assistantRenderIndex = kinds.firstIndex(of: .assistantRender)
        let assistantTextIndex = kinds.firstIndex(of: .assistantText)
        #expect(assistantRenderIndex != nil)
        #expect(assistantTextIndex != nil)
        #expect((assistantRenderIndex ?? 0) > (assistantTextIndex ?? 0))
    }

    @Test
    func replayDeterminism_samePromptProducesSameStreamLogs() async {
        let first = makeViewModel()
        let second = makeViewModel()

        first.updateComposer("Support dashboard")
        first.sendPrompt()

        second.updateComposer("Support dashboard")
        second.sendPrompt()

        let firstDone = await waitUntil {
            !first.isStreaming && first.messages.contains { message in
                if case .render = message.content {
                    return true
                }
                return false
            }
        }

        let secondDone = await waitUntil {
            !second.isStreaming && second.messages.contains { message in
                if case .render = message.content {
                    return true
                }
                return false
            }
        }

        #expect(firstDone)
        #expect(secondDone)

        let firstRenderLog = renderSummaries(from: first.messages)
        let secondRenderLog = renderSummaries(from: second.messages)

        #expect(normalize(firstRenderLog) == normalize(secondRenderLog))

        let firstAssistantText = first.messages.compactMap { message -> String? in
            guard message.kind == .assistantText,
                  case let .text(text) = message.content else {
                return nil
            }
            return text
        }.first

        let secondAssistantText = second.messages.compactMap { message -> String? in
            guard message.kind == .assistantText,
                  case let .text(text) = message.content else {
                return nil
            }
            return text
        }.first

        #expect(firstAssistantText == secondAssistantText)
    }

    @Test
    func secondPromptCancelsFirstStream() async {
        let viewModel = makeViewModel(textDelay: 60_000_000, patchDelay: 120_000_000)

        viewModel.updateComposer("First")
        viewModel.sendPrompt()

        let firstStarted = await waitUntil {
            viewModel.isStreaming
        }
        #expect(firstStarted)

        viewModel.updateComposer("Second")
        viewModel.sendPrompt()

        let hasCancellationNotice = await waitUntil {
            viewModel.messages.contains { message in
                guard case let .system(content) = message.content else {
                    return false
                }
                return content.text.contains("Cancelled previous stream")
            }
        }

        #expect(hasCancellationNotice)
    }

    @Test
    func diagnosticsAreConvertedToSystemMessages() async {
        let viewModel = makeViewModel()

        let issue = GuardrailIssue(
            severity: .error,
            message: "Unsupported component",
            path: "/elements/bad/type"
        )

        viewModel.receiveDiagnostics(renderID: "render-id", issues: [issue])

        let hasIssue = await waitUntil {
            viewModel.messages.contains { message in
                guard case let .system(content) = message.content else {
                    return false
                }
                return content.text.contains("Unsupported component")
                    && content.text.contains("/elements/bad/type")
            }
        }

        #expect(hasIssue)
    }

    @Test
    func actionResultsBecomeSystemMessages() async {
        let viewModel = makeViewModel()

        viewModel.recordActionResult("Action: set_data -> /customer/saved = true")

        let hasActionResult = await waitUntil {
            viewModel.messages.contains { message in
                guard case let .system(content) = message.content else {
                    return false
                }
                return content.text.contains("Action: set_data")
            }
        }

        #expect(hasActionResult)
    }

    private func makeViewModel(
        textDelay: UInt64 = 1_000_000,
        patchDelay: UInt64 = 1_000_000
    ) -> ChatHarnessViewModel {
        ChatHarnessViewModel(
            replayClientFactory: { scenario in
                ReplayChatStreamClient(
                    scenario: scenario,
                    textChunkDelayNanoseconds: textDelay,
                    patchDelayNanoseconds: patchDelay
                )
            },
            localSSEClient: ReplayChatStreamClient(scenario: .supportDashboard)
        )
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 2_500_000_000,
        pollNanoseconds: UInt64 = 20_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        let deadline = Date().timeIntervalSince1970 + Double(timeoutNanoseconds) / 1_000_000_000.0

        while await MainActor.run(body: condition) == false {
            if Date().timeIntervalSince1970 >= deadline {
                return false
            }

            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }

        return true
    }

    private func renderSummaries(from messages: [ChatMessage]) -> [String] {
        messages.compactMap { message in
            guard case let .render(content) = message.content else {
                return nil
            }

            return content.rawEvents.map(\.summary).joined(separator: "|")
        }
    }

    private func normalize(_ logs: [String]) -> [String] {
        logs.map { log in
            log.replacingOccurrences(
                of: "render-[0-9A-F\\-]{36}",
                with: "render-<id>",
                options: .regularExpression
            )
        }
    }
}

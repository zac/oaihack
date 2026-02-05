import Foundation
import SwiftUIRender
import Testing
@testable import RenderChat

@MainActor
struct RenderChatTests {
    @Test
    func submitScenarioActivatesTakeoverAndSuppressesAssistantRenderBubble() async {
        let viewModel = makeViewModel()

        viewModel.updateComposer("Generate a profile form with a submit action")
        viewModel.sendPrompt()

        let takeoverReady = await waitUntil {
            viewModel.takeoverComposerState != nil
        }

        #expect(takeoverReady)
        #expect(viewModel.canSubmitTakeoverFromComposer)

        let hasAssistantRender = viewModel.messages.contains { message in
            message.kind == .assistantRender
        }

        #expect(hasAssistantRender == false)
    }

    @Test
    func dismissTakeoverRefilesAssistantRenderAndRestoresTextComposer() async {
        let viewModel = makeViewModel()

        viewModel.updateComposer("Build a submit form")
        viewModel.sendPrompt()

        let takeoverReady = await waitUntil {
            viewModel.takeoverComposerState != nil
        }

        #expect(takeoverReady)

        viewModel.dismissTakeover()

        let assistantRenderAppeared = await waitUntil {
            viewModel.messages.contains { message in
                message.kind == .assistantRender
            }
        }

        #expect(assistantRenderAppeared)

        if case .text = viewModel.composerMode {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
        }
    }

    @Test
    func submitTakeoverCreatesUserRenderAndAssistantFollowup() async {
        let viewModel = makeViewModel()

        viewModel.updateComposer("Create a form I can submit")
        viewModel.sendPrompt()

        let takeoverReady = await waitUntil {
            viewModel.takeoverComposerState != nil
        }

        #expect(takeoverReady)

        viewModel.submitTakeoverFromComposer()

        let submitted = await waitUntil {
            let hasUserRender = viewModel.messages.contains { message in
                message.kind == .userRender
            }

            let hasFollowup = viewModel.messages.contains { message in
                guard message.kind == .assistantText,
                      case let .text(text) = message.content
                else {
                    return false
                }

                return text.contains("captured your submitted UI")
            }

            return hasUserRender && hasFollowup
        }

        #expect(submitted)

        if case .text = viewModel.composerMode {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
        }
    }

    @Test
    func composerArrowEnabledOnlyForSingleSubmitTarget() async {
        let singleSubmitViewModel = makeViewModel()

        singleSubmitViewModel.updateComposer("Please generate a submit form")
        singleSubmitViewModel.sendPrompt()

        let singleTakeoverReady = await waitUntil {
            singleSubmitViewModel.takeoverComposerState != nil
        }

        #expect(singleTakeoverReady)
        #expect(singleSubmitViewModel.canSubmitTakeoverFromComposer)

        let multiSubmitViewModel = ChatHarnessViewModel(
            replayClientFactory: { _ in
                StubStreamClient(spec: Self.multiSubmitSpec())
            },
            localSSEClient: StubStreamClient(spec: Self.multiSubmitSpec())
        )

        multiSubmitViewModel.updateComposer("submit form")
        multiSubmitViewModel.sendPrompt()

        let settled = await waitUntil {
            multiSubmitViewModel.messages.contains { $0.kind == .assistantRender }
                || multiSubmitViewModel.takeoverComposerState != nil
        }

        #expect(settled)
        #expect(multiSubmitViewModel.takeoverComposerState == nil)
        #expect(multiSubmitViewModel.canSubmitTakeoverFromComposer == false)

        let hasAssistantRender = multiSubmitViewModel.messages.contains { message in
            message.kind == .assistantRender
        }
        #expect(hasAssistantRender)
    }

    @Test
    func clearSessionResetsTranscriptTakeoverAndPayloadCache() async {
        let viewModel = makeViewModel()

        viewModel.updateComposer("Create a form I can submit")
        viewModel.sendPrompt()

        let takeoverReady = await waitUntil {
            viewModel.takeoverComposerState != nil
        }

        #expect(takeoverReady)

        let takeoverRenderID = viewModel.takeoverComposerState?.renderID
        #expect(takeoverRenderID != nil)

        viewModel.clearSession()

        let cleared = await waitUntil {
            viewModel.messages.isEmpty && !viewModel.isStreaming
        }

        #expect(cleared)
        #expect(viewModel.composerText.isEmpty)

        if case .text = viewModel.composerMode {
            #expect(Bool(true))
        } else {
            #expect(Bool(false))
        }

        if let takeoverRenderID {
            #expect(viewModel.payload(for: takeoverRenderID) == nil)
        }
    }

    @Test
    func keywordRoutingIsDeterministicForSamePrompt() async {
        let first = makeViewModel()
        let second = makeViewModel()

        let prompt = "Please generate a profile form with submit"
        first.updateComposer(prompt)
        first.sendPrompt()

        second.updateComposer(prompt)
        second.sendPrompt()

        let firstReady = await waitUntil {
            first.takeoverComposerState != nil
        }
        let secondReady = await waitUntil {
            second.takeoverComposerState != nil
        }

        #expect(firstReady)
        #expect(secondReady)

        let firstAssistantText = first.messages.compactMap { message -> String? in
            guard message.kind == .assistantText,
                  case let .text(text) = message.content
            else {
                return nil
            }

            return text
        }.first

        let secondAssistantText = second.messages.compactMap { message -> String? in
            guard message.kind == .assistantText,
                  case let .text(text) = message.content
            else {
                return nil
            }

            return text
        }.first

        #expect(firstAssistantText == secondAssistantText)

        if let firstRenderID = first.takeoverComposerState?.renderID,
           let secondRenderID = second.takeoverComposerState?.renderID,
           let firstPayload = first.payload(for: firstRenderID),
           let secondPayload = second.payload(for: secondRenderID) {
            #expect(firstPayload.debugInitialSpecJSON == secondPayload.debugInitialSpecJSON)
            #expect(firstPayload.debugPatchSequenceJSON == secondPayload.debugPatchSequenceJSON)
        } else {
            #expect(Bool(false))
        }
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
    func updateComposerReflectsTypedText() async {
        let viewModel = makeViewModel()

        viewModel.updateComposer("hello world")

        let didUpdate = await waitUntil {
            viewModel.composerText == "hello world"
        }

        #expect(didUpdate)
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

    private static func multiSubmitSpec() -> UISpec {
        UISpec(
            root: "root",
            elements: [
                "root": UIElement(
                    type: "root",
                    children: ["children": ["title", "submitOne", "submitTwo"]]
                ),
                "title": UIElement(
                    type: "text",
                    parentKey: "root",
                    props: ["text": .string("Two submit actions")]
                ),
                "submitOne": UIElement(
                    type: "button",
                    parentKey: "root",
                    props: [
                        "text": .string("Submit A"),
                        "action": .object([
                            "name": .string("submit"),
                            "params": .object([
                                "payload": .object([
                                    "variant": .string("A"),
                                ]),
                            ]),
                        ]),
                    ]
                ),
                "submitTwo": UIElement(
                    type: "button",
                    parentKey: "root",
                    props: [
                        "text": .string("Submit B"),
                        "action": .object([
                            "name": .string("submit"),
                            "params": .object([
                                "payload": .object([
                                    "variant": .string("B"),
                                ]),
                            ]),
                        ]),
                    ]
                ),
            ]
        )
    }
}

private struct StubStreamClient: ChatStreamClient {
    let spec: UISpec
    var delayNanoseconds: UInt64 = 50_000_000

    func stream(prompt: String, sessionID: UUID) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                let renderMessageID = "render-\(sessionID.uuidString)"
                let assistantTextMessageID = "assistant-\(sessionID.uuidString)"

                // Keep deterministic ordering while allowing streamStarted mutation to land first.
                try? await Task.sleep(nanoseconds: delayNanoseconds)
                continuation.yield(.assistantTextDelta(messageID: assistantTextMessageID, delta: "stub "))
                continuation.yield(.assistantTextDone(messageID: assistantTextMessageID))
                continuation.yield(
                    .renderStarted(
                        messageID: renderMessageID,
                        initialSpec: spec,
                        initialData: .object([:])
                    )
                )
                continuation.yield(.renderDone(messageID: renderMessageID))
                continuation.yield(.done)
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

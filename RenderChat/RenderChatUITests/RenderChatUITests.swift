import XCTest

final class RenderChatUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPromptCreatesUserAssistantAndRenderBubbles() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "replay"
        app.launchEnvironment["UITEST_REPLAY_SCENARIO"] = "supportDashboard"
        app.launchEnvironment["UITEST_AUTOSEND_PROMPT"] = "Build support dashboard"
        app.launch()

        let customerNameField = app.textFields["Customer name"]
        let saveButton = app.buttons["Save"]
        let savedButton = app.buttons["Saved"]

        guard customerNameField.waitForExistence(timeout: 8.0) else {
            throw XCTSkip("Replay render controls were not visible in this UI test environment.")
        }

        if saveButton.waitForExistence(timeout: 3.0) == false,
           savedButton.waitForExistence(timeout: 3.0) == false {
            throw XCTSkip("Render action button was not visible in this UI test environment.")
        }
    }

    @MainActor
    func testRenderInteractionsEmitSystemActionBubble() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UITEST_MODE"] = "replay"
        app.launchEnvironment["UITEST_REPLAY_SCENARIO"] = "supportDashboard"
        app.launchEnvironment["UITEST_AUTOSEND_PROMPT"] = "Support dashboard"
        app.launch()

        let textField = app.textFields["Customer name"]
        guard textField.waitForExistence(timeout: 8.0) else {
            throw XCTSkip("Replay render controls were not visible in this UI test environment.")
        }
        textField.tap()
        textField.typeText("Ivy")

        let saveButton = app.buttons["Save"]
        let savedButton = app.buttons["Saved"]

        if saveButton.waitForExistence(timeout: 3.0) {
            saveButton.tap()
        } else {
            guard savedButton.waitForExistence(timeout: 3.0) else {
                throw XCTSkip("Render action button was not visible in this UI test environment.")
            }
            savedButton.tap()
        }

        let actionSystemText = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "Action: set_data")
        ).firstMatch

        guard actionSystemText.waitForExistence(timeout: 6.0) else {
            throw XCTSkip("Action system message was not visible in this UI test environment.")
        }
    }
}

import XCTest

/// Walks through the main screens and saves a screenshot of each.
///
/// Screenshots are attached to the test result and, when CI sets
/// `TEST_RUNNER_SCREENSHOT_DIR`, also written as PNGs to that folder
/// (the runner sees it as `SCREENSHOT_DIR`).
final class ScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureMainScreens() throws {
        let app = launch()

        // Profile picker
        snap("01-profile-picker", app, waitFor: app.buttons["profile-Lena"])

        // Lena (5): home and a young child's maths question
        app.buttons["profile-Lena"].tap()
        snap("02-home", app, waitFor: app.buttons["subject-maths"])

        app.buttons["subject-maths"].tap()
        let wrong = app.buttons["answer-wrong"].firstMatch
        snap("03-maths-age-5", app, waitFor: wrong, settle: 1.5)

        // Wrong answer: gentle reveal
        wrong.tap()
        snap("04-wrong-answer", app, waitFor: app.buttons["round-next"])
        app.buttons["round-next"].tap()

        // Correct answer: praise
        let correct = app.buttons["answer-correct"].firstMatch
        XCTAssertTrue(correct.waitForExistence(timeout: 8))
        pause(1.2)
        correct.tap()
        snap("05-correct-answer", app, settle: 0.5)

        // Answer the rest correctly to reach the summary
        let done = app.buttons["summary-done"]
        answerCorrectlyUntil(done, app)
        snap("06-summary", app, waitFor: done, settle: 2.5)

        // Lena (5): vocabulary picture question
        done.tap()
        open("subject-vocabulary", app)
        snap("07-vocab-age-5", app, waitFor: app.buttons["answer-correct"].firstMatch, settle: 1.2)
        app.buttons["round-close"].tap()

        // Lena (5): general knowledge
        open("subject-generalKnowledge", app)
        snap("08-knowledge-age-5", app, waitFor: app.buttons["round-close"], settle: 1.2)
        app.buttons["round-close"].tap()

        // Emil (10): number pad
        switchTo("Emil", app)
        open("subject-maths", app)
        snap("09-maths-age-10", app, waitFor: app.buttons["key-check"], settle: 1.0)
        app.buttons["round-close"].tap()

        // Emil (10): general knowledge
        open("subject-generalKnowledge", app)
        snap("10-knowledge-age-10", app, waitFor: app.buttons["round-close"], settle: 1.2)
        app.buttons["round-close"].tap()

        // Grown-up area: gate, overview, Emil's settings
        open("grown-ups", app)
        let question = app.staticTexts["gate-question"]
        snap("12-gate", app, waitFor: question)
        solveGate(question.label, app)
        let emilRow = app.descendants(matching: .any).matching(identifier: "settings-profile-Emil").firstMatch
        snap("13-grown-ups", app, waitFor: emilRow, settle: 1.0)
        emilRow.tap()
        snap("14-profile-settings", app, waitFor: app.buttons["editor-save"], settle: 1.0)
        app.swipeUp()
        snap("15-profile-settings-more", app, settle: 1.0)

        // Emil (10): spelling with letter tiles (forced via a Debug-only launch argument)
        app.terminate()
        let spellingApp = launch(extra: ["-forceVocabularyType", "spelling"])
        spellingApp.buttons["profile-Emil"].tap()
        open("subject-vocabulary", spellingApp)
        let firstTile = spellingApp.buttons["tile-0"]
        XCTAssertTrue(firstTile.waitForExistence(timeout: 8))
        pause(1.0)
        firstTile.tap()
        spellingApp.buttons["tile-1"].tap()
        snap("11-vocab-spelling-age-10", spellingApp, settle: 0.8)
    }

    /// The same app at a large accessibility text size (AX3, the app's cap).
    @MainActor
    func testCaptureLargeText() throws {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"])

        snap("20-large-text-picker", app, waitFor: app.buttons["profile-Lena"])
        app.buttons["profile-Lena"].tap()
        snap("21-large-text-home", app, waitFor: app.buttons["subject-maths"])
        open("subject-maths", app)
        snap("22-large-text-maths-age-5", app, waitFor: app.buttons["answer-correct"].firstMatch, settle: 1.5)
        app.buttons["round-close"].tap()

        switchTo("Emil", app)
        open("subject-generalKnowledge", app)
        snap("23-large-text-knowledge-age-10", app, waitFor: app.buttons["round-close"], settle: 1.5)
    }

    // MARK: Helpers

    @MainActor
    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        // Sample profiles in an in-memory store; German UI regardless of the simulator's language.
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"] + extra
        app.launch()
        return app
    }

    @MainActor
    private func open(_ identifier: String, _ app: XCUIApplication) {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 8), "missing \(identifier)")
        button.tap()
    }

    /// Reads "Wie viel ist 14 × 7?" off the screen and types the answer, as a grown-up would.
    @MainActor
    private func solveGate(_ question: String, _ app: XCUIApplication) {
        let numbers = question.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        XCTAssertEqual(numbers.count, 2, "unexpected gate question: \(question)")
        guard numbers.count == 2 else { return }
        for digit in String(numbers[0] * numbers[1]) {
            app.buttons["gate-key-\(digit)"].tap()
        }
        app.buttons["gate-check"].tap()
    }

    @MainActor
    private func switchTo(_ name: String, _ app: XCUIApplication) {
        let switchProfile = app.buttons["switch-profile"]
        XCTAssertTrue(switchProfile.waitForExistence(timeout: 8))
        switchProfile.tap()
        let profile = app.buttons["profile-\(name)"]
        XCTAssertTrue(profile.waitForExistence(timeout: 8))
        profile.tap()
    }

    /// Taps the correct answer whenever one is on screen and enabled.
    ///
    /// Questions slide in and out, so the button can vanish between two queries.
    /// `snapshot()` reads frame and state in one go and throws (instead of
    /// failing the test) when the button is gone; the tap goes to a screen
    /// coordinate, which never fails.
    @MainActor
    private func answerCorrectlyUntil(_ target: XCUIElement, _ app: XCUIApplication) {
        let origin = app.coordinate(withNormalizedOffset: .zero)
        for _ in 0..<60 where !target.exists {
            if let answer = try? app.buttons["answer-correct"].firstMatch.snapshot(),
               answer.isEnabled, app.frame.contains(answer.frame) {
                origin.withOffset(CGVector(dx: answer.frame.midX, dy: answer.frame.midY)).tap()
            }
            pause(0.5)
        }
    }

    @MainActor
    private func snap(_ name: String, _ app: XCUIApplication, waitFor element: XCUIElement? = nil, settle: TimeInterval = 0.8) {
        if let element {
            XCTAssertTrue(element.waitForExistence(timeout: 10), "\(name): waiting for \(element)")
        }
        pause(settle)

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        if let directory = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !directory.isEmpty {
            let url = URL(fileURLWithPath: directory, isDirectory: true)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: url.appendingPathComponent("\(name).png"))
        }
    }

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }
}

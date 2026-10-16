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
        let app = XCUIApplication()
        // Sample profiles in an in-memory store; German UI regardless of the simulator's language.
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

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
        for _ in 0..<40 where !done.exists {
            let next = app.buttons["answer-correct"].firstMatch
            if next.exists, next.isHittable, next.isEnabled {
                next.tap()
            }
            pause(0.5)
        }
        snap("06-summary", app, waitFor: done, settle: 2.5)

        // Emil (10): number pad
        done.tap()
        let switchProfile = app.buttons["switch-profile"]
        XCTAssertTrue(switchProfile.waitForExistence(timeout: 8))
        switchProfile.tap()
        let emil = app.buttons["profile-Emil"]
        XCTAssertTrue(emil.waitForExistence(timeout: 8))
        emil.tap()
        let maths = app.buttons["subject-maths"]
        XCTAssertTrue(maths.waitForExistence(timeout: 8))
        maths.tap()
        snap("07-maths-age-10", app, waitFor: app.buttons["key-check"], settle: 1.0)
    }

    // MARK: Helpers

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

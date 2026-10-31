import XCTest

/// Walks through the Spielecke and its three games and saves a screenshot of
/// each (same output as ScreenshotTests: attachments, plus PNGs in
/// `SCREENSHOT_DIR` on CI).
final class PlayCornerScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCapturePlayCorner() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        // Lena (5) has 42 stars: enough for three games at 10 each.
        let lena = app.buttons["profile-Lena"]
        XCTAssertTrue(lena.waitForExistence(timeout: 10))
        lena.tap()
        open("play-corner", app)
        snap("30-play-corner", app, waitFor: app.buttons["game-memory"])

        // Memory: flip two cards
        app.buttons["game-memory"].tap()
        let cards = app.buttons.matching(identifier: "memory-card")
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 8))
        pause(0.8)
        cards.element(boundBy: 0).tap()
        cards.element(boundBy: 1).tap()
        snap("31-memory", app, settle: 0.3)
        endGame(app, snapshot: "32-game-over")

        // Ballon-Pop: let a few balloons rise
        app.buttons["game-balloons"].tap()
        snap("33-balloons", app, waitFor: app.descendants(matching: .any)["balloon-hint"], settle: 4)
        endGame(app)

        // Sternenfänger
        app.buttons["game-stars"].tap()
        snap("34-star-catcher", app, waitFor: app.buttons["game-end"], settle: 4)
        endGame(app)

        // Three games played: the daily limit is reached.
        let status = app.descendants(matching: .any)["play-status"]
        snap("35-daily-limit", app, waitFor: status, settle: 1)
        XCTAssertFalse(app.buttons["game-memory"].isEnabled)

        // A grown-up unlocks two free extra games.
        app.buttons["bonus-unlock"].tap()
        let question = app.staticTexts["gate-question"]
        XCTAssertTrue(question.waitForExistence(timeout: 8))
        solveGate(question.label, app)
        let two = app.buttons["bonus-2"]
        snap("36-bonus-unlock", app, waitFor: two)
        two.tap()
        snap("37-bonus-games", app, waitFor: app.descendants(matching: .any)["play-bonus"], settle: 1)
        XCTAssertTrue(app.buttons["game-memory"].isEnabled)
    }

    // MARK: Helpers

    @MainActor
    private func endGame(_ app: XCUIApplication, snapshot name: String? = nil) {
        let end = app.buttons["game-end"]
        XCTAssertTrue(end.waitForExistence(timeout: 8))
        end.tap()
        let done = app.buttons["game-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 8))
        if let name { snap(name, app, settle: 1.2) }
        done.tap()
        XCTAssertTrue(app.buttons["play-back"].waitForExistence(timeout: 8))
        pause(0.6)
    }

    /// Lazy grids only create on-screen cells, so scroll until the button exists.
    @MainActor
    private func open(_ identifier: String, _ app: XCUIApplication) {
        let button = app.buttons[identifier]
        var swipes = 0
        while !button.waitForExistence(timeout: swipes == 0 ? 8 : 2) && swipes < 4 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(button.exists, "missing \(identifier)")
        button.tap()
    }

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

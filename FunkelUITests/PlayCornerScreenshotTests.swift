import XCTest

/// The Spielecke and its three games, one screenshot each (same output as ScreenshotTests).
final class PlayCornerScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCapturePlayCorner() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        // Lena (5) has 42 stars: four games at 10 stars, three of them today.
        let lena = app.buttons["profile-Lena"]
        XCTAssertTrue(lena.waitForExistence(timeout: 10))
        lena.tap()
        open("play-corner", app)
        snap("30-play-corner", app, waitFor: app.buttons["game-memory"])

        play("game-memory", snapshot: "31-memory", app) {
            let cards = app.buttons.matching(identifier: "memory-card")
            if cards.count > 1 {
                cards.element(boundBy: 0).tap()
                cards.element(boundBy: 1).tap()
            }
        }
        play("game-balloons", snapshot: "32-balloons", app) { self.pause(3) }
        play("game-stars", snapshot: "33-star-catcher", app) {
            let field = app.descendants(matching: .any).matching(identifier: "star-field").firstMatch
            if field.exists { field.tap() }
            self.pause(2)
        }

        // Daily limit reached: the cards are greyed out.
        snap("35-play-corner-limit", app, waitFor: app.buttons["game-memory"], settle: 1.0)
    }

    // MARK: Helpers

    @MainActor
    private func play(_ game: String, snapshot name: String, _ app: XCUIApplication, while action: () -> Void) {
        let button = app.buttons[game]
        XCTAssertTrue(button.waitForExistence(timeout: 8), "missing \(game)")
        button.tap()
        let end = app.buttons["game-end"]
        XCTAssertTrue(end.waitForExistence(timeout: 8))
        pause(1.0)
        action()
        snap(name, app, settle: 0.6)
        end.tap()
        let done = app.buttons["game-done"]
        if name == "31-memory" { snap("34-game-over", app, waitFor: done, settle: 1.2) }
        XCTAssertTrue(done.waitForExistence(timeout: 8))
        done.tap()
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

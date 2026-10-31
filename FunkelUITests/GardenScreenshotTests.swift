import XCTest

/// Pips Garten: Emil's sample farm, the shop, the order board, placing
/// something and drawing a road. Screenshots 40–49 (see ScreenshotTests for
/// how they are saved).
final class GardenScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureGarden() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()

        let emil = app.buttons["profile-Emil"]
        XCTAssertTrue(emil.waitForExistence(timeout: 10))
        emil.tap()
        open("play-corner", app)
        open("game-garden", app)

        let shop = app.buttons["farm-shop"]
        snap("40-garden", app, waitFor: shop, settle: 2.0)

        // Collect everything that's ready: goods and XP float up.
        let collect = app.buttons["farm-collect"]
        if collect.waitForExistence(timeout: 3) {
            collect.tap()
            snap("41-garden-collected", app, settle: 0.5)
        }

        // The shop, with locked items and land.
        shop.tap()
        snap("42-garden-shop", app, waitFor: app.buttons["sheet-close"], settle: 1.0)
        app.buttons["garden-tab-buildings"].tap()
        snap("43-garden-shop-buildings", app, settle: 0.8)

        // Pick a flower and plant it on a free square.
        app.buttons["garden-tab-plants"].tap()
        let flower = app.buttons["shop-flower"]
        XCTAssertTrue(flower.waitForExistence(timeout: 5))
        flower.tap()
        let ground = app.descendants(matching: .any)["garden-ground"].firstMatch
        XCTAssertTrue(ground.waitForExistence(timeout: 5))
        // Row 3, column 1 of the sample farm is free (16 columns, 8 rows).
        ground.coordinate(withNormalizedOffset: CGVector(dx: 0.5 / 16, dy: 2.5 / 8)).tap()
        snap("44-garden-placed", app, settle: 0.6)
        if app.buttons["tool-done"].exists { app.buttons["tool-done"].tap() }

        // The order board: storage, today's orders and the farm shop.
        app.buttons["farm-orders"].tap()
        snap("45-garden-orders", app, waitFor: app.buttons["farm-sell"], settle: 1.0)
        app.buttons["sheet-close"].tap()

        app.buttons["garden-back"].tap()
    }

    // MARK: Helpers

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
        Thread.sleep(forTimeInterval: settle)

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
}

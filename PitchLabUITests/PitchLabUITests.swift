import XCTest

final class PitchLabUITests: XCTestCase {
    func testPianoOpensAndPlays() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["钢琴"].tap()
        XCTAssertTrue(app.staticTexts["触摸琴键，听见标准音"].waitForExistence(timeout: 5))
        saveScreenshot(app, name: "钢琴")
        app.scrollViews.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).press(forDuration: 0.3)
        XCTAssertTrue(app.exists)
    }

    func testQuizOpensAndReplays() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["听音测试"].tap()
        XCTAssertTrue(app.staticTexts["你听到了哪个音？"].waitForExistence(timeout: 5))
        saveScreenshot(app, name: "听音测试")
        app.buttons["再听一次"].tap()
        XCTAssertTrue(app.exists)
    }

    func testPracticeLibraryOpens() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["练唱"].tap()
        XCTAssertTrue(app.staticTexts["导入乐谱，开始练唱"].waitForExistence(timeout: 5))
        saveScreenshot(app, name: "练唱")
    }

    func testVocalPhrasePracticeOpensAndChangesPhrase() {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-test-vocal-score")
        app.launch()
        app.tabBars.buttons["练唱"].tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Vocal UI Test")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["第一句"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["听示范"].exists)
        XCTAssertTrue(app.buttons["开始跟唱"].exists)
        saveScreenshot(app, name: "逐句练唱")
        app.buttons["下句"].tap()
        XCTAssertTrue(app.staticTexts["第二句"].waitForExistence(timeout: 3))
    }

    private func saveScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

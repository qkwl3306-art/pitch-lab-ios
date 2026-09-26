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

    private func saveScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

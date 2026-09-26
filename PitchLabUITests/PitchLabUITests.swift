import XCTest

final class PitchLabUITests: XCTestCase {
    func testPianoOpensAndPlays() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["钢琴"].tap()
        XCTAssertTrue(app.staticTexts["触摸琴键，听见标准音"].waitForExistence(timeout: 5))
        app.otherElements["C4 琴键"].firstMatch.press(forDuration: 0.3)
        XCTAssertTrue(app.exists)
    }

    func testQuizOpensAndReplays() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["听音测试"].tap()
        XCTAssertTrue(app.staticTexts["你听到了哪个音？"].waitForExistence(timeout: 5))
        app.buttons["再听一次"].tap()
        XCTAssertTrue(app.exists)
    }
}

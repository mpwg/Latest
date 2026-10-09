import XCTest

@MainActor final class LatestUITests: XCTestCase {
    private func launch(_ language: String = "en") -> XCUIApplication {
        let app = XCUIApplication()
        let root = ProcessInfo.processInfo.environment["LATEST_UI_TEST_DIRECTORY"] ?? FileManager.default.currentDirectoryPath + "/.build/ui-test-" + UUID().uuidString
        app.launchArguments = ["--ui-testing", "--ui-test-directory", root, "-AppleLanguages", "(\(language))", "-AppleLocale", language == "de" ? "de_AT" : "en_US"]
        app.launch()
        return app
    }
    func testSelectionAndPlainReleaseNotes() {
        let app = launch()
        let row = app.descendants(matching: .any).matching(identifier: "app-row-org.example.test").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10)); row.click()
        XCTAssertTrue(app.staticTexts["release-notes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Controlled release notes fixture."].exists)
        XCTAssertTrue(app.buttons["update-selected"].exists)
    }
    func testSearchFiltersAndRestoresInventory() {
        let app = launch()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.click(); search.typeText("missing application")
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "app-row-org.example.test").firstMatch.exists)
        search.typeKey("a", modifierFlags: .command); search.typeKey(XCUIKeyboardKey.delete.rawValue, modifierFlags: [])
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "app-row-org.example.test").firstMatch.waitForExistence(timeout: 5))
    }
    func testIgnoreIsPersistentAndHidesRow() {
        let app = launch()
        let row = app.descendants(matching: .any).matching(identifier: "app-row-org.example.test").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10)); row.click()
        app.buttons["ignore-selected"].click()
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "app-row-org.example.test").firstMatch.exists)
        app.terminate(); app.launch()
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "app-row-org.example.test").firstMatch.exists)
    }
    func testGermanInterface() {
        let app = launch("de")
        XCTAssertTrue(app.staticTexts["App auswählen"].waitForExistence(timeout: 10))
    }
    func testAccessibilityIdentifiersAndScreenshot() {
        let app = launch()
        XCTAssertTrue(app.buttons["refresh"].waitForExistence(timeout: 10))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Controlled native Latest window"; screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}

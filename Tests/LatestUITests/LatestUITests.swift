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

    func testNativeHomebrewUpdate() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let root = environment["LATEST_NATIVE_FIXTURE_ROOT"] ?? environment["TEST_RUNNER_LATEST_NATIVE_FIXTURE_ROOT"] else {
            throw XCTSkip("Explicit disposable native fixture environment is required.")
        }
        let app = XCUIApplication()
        app.launchArguments = ["--native-install-test-directory", root, "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["XDG_CONFIG_HOME"] = root + "/user-config"
        app.launch()
        let window = app.windows["Latest"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        let row = app.descendants(matching: .any).matching(identifier: "app-row-io.github.mpwg.Latest.NativeFixture.Homebrew").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 60))
        row.click()
        let update = app.buttons["update-selected"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: update)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 60), .completed)
        XCTAssertTrue(app.staticTexts[root + "/applications/Latest Homebrew Fixture.app"].exists)
        let before = XCTAttachment(screenshot: window.screenshot())
        before.name = "L03 real managed baseline before update"; before.lifetime = .keepAlways
        add(before)
        update.click()
        XCTAssertTrue(app.staticTexts["1.1.0 (2)"].firstMatch.waitForExistence(timeout: 90))
        XCTAssertTrue(app.staticTexts["Up to Date"].firstMatch.waitForExistence(timeout: 30))
        XCTAssertFalse(app.alerts["Update Failed"].exists)
        let after = XCTAttachment(screenshot: window.screenshot())
        after.name = "L03 installed version after production verification"; after.lifetime = .keepAlways
        add(after)
        app.terminate()
    }

    private func nativeRoot() throws -> String {
        let environment = ProcessInfo.processInfo.environment
        guard let root = environment["LATEST_NATIVE_FIXTURE_ROOT"] ?? environment["TEST_RUNNER_LATEST_NATIVE_FIXTURE_ROOT"] else {
            throw XCTSkip("Explicit disposable native fixture environment is required.")
        }
        return root
    }

    private func nativeApp(_ root: String, holdScans: Bool = false, catalogue: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--native-install-test-directory", root, "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if holdScans { app.launchArguments.append("--native-install-test-hold-scans") }
        if catalogue {
            let data = try? Data(contentsOf: URL(fileURLWithPath: root + "/manifest.json"))
            let value = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            let port = value?["port"] as? Int ?? 8443
            app.launchArguments += ["--native-install-test-catalogue-url", "https://localhost:\(port)/catalogue.json"]
        }
        app.launchEnvironment["XDG_CONFIG_HOME"] = root + "/user-config"
        app.launchEnvironment["HOMEBREW_CACHE"] = root + "/brew-cache"
        app.launchEnvironment["HOMEBREW_LOGS"] = root + "/brew-logs"
        app.launchEnvironment["HOMEBREW_TEMP"] = root + "/brew-temp"
        app.launch()
        return app
    }

    private func selectManaged(_ app: XCUIApplication, root: String) {
        let row = app.descendants(matching: .any).matching(identifier: "app-row-io.github.mpwg.Latest.NativeFixture.Homebrew").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30)); row.click()
        XCTAssertTrue(app.staticTexts[root + "/applications/Latest Homebrew Fixture.app"].exists)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: app.buttons["update-selected"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 30), .completed)
    }

    private func stage(_ name: String, root: String) {
        FileHandle.standardOutput.write(Data(("L04_READY_" + name + "\n").utf8))
        let path = root + "/evidence/l04/" + name + "-ready"
        let deadline = Date().addingTimeInterval(45)
        while !FileManager.default.fileExists(atPath: path), Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: path), "The external fixture change must complete.")
    }

    func testNativeHomebrewProvenanceLoss() throws {
        let root = try nativeRoot()
        let app = nativeApp(root)
        selectManaged(app, root: root)
        stage("LOSS", root: root)
        app.buttons["refresh"].click()
        let blocked = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == false"), object: app.buttons["update-selected"])
        XCTAssertEqual(XCTWaiter.wait(for: [blocked], timeout: 30), .completed)
        XCTAssertTrue(app.staticTexts["Status Unknown"].firstMatch.exists)
        app.terminate()
    }

    func testNativeHomebrewChangedInstance() throws {
        let root = try nativeRoot()
        let app = nativeApp(root, holdScans: true)
        selectManaged(app, root: root)
        stage("SWAP", root: root)
        app.buttons["update-selected"].click()
        XCTAssertTrue(app.staticTexts["The selected app changed. Check for updates again."].waitForExistence(timeout: 15))
        app.terminate()
    }

    func testNativeCatalogueCannotInstallUnmanagedNameMatch() throws {
        let root = try nativeRoot()
        let app = nativeApp(root, catalogue: true)
        let filter = app.popUpButtons["source-filter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 20)); filter.click()
        app.menuItems["Catalogue Hint"].click()
        let row = app.descendants(matching: .any).matching(identifier: "app-row-io.github.mpwg.Latest.NativeFixture.Homebrew").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30)); row.click()
        XCTAssertTrue(app.staticTexts[root + "/applications/Unmanaged/Latest Homebrew Fixture.app"].exists)
        XCTAssertFalse(app.buttons["update-selected"].isEnabled)
        XCTAssertTrue(app.staticTexts["Catalogue metadata is informational; installation ownership is not established."].exists)
        app.terminate()
    }

    func testNativeHomebrewFailureThenRetry() throws {
        let root = try nativeRoot()
        let app = nativeApp(root)
        selectManaged(app, root: root)
        app.buttons["update-selected"].click()
        XCTAssertTrue(app.staticTexts["Update Failed"].waitForExistence(timeout: 45))
        stage("RETRY", root: root)
        app.windows.buttons["OK"].firstMatch.click()
        app.buttons["refresh"].click()
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: app.buttons["update-selected"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 30), .completed)
        app.buttons["update-selected"].click()
        XCTAssertTrue(app.staticTexts["1.1.0 (2)"].firstMatch.waitForExistence(timeout: 60))
        XCTAssertTrue(app.staticTexts["Up to Date"].firstMatch.waitForExistence(timeout: 20))
        app.terminate()
    }

    private func selectNativeSparkle(_ app: XCUIApplication, root: String) {
        let row = app.descendants(matching: .any).matching(identifier: "app-row-io.github.mpwg.Latest.NativeFixture.Sparkle").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30)); row.click()
        XCTAssertTrue(app.staticTexts[root + "/applications/Latest Sparkle Fixture.app"].exists)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: app.buttons["update-selected"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 30), .completed)
    }

    func testNativeSparkleSelectedInstanceUpdate() throws {
        let root = try nativeRoot()
        let app = nativeApp(root)
        selectNativeSparkle(app, root: root)
        app.buttons["update-selected"].click()
        XCTAssertTrue(app.staticTexts["1.1.0 (2)"].firstMatch.waitForExistence(timeout: 120))
        XCTAssertTrue(app.staticTexts["Up to Date"].firstMatch.waitForExistence(timeout: 30))
        let attachment = XCTAttachment(screenshot: app.windows["Latest"].screenshot())
        attachment.name = "L05 exact selected Sparkle instance updated"; attachment.lifetime = .keepAlways
        add(attachment)
        app.terminate()
    }

    func testNativeSparkleRejectsTamperedUpdate() throws {
        let root = try nativeRoot()
        let app = nativeApp(root)
        selectNativeSparkle(app, root: root)
        app.buttons["update-selected"].click()
        XCTAssertTrue(app.staticTexts["Update Failed"].waitForExistence(timeout: 90))
        XCTAssertFalse(app.staticTexts["Up to Date"].firstMatch.exists)
        app.terminate()
    }

    private func sparkleStage(_ name: String, root: String) {
        FileHandle.standardOutput.write(Data(("L06_READY_" + name + "\n").utf8))
        let path = root + "/evidence/l06/" + name + "-ready"
        let deadline = Date().addingTimeInterval(45)
        while !FileManager.default.fileExists(atPath: path), Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
    }

    private func retrySparkle(_ app: XCUIApplication, root: String) {
        app.buttons["refresh"].click()
        selectNativeSparkle(app, root: root)
        app.buttons["update-selected"].click()
        XCTAssertTrue(app.staticTexts["1.1.0 (2)"].firstMatch.waitForExistence(timeout: 120))
        XCTAssertTrue(app.staticTexts["Up to Date"].firstMatch.waitForExistence(timeout: 30))
        app.terminate(); app.launch()
        let row = app.descendants(matching: .any).matching(identifier: "app-row-io.github.mpwg.Latest.NativeFixture.Sparkle").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30)); row.click()
        XCTAssertTrue(app.staticTexts["1.1.0 (2)"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Up to Date"].firstMatch.waitForExistence(timeout: 30))
        app.terminate()
    }

    func testNativeSparkleCancellationThenRetry() throws {
        let root = try nativeRoot()
        let app = nativeApp(root)
        selectNativeSparkle(app, root: root)
        app.buttons["update-selected"].click()
        let cancel = app.buttons["cancel-update"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["Downloading"].waitForExistence(timeout: 30))
        XCTAssertTrue(cancel.isEnabled); cancel.click()
        XCTAssertTrue(app.buttons["update-selected"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.staticTexts["Update Failed"].exists)
        XCTAssertTrue(app.staticTexts["1.0.0 (1)"].firstMatch.exists)
        sparkleStage("CANCEL_RETRY", root: root)
        app.terminate(); app.launch()
        retrySparkle(app, root: root)
    }

    func testNativeSparkleDownloadFailureThenRetry() throws {
        let root = try nativeRoot()
        let app = nativeApp(root)
        selectNativeSparkle(app, root: root)
        app.buttons["update-selected"].click()
        XCTAssertTrue(app.staticTexts["Update Failed"].waitForExistence(timeout: 90))
        XCTAssertTrue(app.staticTexts["1.0.0 (1)"].firstMatch.exists)
        sparkleStage("FAIL_RETRY", root: root)
        app.windows.buttons["OK"].firstMatch.click()
        retrySparkle(app, root: root)
    }

    func testNativeSparkleHandoffDisablesCancel() throws {
        let root = try nativeRoot()
        let app = nativeApp(root)
        selectNativeSparkle(app, root: root)
        app.buttons["update-selected"].click()
        let cancel = app.buttons["cancel-update"]
        let blocked = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == false"), object: cancel)
        XCTAssertEqual(XCTWaiter.wait(for: [blocked], timeout: 60), .completed)
        XCTAssertTrue(app.staticTexts["Installing"].exists)
        sparkleStage("HANDOFF", root: root)
        XCTAssertTrue(app.staticTexts["1.1.0 (2)"].firstMatch.waitForExistence(timeout: 120))
        XCTAssertTrue(app.staticTexts["Up to Date"].firstMatch.waitForExistence(timeout: 30))
        app.terminate()
    }
}

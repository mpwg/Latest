import XCTest

@MainActor final class LatestUITests: XCTestCase {
    private func launch(_ language: String = "en", matrix: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        let root = ProcessInfo.processInfo.environment["LATEST_UI_TEST_DIRECTORY"] ?? FileManager.default.currentDirectoryPath + "/.build/ui-test-" + UUID().uuidString
        app.launchArguments = ["--ui-testing", "--ui-test-directory", root, "-AppleLanguages", "(\(language))", "-AppleLocale", language == "de" ? "de_AT" : "en_US"]
        if matrix {
            app.launchArguments.append("--ui-testing-matrix")
            do {
                let directory = URL(fileURLWithPath: root)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try Data(#"{"directories":[],"showCurrent":true,"showIgnored":false,"showUnknown":true,"sortBySource":false}"#.utf8).write(to: directory.appendingPathComponent("preferences.json"), options: .atomic)
            } catch { XCTFail("Cannot initialize isolated matrix preferences: \(error)") }
        }
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

    private func matrixPaths(_ app: XCUIApplication) -> [String] {
        app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "app-row-")).allElementsBoundByIndex.compactMap { $0.value as? String }
    }

    private func assertMatrixPaths(_ app: XCUIApplication, _ paths: [String], file: StaticString = #filePath, line: UInt = #line) {
        let matches = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in self.matrixPaths(app) == paths }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [matches], timeout: 10), .completed, "Expected paths \(paths), observed \(matrixPaths(app))", file: file, line: line)
    }

    func testEverySourceFilterAndReset() {
        let app = launch(matrix: true)
        let filter = app.popUpButtons["source-filter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 10))
        let all = ["Alpha", "Beta", "Incompatible", "Mystery", "A/Twin", "B/Twin", "Zebra"].map { "/Applications/" + $0 + ".app" }
        assertMatrixPaths(app, all)
        for (source, names) in [("App Store", ["Zebra"]), ("Homebrew", ["Alpha"]),
                                ("Sparkle", ["Incompatible", "A/Twin", "B/Twin"]),
                                ("Catalogue Hint", ["Beta"]), ("Unknown Source", ["Mystery"])] {
            filter.click(); app.windows.menuItems[source].firstMatch.click()
            assertMatrixPaths(app, names.map { "/Applications/" + $0 + ".app" })
            filter.click(); app.windows.menuItems["All Sources"].firstMatch.click()
            assertMatrixPaths(app, all)
        }
        app.terminate()
    }

    func testVisibilitySettingsAndStableInstanceSorting() {
        let app = launch(matrix: true)
        XCTAssertTrue(app.buttons["settings"].waitForExistence(timeout: 10))
        let twins = app.staticTexts.matching(identifier: "app-row-org.example.twin")
        XCTAssertEqual(twins.count, 2)
        twins.element(boundBy: 1).click()
        XCTAssertTrue(app.staticTexts["/Applications/B/Twin.app"].exists)
        app.buttons["settings"].click()
        let settings = app.windows["Settings…"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.descendants(matching: .any).matching(identifier: "show-current").firstMatch.click()
        assertMatrixPaths(app, ["Alpha", "Beta", "Incompatible", "Mystery", "A/Twin"].map { "/Applications/" + $0 + ".app" })
        settings.descendants(matching: .any).matching(identifier: "show-ignored").firstMatch.click()
        assertMatrixPaths(app, ["Alpha", "Beta", "Ignored", "Incompatible", "Mystery", "Skipped", "A/Twin"].map { "/Applications/" + $0 + ".app" })
        settings.descendants(matching: .any).matching(identifier: "show-unknown").firstMatch.click()
        assertMatrixPaths(app, ["Alpha", "Beta", "Ignored", "Skipped", "A/Twin"].map { "/Applications/" + $0 + ".app" })
        settings.descendants(matching: .any).matching(identifier: "show-current").firstMatch.click()
        settings.descendants(matching: .any).matching(identifier: "show-unknown").firstMatch.click()
        settings.descendants(matching: .any).matching(identifier: "sort-by-source").firstMatch.click()
        let sourceOrder = ["Zebra", "Beta", "Alpha", "Ignored", "Incompatible", "Skipped", "A/Twin", "B/Twin", "Mystery"].map { "/Applications/" + $0 + ".app" }
        assertMatrixPaths(app, sourceOrder)
        app.windows["Latest"].click()
        app.buttons["refresh"].click()
        assertMatrixPaths(app, sourceOrder)
        XCTAssertTrue(app.staticTexts["/Applications/B/Twin.app"].exists)
        app.buttons["settings"].click()
        settings.descendants(matching: .any).matching(identifier: "sort-by-source").firstMatch.click()
        let nameOrder = ["Alpha", "Beta", "Ignored", "Incompatible", "Mystery", "Skipped", "A/Twin", "B/Twin", "Zebra"].map { "/Applications/" + $0 + ".app" }
        assertMatrixPaths(app, nameOrder)
        app.windows["Latest"].click()
        app.buttons["refresh"].click()
        assertMatrixPaths(app, nameOrder)
        XCTAssertTrue(app.staticTexts["/Applications/B/Twin.app"].exists)
        let attachment = XCTAttachment(screenshot: app.windows["Latest"].screenshot())
        attachment.name = "L15 all states, stable twins and retained selected path"; attachment.lifetime = .keepAlways
        add(attachment)
        app.terminate()
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

    private func rejectedSparkle(_ reason: String, status: String) throws {
        let root = try nativeRoot()
        let app = nativeApp(root)
        let row = app.descendants(matching: .any).matching(identifier: "app-row-io.github.mpwg.Latest.NativeFixture.Sparkle").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30)); row.click()
        XCTAssertTrue(app.staticTexts[root + "/applications/Latest Sparkle Fixture.app"].exists)
        XCTAssertTrue(app.staticTexts[reason].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts[status].firstMatch.exists)
        XCTAssertFalse(app.buttons["update-selected"].isEnabled)
        XCTAssertFalse(app.buttons["cancel-update"].exists)
        app.terminate()
    }

    func testNativeSparkleArchitectureRejected() throws {
        try rejectedSparkle("This Sparkle update targets a different architecture or insecure URL. Use the app's own updater.", status: "Status Unknown")
    }
    func testNativeSparkleMinimumOSRejected() throws {
        try rejectedSparkle("The update requires a newer operating system.", status: "Incompatible Update")
    }
    func testNativeSparkleIncomparableVersion() throws {
        try rejectedSparkle("The versions cannot be compared reliably.", status: "Status Unknown")
    }
    func testNativeSparkleBuildPolicy() throws {
        let root = try nativeRoot()
        let app = nativeApp(root)
        selectNativeSparkle(app, root: root)
        XCTAssertTrue(app.staticTexts["New version: 0.9.0 (2)"].exists)
        app.buttons["update-selected"].click()
        XCTAssertTrue(app.staticTexts["0.9.0 (2)"].firstMatch.waitForExistence(timeout: 120))
        XCTAssertTrue(app.staticTexts["Up to Date"].firstMatch.waitForExistence(timeout: 30))
        app.terminate(); app.launch()
        let row = app.descendants(matching: .any).matching(identifier: "app-row-io.github.mpwg.Latest.NativeFixture.Sparkle").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30)); row.click()
        XCTAssertTrue(app.staticTexts["0.9.0 (2)"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Up to Date"].firstMatch.waitForExistence(timeout: 30))
        app.terminate()
    }

    private func selectSparkleInstance(_ app: XCUIApplication, path: String) {
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@ AND value == %@", "app-row-io.github.mpwg.Latest.NativeFixture.Sparkle", path)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30)); row.click()
        XCTAssertTrue(app.staticTexts[path].exists)
    }
    private func assertUpdateEnabled(_ app: XCUIApplication, _ enabled: Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == %@", NSNumber(value: enabled)), object: app.buttons["update-selected"])
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 30), .completed)
    }
    private func preferenceStage(_ name: String, root: String) {
        FileHandle.standardOutput.write(Data(("L16_READY_" + name + "\n").utf8))
        let path = root + "/evidence/l16/" + name + "-ready"
        let deadline = Date().addingTimeInterval(45)
        while !FileManager.default.fileExists(atPath: path), Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
    }

    func testNativeIgnoreSkipAndNewVersion() throws {
        let root = try nativeRoot()
        let top = root + "/applications/Latest Sparkle Fixture.app"
        let other = root + "/applications/Secondary/Latest Sparkle Fixture.app"
        let app = nativeApp(root)
        selectSparkleInstance(app, path: top); assertUpdateEnabled(app, true)
        app.buttons["ignore-selected"].click()
        XCTAssertTrue(app.staticTexts["Ignored"].firstMatch.waitForExistence(timeout: 30))
        assertUpdateEnabled(app, false)
        app.terminate(); app.launch()
        selectSparkleInstance(app, path: top)
        XCTAssertTrue(app.buttons["ignore-selected"].label == "Stop Ignoring")
        assertUpdateEnabled(app, false)
        app.buttons["ignore-selected"].click(); assertUpdateEnabled(app, true)
        app.buttons["skip-selected"].click()
        XCTAssertTrue(app.staticTexts["Version Skipped"].firstMatch.waitForExistence(timeout: 30))
        assertUpdateEnabled(app, false)
        app.terminate(); app.launch()
        selectSparkleInstance(app, path: top)
        XCTAssertTrue(app.staticTexts["Version Skipped"].firstMatch.waitForExistence(timeout: 30))
        assertUpdateEnabled(app, false)
        selectSparkleInstance(app, path: other); assertUpdateEnabled(app, true)
        selectSparkleInstance(app, path: top)
        app.buttons["clear-skip-selected"].click(); assertUpdateEnabled(app, true)
        app.buttons["skip-selected"].click()
        XCTAssertTrue(app.staticTexts["Version Skipped"].firstMatch.waitForExistence(timeout: 30))
        preferenceStage("NEXT", root: root)
        app.buttons["refresh"].click()
        XCTAssertTrue(app.staticTexts["New version: 1.2.0 (3)"].waitForExistence(timeout: 30))
        assertUpdateEnabled(app, true)
        app.terminate(); app.launch()
        selectSparkleInstance(app, path: top)
        XCTAssertTrue(app.staticTexts["New version: 1.2.0 (3)"].waitForExistence(timeout: 30))
        assertUpdateEnabled(app, true)
        app.terminate()
    }

    func testNativeChannelsAreInstanceScopedAndPersistent() throws {
        let root = try nativeRoot()
        let top = root + "/applications/Latest Sparkle Fixture.app"
        let other = root + "/applications/Secondary/Latest Sparkle Fixture.app"
        let app = nativeApp(root)
        selectSparkleInstance(app, path: top)
        XCTAssertTrue(app.staticTexts["New version: 1.1.0 (2)"].waitForExistence(timeout: 30))
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Beta")).firstMatch.click()
        XCTAssertTrue(app.staticTexts["New version: 1.2.0 (3)"].waitForExistence(timeout: 30))
        app.terminate(); app.launch()
        selectSparkleInstance(app, path: top)
        XCTAssertTrue(app.staticTexts["New version: 1.2.0 (3)"].waitForExistence(timeout: 30))
        app.buttons["refresh"].click()
        XCTAssertTrue(app.staticTexts["New version: 1.2.0 (3)"].waitForExistence(timeout: 30))
        selectSparkleInstance(app, path: other)
        XCTAssertTrue(app.staticTexts["New version: 1.1.0 (2)"].waitForExistence(timeout: 30))
        preferenceStage("CHANNELS", root: root)
        selectSparkleInstance(app, path: top)
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Stable")).firstMatch.click()
        XCTAssertTrue(app.staticTexts["New version: 1.1.0 (2)"].waitForExistence(timeout: 30))
        app.terminate(); app.launch()
        selectSparkleInstance(app, path: top)
        XCTAssertTrue(app.staticTexts["New version: 1.1.0 (2)"].waitForExistence(timeout: 30))
        app.terminate()
    }

    private func majorBulkStage(_ name: String, root: String) {
        FileHandle.standardOutput.write(Data(("L17_READY_" + name + "\n").utf8))
        let path = root + "/evidence/l17/" + name + "-ready"
        let deadline = Date().addingTimeInterval(45)
        while !FileManager.default.fileExists(atPath: path), Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
    }
    private func selectNativePath(_ app: XCUIApplication, _ path: String) {
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND value == %@", "app-row-", path)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30)); row.click()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "value == %@ OR label == %@ OR identifier == %@", path, path, path)).firstMatch.exists)
    }
    private func assertNativeText(_ element: XCUIElement, _ text: String, timeout: TimeInterval = 30) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@ OR label == %@", text, text), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed)
    }

    func testNativeMajorConsentAndCancellation() throws {
        try verifyNativeMajorConsent("2.0.0 (2)")
    }
    func testNativeProviderDeclaredMajorConsent() throws {
        try verifyNativeMajorConsent("1.1.0 (2)")
    }
    private func verifyNativeMajorConsent(_ targetVersion: String) throws {
        let root = try nativeRoot()
        let app = nativeApp(root)
        selectNativeSparkle(app, root: root)
        XCTAssertTrue(app.staticTexts["Major Upgrade"].exists)
        app.buttons["update-selected"].click()
        let consent = app.windows["Latest"].sheets.firstMatch
        XCTAssertTrue(consent.buttons["Install Major Upgrade"].waitForExistence(timeout: 10))
        consent.buttons["Cancel"].click()
        XCTAssertFalse(consent.exists)
        majorBulkStage("CANCEL_MAJOR", root: root)
        assertNativeText(app.staticTexts["installed-version"], "1.0.0 (1)")
        app.buttons["update-selected"].click()
        consent.buttons["Install Major Upgrade"].click()
        assertNativeText(app.staticTexts["selected-status"], "Up to Date", timeout: 120)
        let values = app.staticTexts.matching(identifier: "installed-version").allElementsBoundByIndex.map { "label=\($0.label), value=\(String(describing: $0.value))" }
        FileHandle.standardOutput.write(Data(("L17_INSTALLED_VALUES " + values.joined(separator: "; ") + "\n").utf8))
        let screenshot = app.windows["Latest"].screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "L17 native major post-install metadata"; attachment.lifetime = .keepAlways
        add(attachment)
        assertNativeText(app.staticTexts["installed-version"], targetVersion, timeout: 5)
        app.terminate()
    }

    func testNativeChangedMajorRequirementIsRejected() throws {
        let root = try nativeRoot()
        let app = nativeApp(root)
        selectNativeSparkle(app, root: root)
        XCTAssertFalse(app.staticTexts["Major Upgrade"].exists)
        majorBulkStage("CHANGED_MAJOR", root: root)
        app.buttons["update-selected"].click()
        XCTAssertTrue(app.staticTexts["Update Failed"].waitForExistence(timeout: 60))
        XCTAssertTrue(app.staticTexts["The Sparkle update's major-upgrade requirement changed. Check for updates again."].exists)
        assertNativeText(app.staticTexts["installed-version"], "1.0.0 (1)")
        app.terminate()
    }

    func testNativeBulkEligibilityAndDuplicateActivation() throws {
        let root = try nativeRoot()
        let app = nativeApp(root)
        let top = root + "/applications/Latest Sparkle Fixture.app"
        selectNativePath(app, top)
        XCTAssertTrue(app.staticTexts["New version: 1.1.0 (2)"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["refresh"].isEnabled)
        XCTAssertFalse(app.buttons["update-selected"].isEnabled)
        XCTAssertFalse(app.buttons["update-all"].isEnabled)
        majorBulkStage("SCAN", root: root)
        let scanned = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: app.buttons["refresh"])
        XCTAssertEqual(XCTWaiter.wait(for: [scanned], timeout: 60), .completed)
        XCTAssertTrue(app.buttons["update-all"].isEnabled)
        app.buttons["update-all"].doubleClick()
        XCTAssertTrue(app.buttons["cancel-update"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["update-all"].isEnabled)
        XCTAssertFalse(app.buttons["update-selected"].exists)
        majorBulkStage("BULK", root: root)
        let data = try Data(contentsOf: URL(fileURLWithPath: root + "/evidence/l17/bulk/paths.json"))
        let paths = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
        for key in ["selected", "minor"] {
            selectNativePath(app, try XCTUnwrap(paths[key]))
            assertNativeText(app.staticTexts["installed-version"], "1.1.0 (2)", timeout: 120)
            assertNativeText(app.staticTexts["selected-status"], "Up to Date")
        }
        selectNativePath(app, try XCTUnwrap(paths["major"]))
        assertNativeText(app.staticTexts["installed-version"], "1.0.0 (1)")
        XCTAssertTrue(app.staticTexts["Major Upgrade"].exists)
        app.terminate()
    }
    private func verifyNativeExecutableChange(_ name: String) throws {
        let root = try nativeRoot()
        let app = nativeApp(root, holdScans: true)
        selectNativeSparkle(app, root: root)
        FileHandle.standardOutput.write(Data(("L51_READY_" + name + "\n").utf8))
        let path = root + "/evidence/l51/" + name + "-ready"
        let deadline = Date().addingTimeInterval(45)
        while !FileManager.default.fileExists(atPath: path), Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
        app.buttons["update-selected"].click()
        XCTAssertTrue(app.staticTexts["Update Failed"].waitForExistence(timeout: 30))
        let reason = app.staticTexts.matching(NSPredicate(format: "value == %@ OR value == %@ OR label == %@ OR label == %@", "The selected app changed. Check for updates again.", "Code signature verification failed.", "The selected app changed. Check for updates again.", "Code signature verification failed.")).firstMatch
        XCTAssertTrue(reason.exists)
        app.terminate()
    }
    func testNativeSignedExecutableReplacementIsRejected() throws {
        try verifyNativeExecutableChange("REPLACED")
    }
    func testNativeExecutableTamperingWithPreservedTimesIsRejected() throws {
        try verifyNativeExecutableChange("TAMPERED")
    }

    private func migrationValue(_ name: String) throws -> String {
        let values = ProcessInfo.processInfo.environment
        guard let value = values[name] ?? values["TEST_RUNNER_" + name] else {
            throw XCTSkip("An explicit isolated native migration profile is required.")
        }
        return value
    }
    private func migrationApp() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--native-migration-test-domain", try migrationValue("LATEST_MIGRATION_DOMAIN"), "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["CFFIXED_USER_HOME"] = try migrationValue("LATEST_MIGRATION_PROFILE")
        app.launch()
        return app
    }
    private func assertToggle(_ window: XCUIElement, _ name: String, _ enabled: Bool) {
        let value = window.descendants(matching: .any).matching(identifier: name).firstMatch.value
        if let number = value as? NSNumber { XCTAssertEqual(number.boolValue, enabled) }
        else { XCTAssertEqual(value as? String, enabled ? "1" : "0") }
    }
    private func migrationStage(_ name: String) throws {
        let root = try migrationValue("LATEST_MIGRATION_EVIDENCE")
        FileHandle.standardOutput.write(Data(("L18_READY_" + name + "\n").utf8))
        let path = root + "/" + name + "-ready"
        let deadline = Date().addingTimeInterval(45)
        while !FileManager.default.fileExists(atPath: path), Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
    }
    private func quitNormally(_ app: XCUIApplication) {
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
    }
    func testNativeNormalMigrationAndPersistence() throws {
        let app = try migrationApp()
        XCTAssertTrue(app.buttons["settings"].waitForExistence(timeout: 10)); app.buttons["settings"].click()
        let settings = app.windows["Settings…"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        assertToggle(settings, "show-current", false)
        assertToggle(settings, "show-ignored", true)
        assertToggle(settings, "show-unknown", false)
        try migrationStage("MIGRATED")
        for name in ["show-current", "show-ignored", "show-unknown", "sort-by-source"] {
            settings.descendants(matching: .any).matching(identifier: name).firstMatch.click()
        }
        try migrationStage("EDITED")
        quitNormally(app); app.launch()
        XCTAssertTrue(app.buttons["settings"].waitForExistence(timeout: 10)); app.buttons["settings"].click()
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        assertToggle(settings, "show-current", true)
        assertToggle(settings, "show-ignored", false)
        assertToggle(settings, "show-unknown", true)
        assertToggle(settings, "sort-by-source", true)
        try migrationStage("RESTARTED")
        quitNormally(app)
    }
    func testNativeMalformedLegacyFieldsUseDefaults() throws {
        let app = try migrationApp()
        XCTAssertTrue(app.buttons["settings"].waitForExistence(timeout: 10)); app.buttons["settings"].click()
        let settings = app.windows["Settings…"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        assertToggle(settings, "show-current", true)
        assertToggle(settings, "show-ignored", false)
        assertToggle(settings, "show-unknown", true)
        try migrationStage("MALFORMED")
        quitNormally(app); app.launch()
        XCTAssertTrue(app.buttons["settings"].waitForExistence(timeout: 10)); app.buttons["settings"].click()
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        assertToggle(settings, "show-current", true)
        try migrationStage("MALFORMED_RESTART")
        quitNormally(app)
    }
}

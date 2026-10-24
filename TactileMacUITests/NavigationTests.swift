import XCTest

final class NavigationTests: XCTestCase {
    private var dataDirectory: String!

    override func setUpWithError() throws {
        continueAfterFailure = false
        dataDirectory = NSTemporaryDirectory() + "TactileMacUITests-\(UUID().uuidString)"
    }

    override func tearDownWithError() throws {
        if let dataDirectory {
            try? FileManager.default.removeItem(atPath: dataDirectory)
        }
    }

    private func launch(extraEnvironment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launchEnvironment["TACTILEMAC_DATA_DIR"] = dataDirectory
        for (key, value) in extraEnvironment { app.launchEnvironment[key] = value }
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15), "The main window should open on launch")
        return app
    }

    func testWindowLaunchesOnOverview() {
        let app = launch()
        XCTAssertTrue(app.buttons["sidebar.overview"].exists)
        XCTAssertTrue(app.buttons["sidebar.keyboard"].exists)
        XCTAssertTrue(app.buttons["sidebar.permissions"].exists)
        app.terminate()
    }

    func testSidebarNavigatesEveryPage() {
        let app = launch()
        let pages: [(String, String)] = [
            ("profiles", "Sound Profiles"),
            ("keyboard", "Keyboard Sounds"),
            ("trackpad", "Trackpad Sounds"),
            ("haptics", "Haptics"),
            ("soundPacks", "Sound Packs"),
            ("advanced", "Advanced"),
            ("permissions", "Permissions & Hardware"),
            ("about", "License & About"),
            ("overview", "Overview")
        ]
        for (rawValue, title) in pages {
            let button = app.buttons["sidebar.\(rawValue)"]
            XCTAssertTrue(button.waitForExistence(timeout: 3), "Sidebar item \(rawValue) missing")
            button.click()
            XCTAssertTrue(app.staticTexts[title].firstMatch.waitForExistence(timeout: 3), "Page \(title) did not appear")
        }
        app.terminate()
    }

    func testPermissionGuidanceIsVisible() {
        let app = launch()
        app.buttons["sidebar.permissions"].click()
        XCTAssertTrue(element(app, "permissions.requestInput").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Input Monitoring"].firstMatch.exists)
        app.terminate()
    }

    func testKeyboardTogglePersistsAcrossRelaunch() {
        var app = launch()
        app.buttons["sidebar.overview"].click()
        let toggle = element(app, "overview.keyboard.enabled")
        XCTAssertTrue(toggle.waitForExistence(timeout: 4), "Keyboard toggle should be addressable")
        XCTAssertTrue(isOn(toggle))
        toggle.click()
        XCTAssertFalse(isOn(toggle))
        Thread.sleep(forTimeInterval: 1.0)
        app.terminate()

        app = launch()
        app.buttons["sidebar.overview"].click()
        let relaunched = element(app, "overview.keyboard.enabled")
        XCTAssertTrue(relaunched.waitForExistence(timeout: 4))
        XCTAssertFalse(isOn(relaunched), "Settings should persist across relaunch")
        app.terminate()
    }

    func testProfileSelectionUpdatesSelectedProfile() {
        let app = launch()
        app.buttons["sidebar.profiles"].click()
        let selected = element(app, "profiles.selectedKeyboardPack")
        XCTAssertTrue(selected.waitForExistence(timeout: 4))
        XCTAssertEqual(text(of: selected), "Thock")
        let useClicky = app.buttons["pack.clicky.useKeyboard"].firstMatch
        XCTAssertTrue(useClicky.waitForExistence(timeout: 4))
        useClicky.click()
        let updated = element(app, "profiles.selectedKeyboardPack")
        XCTAssertTrue(updated.waitForExistence(timeout: 3))
        XCTAssertEqual(text(of: updated), "Clicky")
        app.terminate()
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func text(of element: XCUIElement) -> String {
        if !element.label.isEmpty { return element.label }
        if let value = element.value as? String { return value }
        return ""
    }

    private func isOn(_ element: XCUIElement) -> Bool {
        if let value = element.value as? String {
            return value == "1" || value.caseInsensitiveCompare("on") == .orderedSame
        }
        if let value = element.value as? NSNumber { return value.boolValue }
        return false
    }

    func testSoundPackImportFlow() throws {
        let fixture = try XCTUnwrap(
            Bundle(for: NavigationTests.self).resourceURL?
                .appendingPathComponent("Fixtures/UITestPack", isDirectory: true)
        )
        let app = launch(extraEnvironment: ["TACTILEMAC_UI_TEST_IMPORT_PATH": fixture.path])
        app.buttons["sidebar.soundPacks"].click()
        let importButton = element(app, "soundPacks.importTestPack")
        XCTAssertTrue(importButton.waitForExistence(timeout: 4))
        importButton.click()
        let success = element(app, "soundPacks.importSuccess")
        XCTAssertTrue(success.waitForExistence(timeout: 15), "Import should complete and show the success state")
        XCTAssertEqual(text(of: success), "Imported UI Test Pack")
        app.terminate()
    }

    func testHapticMaterialSelection() {
        let app = launch()
        app.buttons["sidebar.haptics"].click()
        let pebbled = element(app, "material.pebbled")
        XCTAssertTrue(pebbled.waitForExistence(timeout: 4))
        pebbled.click()
        let selected = app.staticTexts["Pebbled"].firstMatch
        XCTAssertTrue(selected.waitForExistence(timeout: 3))
        app.terminate()
    }

    func testSoundPacksPageShowsBuiltInPacks() {
        let app = launch()
        app.buttons["sidebar.soundPacks"].click()
        XCTAssertTrue(element(app, "soundPacks.import").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Thock"].firstMatch.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Clicky"].firstMatch.exists)
        app.terminate()
    }
}

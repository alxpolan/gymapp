import XCTest

@MainActor
final class ExportReproTests: XCTestCase {
    func testExportFlow() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ui_test_pro"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))

        var gear = app.buttons["gearshape.fill"]
        if !gear.waitForExistence(timeout: 2) { gear = app.images["gearshape.fill"] }
        if !gear.exists {
            let coord = app.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.045))
            coord.tap()
        } else {
            gear.tap()
        }
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 3)

        let exportEN = app.staticTexts["Export data (CSV)"]
        let exportDE = app.staticTexts["Daten exportieren (CSV)"]
        if exportEN.waitForExistence(timeout: 2) {
            exportEN.tap()
        } else if exportDE.waitForExistence(timeout: 2) {
            exportDE.tap()
        } else {
            XCTFail("Could not find Export row label")
        }

        for i in 1...20 {
            sleep(1)
            let s = app.screenshot()
            let a = XCTAttachment(screenshot: s)
            a.name = "step_\(i)"
            a.lifetime = .keepAlways
            add(a)
        }

        let dump = app.debugDescription
        let dumpAttachment = XCTAttachment(string: dump)
        dumpAttachment.name = "hierarchy_dump"
        dumpAttachment.lifetime = .keepAlways
        add(dumpAttachment)
        print("=== HIERARCHY DUMP START ===")
        print(dump)
        print("=== HIERARCHY DUMP END ===")
    }
}

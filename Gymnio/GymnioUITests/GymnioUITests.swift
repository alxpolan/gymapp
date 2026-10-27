//
//  GymnioUITests.swift
//  GymnioUITests
//
//  Marteso screenshot pipeline - see config.json for device/language config.
//  Demo data: seeded via -ui_test_seed_demo_data (handled in AppDelegate).
//

import XCTest

@MainActor
final class GymnioUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        setupScreenshots(app)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private func launchWithDemoData() {
        app.launchArguments += [
            "-ui_testing",
            "-ui_test_seed_demo_data",
            "-ui_test_force_morning",
            "-ui_test_force_tab_bar",
        ]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    }

    func testScreenshot01_HomeDashboard() throws {
        launchWithDemoData()
        XCTAssertTrue(app.staticTexts[t("Guten Morgen!", "Good morning!")].waitForExistence(timeout: 6))
        takeScreenshot("testScreenshot01_HomeDashboard")
    }

    func testScreenshot02_ExercisesOverview() throws {
        launchWithDemoData()
        tapTab(t("Übungen", "Exercises"))
        XCTAssertTrue(app.staticTexts[demoExercise].firstMatch.waitForExistence(timeout: 6))
        takeScreenshot("testScreenshot02_ExercisesOverview")
    }

    func testScreenshot03_ExerciseDetail() throws {
        launchWithDemoData()
        tapTab(t("Übungen", "Exercises"))
        let exercise = app.staticTexts[demoExercise].firstMatch
        XCTAssertTrue(exercise.waitForExistence(timeout: 6))
        exercise.tap()
        XCTAssertTrue(app.buttons[t("Eintrag hinzufügen", "Add Entry")].waitForExistence(timeout: 6))
        takeScreenshot("testScreenshot03_ExerciseDetail")
    }

    func testScreenshot04_History() throws {
        launchWithDemoData()
        tapTab(t("Verlauf", "History"))
        XCTAssertTrue(app.staticTexts[demoExercise].firstMatch.waitForExistence(timeout: 6))
        takeScreenshot("testScreenshot04_History")
    }

    func testScreenshot05_AddExerciseModal() throws {
        launchWithDemoData()
        tapTab(t("Hinzufügen", "Add"))
        XCTAssertTrue(app.staticTexts[t("Übung hinzufügen", "Add Exercise")].waitForExistence(timeout: 6))
        takeScreenshot("testScreenshot05_AddExerciseModal")
    }

    private var demoExercise: String { t("Bankdrücken", "Bench Press") }

    private func t(_ de: String, _ en: String) -> String {
        let language = ProcessInfo.processInfo.environment["XCUITESTS_LANGUAGE"] ?? "en"
        return language.hasPrefix("de") ? de : en
    }

    private func tapTab(_ name: String) {
        let button = app.tabBars.buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout: 2), "Tab '\(name)' not found")
        button.tap()
    }
}

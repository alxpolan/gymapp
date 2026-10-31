//
//  GymnioUITests.swift
//  GymnioUITests
//
//  Marteso screenshot pipeline - see config.json for device/language config.
//  Demo data comes from the app itself (-ui_test_seed_demo_data): three months of push/pull/legs training,
//  routines, body weight and, with -ui_test_active_workout, a workout in progress.
//  All shots run in Pro mode so no upsell appears.
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

    // Titles are localized, so queries use accessibility identifiers, tab position or the English demo
    // exercise names (they stay English in every language so the demo videos match).
    private let launchTimeout: TimeInterval = 60
    private let uiTimeout: TimeInterval = 30

    private func launch(activeWorkout: Bool = false) {
        app.launchArguments += ["-ui_testing", "-ui_test_seed_demo_data", "-ui_test_pro"]
        if activeWorkout { app.launchArguments += ["-ui_test_active_workout"] }
        app.launch()
    }

    private func openTab(_ index: Int) {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: launchTimeout))
        let button = tabBar.buttons.element(boundBy: index)
        XCTAssertTrue(button.waitForExistence(timeout: uiTimeout))
        button.tap()
    }

    // MARK: - Screenshots

    func testScreenshot01_Train() throws {
        launch()
        XCTAssertTrue(app.buttons["startWorkoutButton"].waitForExistence(timeout: launchTimeout))
        takeScreenshot("01_Train")
    }

    func testScreenshot02_ActiveWorkout() throws {
        launch(activeWorkout: true)
        XCTAssertTrue(app.buttons["finishWorkoutButton"].waitForExistence(timeout: launchTimeout))
        takeScreenshot("02_ActiveWorkout")
    }

    func testScreenshot03_Summary() throws {
        launch(activeWorkout: true)
        let finish = app.buttons["finishWorkoutButton"]
        XCTAssertTrue(finish.waitForExistence(timeout: launchTimeout))
        finish.tap()
        XCTAssertTrue(app.buttons["summaryDoneButton"].waitForExistence(timeout: uiTimeout))
        takeScreenshot("03_Summary")
    }

    func testScreenshot04_History() throws {
        launch()
        openTab(1)
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: uiTimeout))
        takeScreenshot("04_History")
    }

    func testScreenshot05_Exercises() throws {
        launch()
        openTab(2)
        XCTAssertTrue(app.staticTexts["Bench Press"].firstMatch.waitForExistence(timeout: uiTimeout))
        takeScreenshot("05_Exercises")
    }

    func testScreenshot06_ExerciseDetail() throws {
        launch()
        openTab(2)
        let exercise = app.staticTexts["Bench Press"].firstMatch
        XCTAssertTrue(exercise.waitForExistence(timeout: uiTimeout))
        exercise.tap()
        XCTAssertTrue(app.buttons["addToWorkoutButton"].waitForExistence(timeout: uiTimeout))
        takeScreenshot("06_ExerciseDetail")
    }

    func testScreenshot07_Progress() throws {
        launch()
        openTab(3)
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: uiTimeout))
        takeScreenshot("07_Progress")
    }

    func testScreenshot08_ProgressStats() throws {
        launch()
        openTab(3)
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: uiTimeout))
        scroll.swipeUp()
        scroll.swipeUp()
        takeScreenshot("08_ProgressStats")
    }
}

//
//  ScreenshotHelper.swift
//  CalcBlitzUITests
//
//  Lightweight replacement for fastlane's SnapshotHelper.
//  Reads XCUITESTS_LANGUAGE / XCUITESTS_LOCALE from the test runner environment
//  (set by the snapshot worker), forwards them to the app via launch arguments,
//  and saves screenshots as XCTAttachments in the xcresult bundle so the worker
//  can extract them post-run via `xcresulttool export attachments`.
//

import Foundation
import XCTest

@MainActor
func setupScreenshots(_ app: XCUIApplication) {
    let env = ProcessInfo.processInfo.environment
    let language = env["XCUITESTS_LANGUAGE"] ?? "en"
    let locale = env["XCUITESTS_LOCALE"] ?? "en_US"

    app.launchArguments += [
        "-AppleLanguages", "(\(language))",
        "-AppleLocale", locale,
    ]
}

@MainActor
extension XCTestCase {
    func takeScreenshot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.5)
        let language = ProcessInfo.processInfo.environment["XCUITESTS_LANGUAGE"] ?? "en"
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(language)__\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
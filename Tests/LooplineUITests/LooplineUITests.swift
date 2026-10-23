import XCTest

@MainActor
final class LooplineUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ name: String, trackCount: Int? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-LooplineHarnessMode", "-LooplineProjectRoot", "UITest-\(name)-\(UUID().uuidString)"]
        if let trackCount { app.launchArguments += ["-LooplineSeedTrackCount", String(trackCount)] }
        app.launch()
        if let trackCount {
            let ready = NSPredicate(format: "label CONTAINS %@", "Simulator \(trackCount) parts")
            XCTAssertTrue(app.buttons["project.library"].waitForExistence(timeout: 10))
            XCTAssertTrue(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready,
                object: app.buttons["project.library"])], timeout: 120) == .completed)
        }
        return app
    }

    func testCaptureAndEmptyMixExportNavigation() {
        let app = launch("navigation")
        XCTAssertTrue(app.buttons["capture.record"].waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(app.buttons["capture.record"].frame.height, 44)
        saveScreenshot(app, name: "Capture")
        app.buttons["tab.mix"].tap()
        XCTAssertTrue(app.staticTexts["Give your mix a first part."].waitForExistence(timeout: 5))
        saveScreenshot(app, name: "Mix")
        app.buttons["tab.export"].tap()
        XCTAssertTrue(app.staticTexts["A little studio. A real file."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Create my video"].isEnabled)
        saveScreenshot(app, name: "Export")
    }

    func testSessionCreationSurvivesRelaunch() {
        let app = launch("library")
        app.buttons["project.library"].tap()
        app.buttons["New session"].tap()
        let sessionName = app.buttons["project.library"].label
        XCTAssertTrue(sessionName.contains("Session 2"))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["project.library"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["project.library"].label, sessionName)
    }

    func testMetronomeSettingsSurviveRelaunch() {
        let app = launch("settings")
        app.swipeUp()
        let countIn = app.segmentedControls["capture.countIn"]
        XCTAssertTrue(countIn.waitForExistence(timeout: 5))
        countIn.buttons["Off"].tap()
        app.terminate()
        app.launch()
        app.swipeUp()
        XCTAssertTrue(countIn.waitForExistence(timeout: 5))
        XCTAssertTrue(countIn.buttons["Off"].isSelected)
    }

    func testTwoTrackSyncPreviewAndExport() {
        let app = launch("two-track", trackCount: 2)
        app.buttons["tab.mix"].tap()
        let select = app.buttons["Select Part 2"]
        scrollTo(select, in: app)
        select.tap()
        XCTAssertEqual(select.value as? String, "Selected")
        scrollTo(app.buttons["Find a match"], in: app, down: true)
        app.buttons["Find a match"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@",
            "Suggested placement -120 ms")).firstMatch.waitForExistence(timeout: 15))
        scrollTo(app.buttons["Apply timing"], in: app)
        app.buttons["Apply timing"].tap()
        XCTAssertTrue(app.staticTexts["Alignment applied"].waitForExistence(timeout: 5))
        scrollTo(app.staticTexts["track.offset.Part 2"], in: app)
        XCTAssertEqual(app.staticTexts["track.offset.Part 2"].label, "-120 ms")
        scrollTo(app.buttons["Undo last adjustment"], in: app, down: true)
        app.buttons["Undo last adjustment"].tap()
        scrollTo(app.staticTexts["track.offset.Part 2"], in: app)
        XCTAssertEqual(app.staticTexts["track.offset.Part 2"].label, "0 ms")
        previewMix(app)
        scrollTo(app.staticTexts["Better together."], in: app, down: true)
        saveScreenshot(app, name: "Two-track mix")
        createVideo(app, name: "Two-track export")
    }

    func testEightTrackEditsPersistAndExport() {
        let app = launch("eight-track", trackCount: 8)
        XCTAssertTrue(app.buttons["capture.record"].isEnabled)
        app.buttons["tab.mix"].tap()
        let mute = app.buttons["Mute Part 8"]
        scrollTo(mute, in: app)
        mute.tap()
        app.buttons["Solo Part 8"].tap()
        app.buttons["Move Part 8 by 10 milliseconds"].tap()
        let volume = app.sliders["Volume for Part 8"]
        let originalVolume = volume.value as? String
        volume.adjust(toNormalizedSliderPosition: 0.5)
        let savedVolume = volume.value as? String
        XCTAssertNotNil(savedVolume)
        XCTAssertNotEqual(savedVolume, originalVolume)
        XCTAssertEqual(app.staticTexts["track.offset.Part 8"].label, "+10 ms")
        scrollTo(app.buttons["mix.addPart"], in: app)
        XCTAssertTrue(app.buttons["mix.addPart"].isEnabled)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["tab.mix"].waitForExistence(timeout: 10))
        app.buttons["tab.mix"].tap()
        scrollTo(mute, in: app)
        XCTAssertEqual(mute.value as? String, "On")
        XCTAssertEqual(app.buttons["Solo Part 8"].value as? String, "On")
        XCTAssertEqual(volume.value as? String, savedVolume)
        XCTAssertEqual(app.staticTexts["track.offset.Part 8"].label, "+10 ms")
        saveScreenshot(app, name: "Eight-track saved edits")
        mute.tap()
        previewMix(app)
        scrollTo(app.staticTexts["Better together."], in: app, down: true)
        saveScreenshot(app, name: "Eight-track mix")
        createVideo(app, name: "Eight-track export")
    }

    private func previewMix(_ app: XCUIApplication) {
        let play = app.buttons["Listen to the mix"]
        scrollTo(play, in: app, down: true)
        let position = play.frame.midY
        play.tap()
        let stop = app.buttons["Stop preview"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        XCTAssertEqual(stop.frame.midY, position, accuracy: 2, "Starting playback must keep its control in place")
        XCTAssertTrue(stop.isHittable)
        stop.tap()
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        XCTAssertEqual(play.frame.midY, position, accuracy: 2, "Stopping playback must keep its control in place")
    }

    private func createVideo(_ app: XCUIApplication, name: String) {
        app.buttons["tab.export"].tap()
        let create = app.buttons["Create my video"]
        scrollTo(create, in: app)
        XCTAssertTrue(create.isEnabled)
        create.tap()
        let ready = app.staticTexts["export.ready"]
        XCTAssertTrue(ready.waitForExistence(timeout: 120))
        scrollTo(ready, in: app, down: true)
        XCTAssertTrue(app.buttons["Save to Files"].exists)
        XCTAssertTrue(app.buttons["Save to Photos"].exists)
        XCTAssertTrue(app.buttons["Share video"].exists)
        saveScreenshot(app, name: name)
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, down: Bool = false,
                          file: StaticString = #filePath, line: UInt = #line) {
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<24 {
            let viewport = scroll.frame.insetBy(dx: 0, dy: 6)
            let maximumMove = viewport.height * 0.45
            var movement = down ? -maximumMove : maximumMove
            if element.exists {
                let frame = element.frame
                if viewport.contains(frame), element.isHittable { return }
                movement = min(maximumMove, max(-maximumMove, frame.midY - viewport.midY))
            }
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let end = start.withOffset(CGVector(dx: 0, dy: -movement))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        XCTAssertTrue(element.isHittable, "Could not reach \(element)", file: file, line: line)
    }

    private func saveScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest

final class LaunchTests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing"]; app.launch(); return app
    }
    private func tool(_ name: String, app: XCUIApplication) {
        let command = app.buttons["open-command"].firstMatch
        XCTAssertTrue(command.waitForExistence(timeout: 10)); command.tap()
        let field = app.textFields["command-search"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText(name)
        let tool = app.buttons["tool-\(name)"]
        XCTAssertTrue(tool.waitForExistence(timeout: 5)); tool.tap()
    }
    func testWorkspaceLaunchAndFloatingControls() {
        let app = launch()
        XCTAssertTrue(app.buttons["open-command"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Expand floating island"].waitForExistence(timeout: 5))
        app.buttons["Expand floating island"].tap()
        XCTAssertTrue(app.buttons["Focus 25 min"].waitForExistence(timeout: 5))
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Floating workspace"; image.lifetime = .keepAlways; add(image)
    }
    func testNoteEditingAndTaskCreation() {
        let app = launch(); tool("Notes", app: app)
        let editor = app.textViews["note-body"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5)); editor.tap(); editor.typeText("A tested idea")
        tool("Tasks", app: app)
        let input = app.textFields["task-title"]
        XCTAssertTrue(input.waitForExistence(timeout: 5)); input.tap(); input.typeText("Review launch build")
        app.buttons["Add task"].tap()
        XCTAssertTrue(app.staticTexts["Review launch build"].waitForExistence(timeout: 5))
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Task board"; image.lifetime = .keepAlways; add(image)
    }
    func testLargeTextAndAccessibilityDescriptions() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["open-command"].firstMatch.waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .trait])
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Largest accessibility text"; image.lifetime = .keepAlways; add(image)
    }
    func testLandscapeWorkspace() {
        let app = launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.buttons["open-command"].firstMatch.waitForExistence(timeout: 10))
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Landscape workspace"; image.lifetime = .keepAlways; add(image)
    }

}

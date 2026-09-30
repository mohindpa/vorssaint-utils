// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest
@testable import iPadOnSteroids

final class CoreTests: XCTestCase {
    func testCleanerPreservesFunctionalParametersAndFragment() {
        XCTAssertEqual(LinkCleaner.clean("https://example.com/search?q=ipad&utm_source=news&fbclid=123#results"), "https://example.com/search?q=ipad#results")
    }
    func testCleanerRemovesEmptyQueryAndRejectsNonWebLinks() {
        XCTAssertEqual(LinkCleaner.clean("https://example.com/?UTM_campaign=test"), "https://example.com/")
        XCTAssertNil(LinkCleaner.clean("javascript:alert(1)"))
        XCTAssertNil(LinkCleaner.clean("hello world"))
    }
    func testShortcutNamesAreEncodedAsOneQueryValue() throws {
        let url = try XCTUnwrap(ShortcutLink.url(for: "Work & Play #1"))
        let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(parts.queryItems, [URLQueryItem(name: "name", value: "Work & Play #1")])
        XCTAssertNil(ShortcutLink.url(for: "  "))
    }
    func testBackupRoundTripKeepsPinnedItemsAndIdentity() throws {
        var workspace = Workspace()
        workspace.note = "Unicode ✨\nSecond line"
        workspace.shelf = [ShelfItem(text: "secret note", pinned: true)]
        workspace.launchers = [Launcher(name: "Focus", shortcut: "Start work")]
        let restored = try JSONDecoder().decode(Workspace.self, from: JSONEncoder().encode(workspace))
        XCTAssertEqual(restored.note, workspace.note)
        XCTAssertEqual(restored.shelf, workspace.shelf)
        XCTAssertEqual(restored.launchers, workspace.launchers)
    }
}

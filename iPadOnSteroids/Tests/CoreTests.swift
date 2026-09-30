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

final class WorkspaceUpgradeTests: XCTestCase {
    func testLegacyBackupMigratesSingleNoteWithoutDataLoss() throws {
        let backup = Data(#"{"note":"legacy note","shelf":[],"launchers":[]}"#.utf8)
        let value = try BackupCodec.decode(backup)
        XCTAssertEqual(value.notes.count, 1)
        XCTAssertEqual(value.notes[0].text, "legacy note")
        XCTAssertEqual(try BackupCodec.decode(BackupCodec.encode(value)), value)
    }
    func testUnknownVersionAndUnrelatedJSONAreRejected() {
        XCTAssertThrowsError(try BackupCodec.decode(Data(#"{"version":999,"notes":[]}"#.utf8)))
        XCTAssertThrowsError(try BackupCodec.decode(Data(#"{"hello":"world"}"#.utf8)))
    }
    func testDuplicateIDsAreRejectedWithoutMutation() {
        var workspace = Workspace()
        let note = NoteItem(title: "Copy")
        workspace.notes = [note, note]
        XCTAssertThrowsError(try BackupCodec.encode(workspace))
    }
    func testInvalidAndOversizedEntriesAreRejected() {
        var value = Workspace(); value.tasks = [TaskItem(title: " ")]
        XCTAssertThrowsError(try BackupCodec.encode(value))
        value = Workspace(); value.launchers = [Launcher(name: "Focus", shortcut: String(repeating: "x", count: 201))]
        XCTAssertThrowsError(try BackupCodec.encode(value))
        XCTAssertThrowsError(try BackupCodec.decode(Data(repeating: 32, count: BackupCodec.maximumBytes + 1)))
    }
    func testAllWorkspaceCollectionsSurviveRoundTrip() throws {
        var value = Workspace(); value.notes = [NoteItem(title: "One", text: "Hello"), NoteItem(title: "Two", text: "✨")]
        value.tasks = [TaskItem(title: "Done", done: true)]
        value.shelf = [ShelfItem(text: "Pinned", pinned: true)]
        value.launchers = [Launcher(name: "Routine", shortcut: "Work & Play")]
        XCTAssertEqual(try BackupCodec.decode(BackupCodec.encode(value)), value)
    }
    func testRecapturePreservesIdentityAndPin() {
        var value = Workspace(); let original = ShelfItem(text: "Keep", pinned: true); value.shelf = [original]
        value.capture("Keep", at: Date(timeIntervalSince1970: 123))
        XCTAssertEqual(value.shelf.count, 1)
        XCTAssertEqual(value.shelf[0].id, original.id)
        XCTAssertTrue(value.shelf[0].pinned)
        XCTAssertEqual(value.shelf[0].date, Date(timeIntervalSince1970: 123))
    }
    func testShelfEvictsOldUnpinnedItemsButRetainsPins() {
        var value = Workspace(); let pin = ShelfItem(text: "Keep", pinned: true); value.shelf = [pin]
        for i in 0..<150 { value.capture("Item \(i)") }
        XCTAssertEqual(value.shelf.count, 101)
        XCTAssertTrue(value.shelf.contains { $0.id == pin.id })
        XCTAssertFalse(value.shelf.contains { $0.text == "Item 0" })
        XCTAssertEqual(value.shelf.first?.text, "Item 149")
    }
    func testCleanerPreservesEncodedFunctionalQueryAndRepeatedValues() {
        XCTAssertEqual(LinkCleaner.clean("https://example.com/?q=a%20b&token=a%2Fb&x=1&x=2&utm_source=z#keep"), "https://example.com/?q=a%20b&token=a%2Fb&x=1&x=2#keep")
        XCTAssertEqual(LinkCleaner.clean("https://example.com/?%75tm_source=x&q=a+b"), "https://example.com/?q=a+b")
    }
    func testPausedSessionDoesNotLoseTimeAndResumesFromPause() {
        let start = Date(timeIntervalSince1970: 1000)
        var session = FocusSession(seconds: 300, now: start)
        session.pause(at: start.addingTimeInterval(100))
        XCTAssertTrue(session.isPaused)
        XCTAssertEqual(session.remaining(at: start.addingTimeInterval(1000)), 200)
        session.resume(at: start.addingTimeInterval(1000))
        XCTAssertFalse(session.isPaused)
        XCTAssertEqual(session.remaining(at: start.addingTimeInterval(1050)), 150)
        XCTAssertEqual(session.progress(at: start.addingTimeInterval(1050)), 0.5, accuracy: 0.0001)
    }
    func testFocusClampsDurationAndExpiredClockToZero() {
        let start = Date(timeIntervalSince1970: 1000)
        XCTAssertEqual(FocusSession(seconds: -10, now: start).duration, 60)
        XCTAssertEqual(FocusSession(seconds: 99999, now: start).duration, 10800)
        let session = FocusSession(seconds: 60, now: start)
        XCTAssertEqual(session.remaining(at: start.addingTimeInterval(100)), 0)
        XCTAssertEqual(session.progress(at: start.addingTimeInterval(100)), 1)
    }
    func testFocusRoundTripPreservesPausedState() throws {
        var session = FocusSession(seconds: 300, now: Date(timeIntervalSince1970: 1000)); session.pause(at: Date(timeIntervalSince1970: 1100))
        XCTAssertEqual(try JSONDecoder().decode(FocusSession.self, from: JSONEncoder().encode(session)), session)
    }
    func testFileWriterNeverLetsOlderRevisionOverwriteNewerData() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("workspace.json"); let writer = WorkspaceFile(url: url)
        var newer = Workspace(); newer.note = "new"
        var older = Workspace(); older.note = "old"
        try await writer.write(newer, revision: 2)
        try await writer.write(older, revision: 1)
        XCTAssertEqual(try BackupCodec.read(url).note, "new")
    }
    func testRecoveryArchivesOriginalBeforeReplacement() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("workspace.json"); let original = Data("broken data".utf8)
        try original.write(to: url)
        let writer = WorkspaceFile(url: url); try await writer.archiveUnreadableFile(); try await writer.write(Workspace(), revision: 1)
        let recovery = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).first { $0.lastPathComponent.hasPrefix("recovery-") })
        XCTAssertEqual(try Data(contentsOf: recovery), original)
        XCTAssertNoThrow(try BackupCodec.read(url))
    }
}

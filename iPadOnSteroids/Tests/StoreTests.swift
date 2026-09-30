// SPDX-License-Identifier: GPL-3.0-or-later
#if canImport(UIKit)
import XCTest
import UIKit
@testable import iPadOnSteroids

final class StoreTests: XCTestCase {
    func testDebouncedEditsFlushLatestSnapshot() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("workspace.json")
        let store = await MainActor.run { Store(file: url) }
        await MainActor.run { store.workspace.note = "First"; store.workspace.note = "Latest"; store.flush() }
        try await Task.sleep(for: .seconds(1))
        XCTAssertEqual(try BackupCodec.read(url).note, "Latest")
        let state = await MainActor.run { (store.saveError, store.saving) }
        XCTAssertNil(state.0); XCTAssertFalse(state.1)
    }
    func testUnreadableWorkspaceIsProtectedFromAutosave() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("workspace.json"), original = Data("broken".utf8)
        try original.write(to: url)
        let store = await MainActor.run { Store(file: url) }
        let hasError = await MainActor.run { store.persistenceError != nil }
        XCTAssertTrue(hasError)
        await MainActor.run { store.workspace.note = "Do not replace"; store.flush() }
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
    func testInvalidReplacementKeepsCurrentWorkspace() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("workspace.json")
        let store = await MainActor.run { Store(file: url) }
        await MainActor.run {
            store.workspace.note = "Keep me"
            var invalid = Workspace(); invalid.tasks = [TaskItem(title: " ")]
            store.replaceWorkspace(invalid)
            XCTAssertEqual(store.workspace.note, "Keep me")
        }
        await MainActor.run { store.flush() }
        try? await Task.sleep(for: .milliseconds(500))
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
final class OCRTests: XCTestCase {
    func testRecognitionOfActualRenderedImage() async throws {
        let data = try await MainActor.run {
            let image = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 200)).image { context in
                context.cgContext.setFillColor(UIColor.white.cgColor)
                context.cgContext.fill(CGRect(x: 0, y: 0, width: 800, height: 200))
                ("HELLO IPAD" as NSString).draw(at: CGPoint(x: 40, y: 60), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 64), .foregroundColor: UIColor.black])
            }
            return try XCTUnwrap(image.pngData())
        }
        let text = try await Task.detached { try OCRService.recognize(data) }.value
        XCTAssertTrue(text.uppercased().contains("HELLO IPAD"), text)
    }
    func testUnreadableAndOversizedImagesAreRejected() {
        XCTAssertThrowsError(try OCRService.recognize(Data("not an image".utf8)))
        XCTAssertThrowsError(try OCRService.recognize(Data(repeating: 0, count: 40 * 1024 * 1024 + 1)))
    }
}
#endif

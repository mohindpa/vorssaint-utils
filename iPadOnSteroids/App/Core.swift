// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

struct ShelfItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var date = Date()
    var pinned = false
}
struct Launcher: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var shortcut: String
}
struct NoteItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title = "Untitled note"
    var text = ""
}
struct TaskItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var done = false
}
struct Workspace: Codable, Equatable {
    static let currentVersion = 2
    var notes = [NoteItem(title: "Scratchpad")]
    var shelf: [ShelfItem] = []
    var launchers: [Launcher] = []
    var tasks: [TaskItem] = []
    // Source-compatible convenience for the original single-note workspace.
    var note: String {
        get { notes.first?.text ?? "" }
        set { if notes.isEmpty { notes = [NoteItem(title: "Scratchpad", text: newValue)] } else { notes[0].text = newValue } }
    }
    init() {}
    enum CodingKeys: String, CodingKey { case version, note, notes, shelf, launchers, tasks }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        guard (1...Self.currentVersion).contains(version) else { throw WorkspaceError.unsupportedVersion }
        // Reject unrelated JSON instead of silently importing an empty workspace.
        guard c.contains(.notes) || c.contains(.note) || c.contains(.shelf) || c.contains(.launchers) || c.contains(.tasks) else { throw WorkspaceError.invalidBackup }
        if let saved = try c.decodeIfPresent([NoteItem].self, forKey: .notes) { notes = saved }
        else { notes = [NoteItem(title: "Scratchpad", text: try c.decodeIfPresent(String.self, forKey: .note) ?? "")] }
        shelf = try c.decodeIfPresent([ShelfItem].self, forKey: .shelf) ?? []
        launchers = try c.decodeIfPresent([Launcher].self, forKey: .launchers) ?? []
        tasks = try c.decodeIfPresent([TaskItem].self, forKey: .tasks) ?? []
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.currentVersion, forKey: .version)
        try c.encode(notes, forKey: .notes)
        try c.encode(shelf, forKey: .shelf)
        try c.encode(launchers, forKey: .launchers)
        try c.encode(tasks, forKey: .tasks)
    }
    mutating func capture(_ text: String, at date: Date = Date()) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var item = shelf.first { $0.text == text } ?? ShelfItem(text: text)
        item.date = date
        shelf.removeAll { $0.text == text }
        shelf.insert(item, at: 0)
        var unpinned = 0
        shelf = shelf.filter { item in
            if item.pinned { return true }
            unpinned += 1
            return unpinned <= 100
        }
    }
}
enum WorkspaceError: LocalizedError {
    case unsupportedVersion, invalidBackup, tooLarge, duplicateIDs, invalidEntry
    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: return "This backup uses an unsupported workspace version."
        case .invalidBackup: return "This file is not a workspace backup."
        case .tooLarge: return "This workspace exceeds the 10 MB backup or item limits."
        case .duplicateIDs: return "This backup contains duplicate item identifiers."
        case .invalidEntry: return "This backup contains an empty or oversized entry."
        }
    }
}
enum BackupCodec {
    static let maximumBytes = 10 * 1024 * 1024
    static let maximumText = 200_000
    static func decode(_ data: Data) throws -> Workspace {
        guard data.count <= maximumBytes else { throw WorkspaceError.tooLarge }
        let value = try JSONDecoder().decode(Workspace.self, from: data)
        try validate(value)
        return value
    }
    static func encode(_ value: Workspace) throws -> Data {
        try validate(value)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        guard data.count <= maximumBytes else { throw WorkspaceError.tooLarge }
        return data
    }
    static func validate(_ value: Workspace) throws {
        guard value.notes.count <= 500, value.tasks.count <= 500, value.shelf.count <= 1000, value.launchers.count <= 100 else { throw WorkspaceError.tooLarge }
        func unique(_ ids: [UUID]) throws { guard Set(ids).count == ids.count else { throw WorkspaceError.duplicateIDs } }
        try unique(value.notes.map(\.id)); try unique(value.shelf.map(\.id)); try unique(value.launchers.map(\.id)); try unique(value.tasks.map(\.id))
        func valid(_ s: String, limit: Int, allowEmpty: Bool = true) -> Bool { s.count <= limit && (allowEmpty || !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        guard value.notes.allSatisfy({ valid($0.title, limit: 200) && valid($0.text, limit: maximumText) }),
              value.shelf.allSatisfy({ valid($0.text, limit: maximumText, allowEmpty: false) }),
              value.launchers.allSatisfy({ valid($0.name, limit: 200, allowEmpty: false) && valid($0.shortcut, limit: 200, allowEmpty: false) }),
              value.tasks.allSatisfy({ valid($0.title, limit: 500, allowEmpty: false) }) else { throw WorkspaceError.invalidEntry }
    }
    static func read(_ url: URL) throws -> Workspace {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= maximumBytes else { throw WorkspaceError.tooLarge }
        return try decode(Data(contentsOf: url))
    }
}

// Serial, revision-aware disk writes prevent a delayed autosave from replacing a newer snapshot.
actor WorkspaceFile {
    let url: URL
    private var lastRevision: UInt64 = 0
    init(url: URL) { self.url = url }
    func write(_ workspace: Workspace, revision: UInt64) throws {
        guard revision > lastRevision else { return }
        let data = try BackupCodec.encode(workspace)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        lastRevision = revision
    }
    func archiveUnreadableFile() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let backup = url.deletingLastPathComponent().appendingPathComponent("recovery-\(UUID().uuidString).json")
        try FileManager.default.copyItem(at: url, to: backup)
    }
}

struct FocusSession: Codable, Equatable {
    var id = UUID()
    var duration: TimeInterval
    var deadline: Date?
    var pausedRemaining: TimeInterval?
    init(seconds: TimeInterval, now: Date) {
        duration = min(180 * 60, max(60, seconds))
        deadline = now.addingTimeInterval(duration)
    }
    var isPaused: Bool { pausedRemaining != nil }
    func remaining(at now: Date) -> TimeInterval { max(0, pausedRemaining ?? deadline?.timeIntervalSince(now) ?? 0) }
    func progress(at now: Date) -> Double { min(1, max(0, 1 - remaining(at: now) / max(1, duration))) }
    mutating func pause(at now: Date) { guard deadline != nil else { return }; pausedRemaining = remaining(at: now); deadline = nil }
    mutating func resume(at now: Date) { guard let seconds = pausedRemaining else { return }; deadline = now.addingTimeInterval(seconds); pausedRemaining = nil }
}

enum LinkCleaner {
    static func clean(_ input: String) -> String? {
        guard var parts = URLComponents(string: input.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(parts.scheme?.lowercased() ?? ""), let host = parts.host, !host.isEmpty else { return nil }
        // Keep the original percent encoding; decoding/re-encoding can change functional parameters.
        if let query = parts.percentEncodedQuery {
            let tracking: Set<String> = ["fbclid", "gclid", "dclid", "msclkid", "mc_cid", "mc_eid", "igshid"]
            let kept = query.split(separator: "&", omittingEmptySubsequences: false).filter { field in
                let raw = field.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
                let name = (raw.removingPercentEncoding ?? raw).lowercased()
                return !tracking.contains(name) && !name.hasPrefix("utm_")
            }
            parts.percentEncodedQuery = kept.isEmpty ? nil : kept.joined(separator: "&")
        }
        return parts.url?.absoluteString
    }
}
enum ShortcutLink {
    static func url(for name: String) -> URL? {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        var parts = URLComponents(); parts.scheme = "shortcuts"; parts.host = "run-shortcut"
        parts.queryItems = [URLQueryItem(name: "name", value: name)]
        return parts.url
    }
}

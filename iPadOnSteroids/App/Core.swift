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
struct Workspace: Codable {
    var note = ""
    var shelf: [ShelfItem] = []
    var launchers: [Launcher] = []
}
enum LinkCleaner {
    static func clean(_ input: String) -> String? {
        guard var parts = URLComponents(string: input.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(parts.scheme?.lowercased() ?? ""),
              let host = parts.host, !host.isEmpty else { return nil }
        let tracking: Set<String> = ["fbclid", "gclid", "dclid", "msclkid", "mc_cid", "mc_eid", "igshid"]
        if let query = parts.queryItems {
            let kept = query.filter { !tracking.contains($0.name.lowercased()) && !$0.name.lowercased().hasPrefix("utm_") }
            parts.queryItems = kept.isEmpty ? nil : kept
        }
        return parts.url?.absoluteString
    }
}
enum ShortcutLink {
    static func url(for name: String) -> URL? {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        var parts = URLComponents()
        parts.scheme = "shortcuts"
        parts.host = "run-shortcut"
        parts.queryItems = [URLQueryItem(name: "name", value: name)]
        return parts.url
    }
}

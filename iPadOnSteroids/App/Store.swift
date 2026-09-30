// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import UIKit
import UserNotifications

@MainActor final class Store: ObservableObject {
    @Published var workspace: Workspace { didSet { save() } }
    @Published var message = ""
    @Published var deadline: Date?
    @Published var now = Date()
    @Published var battery: Float = -1
    @Published var thermal = "Nominal"
    @Published var storage = "Unavailable"
    @Published var persistenceError: String?
    private var timer: Timer?
    private var focusGeneration = UUID()
    private let file: URL
    private let deadlineKey = "focusDeadline"

    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        file = folder.appendingPathComponent("workspace.json")
        var initial = Workspace()
        var loadError: String?
        if FileManager.default.fileExists(atPath: file.path) {
            do { initial = try JSONDecoder().decode(Workspace.self, from: Data(contentsOf: file)) }
            catch { loadError = "Saved workspace could not be read. Existing data is preserved; export or recover it before editing." }
        }
        workspace = initial
        persistenceError = loadError
        if let saved = UserDefaults.standard.object(forKey: deadlineKey) as? Date, saved > Date() { deadline = saved }
        else { UserDefaults.standard.removeObject(forKey: deadlineKey) }
        UIDevice.current.isBatteryMonitoringEnabled = true
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }
    var remaining: Int { max(0, Int(ceil(deadline?.timeIntervalSince(now) ?? 0))) }
    var timeLabel: String { String(format: "%02d:%02d", remaining / 60, remaining % 60) }
    private func tick() {
        now = Date()
        if let end = deadline, end <= now {
            deadline = nil
            UserDefaults.standard.removeObject(forKey: deadlineKey)
            message = "Focus complete. Take a breath."
        }
        if Int(now.timeIntervalSince1970) % 10 == 0 { refresh() }
    }
    func refresh() {
        battery = UIDevice.current.batteryLevel
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = "Nominal"
        case .fair: thermal = "Fair"
        case .serious: thermal = "Serious"
        case .critical: thermal = "Critical"
        @unknown default: thermal = "Unknown"
        }
        if let values = try? file.deletingLastPathComponent().resourceValues(forKeys: [.volumeAvailableCapacityKey]), let free = values.volumeAvailableCapacity {
            storage = ByteCountFormatter.string(fromByteCount: Int64(free), countStyle: .file)
        }
    }
    func startFocus(minutes: Int) {
        let generation = UUID()
        focusGeneration = generation
        let end = Date().addingTimeInterval(Double(minutes * 60))
        deadline = end
        now = Date()
        UserDefaults.standard.set(end, forKey: deadlineKey)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["focus"])
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            Task { @MainActor [weak self] in
            guard let self, self.focusGeneration == generation, self.deadline == end else { return }
            guard granted else {
                Task { @MainActor [weak self] in self?.message = error == nil ? "Timer started. Notifications are disabled; return to the app to see completion." : "Timer started. Notification permission could not be requested." }
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "Focus complete"
            content.body = "Your iPad on Steroids session is finished."
            content.sound = .default
            let request = UNNotificationRequest(identifier: "focus", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, end.timeIntervalSinceNow), repeats: false))
            center.add(request) { error in
                if error != nil { Task { @MainActor [weak self] in self?.message = "Timer started, but the notification could not be scheduled." } }
            }
            }
        }
    }
    func stopFocus() {
        focusGeneration = UUID()
        deadline = nil
        UserDefaults.standard.removeObject(forKey: deadlineKey)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["focus"])
    }
    func capture(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let existing = workspace.shelf.first(where: { $0.text == text })
        workspace.shelf.removeAll { $0.text == text }
        workspace.shelf.insert(ShelfItem(text: text, pinned: existing?.pinned ?? false), at: 0)
        // Keep every pinned item plus the 100 newest unpinned items.
        var count = 0
        workspace.shelf = workspace.shelf.filter { item in
            if item.pinned { return true }
            count += 1
            return count <= 100
        }
        message = "Saved to your local shelf."
    }
    func copy(_ text: String) { UIPasteboard.general.string = text; message = "Copied." }
    private func save() {
        // Do not overwrite an unreadable existing workspace.
        guard persistenceError == nil else { return }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(workspace).write(to: file, options: .atomic)
        } catch { message = "Changes could not be saved: \(error.localizedDescription)" }
    }
}

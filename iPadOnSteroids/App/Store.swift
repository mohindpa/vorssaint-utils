// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import UIKit
import UserNotifications

@MainActor final class Store: ObservableObject {
    @Published var workspace: Workspace { didSet { scheduleSave() } }
    @Published var message = ""
    @Published var focus: FocusSession?
    private var now = Date()
    @Published var battery: Float = -1
    @Published var thermal = "Unavailable"
    @Published var storage = "Unavailable"
    @Published var persistenceError: String?
    @Published var saveError: String?
    @Published var saving = false
    private var ticker: Timer?
    private var saveTask: Task<Void, Never>?
    private var notificationTask: Task<Void, Never>?
    private var notificationID: String?
    private var revision: UInt64 = 0
    private var active = false
    private var activeScenes: Set<UUID> = []
    private var keepAwake = false
    private let file: URL
    private let writer: WorkspaceFile
    private let defaults: UserDefaults
    private let center: UNUserNotificationCenter
    private let focusKey = "focusSession.v2"
    var recoveryURL: URL { file }

    init(file: URL? = nil, defaults: UserDefaults = .standard, center: UNUserNotificationCenter = .current()) {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let destination = file ?? folder.appendingPathComponent("workspace.json")
        self.file = destination; writer = WorkspaceFile(url: destination)
        self.defaults = defaults; self.center = center
        var loaded = Workspace()
        var loadError: String?
        if FileManager.default.fileExists(atPath: destination.path) {
            do { loaded = try BackupCodec.read(destination) }
            catch { loadError = "Saved data could not be opened. Export the original file or use recovery before editing. \(error.localizedDescription)" }
        }
        workspace = loaded; persistenceError = loadError
        if let data = defaults.data(forKey: focusKey), let saved = try? JSONDecoder().decode(FocusSession.self, from: data), saved.duration.isFinite, saved.duration >= 60, saved.duration <= 10800,
           saved.remaining(at: Date()).isFinite, saved.remaining(at: Date()) > 0, saved.remaining(at: Date()) <= saved.duration {
            focus = saved
        } else if let end = defaults.object(forKey: "focusDeadline") as? Date, end > Date() {
            focus = FocusSession(seconds: min(10800, max(60, end.timeIntervalSinceNow)), now: Date())
            focus?.deadline = end
            defaults.removeObject(forKey: "focusDeadline")
            persistFocus()
        } else { defaults.removeObject(forKey: focusKey) }
        notificationID = focus.map { "focus.\($0.id.uuidString)" }
        UIDevice.current.isBatteryMonitoringEnabled = true
        refresh()
    }
    var remaining: Int { Int(ceil(focus?.remaining(at: now) ?? 0)) }
    var timeLabel: String { String(format: "%02d:%02d", remaining / 60, remaining % 60) }
    var isPaused: Bool { focus?.isPaused == true }
    var progress: Double { focus?.progress(at: now) ?? 0 }
    func setActive(_ value: Bool, sceneID: UUID) {
        if value { activeScenes.insert(sceneID) } else { activeScenes.remove(sceneID) }
        active = !activeScenes.isEmpty
        UIApplication.shared.isIdleTimerDisabled = keepAwake && active
        updateTicker()
    }
    func setKeepAwake(_ value: Bool) {
        keepAwake = value
        UIApplication.shared.isIdleTimerDisabled = keepAwake && active
    }
    private func updateTicker() {
        now = Date(); tick()
        ticker?.invalidate(); ticker = nil
        if active {
            refresh()
            if focus != nil && !isPaused {
                ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in self?.tick() }
                }
                ticker?.tolerance = 0.15
            }
        } else { flush() }
    }
    private func tick() {
        now = Date()
        if let session = focus, !session.isPaused, session.remaining(at: now) <= 0 {
            focus = nil; persistFocus(); ticker?.invalidate(); ticker = nil
            message = "Focus complete. Take a breath."
        }
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
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let values = try? directory.resourceValues(forKeys: [.volumeAvailableCapacityKey]), let free = values.volumeAvailableCapacity {
            storage = ByteCountFormatter.string(fromByteCount: Int64(free), countStyle: .file)
        }
    }
    func startFocus(minutes: Int) {
        now = Date(); focus = FocusSession(seconds: TimeInterval(minutes) * 60, now: now)
        persistFocus(); scheduleNotification(); updateTicker()
    }
    func pauseFocus() {
        now = Date(); focus?.pause(at: now)
        persistFocus(); cancelNotification(); updateTicker()
    }
    func resumeFocus() {
        now = Date(); focus?.resume(at: now)
        persistFocus(); scheduleNotification(); updateTicker()
    }
    func stopFocus() {
        focus = nil; persistFocus(); cancelNotification(); ticker?.invalidate(); ticker = nil
    }
    private func persistFocus() {
        if let focus, let data = try? JSONEncoder().encode(focus) { defaults.set(data, forKey: focusKey) }
        else { defaults.removeObject(forKey: focusKey) }
    }
    private func cancelNotification() {
        notificationTask?.cancel(); notificationTask = nil
        center.removePendingNotificationRequests(withIdentifiers: ["focus"] + [notificationID].compactMap { $0 })
        notificationID = nil
    }
    private func scheduleNotification() {
        cancelNotification()
        guard let end = focus?.deadline, let sessionID = focus?.id else { return }
        let identifier = "focus.\(sessionID.uuidString)"
        notificationID = identifier
        notificationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                guard !Task.isCancelled, focus?.deadline == end else { return }
                guard granted else { message = "Timer started. Completion notifications are disabled."; return }
                let content = UNMutableNotificationContent()
                content.title = "Focus complete"; content.body = "Your focus session is finished."; content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, end.timeIntervalSinceNow), repeats: false)
                try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
                // A stop/restart can interleave while add awaits: reconcile the request to current state.
                if Task.isCancelled || focus?.deadline != end {
                    center.removePendingNotificationRequests(withIdentifiers: [identifier])
                }
            } catch {
                if !Task.isCancelled { message = "Timer works in-app, but its notification failed: \(error.localizedDescription)" }
            }
        }
    }
    func capture(_ text: String) {
        guard text.count <= BackupCodec.maximumText else { message = "Text is too long to save (200,000 character limit)."; return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var next = workspace; next.capture(text); workspace = next
        message = "Saved to your shelf."
    }
    func copy(_ text: String) { UIPasteboard.general.string = text; message = "Copied." }
    private func scheduleSave() {
        guard persistenceError == nil else { return }
        revision += 1; let version = revision; let snapshot = workspace
        saveTask?.cancel(); saving = true
        saveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                await self?.write(snapshot, version: version)
            } catch { /* Canceled debounce; the next snapshot or flush owns the save. */ }
        }
    }
    private func write(_ snapshot: Workspace, version: UInt64) async {
        do {
            try await writer.write(snapshot, revision: version)
            if revision == version { saveError = nil; saving = false }
        } catch {
            if revision == version { saveError = "Changes are not saved: \(error.localizedDescription)"; saving = false }
        }
    }
    func flush() {
        guard persistenceError == nil else { return }
        saveTask?.cancel(); revision += 1; let version = revision; let snapshot = workspace; saving = true
        saveTask = Task { [weak self] in await self?.write(snapshot, version: version) }
    }
    func replaceWorkspace(_ value: Workspace) {
        do { try BackupCodec.validate(value); workspace = value; flush(); message = "Workspace restored." }
        catch { message = error.localizedDescription }
    }
    func recoverStorage() async {
        do {
            try await writer.archiveUnreadableFile()
            persistenceError = nil; workspace = Workspace(); flush()
            message = "Original file preserved as a recovery copy. A new workspace is ready."
        } catch { message = "Recovery failed: \(error.localizedDescription)" }
    }
}

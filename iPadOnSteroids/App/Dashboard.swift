// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct WorkspaceDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var workspace: Workspace
    init(workspace: Workspace) { self.workspace = workspace }
    init(configuration: ReadConfiguration) throws { workspace = try BackupCodec.decode(configuration.file.regularFileContents ?? Data()) }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: try BackupCodec.encode(workspace)) }
}
struct Dashboard: View {
    @EnvironmentObject private var store: Store
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("accent") private var accent = "Mint"
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("showIsland") private var showIsland = true
    @AppStorage("showTelemetry") private var showTelemetry = true
    @AppStorage("keepAwake") private var keepAwake = false
    @AppStorage("quickTools") private var quickTools = "Notes|Clipboard shelf|Tasks|Launchpad"
    @State private var sceneID = UUID()
    @State private var selected: Panel? = .overview
    @State private var selectedNote: UUID?
    @State private var command = ""
    @State private var showCommand = false
    @State private var expanded = false
    @State private var filter = ""
    @State private var pinnedOnly = false
    @State private var linkInput = ""
    @State private var cleaned = ""
    @State private var shortcutName = ""
    @State private var displayName = ""
    @State private var exporting = false
    @State private var importing = false
    @State private var importingBusy = false
    @State private var confirmClear = false
    @State private var confirmImport = false
    @State private var confirmRecovery = false
    @State private var pendingWorkspace: Workspace?
    private var tint: Color { accent == "Mint" ? .mint : accent == "Purple" ? .purple : .orange }
    private var pinnedPanels: [Panel] { quickTools.split(separator: "|").compactMap { Panel(rawValue: String($0)) } }
    private var panel: Panel { selected ?? .overview }
    private var filteredShelf: [ShelfItem] {
        store.workspace.shelf.filter { (!pinnedOnly || $0.pinned) && (filter.isEmpty || $0.text.localizedCaseInsensitiveContains(filter)) }.sorted { a,b in
            if a.pinned != b.pinned { return a.pinned }
            return a.date > b.date
        }
    }
    var body: some View {
        presentation
        .confirmationDialog("Replace your notes, tasks, shelf and launchers? Export your current workspace first if you want to keep it.", isPresented: $confirmImport, titleVisibility: .visible) {
            Button("Replace workspace", role: .destructive) { if let value = pendingWorkspace { store.replaceWorkspace(value) }; pendingWorkspace = nil }
            Button("Cancel", role: .cancel) { pendingWorkspace = nil }
        }
        .confirmationDialog("Delete all saved clipboard items?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Delete shelf", role: .destructive) { store.workspace.shelf.removeAll() }
        }
        .confirmationDialog("Start a new workspace? Your unreadable file will be preserved as a recovery copy.", isPresented: $confirmRecovery, titleVisibility: .visible) {
            Button("Preserve file and start fresh") { Task { await store.recoverStorage() } }
        }
        .onChange(of: keepAwake) { _, _ in updateIdleTimer() }
        .onChange(of: scenePhase) { _, phase in store.setActive(phase == .active, sceneID: sceneID); updateIdleTimer() }
        .onAppear { store.setActive(scenePhase == .active, sceneID: sceneID); updateIdleTimer() }
        .onDisappear { store.setActive(false, sceneID: sceneID) }
    }
    private var navigation: some View {
        NavigationSplitView {
            List(Panel.allCases, selection: $selected) { item in Label(item.rawValue, systemImage: item.icon).tag(item) }
                .navigationTitle("On Steroids")
                .safeAreaInset(edge: .bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("YOUR IPAD WORKSPACE").font(.caption2.bold())
                        Text("Local-first · v0.2").font(.caption).foregroundStyle(.secondary)
                    }.padding()
                }
        } detail: {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    Text(panel.detail).font(.title2).foregroundStyle(.secondary)
                    feedback
                    content.disabled(store.persistenceError != nil && panel != .settings)
                }.padding(24).frame(maxWidth: 1100, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background {
                ZStack {
                    Color(uiColor: .systemGroupedBackground)
                    LinearGradient(colors: [tint.opacity(0.10), .clear, tint.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
                }.ignoresSafeArea()
            }
            .navigationTitle(panel.rawValue)
            .safeAreaInset(edge: .top, spacing: 0) {
                if showIsland { FloatingIsland(expanded: $expanded, openNotes: { selected = .notes }, openCommands: { showCommand = true }).frame(maxWidth: .infinity) }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { floatingDock }
            .toolbar {
                Button { showCommand = true } label: { Label("Command bar", systemImage: "command") }.keyboardShortcut("k", modifiers: .command).accessibilityIdentifier("open-command")
            }
        }
    }
    private var presentation: some View {
        navigation
        .tint(tint)
        .preferredColorScheme(appearance == "System" ? nil : appearance == "Dark" ? .dark : .light)
        .sheet(isPresented: $showCommand) { commandBar }
        .fileExporter(isPresented: $exporting, document: WorkspaceDocument(workspace: store.workspace), contentType: .json, defaultFilename: "iPad-on-Steroids-workspace") { result in
            switch result { case .success: store.message = "Backup exported."; case .failure(let error): store.message = "Export failed: \(error.localizedDescription)" }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            Task { await importBackup(result) }
        }
    }
    private func updateIdleTimer() { store.setKeepAwake(keepAwake) }
    @ViewBuilder private var feedback: some View {
        if let error = store.persistenceError {
            ToolCard(title: "Protect your saved data", icon: "exclamationmark.shield") {
                Text(error).foregroundStyle(.red)
                ShareLink("Export original file", item: store.recoveryURL)
                Button("Start fresh with recovery copy") { confirmRecovery = true }
            }
        }
        if let error = store.saveError {
            ToolCard(title: "Save needs attention", icon: "exclamationmark.triangle") {
                Text(error).foregroundStyle(.red)
                HStack { Button("Retry save") { store.flush() }; Button("Export backup") { exporting = true } }
            }
        }
        if !store.message.isEmpty {
            HStack {
                Text(store.message).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                Button { store.message = "" } label: { Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44) }.accessibilityLabel("Dismiss message")
            }.padding(.leading, 16).glassSurface(corner: 18).accessibilityAddTraits(.updatesFrequently)
        }
    }
    private var floatingDock: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(pinnedPanels) { item in
                    Button { selected = item } label: {
                        Label(item.rawValue, systemImage: item.icon).font(.callout.bold()).padding(.horizontal, 14).frame(minHeight: 44)
                            .background(selected == item ? tint.opacity(0.18) : .clear, in: Capsule())
                    }.buttonStyle(.plain).accessibilityLabel("Open \(item.rawValue)")
                }
                Button { showCommand = true } label: { Image(systemName: "command").frame(width: 44, height: 44) }.accessibilityLabel("Search workspace")
            }.padding(10).glassSurface(corner: 32).padding(.horizontal, 18).padding(.vertical, 12)
        }.frame(maxWidth: 820).frame(maxWidth: .infinity)
    }
    @ViewBuilder private var content: some View {
        switch panel {
        case .overview: overview
        case .shelf: shelf
        case .notes: NotesView(selectedID: $selectedNote)
        case .tasks: TasksView()
        case .links: links
        case .text: ImageTextView()
        case .launchers: launchers
        case .settings: settings
        }
    }
    private var overview: some View {
        VStack(alignment: .leading, spacing: 24) {
            if showTelemetry {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 16) {
                    metric("Battery", value: store.battery < 0 ? "Unavailable" : "\(Int(store.battery * 100))%", icon: "battery.100percent")
                    metric("Thermal state", value: store.thermal, icon: "thermometer.medium")
                    metric("Available storage", value: store.storage, icon: "internaldrive")
                }
                Button("Refresh device readings") { store.refresh() }.font(.caption)
            }
            FocusStudio()
            ToolCard(title: "At a glance", icon: "sparkles") {
                Text("\(store.workspace.notes.count) notes · \(store.workspace.shelf.count) shelf items · \(store.workspace.tasks.filter { !$0.done }.count) tasks remaining").foregroundStyle(.secondary)
                if let task = store.workspace.tasks.first(where: { !$0.done }) { Label(task.title, systemImage: "circle").lineLimit(3) }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], spacing: 16) {
                ForEach(Panel.allCases.filter { $0 != .overview && $0 != .settings }) { item in
                    Button { selected = item } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: item.icon).font(.title2).foregroundStyle(tint)
                            Text(item.rawValue).font(.headline)
                            Text(item.detail).font(.caption).foregroundStyle(.secondary)
                        }.padding(22).frame(maxWidth: .infinity, minHeight: 145, alignment: .leading).glassSurface()
                    }.buttonStyle(.plain)
                }
            }
        }
    }
    private func metric(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) { Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary); Text(value).font(.title2.bold()) }
            .frame(maxWidth: .infinity, alignment: .leading).padding(22).glassSurface()
    }
    private var shelf: some View {
        VStack(alignment: .leading, spacing: 16) {
            ViewThatFits {
                HStack { shelfControls }
                VStack(alignment: .leading) { shelfControls }
            }
            TextField("Search saved text", text: $filter).textFieldStyle(.roundedBorder)
            Toggle("Pinned only", isOn: $pinnedOnly)
            if filteredShelf.isEmpty { ContentUnavailableView("Nothing here yet", systemImage: "clipboard", description: Text("Tap Paste to save text, or try another search.")) }
            LazyVStack(spacing: 16) {
                ForEach(filteredShelf) { item in
                    ToolCard(title: item.pinned ? "Pinned" : item.date.formatted(date: .abbreviated, time: .shortened), icon: "doc.on.clipboard") {
                        Text(item.text).lineLimit(8).textSelection(.enabled)
                        ViewThatFits { HStack { shelfActions(item) }; VStack(alignment: .leading) { shelfActions(item) } }
                    }
                }
            }
        }
    }
    @ViewBuilder private var shelfControls: some View {
        PasteButton(payloadType: String.self) { $0.forEach { store.capture($0) } }
        Text("Save text explicitly.").font(.caption).foregroundStyle(.secondary)
        Button("Clear shelf", role: .destructive) { confirmClear = true }.disabled(store.workspace.shelf.isEmpty)
    }
    @ViewBuilder private func shelfActions(_ item: ShelfItem) -> some View {
        Button("Copy") { store.copy(item.text) }.buttonStyle(.bordered)
        ShareLink(item: item.text).buttonStyle(.bordered)
        Button(item.pinned ? "Unpin" : "Pin") { if let i = store.workspace.shelf.firstIndex(where: { $0.id == item.id }) { store.workspace.shelf[i].pinned.toggle() } }.buttonStyle(.bordered)
        Button("Delete", role: .destructive) { store.workspace.shelf.removeAll { $0.id == item.id } }.buttonStyle(.bordered)
    }
    private var links: some View {
        ToolCard(title: "Clean link", icon: "link") {
            TextField("https://example.com/?utm_source=…", text: $linkInput, axis: .vertical).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
            PasteButton(payloadType: String.self) { values in linkInput = values.first ?? ""; cleaned = "" }
            Button("Clean URL") {
                if let result = LinkCleaner.clean(linkInput) { cleaned = result }
                else { cleaned = ""; store.message = "Enter a valid http or https link." }
            }.buttonStyle(.borderedProminent)
            if !cleaned.isEmpty {
                Text(cleaned).textSelection(.enabled)
                ViewThatFits { HStack { linkActions }; VStack(alignment: .leading) { linkActions } }
            }
            Text("Known trackers are removed. Functional parameter encoding is preserved. Removing tracking fields can invalidate a signed link.").font(.caption).foregroundStyle(.secondary)
        }.onChange(of: linkInput) { _, _ in cleaned = "" }
    }
    @ViewBuilder private var linkActions: some View {
        Button("Copy") { store.copy(cleaned) }.buttonStyle(.bordered)
        Button("Save to shelf") { store.capture(cleaned) }.buttonStyle(.bordered)
        ShareLink(item: cleaned).buttonStyle(.bordered)
    }
    private var launchers: some View {
        VStack(alignment: .leading, spacing: 16) {
            ToolCard(title: "Add your routine", icon: "bolt.fill") {
                TextField("Tile name", text: $displayName).textFieldStyle(.roundedBorder)
                TextField("Exact name in Apple Shortcuts", text: $shortcutName).textFieldStyle(.roundedBorder)
                Button("Add launcher") {
                    store.workspace.launchers.append(Launcher(name: displayName.trimmingCharacters(in: .whitespacesAndNewlines), shortcut: shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)))
                    shortcutName = ""; displayName = ""
                }.buttonStyle(.borderedProminent).disabled(!canAddLauncher)
                Text("Create the Shortcut first. It may set Focus, brightness or open an app, depending on supported actions and permissions.").font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], spacing: 16) {
                ForEach(store.workspace.launchers) { launcher in
                    ToolCard(title: launcher.name, icon: "bolt.fill") {
                        Text(launcher.shortcut).font(.caption).foregroundStyle(.secondary)
                        Button("Run Shortcut") { run(launcher) }.buttonStyle(.borderedProminent)
                        Menu("Manage") { Button("Remove", role: .destructive) { store.workspace.launchers.removeAll { $0.id == launcher.id } } }
                    }
                }
            }
        }
    }
    private var canAddLauncher: Bool { !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !shortcutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && displayName.count <= 200 && shortcutName.count <= 200 && store.workspace.launchers.count < 100 }
    private func run(_ launcher: Launcher) {
        guard let url = ShortcutLink.url(for: launcher.shortcut) else { return }
        store.flush()
        openURL(url) { accepted in if !accepted { store.message = "Could not open Shortcuts. Make sure it is installed and the routine exists." } }
    }
    private var settings: some View {
        VStack(spacing: 20) {
            ToolCard(title: "Make it yours", icon: "slider.horizontal.3") {
                Picker("Accent", selection: $accent) { ForEach(["Mint", "Purple", "Orange"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
                Picker("Appearance", selection: $appearance) { ForEach(["System", "Dark", "Light"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
                Toggle("Show floating island", isOn: $showIsland)
                Toggle("Show device readings", isOn: $showTelemetry)
                Toggle("Keep screen awake while this app is active", isOn: $keepAwake)
                Text("Reduce Motion, Reduce Transparency and increased contrast follow your system accessibility settings.").font(.caption).foregroundStyle(.secondary)
            }
            ToolCard(title: "Floating menu favorites", icon: "star") {
                ForEach(Panel.allCases.filter { $0 != .overview && $0 != .settings }) { item in
                    Toggle(item.rawValue, isOn: Binding(get: { pinnedPanels.contains(item) }, set: { enabled in
                        var values = pinnedPanels.filter { $0 != item }
                        if enabled { values.append(item) }
                        quickTools = values.map(\.rawValue).joined(separator: "|")
                    }))
                }
                Text("Favorites appear in the order you add them. Scroll the floating menu in narrow windows.").font(.caption).foregroundStyle(.secondary)
            }
            ToolCard(title: "Backups and recovery", icon: "externaldrive") {
                ViewThatFits { HStack { backupActions }; VStack(alignment: .leading) { backupActions } }
                if importingBusy { ProgressView("Checking backup…") }
                Text("JSON backups contain notes, tasks, shelf items and launchers. Appearance and timers are saved separately. Keep exported personal data in a trusted destination.").font(.caption).foregroundStyle(.secondary)
            }
            ToolCard(title: "Compatibility", icon: "ipad") {
                Text("Running \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)").font(.headline)
                Text("Minimum iPadOS 17. Floating controls use public SwiftUI materials with accessibility fallbacks. Compatibility with a particular OS release still requires a build and device test.").font(.caption).foregroundStyle(.secondary)
            }
            ToolCard(title: "iPadOS boundaries", icon: "info.circle") {
                Text("Floating controls stay inside this app. System-wide overlays, per-app audio mixing, other apps’ files and global key remapping are unavailable through general public APIs. Use iPadOS for window management.").font(.callout)
                Text("Independent utility app inspired by Vorssaint’s categories. No official branding or macOS code included.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    @ViewBuilder private var backupActions: some View {
        Button("Export backup") { store.flush(); exporting = true }.buttonStyle(.bordered).disabled(store.persistenceError != nil)
        Button("Import backup") { importing = true }.buttonStyle(.bordered).disabled(importingBusy || store.persistenceError != nil)
    }
    @MainActor private func importBackup(_ result: Result<URL, Error>) async {
        importingBusy = true
        defer { importingBusy = false }
        do {
            let url = try result.get()
            let worker = Task.detached {
                let granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                return try BackupCodec.read(url)
            }
            pendingWorkspace = try await worker.value
            confirmImport = true
        } catch { store.message = "Import failed: \(error.localizedDescription)" }
    }
    private var commandBar: some View {
        NavigationStack {
            List {
                TextField("Find tools, notes, shelf items or routines", text: $command).accessibilityIdentifier("command-search").textInputAutocapitalization(.never).autocorrectionDisabled()
                if let result = CommandUtility.evaluate(command) {
                    Section(result.title) { Button(result.value) { store.copy(result.value); showCommand = false } }
                }
                if command.isEmpty {
                    Text("Try =42 * 3, 10 cm to in, 32 f to c or #62E3B5.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Tools") {
                    ForEach(Panel.allCases.filter { matches($0.rawValue) }) { item in
                        Button { selected = item; showCommand = false } label: { Label(item.rawValue, systemImage: item.icon) }.accessibilityIdentifier("tool-\(item.rawValue)")
                    }
                }
                if !command.isEmpty {
                    Section("Notes") {
                        ForEach(Array(store.workspace.notes.filter { matches($0.title) || matches($0.text) }.prefix(20))) { note in
                            Button { selectedNote = note.id; selected = .notes; showCommand = false } label: { Label(note.title.isEmpty ? "Untitled note" : note.title, systemImage: "note.text") }
                        }
                    }
                    Section("Shelf · tap to copy") {
                        ForEach(Array(store.workspace.shelf.filter { matches($0.text) }.prefix(20))) { item in
                            Button { store.copy(item.text); showCommand = false } label: { Text(item.text).lineLimit(2) }
                        }
                    }
                    Section("Tasks") {
                        ForEach(Array(store.workspace.tasks.filter { matches($0.title) }.prefix(20))) { task in
                            Button { selected = .tasks; showCommand = false } label: { Label(task.title, systemImage: task.done ? "checkmark.circle" : "circle") }
                        }
                    }
                }
                Section("Shortcuts") {
                    ForEach(store.workspace.launchers.filter { matches($0.name) || matches($0.shortcut) }) { launcher in Button(launcher.name) { run(launcher); showCommand = false } }
                }
            }.navigationTitle("Command bar").toolbar { Button("Done") { showCommand = false } }
        }.presentationDetents([.medium, .large])
    }
    private func matches(_ value: String) -> Bool { command.isEmpty || value.localizedCaseInsensitiveContains(command) }
}

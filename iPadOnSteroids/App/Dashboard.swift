// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI
import PhotosUI
import Vision
import UIKit
import UniformTypeIdentifiers

struct WorkspaceDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var workspace: Workspace
    init(workspace: Workspace) { self.workspace = workspace }
    init(configuration: ReadConfiguration) throws {
        workspace = try JSONDecoder().decode(Workspace.self, from: configuration.file.regularFileContents ?? Data())
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try JSONEncoder().encode(workspace))
    }
}

enum Panel: String, CaseIterable, Identifiable {
    case overview = "Workspace", shelf = "Clipboard shelf", notes = "Scratchpad", links = "Clean links", text = "Image to text", launchers = "Launchpad", settings = "Customize"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .shelf: return "clipboard"
        case .notes: return "note.text"
        case .links: return "link"
        case .text: return "text.viewfinder"
        case .launchers: return "bolt.fill"
        case .settings: return "slider.horizontal.3"
        }
    }
}

struct Dashboard: View {
    @EnvironmentObject private var store: Store
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("accent") private var accent = "Mint"
    @AppStorage("appearance") private var appearance = "Dark"
    @AppStorage("showIsland") private var showIsland = true
    @AppStorage("showTelemetry") private var showTelemetry = true
    @AppStorage("keepAwake") private var keepAwake = false
    @State private var selected: Panel? = .overview
    @State private var command = ""
    @State private var showCommand = false
    @State private var filter = ""
    @State private var linkInput = ""
    @State private var cleaned = ""
    @State private var photo: PhotosPickerItem?
    @State private var recognized = ""
    @State private var recognizing = false
    @State private var shortcutName = ""
    @State private var displayName = ""
    @State private var focusMinutes = 25
    @State private var exporting = false
    @State private var importing = false
    @State private var confirmClear = false
    @State private var confirmImport = false
    @State private var pendingWorkspace: Workspace?
    private var tint: Color { accent == "Mint" ? .mint : accent == "Purple" ? .purple : .orange }

    var body: some View {
        NavigationSplitView {
            List(Panel.allCases, selection: $selected) { panel in Label(panel.rawValue, systemImage: panel.icon).tag(panel) }
                .navigationTitle("iPad on Steroids")
                .safeAreaInset(edge: .bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("YOUR WORKSPACE, SUPERCHARGED").font(.caption2.bold())
                        Text("Local-first · Made for iPad").font(.caption).foregroundStyle(.secondary)
                    }.padding()
                }
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if showIsland { island }
                    if let error = store.persistenceError { Text(error).foregroundStyle(.red) }
                    if !store.message.isEmpty { Text(store.message).font(.callout).foregroundStyle(tint).accessibilityAddTraits(.updatesFrequently) }
                    content
                }.padding(28).frame(maxWidth: 1100, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle((selected ?? .overview).rawValue)
            .toolbar {
                Button { showCommand = true } label: { Label("Command bar", systemImage: "command") }.keyboardShortcut("k", modifiers: .command)
            }
        }
        .tint(tint)
        .preferredColorScheme(appearance == "System" ? nil : appearance == "Dark" ? .dark : .light)
        .sheet(isPresented: $showCommand) { commandBar }
        .fileExporter(isPresented: $exporting, document: WorkspaceDocument(workspace: store.workspace), contentType: .json, defaultFilename: "iPad-on-Steroids-workspace") { result in
            if case .failure(let error) = result { store.message = error.localizedDescription }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                guard url.startAccessingSecurityScopedResource() else { throw CocoaError(.fileReadNoPermission) }
                defer { url.stopAccessingSecurityScopedResource() }
                pendingWorkspace = try JSONDecoder().decode(Workspace.self, from: Data(contentsOf: url))
                confirmImport = true
            } catch { store.message = "Import failed: \(error.localizedDescription)" }
        }
        .confirmationDialog("Replace your notes, shelf and launchers with this backup?", isPresented: $confirmImport, titleVisibility: .visible) {
            Button("Replace workspace", role: .destructive) {
                if let workspace = pendingWorkspace { store.workspace = workspace; store.message = "Workspace imported." }
                pendingWorkspace = nil
            }
            Button("Cancel", role: .cancel) { pendingWorkspace = nil }
        }
        .confirmationDialog("Delete all saved clipboard items?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Delete shelf", role: .destructive) { store.workspace.shelf.removeAll() }
        }
        .onChange(of: photo) { _, item in
            Task { await recognize(item) }
        }
        .onChange(of: keepAwake) { _, _ in updateIdleTimer() }
        .onChange(of: scenePhase) { _, phase in
            updateIdleTimer()
            if phase == .active { store.refresh() }
        }
        .onAppear { updateIdleTimer() }
    }
    private func updateIdleTimer() { UIDevice.current.isIdleTimerDisabled = keepAwake && scenePhase == .active }

    private var island: some View {
        HStack(spacing: 16) {
            Image(systemName: store.deadline == nil ? "bolt.fill" : "timer").foregroundStyle(tint)
            VStack(alignment: .leading) {
                Text(store.deadline == nil ? "Ready for your next idea" : "Focus session").font(.caption).foregroundStyle(.secondary)
                Text(store.deadline == nil ? "Supercharge your workspace" : store.timeLabel).font(.headline.monospacedDigit())
            }
            Spacer()
            Button { selected = .notes } label: { Image(systemName: "square.and.pencil") }.accessibilityLabel("Open scratchpad")
            Button { showCommand = true } label: { Image(systemName: "command") }.accessibilityLabel("Open command bar")
        }
        .padding(20).background(.black.opacity(0.9), in: Capsule()).foregroundStyle(.white)
        .frame(maxWidth: 660).frame(maxWidth: .infinity)
    }
    @ViewBuilder private var content: some View {
        switch selected ?? .overview {
        case .overview: overview
        case .shelf: shelf
        case .notes: notes
        case .links: links
        case .text: imageText
        case .launchers: launchers
        case .settings: settings
        }
    }
    private var overview: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("More flow. Less friction.").font(.largeTitle.bold())
            Text("A personal control room for your ideas, tools and focus.").foregroundStyle(.secondary)
            if showTelemetry {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 16) {
                    metric("Battery", value: store.battery < 0 ? "Unavailable" : "\(Int(store.battery * 100))%", icon: "battery.100percent")
                    metric("Thermal state", value: store.thermal, icon: "thermometer.medium")
                    metric("Available storage", value: store.storage, icon: "internaldrive")
                }
            }
            card("Focus studio", icon: "timer") {
                Text(store.deadline == nil ? "Make room for deep work." : store.timeLabel).font(.title.monospacedDigit())
                Picker("Session length", selection: $focusMinutes) {
                    Text("15 min").tag(15); Text("25 min").tag(25); Text("50 min").tag(50)
                }.pickerStyle(.segmented)
                HStack {
                    Button(store.deadline == nil ? "Start focus" : "Restart focus") { store.startFocus(minutes: focusMinutes) }.buttonStyle(.borderedProminent)
                    if store.deadline != nil { Button("Stop", role: .destructive) { store.stopFocus() }.buttonStyle(.bordered) }
                }
                Text("The island stays inside this app. Completion notifications depend on your notification settings.").font(.caption).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240))], spacing: 16) {
                ForEach([Panel.shelf, .notes, .links, .text, .launchers]) { panel in
                    Button { selected = panel } label: {
                        HStack { Label(panel.rawValue, systemImage: panel.icon); Spacer(); Image(systemName: "arrow.up.right") }.padding(22).frame(maxWidth: .infinity).background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain)
                }
            }
        }
    }
    private func metric(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).foregroundStyle(.secondary)
            Text(value).font(.title2.bold())
        }.frame(maxWidth: .infinity, alignment: .leading).padding(22).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
    private func card<C: View>(_ title: String, icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon).font(.headline)
            content()
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
    private var shelf: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                PasteButton(payloadType: String.self) { strings in strings.forEach { store.capture($0) } }
                Spacer()
                Button("Clear shelf", role: .destructive) { confirmClear = true }.disabled(store.workspace.shelf.isEmpty)
            }
            Text("Tap Paste to save text or links. History is saved on this iPad; clipboard access is always explicit.").foregroundStyle(.secondary)
            TextField("Search saved items", text: $filter).textFieldStyle(.roundedBorder)
            if store.workspace.shelf.isEmpty { ContentUnavailableView("Your shelf is ready", systemImage: "clipboard", description: Text("Copy some text, then tap Paste here.")) }
            ForEach(store.workspace.shelf.filter { filter.isEmpty || $0.text.localizedCaseInsensitiveContains(filter) }.sorted { $0.pinned && !$1.pinned }) { item in
                card(item.pinned ? "Pinned" : item.date.formatted(date: .abbreviated, time: .shortened), icon: "doc.on.clipboard") {
                    Text(item.text).lineLimit(8).textSelection(.enabled)
                    HStack {
                        Button("Copy") { store.copy(item.text) }
                        ShareLink(item: item.text)
                        Button(item.pinned ? "Unpin" : "Pin") {
                            if let index = store.workspace.shelf.firstIndex(where: { $0.id == item.id }) { store.workspace.shelf[index].pinned.toggle() }
                        }
                        Spacer()
                        Button("Delete", role: .destructive) { store.workspace.shelf.removeAll { $0.id == item.id } }
                    }.buttonStyle(.bordered)
                }
            }
        }
    }
    private var notes: some View {
        card("Scratchpad · autosaved", icon: "note.text") {
            TextEditor(text: $store.workspace.note).frame(minHeight: 400).scrollContentBackground(.hidden)
            HStack { Button("Save to shelf") { store.capture(store.workspace.note) }; ShareLink(item: store.workspace.note) }.buttonStyle(.bordered)
        }
    }
    private var links: some View {
        card("Keep the link. Lose the trackers.", icon: "link") {
            TextField("https://example.com/?utm_source=…", text: $linkInput).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
            Button("Clean URL") {
                if let result = LinkCleaner.clean(linkInput) { cleaned = result }
                else { cleaned = ""; store.message = "Enter a valid http or https link." }
            }.buttonStyle(.borderedProminent)
            if !cleaned.isEmpty {
                Text(cleaned).textSelection(.enabled)
                HStack { Button("Copy clean link") { store.copy(cleaned) }; Button("Save to shelf") { store.capture(cleaned) }; ShareLink(item: cleaned) }.buttonStyle(.bordered)
            }
            Text("Removes known tracking parameters and utm_ fields. Other query parameters stay intact; removing tracking fields can invalidate signed links.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private var imageText: some View {
        card("Offline image text recognition", icon: "text.viewfinder") {
            PhotosPicker(selection: $photo, matching: .images) { Label("Choose a screenshot or photo", systemImage: "photo") }.buttonStyle(.borderedProminent).disabled(recognizing)
            if recognizing { ProgressView("Reading text on this iPad…") }
            TextEditor(text: $recognized).frame(minHeight: 280).scrollContentBackground(.hidden)
            HStack { Button("Copy text") { store.copy(recognized) }; Button("Save to shelf") { store.capture(recognized) }; ShareLink(item: recognized) }.buttonStyle(.bordered).disabled(recognized.isEmpty)
            Text("Choose a screenshot captured with iPadOS. This app cannot read the contents of other apps directly.").font(.caption).foregroundStyle(.secondary)
        }
    }
    @MainActor private func recognize(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        recognizing = true
        defer { recognizing = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadCorruptFile) }
            let output = try await Task.detached(priority: .userInitiated) {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                try VNImageRequestHandler(data: data).perform([request])
                return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            }.value
            recognized = output
            if output.isEmpty { store.message = "No text found in this image." }
        } catch { store.message = "Could not read this image: \(error.localizedDescription)" }
    }
    private var launchers: some View {
        VStack(alignment: .leading, spacing: 16) {
            card("Your Shortcuts, one tap away", icon: "bolt.fill") {
                TextField("Tile name", text: $displayName).textFieldStyle(.roundedBorder)
                TextField("Exact name in the Shortcuts app", text: $shortcutName).textFieldStyle(.roundedBorder)
                Button("Add launcher") {
                    let shortcut = shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !shortcut.isEmpty, !name.isEmpty else { return }
                    store.workspace.launchers.append(Launcher(name: name, shortcut: shortcut))
                    shortcutName = ""; displayName = ""
                }.buttonStyle(.borderedProminent).disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || shortcutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("Create the shortcut in Apple Shortcuts first. Actions such as Set Focus, Set Brightness and Open App run through Shortcuts and may switch apps or ask for permission.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(store.workspace.launchers) { launcher in
                HStack {
                    Button { if let url = ShortcutLink.url(for: launcher.shortcut) { openURL(url) } } label: { Label(launcher.name, systemImage: "bolt.fill") }.buttonStyle(.borderedProminent)
                    Text(launcher.shortcut).foregroundStyle(.secondary)
                    Spacer()
                    Button("Remove", role: .destructive) { store.workspace.launchers.removeAll { $0.id == launcher.id } }
                }.padding(18).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }
    private var settings: some View {
        VStack(spacing: 18) {
            card("Make it yours", icon: "slider.horizontal.3") {
                Picker("Accent", selection: $accent) { ForEach(["Mint", "Purple", "Orange"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
                Picker("Appearance", selection: $appearance) { ForEach(["System", "Dark", "Light"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
                Toggle("Show in-app island", isOn: $showIsland)
                Toggle("Show device readouts", isOn: $showTelemetry)
                Toggle("Keep screen awake while this app is active", isOn: $keepAwake)
            }
            card("Your data", icon: "externaldrive") {
                HStack { Button("Export backup") { exporting = true }; Button("Import backup") { importing = true } }.buttonStyle(.bordered).disabled(store.persistenceError != nil)
                Text("Backups contain your notes, saved clipboard items and launcher names as readable JSON. Appearance settings and timers are stored separately. There is no account, analytics or cloud sync; exported files use the destination you choose.").font(.caption).foregroundStyle(.secondary)
            }
            card("iPadOS boundaries", icon: "info.circle") {
                Text("The island appears inside this app. iPadOS does not expose a public API for a floating island above other apps, per-app audio mixing, global clipboard monitoring, system-wide key remapping, other apps’ CPU usage, fan control or a system cache cleaner. M1 iPads have no fan. Use Stage Manager or your iPadOS windowing controls for multitasking.")
                Text("Independent app inspired by Vorssaint’s utility categories. No Vorssaint branding or macOS code is included.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var commandBar: some View {
        NavigationStack {
            List {
                TextField("Find a tool or shortcut", text: $command)
                ForEach(Panel.allCases.filter { command.isEmpty || $0.rawValue.localizedCaseInsensitiveContains(command) }) { panel in
                    Button { selected = panel; showCommand = false } label: { Label(panel.rawValue, systemImage: panel.icon) }
                }
                ForEach(store.workspace.launchers.filter { command.isEmpty || $0.name.localizedCaseInsensitiveContains(command) }) { launcher in
                    Button(launcher.name) { if let url = ShortcutLink.url(for: launcher.shortcut) { openURL(url) }; showCommand = false }
                }
            }.navigationTitle("Command bar").toolbar { Button("Done") { showCommand = false } }
        }.presentationDetents([.medium, .large])
    }
}

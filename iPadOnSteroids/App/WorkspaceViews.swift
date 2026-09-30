// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

struct FocusStudio: View {
    @EnvironmentObject private var store: Store
    @State private var minutes = 25
    var body: some View {
        ToolCard(title: "Focus studio", icon: "timer") {
            if let session = store.focus {
                FocusTimeline(session: session) { date in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(FloatingIsland.clock(session.remaining(at: date))).font(.system(.largeTitle, design: .rounded).monospacedDigit()).contentTransition(.numericText())
                        ProgressView(value: session.progress(at: date))
                    }
                }
            } else { Text("Make room for deep work.").font(.title2.bold()) }
            Stepper("\(minutes) minute session", value: $minutes, in: 1...180)
            ViewThatFits {
                HStack { controls }
                VStack(alignment: .leading) { controls }
            }
            Text("Completion notifications need your permission. Your timer keeps its end time when you leave the app.").font(.caption).foregroundStyle(.secondary)
        }
    }
    @ViewBuilder private var controls: some View {
        Button(store.focus == nil ? "Start focus" : "Restart") { store.startFocus(minutes: minutes) }.buttonStyle(.borderedProminent)
        if store.focus != nil {
            Button(store.isPaused ? "Resume" : "Pause") { store.isPaused ? store.resumeFocus() : store.pauseFocus() }.buttonStyle(.bordered)
            Button("End", role: .destructive) { store.stopFocus() }.buttonStyle(.bordered)
        }
    }
}
struct NotesView: View {
    @EnvironmentObject private var store: Store
    @Binding var selectedID: UUID?
    @State private var deleteID: UUID?
    @State private var confirmDelete = false
    private var index: Int? { store.workspace.notes.firstIndex { $0.id == selectedID } }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("\(store.workspace.notes.count) notes").foregroundStyle(.secondary)
                Spacer()
                Button { addNote() } label: { Label("New note", systemImage: "plus") }.buttonStyle(.borderedProminent).keyboardShortcut("n", modifiers: [.command, .shift]).disabled(store.workspace.notes.count >= 500)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(store.workspace.notes) { note in
                        Button { selectedID = note.id } label: {
                            Label(note.title.isEmpty ? "Untitled" : note.title, systemImage: "note.text").lineLimit(1).padding(.vertical, 8).padding(.horizontal, 14)
                                .background(note.id == selectedID ? Color.accentColor.opacity(0.18) : Color.clear, in: Capsule())
                        }.buttonStyle(.plain).contextMenu {
                            Button("Delete note", role: .destructive) { deleteID = note.id; confirmDelete = true }
                        }
                    }
                }
            }
            if let i = index {
                ToolCard(title: "Editor", icon: "square.and.pencil") {
                    TextField("Note title", text: noteBinding(store.workspace.notes[i].id, title: true)).font(.title2.bold())
                    TextEditor(text: noteBinding(store.workspace.notes[i].id, title: false)).frame(minHeight: 320).scrollContentBackground(.hidden).accessibilityLabel("Note text").accessibilityIdentifier("note-body")
                    ViewThatFits {
                        HStack { noteActions(i) }
                        VStack(alignment: .leading) { noteActions(i) }
                    }
                    Text(store.saving ? "Saving…" : store.saveError == nil ? "Saved locally" : "Save needs attention").font(.caption).foregroundStyle(.secondary)
                }
            } else { ContentUnavailableView("Room for a new idea", systemImage: "note.text", description: Text("Create a note to begin.")) }
        }
        .onAppear { if index == nil { selectedID = store.workspace.notes.first?.id } }
        .onChange(of: store.workspace.notes.map(\.id)) { _, ids in if !ids.contains(selectedID ?? UUID()) { selectedID = ids.first } }
        .confirmationDialog("Delete this note?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete note", role: .destructive) { store.workspace.notes.removeAll { $0.id == deleteID } }
        }
    }
    @ViewBuilder private func noteActions(_ i: Int) -> some View {
        Button("Save to shelf") { store.capture(store.workspace.notes[i].text) }.buttonStyle(.bordered)
        ShareLink(item: store.workspace.notes[i].text).buttonStyle(.bordered)
        Button("Delete", role: .destructive) { deleteID = store.workspace.notes[i].id; confirmDelete = true }.buttonStyle(.bordered)
    }
    private func noteBinding(_ id: UUID, title: Bool) -> Binding<String> {
        Binding(get: {
            guard let note = store.workspace.notes.first(where: { $0.id == id }) else { return "" }
            return title ? note.title : note.text
        }, set: { value in
            guard let i = store.workspace.notes.firstIndex(where: { $0.id == id }) else { return }
            if title { store.workspace.notes[i].title = String(value.prefix(200)) }
            else { store.workspace.notes[i].text = String(value.prefix(BackupCodec.maximumText)) }
        })
    }
    private func addNote() {
        let note = NoteItem(); store.workspace.notes.append(note); selectedID = note.id
    }
}
struct TasksView: View {
    @EnvironmentObject private var store: Store
    @State private var title = ""
    @State private var showCompleted = true
    @State private var clearCompleted = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ToolCard(title: "Your next small step", icon: "checklist") {
                TextField("Add a task", text: $title).accessibilityIdentifier("task-title").textFieldStyle(.roundedBorder).onSubmit(add)
                Button("Add task", action: add).buttonStyle(.borderedProminent).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.count > 500 || store.workspace.tasks.count >= 500)
                Toggle("Show completed tasks", isOn: $showCompleted)
            }
            if store.workspace.tasks.isEmpty { ContentUnavailableView("A clear starting point", systemImage: "checkmark.circle", description: Text("Add a task, then start a focus session.")) }
            LazyVStack(spacing: 12) {
                ForEach(store.workspace.tasks.filter { showCompleted || !$0.done }) { task in
                    HStack {
                        Button { if let i = store.workspace.tasks.firstIndex(where: { $0.id == task.id }) { store.workspace.tasks[i].done.toggle() } } label: {
                            Image(systemName: task.done ? "checkmark.circle.fill" : "circle").font(.title2).frame(width: 44, height: 44)
                        }.accessibilityLabel(task.done ? "Mark task incomplete" : "Complete task")
                        Text(task.title).strikethrough(task.done).foregroundStyle(task.done ? .secondary : .primary)
                        Spacer()
                        Button { store.workspace.tasks.removeAll { $0.id == task.id } } label: { Image(systemName: "trash").frame(width: 44, height: 44) }.accessibilityLabel("Delete task")
                    }.padding(14).glassSurface(corner: 20)
                }
            }
            if store.workspace.tasks.contains(where: \.done) { Button("Clear completed", role: .destructive) { clearCompleted = true } }
        }.confirmationDialog("Delete completed tasks?", isPresented: $clearCompleted, titleVisibility: .visible) {
            Button("Delete completed", role: .destructive) { store.workspace.tasks.removeAll { $0.done } }
        }
    }
    private func add() {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 500, store.workspace.tasks.count < 500 else { return }
        store.workspace.tasks.append(TaskItem(title: value)); title = ""
    }
}

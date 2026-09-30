// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

enum Panel: String, CaseIterable, Identifiable, Codable {
    case overview = "Workspace", shelf = "Clipboard shelf", notes = "Notes", tasks = "Tasks", links = "Clean links", text = "Image to text", launchers = "Launchpad", settings = "Customize"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .shelf: return "clipboard"
        case .notes: return "note.text"
        case .tasks: return "checklist"
        case .links: return "link"
        case .text: return "text.viewfinder"
        case .launchers: return "bolt.fill"
        case .settings: return "slider.horizontal.3"
        }
    }
    var detail: String {
        switch self {
        case .overview: return "Your ideas, tools and focus in one place."
        case .shelf: return "Keep the useful bits within reach."
        case .notes: return "Room for the thought you want to keep."
        case .tasks: return "Turn an idea into your next small step."
        case .links: return "Keep the link. Lose the trackers."
        case .text: return "Turn an image into editable text."
        case .launchers: return "Your own routines, one tap away."
        case .settings: return "A workspace that feels like yours."
        }
    }
}
struct GlassSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var opaque
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var scheme
    var corner: CGFloat = 26
    var nativeGlass = false
    func body(content: Content) -> some View {
        surface(content)
            .overlay { RoundedRectangle(cornerRadius: corner).strokeBorder(scheme == .dark ? .white.opacity(0.14) : .black.opacity(0.08), lineWidth: 1).allowsHitTesting(false) }
            .shadow(color: .black.opacity(opaque ? 0 : 0.12), radius: 18, y: 8)
    }
    @ViewBuilder private func surface(_ content: Content) -> some View {
        if opaque || contrast == .increased {
            content.background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: corner))
        } else {
            #if compiler(>=6.2)
            if nativeGlass {
                if #available(iOS 26.0, *) {
                    content.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: corner))
                } else {
                    content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: corner))
                }
            } else {
                content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: corner))
            }
            #else
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: corner))
            #endif
        }
    }
}

extension View {
    func glassSurface(corner: CGFloat = 26, nativeGlass: Bool = false) -> some View { modifier(GlassSurface(corner: corner, nativeGlass: nativeGlass)) }
}
struct ToolCard<Content: View>: View {
    var title: String
    var icon: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(title, systemImage: icon).font(.headline)
            content()
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).glassSurface()
    }
}
struct FloatingIsland: View {
    @EnvironmentObject private var store: Store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var expanded: Bool
    var openNotes: () -> Void
    var openCommands: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: store.focus == nil ? "sparkles" : "timer").foregroundStyle(.tint).font(.title3)
                Button { expanded.toggle() } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.focus == nil ? "Your workspace" : store.isPaused ? "Focus paused" : "Focus session").font(.caption).foregroundStyle(.secondary)
                        if let session = store.focus {
                            FocusTimeline(session: session) { date in
                                Text(Self.clock(session.remaining(at: date))).font(.headline.monospacedDigit())
                            }
                        } else { Text("Ready when you are").font(.headline) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain).accessibilityLabel(expanded ? "Collapse floating island" : "Expand floating island")
                Button(action: openCommands) { Image(systemName: "command").frame(width: 44, height: 44) }.accessibilityLabel("Open command bar")
                Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption).accessibilityHidden(true)
            }
            if expanded {
                if let session = store.focus {
                    FocusTimeline(session: session) { date in ProgressView(value: session.progress(at: date)).accessibilityLabel("Focus progress") }
                    HStack {
                        Button(store.isPaused ? "Resume" : "Pause") { store.isPaused ? store.resumeFocus() : store.pauseFocus() }
                        Button("End", role: .destructive) { store.stopFocus() }
                        Spacer()
                        Button(action: openNotes) { Label("Note", systemImage: "square.and.pencil") }
                    }.buttonStyle(.bordered)
                } else {
                    HStack {
                        Button { store.startFocus(minutes: 25) } label: { Label("Focus 25 min", systemImage: "play.fill") }
                        Spacer()
                        Button(action: openNotes) { Label("Notes", systemImage: "square.and.pencil") }
                    }.buttonStyle(.bordered)
                }
            }
        }
        .padding(18).frame(maxWidth: 550).glassSurface(corner: expanded ? 28 : 36, nativeGlass: true)
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: expanded)
        .padding(.horizontal, 16).padding(.vertical, 8)
    }
    static func clock(_ seconds: TimeInterval) -> String {
        let remaining = max(0, Int(ceil(seconds)))
        return String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }
}

struct SettingsChoice: View {
    let title: String
    let values: [String]
    @Binding var selection: String
    @Environment(\.dynamicTypeSize) private var textSize
    var body: some View {
        if textSize.isAccessibilitySize {
            Picker(title, selection: $selection) { ForEach(values, id: \.self) { Text($0) } }.pickerStyle(.menu)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Picker(title, selection: $selection) { ForEach(values, id: \.self) { Text($0) } }.pickerStyle(.segmented)
            }
        }
    }
}

struct FocusTimeline<Content: View>: View {
    let session: FocusSession
    @ViewBuilder var content: (Date) -> Content
    var body: some View {
        if session.isPaused { content(.now) }
        else { TimelineView(.periodic(from: .now, by: 1)) { context in content(context.date) } }
    }
}

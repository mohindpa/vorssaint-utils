// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

@main struct iPadOnSteroidsApp: App {
    @StateObject private var store: Store
    init() {
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("ui-test-workspace.json")
            try? FileManager.default.removeItem(at: url)
            let defaults = UserDefaults(suiteName: "ui-tests")!
            defaults.removePersistentDomain(forName: "ui-tests")
            _store = StateObject(wrappedValue: Store(file: url, defaults: defaults))
        } else { _store = StateObject(wrappedValue: Store()) }
    }
    var body: some Scene { WindowGroup { Dashboard().environmentObject(store) } }
}

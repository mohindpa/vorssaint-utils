// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

@main struct iPadOnSteroidsApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup {
            Dashboard().environmentObject(store)
        }
    }
}

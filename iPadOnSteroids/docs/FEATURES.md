# Vorssaint to iPad feature mapping

Upstream inspected on September 30, 2026. Its Package.swift targets macOS 14+ and uses macOS-specific system libraries. The changelog's September 29 `3.4.1-beta.1` describes a floating island, multiple displays, lock-screen presentation and calendar countdowns. Those are macOS features, not an iPad implementation to enable with a build flag.

| Upstream feature | iPad implementation / boundary |
| --- | --- |
| Dynamic Island | In-app capsule with focus countdown and quick tool buttons, implemented. No overlay on other apps or lock screen. Widgets and supported Live Activities would require dedicated extensions and OS-specific implementation. |
| Clipboard history | Explicit text/link Paste capture, implemented. Global background monitoring is unavailable. |
| Scratchpad | Autosaved local note and sharing, implemented. Tabs/Markdown preview not included. |
| Command Bar | Find implemented tools and saved Shortcuts; Command-K, implemented. System app/file search and shell scripts not included. |
| Quick tools and personalization | Theme, accent, island/readout visibility and Shortcut tiles, implemented. No system theme replacement. |
| Text from screen | Select screenshot/photo and run offline Vision OCR, implemented. Cannot silently inspect another app. |
| Clean URL | Known tracker removal, copy/share/save, implemented. |
| System monitor | Battery level, thermal state, available storage, implemented. Public APIs do not provide global per-app usage, battery health percentage or Mac SMC temperatures. |
| Keep awake | Foreground idle-timer control, implemented. No background system wake lock. |
| Brightness / Focus / app launch | Through user-created Apple Shortcuts where the system supports the action, implemented as launchers. |
| Window layouts / Dock previews | Use iPadOS multitasking/windowing controls. This app cannot reposition other apps' windows. |
| Per-app audio volume/output | No public general-purpose iPad equivalent. Not implemented. |
| Fan control | M1 iPad Pro is passively cooled; no fan to control. |
| Global key/mouse remapping | No general system-wide public API. App-local shortcuts only. |
| Cache cleaner / uninstaller / Homebrew / port process killer | Sandboxed iPad apps cannot manage other apps' files/processes; not implemented. |
| Capture / media editing / radial menu / custom keyboard | Future app-local features or dedicated extensions; not implemented. |
| Control a Mac from iPad | Would require an authenticated Mac companion plus appropriate Mac permissions. No remote-control server is included. |

The app uses stock public APIs and does not require a jailbreak. A jailbreak/private-API build would be a separate project with version/device-specific feasibility; it is outside this source prototype.

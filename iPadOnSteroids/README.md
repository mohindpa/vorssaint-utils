# iPad on Steroids

An independent native iPad utility workspace inspired by the utility categories in [Vorssaint](https://github.com/vorssaint/vorssaint-utils). Version 0.1 is a source prototype for **iPadOS 17+**, including iPad Pro M1. Open `iPadOnSteroids.xcodeproj` on a Mac with Xcode 15 or later (use a current Xcode that supports your iPadOS version).

## Implemented in the source

- In-app island with focus countdown and quick access to scratchpad and command bar.
- Focus sessions, persisted end times, and permission-based completion notifications.
- Text/link clipboard shelf with explicit Paste, pinning, search, sharing and deletion.
- Autosaved scratchpad and JSON workspace export/import with replacement confirmation.
- URL cleaning that preserves functional query parameters and fragments.
- On-device image text recognition through Vision and the system photo picker.
- User-defined Apple Shortcuts launchers; command bar with Command-K on a keyboard.
- Battery level, thermal state and available storage from public device APIs.
- Accent/theme choices, optional island/readouts and foreground keep-awake.
- Adaptive iPad layout, system controls, selectable text and accessible button labels.

No account, server, analytics, third-party packages or private APIs. Local app storage can be included in device backups according to your device settings. Exported JSON is readable and contains your notes and clipboard items.

## Status

Source and Xcode project are prepared. This Linux authoring environment has no Swift toolchain, Xcode, Apple signing identity or iPad attached. **The app has not been compiled, simulator-tested or device-tested. No signed IPA is supplied.** Structural checks are recorded in `docs/VALIDATION.md`; XCTest coverage is provided for URL cleaning, shortcut encoding and backup round trips and must run on your Mac.

This is a first implementation of the feasible workspace features, not a complete port of the macOS app. Widgets, Live Activities, share extensions, a custom keyboard, media editing and a Mac companion are not implemented. See [feature mapping](docs/FEATURES.md) for the scope and platform constraints.

## Install and test

Follow [INSTALL.md](docs/INSTALL.md). A free Apple Account can install a development build using Xcode; Personal Team provisioning generally expires after seven days. TestFlight requires paid Apple Developer Program membership and App Store Connect setup.

## Project maintenance

The Xcode project is included. If sources change, regenerate it with `python3 scripts/generate_project.py`. No Homebrew/XcodeGen dependency is required. Set your own development team in Xcode after regeneration. `scripts/test-on-mac.sh` runs unit tests on a simulator you select.

## License and attribution

GPL-3.0-or-later; see LICENSE. This implementation was written independently; it contains no Vorssaint application code, logo, icon, bundle identity or copied interface assets. Upstream source inspected: README.md, Package.swift, TRADEMARKS.md, and the recent CHANGELOG.md entries. This app lives under `iPadOnSteroids/` in the user’s fork. Open the Xcode project in this directory; the repository-root Package.swift builds the upstream macOS app.

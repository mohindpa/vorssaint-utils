# iPad on Steroids — v0.2

A native iPad utility workspace with expandable floating controls, local tools and personal Shortcut launchers. Independent app inspired by Vorssaint’s utility categories; no upstream branding or macOS application code is included.

Open **`iPadOnSteroids/iPadOnSteroids.xcodeproj`** from branch `ipad-on-steroids` in `mohindpa/vorssaint-utils`. The repository-root Package.swift belongs to the upstream Mac app. Minimum deployment target: **iPadOS 17**. A newer deployment target alone does not certify iPadOS 27 compatibility.

## What changed

- **Floating controls:** expandable Liquid Glass island (supported SDK/OS) with material/accessibility fallback, timer actions, quick note/command access, and a floating dock with configurable favorites. Controls stay inside this app.
- **Notes:** multiple named notes, safe identity-based editing, local autosave, sharing and shelf capture. Legacy single-note backups migrate automatically.
- **Tasks:** add/complete/delete tasks, filter completed items, confirm bulk clearing and see the next task on the dashboard.
- **Focus:** 1–180-minute sessions, pause/resume, persisted deadlines/paused time and optional completion notifications. Timers stop ticking while paused, idle or inactive.
- **Command bar:** Command-K; find tools, notes, shelf text, tasks and Shortcuts. Calculate with `=42 * 3`, convert supported units with `10 cm to in` or `32 f to c`, and convert hex colors such as `#62E3B5` to RGB. Tap a result to copy it.
- **Clipboard shelf:** explicit Paste capture, pinned-only filtering, search, sharing and delete controls. Recapture preserves identity/pins. History retains up to 100 unpinned items plus pinned items within backup limits.
- **URL cleaner:** removes known tracking parameters while preserving original encoding of functional query values, repeated parameters and fragments.
- **Image text:** selected-photo Vision OCR, canceled when the selection/view changes, 40 MB input guard and 4096-pixel thumbnail decoding to bound decoded-image memory. OCR output needs review.
- **Shortcuts:** named tiles launch existing Apple Shortcuts and report failure to open the app. The user creates and authorizes each Shortcut.
- **Customization:** system/light/dark appearance, three accents, island/readout visibility, dock favorites and foreground-only keep-awake. Materials respect Reduce Transparency and increased contrast; expansion respects Reduce Motion.
- **Storage:** 350 ms debounced autosave; serial revision-aware writes prevent stale snapshots replacing newer data. Visible save errors, retry/export actions, bounded/validated JSON backups, and an explicit recovery path preserving unreadable originals.

No account, app server, telemetry or private APIs. Device backups can include local app data according to device settings. Exported JSON is readable and may contain private content. iCloud-backed Photos selections and user-run Shortcuts can involve services outside this app.

## Validation and the 9.5 target

A native Mac CI workflow is committed at `.github/workflows/ipad.yml`. It records Xcode/SDK versions, runs core tests, exercises native app/unit/UI tests on baseline and Xcode 27 iPad simulators and builds an optimized unsigned device binary. See [VALIDATION.md](docs/VALIDATION.md) for observed results and [QUALITY.md](docs/QUALITY.md) for the evidence required to meet the **9.5/10 goal**.

Final app source `2d12d48989ed97cc18aed0d37371da8b10937e5b` passed [native validation](https://github.com/mohindpa/vorssaint-utils/actions/runs/36787477441) on Xcode 16.4/iOS 18.5 and Xcode 27/iOS 27: 26 native unit/OCR tests and four UI tests per job, plus overlapping core tests and optimized unsigned device builds.

A passing simulator run cannot establish physical-device battery usage, every accessibility flow or compatibility on your physical M1. Those remain explicit release gates. No signed IPA or TestFlight distribution is supplied.

## Run on your M1 iPad

Follow [INSTALL.md](docs/INSTALL.md). Use an Xcode version that supports your installed iPadOS. Select your Apple Account/team, connect the iPad, enable Developer Mode and press Command-R. Free Personal Team builds generally need renewal after seven days.

On a Mac, run core tests with `cd iPadOnSteroids && swift test`. For native tests, choose an iPad simulator and run `SIMULATOR_ID='<UUID>' bash scripts/test-on-mac.sh`, or use Command-U in Xcode. Native UI tests use a temporary workspace and a separate timer-defaults suite, preserving normal workspace files.

If sources change, regenerate the project with `python3 scripts/generate_project.py`; check it with `python3 scripts/check_project.py`. No XcodeGen or third-party runtime package is required. Select your development team again after regeneration if needed.

## License

GPL-3.0-or-later; see LICENSE. This is an independent app, not an official Vorssaint release or a full port. Use iPadOS for system windowing; no app-local implementation can promise an unrestricted global overlay, per-app mixer or other-app cache cleaner through general public APIs.

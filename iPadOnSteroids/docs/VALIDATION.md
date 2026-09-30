# v0.2 validation record

September 30, 2026. Acceptance target: 9.5/10; see QUALITY.md. Native execution used GitHub-hosted Macs; authoring used Linux.

## Passed native validation

Tested source: `134e6904f7105715a96b7de1016cfc29a437f667`.
Run: https://github.com/mohindpa/vorssaint-utils/actions/runs/36785797703
Both matrix jobs completed successfully.

| Check | Xcode 16.4 / iOS 18.5 | Xcode 27.0 / iOS 27.0 |
| --- | --- | --- |
| Foundation core tests | 21 passed | 21 passed |
| Simulator app/test compilation | Passed | Passed |
| Optimized unsigned device build | Passed | Passed |
| Native unit tests, including real Vision OCR | 26 passed | 26 passed |
| Native interaction/accessibility-description tests | 4 passed | 4 passed |

The core suite is also included in the native unit suite; do not describe these as 51 distinct tests. Xcode 27 logged build 27A266a and Swift 6.4. Simulator operation is verified; signed installation on an M1 device is not.

Tests cover backup/migration/identity validation, URL encoding, calculations/conversions, focus logic, disk persistence/recovery, a rendered text-image OCR fixture, bad OCR inputs, launch/floating actions, notes-to-task interaction, selected accessibility description/trait checks and landscape window geometry. A passing description/trait audit is not a full VoiceOver or visual review.

## Test-and-fix findings

Earlier native runs exposed an oversized SwiftUI compiler expression and an incorrect idle-timer API; these were corrected. The interaction suite exposed retained command searches; opening the palette now clears its query. Screenshot inspection exposed narrow cards at maximum Dynamic Type; those now use one column and the dock uses accessible icon buttons.

Final screenshot inspection still exposed sidebar footer overlap at maximum text size. Commit `2d12d48989ed97cc18aed0d37371da8b10937e5b` hides that decorative footer at accessibility sizes. Follow-up run https://github.com/mohindpa/vorssaint-utils/actions/runs/36787477441 completed successfully on both toolchains: 21 core tests, 26 native unit/OCR tests, four UI tests and both simulator/device builds passed per job. The final largest-text screenshot was inspected and the footer overlap is gone. This is the final tested app-source revision; subsequent documentation changes do not alter it.

The exported landscape app screenshot has a black area and a cropped viewport despite the test observing a landscape window. Treat that screenshot as inconclusive; it does not establish that the landscape visual layout is correct. Review landscape on a physical device or a directly observed simulator.

## Passed structural checks

Seven app Swift sources, two unit-test sources, one UI-test source; 59 unique project objects, no dangling references. Shared scheme XML and privacy manifest parse. iPad-only target, minimum iPadOS 17. Python scripts and Bash syntax checks passed.

## Evidence still required for 9.5 acceptance

Signed M1 installation; cold/warm launch, typing/scrolling responsiveness, idle energy and large-image OCR memory/latency measured with Instruments; complete VoiceOver/keyboard/contrast/motion review; narrow-window/landscape review; photo-picker/iCloud integration; real Shortcut execution; background notification behavior. No signed IPA or TestFlight release is supplied.

**Status: improved, with passing native compatibility tests; 9.5 overall is not yet demonstrated.**

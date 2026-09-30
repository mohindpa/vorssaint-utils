# v0.2 validation record

September 30, 2026. Acceptance target: 9.5/10; see QUALITY.md. Source authoring is in Linux, with native execution attempted through GitHub Actions on a hosted Mac.

## Passed structural checks

- Generated Xcode project includes seven app sources, two unit-test sources and one UI-test source.
- 59 unique project objects, all source files included, no dangling references.
- Shared scheme XML and privacy manifest parse; iPad-only target and iPadOS 17 minimum are configured.
- Python project scripts compile and the Mac test script passes Bash syntax checking.
- Native CI YAML parses and defines toolchain recording, behavior tests, simulator unit/UI tests and an optimized unsigned device build.

## Native runs

Initial upgrade commit: 5e55b9bf279669e6455437cc34b9a36db3000e87.

- https://github.com/mohindpa/vorssaint-utils/actions/runs/36781895355
- Core behavior test step observed successful; native simulator build/test step was still running when this record was first written.

Additional refinements include task/note simulator checks, indexed-note safety, multi-window activity coordination and calculator/conversion tests. Their final CI result must be recorded after execution. Do not treat source inclusion as a passing runtime test.

## Still requires physical evidence

Signed installation, M1 iPad responsiveness/energy measurements, full VoiceOver/Dynamic Type review, photo-picker/iCloud integration, real Shortcut execution and any specific iPadOS 27 compatibility claim. No signed IPA or TestFlight release is included.

## Confirmed baseline results before the latest fixes

Run https://github.com/mohindpa/vorssaint-utils/actions/runs/36783492660, macos-15 job:

- Xcode 16.4 compiled the app/test targets with the iOS 18.5 SDK.
- All 24 native unit tests passed, including disk persistence, recovery, backup validation and utility behavior.
- Launch/floating controls, landscape and accessibility-description/trait UI tests passed.
- Notes-to-tasks interaction failed because the command bar retained its earlier search; this is corrected in the next revision.
- Actual screenshots were inspected. The largest Dynamic Type layout exposed narrow device cards; the next revision uses one column and an icon dock at accessibility sizes.
- Native Liquid Glass is compiled only on the newer SDK path. Core tests on Xcode 27 passed; full app runtime validation on that SDK is still pending.

The next CI revision separates compilation, release/device builds, native unit/OCR tests and interaction tests with bounded phase timeouts. Screenshot export skips incomplete result bundles. An actual image fixture tests Vision recognition, rather than only checking that OCR code exists.

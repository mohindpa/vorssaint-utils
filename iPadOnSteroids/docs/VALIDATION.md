# v0.2 validation record

September 30, 2026. Acceptance target: 9.5/10; see QUALITY.md. Source authoring is in Linux, with native execution attempted through GitHub Actions on a hosted Mac.

## Passed structural checks

- Generated Xcode project includes seven app sources, two unit-test sources and one UI-test source.
- 57 unique project objects, all source files included, no dangling references.
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

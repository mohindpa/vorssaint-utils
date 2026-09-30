# Acceptance target: at least 9.5/10

This is a quality target, not a score awarded for writing more code. The rubric applies to the supported app-local utility product, not to unavailable system-wide iPadOS capabilities. A final score requires evidence for each dimension; untested dimensions remain unscored. No amount of polish overrides a data-loss, crash or compatibility blocker.

| Dimension | Weight | Evidence needed for full credit |
| --- | ---: | --- |
| Functional workflows | 20 | Notes/tasks/shelf/links/OCR/Shortcuts/focus/backups complete end-to-end; error and cancellation flows work. |
| Visual usability | 20 | Actual screenshots and interaction review at portrait, landscape and narrow window widths; readable text, no clipping, understandable empty states. |
| Reliability/data integrity | 20 | Passing migration, backup validation, stale-write, persistence and cancellation tests; no data loss after relaunch/background/recovery. |
| Performance/energy | 15 | Release build; device measurements for launch, typing, scrolling and large-image OCR; no idle timer work or sustained unnecessary CPU load. |
| Accessibility | 10 | VoiceOver flow review, largest Dynamic Type, increased contrast, Reduce Motion/Transparency and keyboard navigation. |
| Compatibility/installability | 15 | Native build/unit/UI tests on available SDKs; signed install and operation on M1 iPad and the claimed target OS. |

**Acceptance:** at least 95/100 on documented reviews and measurements, all critical release gates passed. If evidence is missing, do not substitute an invented numerical score. Simulator metrics are useful but do not certify M1-device energy performance.

## Concrete release gates

- No outstanding native compiler errors or failed meaningful tests.
- No crashes or data loss in repeated save/restore, background/resume and malformed-backup scenarios.
- Floating dock, island, notes editor and task board remain usable at the largest accessibility text size and in a narrow iPad window.
- OCR handles cancellation, a large selected image and an unreadable image without blocking input or replacing a newer result.
- Timer pause/resume, restart, stop and permission denial do not create an obsolete completion notification.
- Export/import preserves all model identities and pin/completion states; unreadable originals are recoverable.
- On an M1 iPad, record cold/warm launch, UI responsiveness, idle energy and OCR peak memory/latency using Xcode Instruments. Set targets from those measurements and review any outliers before release.
- Record exact iPadOS and Xcode versions. iPadOS 27 simulator tests and device compilation have passed; physical M1 operation on that version still requires validation.

## Current evidence categories

Implemented source changes and structural validation are recorded in README/VALIDATION. Native CI results must be cited by run URL and commit. Physical-device, VoiceOver and target-OS evidence require access to the relevant hardware/runtime and remain separate from source review.

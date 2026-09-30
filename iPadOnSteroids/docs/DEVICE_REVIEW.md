# M1 device acceptance record

Goal: at least 95/100 using QUALITY.md. Fill in observed results; blank fields mean unverified. Do not score from implementation claims.

Device: iPad Pro M1 / size: ____ / iPadOS version and build: ____
Xcode version: ____ / source revision: ____ / date: ____
Installation: development team selected, signed device build installed: ____

## Functional and reliability checks

- Notes: create three, edit rapidly, switch/delete, background immediately, force quit and relaunch; verify latest content and surviving identities: ____
- Tasks: add/complete/filter/delete; verify after relaunch: ____
- Shelf: explicit Paste, recapture a pinned item, search/share/copy/delete; confirm pin and identity persist: ____
- Backup: export/import complete workspace; reject malformed, unrelated and future-version files without changing current data: ____
- Focus: one-minute run, pause/resume, background/foreground, stop/restart, deny notification permission; confirm no obsolete reminders: ____
- OCR: readable screenshot, large camera photo, corrupt image, cancel/reselect quickly, iCloud-backed photo; compare recognized text and ensure input remains responsive: ____
- Shortcuts: launch an existing Shortcut and a missing name; check real system prompts and failure handling: ____

## Visual and accessibility review

Review portrait, landscape and narrow Stage Manager windows. Verify island, dock overflow, editor, keyboard and every task/backup action are reachable without overlapping controls: ____
Largest accessibility text: ____ / VoiceOver navigation and announced controls: ____
Reduce Motion: ____ / Reduce Transparency and increased contrast: ____
External keyboard, Command-K and dismissal/navigation: ____
Check actual landscape display; CI exported landscape screenshots were inconclusive.

## Instruments measurements (Release configuration)

Use Xcode Product → Profile. Measure on the physical M1; do not substitute simulator results.

| Measurement | Conditions | Observed result | Acceptance review |
| --- | --- | --- | --- |
| Cold and warm launch | At least five launches each | ____ | ____ |
| Typing and scrolling | Notes, long shelf and tasks; Animation Hitches | ____ | ____ |
| Idle CPU/energy | Five minutes foreground without timer; Time Profiler/Energy instrument | ____ | ____ |
| Active/paused focus | Compare active countdown to paused and background | ____ | ____ |
| OCR latency/peak memory | Screenshot and full camera image; Allocations/Time Profiler | ____ | ____ |
| Cancellation | Reselect/cancel during large OCR | ____ | ____ |

Record crashes, hangs, save errors, thermal changes and outliers. Set numerical budgets from these device measurements and the product expectations, then rerun failures after correction.

## Scoring

Functional workflows: ____ /20
Visual usability: ____ /20
Reliability/data integrity: ____ /20
Performance/energy: ____ /15
Accessibility: ____ /10
Compatibility/installability: ____ /15
Total: ____ /100

Acceptance requires at least 95 with all critical gates passed. Missing evidence leaves the overall rating unverified. Include exact reproductions and screenshots for any failed gate before fixing and repeating it.

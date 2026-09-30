# v0.2 feature scope

| Tool | Implemented source behavior | Boundary |
| --- | --- | --- |
| Floating island | Expand/collapse material capsule, timer progress/actions, note and command buttons | Inside the app; no system-wide or lock-screen island |
| Floating dock | Configurable favorite tools, horizontal overflow, current-tool highlight | App navigation only |
| Notes | Multiple named notes, autosave, share, capture to shelf, confirmed deletion | Plain text; no Markdown renderer or automatic sync |
| Tasks | Add, complete, delete, hide completed, confirmed bulk clear | Local tasks; no Reminders integration |
| Focus | Custom 1–180 min, pause/resume, persisted state, optional notification | No background wake lock; notification delivery depends on iPadOS |
| Clipboard | Explicit text/link Paste, history, pinning, search and sharing | No background monitoring or image/file clipboard history |
| Clean links | Remove known tracking fields, preserve functional encoding | Signed links can be invalidated by removed parameters |
| OCR | Selected-image offline Vision recognition, bounded thumbnail decode, cancellation | Cannot silently capture/read another app; no guarantee of perfect text |
| Shortcuts | Launch user-created named routines | App does not create/inspect system Shortcuts; their own permissions apply |
| Command bar | Tool/note/shelf/task/Shortcut search, calculator, unit conversion, hex-to-RGB | No global file search, arbitrary script evaluator or system hotkey takeover |
| Device readings | Battery level, thermal state, available storage, manual refresh | No Mac SMC sensors, per-app CPU usage or battery health percentage |
| Personalization | Theme/accent, visibility, dock favorites, foreground keep-awake | Does not replace system UI, launcher or gesture handling |
| Backups | Validated versioned JSON, legacy migration, explicit replacement, recovery copies | Readable exports; appearance/timers are stored separately |

Calculator supports decimal numbers, + - * /, parentheses and unary signs, within bounded input/depth. Unit conversions support mm/cm/m/km/in/ft/yd/mi, g/kg/oz/lb, and c/f/k. Incompatible units and temperatures below absolute zero are rejected.

Native materials are available on the iPadOS 17 baseline. The visual direction is floating, translucent and capsule-based; it does not rely on undocumented iPadOS 27 APIs or copy Vorssaint’s assets. Widgets, Live Activities, share extensions, global audio mixing, media editing and a Mac companion are not implemented.

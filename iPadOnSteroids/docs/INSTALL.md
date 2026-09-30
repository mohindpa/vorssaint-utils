# Install on your iPad Pro M1

## What you need

- Your Mac and a current Xcode from the Mac App Store. Xcode must support the iPadOS version installed on your iPad.
- iPadOS 17 or later; update if needed. The app is iPad-only.
- An Apple Account (free is sufficient for development installation).
- USB-C cable for the first pairing. Wireless deployment can be enabled later in Xcode.

## Run on the iPad

1. Unzip the source download on your Mac. Open `iPadOnSteroids.xcodeproj`.
2. Open Xcode → Settings → Accounts and add your Apple Account.
3. Select the project in the navigator, then the **iPadOnSteroids** target → Signing & Capabilities. Enable Automatically manage signing and select your Personal Team or paid team. Change `com.mohindpa.ipadonsteroids` to a unique identifier if Xcode reports a conflict. Do the same for the tests target if running tests on the device.
4. Connect and unlock your iPad. Trust the Mac if asked. In Xcode → Window → Devices and Simulators, wait for pairing and device preparation.
5. Enable Settings → Privacy & Security → Developer Mode on the iPad, restart, and confirm when prompted. The option can appear after pairing with Xcode.
6. In Xcode's toolbar, select scheme **iPadOnSteroids** and your connected iPad as the run destination. Press **Command-R**. Xcode compiles, signs, installs and launches the app.
7. If iPadOS asks you to trust a development identity, follow its prompt under Settings → General → VPN & Device Management. Allow notifications when starting a focus timer if you want completion alerts.

An unsigned ZIP or macOS DMG cannot be installed as an iPad app. This package supplies source, not an IPA. Compilation must succeed on your Mac before device installation is possible.

A Personal Team build generally lasts seven days; connect to Xcode and run again to renew it. Paid provisioning has different validity periods. For ongoing beta distribution, use a paid Developer Program team, configure a unique App Store Connect app, archive in Xcode and upload to TestFlight. External TestFlight testing may require beta review. TestFlight setup and app submission are not included here.

## Tests before using personal data

1. Run unit tests with **Command-U** on an iPad simulator. You can list simulators using `xcrun simctl list devices available`, then run `SIMULATOR_ID='<UUID>' bash scripts/test-on-mac.sh`.
2. On your iPad, try portrait, landscape, Split View/Stage Manager and an external keyboard if available. Command-K should open the tool finder.
3. Copy a sentence in another app. Tap Paste in Clipboard shelf; pin, search, copy, share and delete it. Relaunch and verify saved items and notes persist.
4. Clean `https://example.com/?q=ipad&utm_source=news&fbclid=123#results`. Expect `https://example.com/?q=ipad#results`.
5. Import a screenshot containing text. Check recognized text against the image; OCR is imperfect and should be reviewed.
6. Create a Shortcut named `Desk Mode` in Apple's Shortcuts app. Add a Set Focus action, save it, then add a launcher with that exact name. Tap it and follow any system permission prompts. This app does not create Shortcuts automatically.
7. Start a focus timer, leave the app and return. Check the countdown reflects elapsed time. Stop it and verify the notification is canceled. Select the existing one-minute session for a quick check.
8. Export a backup to Files, edit a note, import the backup and confirm replacement. Try a malformed JSON file and verify an error appears without replacing data.
9. Switch appearance/accent, hide the island, and test foreground keep-awake. Confirm normal auto-lock returns after leaving the app or disabling keep-awake.
10. Test denied notification access. The timer should still work in-app and explain the notification limitation. There is no background clipboard capture or floating overlay over other apps.

## Common setup issues

- **Unsupported device OS / missing device support:** update Xcode and use a Mac version compatible with that Xcode release.
- **Signing fails:** select your team, use a unique bundle identifier, and check Apple Account access. Do not send account passwords or signing credentials in chat.
- **Shortcut not found:** launcher names must match an existing shortcut. Test it in Shortcuts first.
- **Photos unavailable:** use an image available locally or allow an iCloud-backed selection to download. Only selected images are passed to the app.
- **Source build failure:** retain Xcode's exact error and file/line. Hosted native builds passed on Xcode 16.4 and 27; see VALIDATION.md for the tested revision.

## v0.2 regression checks

- Expand/collapse the island; customize floating-dock favorites; test overflow in a narrow window.
- Create and rename multiple notes, edit them, switch between them, delete one with confirmation, and relaunch. Import a v0.1 backup and verify its original note survived migration.
- Add tasks, mark complete, hide completed and confirm bulk clearing.
- In Command-K, find a note by content and a pinned shelf item. Try `=2 + 3 * 4`, `10 cm to in`, `32 f to c` and `#62E3B5`; copy the results.
- Pause a focus timer, wait, resume and confirm paused time was preserved. Stop/restart while the notification permission prompt is open and verify there is no obsolete reminder.
- Edit quickly and background the app; relaunch and verify the latest text. Exercise retry/export if a save error appears.
- Test oversized, unrelated, future-version and duplicate-ID JSON backups. Each must be rejected without replacing current data.
- If saved data cannot be opened, export the original file and use the explicit recovery action; verify a recovery copy remains before writing a new workspace.
- Change Photos selections while OCR runs, cancel and leave the OCR screen. Only the current selection should populate the editor.
- Test VoiceOver, largest Dynamic Type, Reduce Motion, Reduce Transparency, increased contrast and keyboard navigation. Check all primary actions remain reachable.
- Record your exact iPadOS version, including 27 if that is installed. Passing CI on another simulator version does not prove your OS compatibility.

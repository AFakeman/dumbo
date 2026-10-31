<p align="center">
  <img src="Dumbo/Dumbo/Assets.xcassets/AppIcon.appiconset/elephant.png" width="112" alt="Dumbo's purple elephant icon">
</p>

# Dumbo

An iOS app for taking control of distracting apps. Create reusable app lists, block them manually, or connect them to an iOS Focus.

Dumbo is an early working prototype built with SwiftUI and Apple's Screen Time APIs. App lists stay on your device; there is no backend or account system.

## Features

- **Named app lists** using Apple's application picker.
- **Block or allow:** block the apps in a list, or allow only those apps within iOS's supported shielding scope.
- **Manual controls:** start, stop, and switch policies from the app, or continue a paused Focus policy.
- **Focus integration:** choose a list and mode in an iOS Focus Filter.
- **Live edits:** changes to the active list are reapplied immediately.
- **App previews:** cards show up to three app icons and an overflow count.
- **Custom deny screen** when a restricted app is opened.
- **Local storage** shared between the app and its extensions, with opaque application tokens rather than extracted app identities.

## Notification behavior

Device testing on an iPhone Air running iOS 27.0.1 found that shielding an app hides its badge and Notification Center items. Unblocking makes badges and missed notifications visible again. The same behavior was reported with manual blocking and all Focus modes disabled.

These are observations for the tested configuration. Banners, Lock Screen alerts, sounds, summaries, exceptional notification types, and other iOS versions still need verification. Dumbo does not intercept other apps' notifications or configure their notification permissions; its Focus Filter's notification API is limited to Dumbo's own notifications.

See [device verification](docs/device-verification.md) for results and outstanding checks.

## Build and run

### Requirements

- A Mac with **Xcode 27.2**, the version used to build this project. The project uses Xcode's JSON project configuration format.
- An active **Apple Developer Program** membership. A free Personal Team cannot provision the Family Controls capability used here.
- A physical iPhone with **Developer Mode** enabled for Screen Time verification. The app's deployment target is **iOS 17.0**; device testing so far has used iOS 27.0.1.

### Setup

1. Clone this repository and open `Dumbo/Dumbo.xcodeproj` in Xcode.
2. Choose the **Dumbo** scheme.
3. Under **Signing & Capabilities**, select your development team for the app and all three extensions. Keep automatic signing enabled.
4. Confirm the required capabilities:

   | Target | Capabilities |
   | --- | --- |
   | Dumbo | Family Controls, App Groups |
   | DumboFocus | Family Controls, App Groups |
   | DumboShield | Family Controls |
   | DumboShieldAction | Family Controls |

5. The configured app identifier is `com.afakeman.dumbo` and the shared App Group is `group.com.afakeman.dumbo`. If building under another team, use identifiers available to that team. Update the shared group in both entitlement files and `ScreenTimeController.groupID`; extension bundle identifiers must remain prefixed by the app's identifier.
6. Connect and unlock your iPhone, trust the Mac if prompted, select it as the run destination, and run the app.
7. In Dumbo, allow Screen Time access and complete the system authentication prompt.

TestFlight and App Store distribution require Apple's separate [Family Controls distribution entitlement approval](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement) for the relevant app and extension identifiers.

## Using Dumbo

### App lists

Tap **+** beside App lists, name the list, choose individual applications, and save. Whole categories and websites are not supported in this prototype.

Each card contains a **Block / Allow** selector and a **Start** button:

- **Block** restricts the selected apps.
- **Allow** restricts other shieldable apps, keeping the selected apps available. Allow-lists require **1–50 applications**. Essential system exceptions need further device testing.
- **Stop** ends manual restrictions; **Pause** suspends Focus-driven restrictions. Both clear Dumbo's restrictions. If a Focus policy is current, App access stays visible as **Focus paused**, with **Continue restrictions** to reapply its list and mode. Other apps' or system Screen Time restrictions may still apply.
- Changing the mode on an active card offers **Apply** to activate that change.

Tap the name or pencil to edit a list. Swipe its card to delete it; active lists must be stopped before deletion.

### iOS Focus

1. Save an app list in Dumbo.
2. Open **Settings → Focus → choose a Focus → Add Filter → Dumbo**.
3. Select the list and blocking mode, then add the filter.
4. If that Focus is already enabled, switch it off and on. In device testing, adding a filter to an already active Focus did not apply it until reactivation.

Only one Dumbo policy is effective at a time. A delivered Focus activation replaces the current policy. A later manual override survives Focus reset; manually stopping restrictions pauses them until **Continue restrictions** is chosen or another activation is delivered. Continue keeps Focus ownership and uses the latest saved selection. A delivered Focus reset removes the continuation, while a new Focus activation replaces it. Delivery timing and background behavior remain part of device verification.

### Continuing a paused Focus

With a Dumbo Focus Filter active, tap **Pause restrictions**. The App access card changes to **Focus paused** and offers **Continue restrictions**. Continue restores the Focus list and mode; it does not create a manual override or switch the system Focus.

Edits made while paused are used when you continue. A manual-only policy has no Focus continuation. Deleting the referenced list, revoking permission, or receiving Focus reset clears the saved continuation. Paused context persists across app launches.

When upgrading from a version without this feature, an active Focus-owned policy can be recovered automatically. If it was already stopped by the old version, toggle that Focus off/on once so Dumbo receives its configuration.

### Permission recovery

If Screen Time authorization is denied or revoked, previously selected tokens require fresh selection. Dumbo keeps the list names and displays **Select apps again**. Allow access, reopen each affected list, choose its apps, and save.

## Development and verification

The shared storage and policy logic can be tested on macOS without changing the Mac's Screen Time settings:

```sh
swift test
```

The suite currently contains **33 passing tests**, covering persistence, corrupt/newer documents, concurrent writes, failed saves, allow-list bounds, policy transitions, Focus reset, and authorization recovery.

Build the iPhone app from Xcode or the command line:

```sh
xcodebuild \
  -project Dumbo/Dumbo.xcodeproj \
  -scheme Dumbo \
  -destination 'generic/platform=iOS' \
  build
```

After building, verify that the embedded Focus extension includes its registration metadata:

```sh
python3 scripts/verify-focus-metadata.py /absolute/path/to/Dumbo.app
```

`DumboFocus` sets `ENABLE_DEBUG_DYLIB=NO`: the initial debug-dylib layout caused App Intents metadata extraction to be skipped despite a successful build. The packaging check verifies the discoverable Focus declaration and its list/mode parameters.

Unit tests and compilation do not establish iOS enforcement or notification behavior. Follow the [device-test checklist](docs/device-verification.md) on a physical iPhone.

## Project layout

| Path | Purpose |
| --- | --- |
| `Dumbo/Dumbo/` | SwiftUI app, list cards, permission flow, and app icon |
| `Dumbo/Shared/` | Shared models, coordinated local storage, and policy application |
| `Dumbo/DumboFocus/` | Focus Filter and saved-list entity query |
| `Dumbo/DumboShield/` | Deny-screen appearance |
| `Dumbo/DumboShieldAction/` | Deny-screen close action |
| `Tests/DumboCoreTests/` | Foundation-only storage and policy tests |
| `scripts/` | Built-app verification tools |
| `openspec/` | Requirements, design, and implementation checklist |
| `docs/` | Product brief, device findings, and icon-generation prompt |

This project uses **OpenSpec**. The active [screen-time prototype change](openspec/changes/screen-time-prototype/proposal.md) and its [task list](openspec/changes/screen-time-prototype/tasks.md) distinguish implementation from checks still awaiting device evidence.

## Known limitations

- Notification coverage is partially verified, as described above.
- Focus configuration changes may need a Focus off/on cycle to take effect.
- System authorization can be revoked; Dumbo is a self-management tool, not tamper-proof device administration.
- Shield backgrounds have shown square corners in the app switcher on the tested device. Apple's public shield API exposes no app-switcher clipping control; no workaround is verified.
- No usage budgets, schedules, usage dashboard, or cloud sync yet.

# Design

## Context

The repository contains a SwiftUI starter app, no implementation tests, and no Screen Time extensions. Xcode 27.2 is installed and connected. The user has set the app identifier to com.afakeman.dumbo and selected signing; preserve these settings and inspect them through Xcode tools before changing target configuration. See proposal.md for motivation and docs/product-brief.md for platform sources.

## Goals / Non-Goals

**Goals:** Share one policy implementation between the app and a background Focus extension, persist selections privately, and produce enough device evidence to decide whether the intended product is feasible.

**Non-Goals:** A usage dashboard, Device Activity scheduling, bypass timers, cloud sync, a backend, and arbitrary overlays. No notification service extension: it cannot filter another app's notifications.

## Decisions

### Native app and explicit extensions

Use SwiftUI with FamilyControls and ManagedSettings. Add a Shield Configuration extension, a Shield Action extension for the close action, and an App Intents extension hosting SetFocusFilterIntent. Share common Swift sources across app and intents targets. Keep UIKit shield presentation code within the shield extension. Use iOS 17 as an initial deployment baseline unless an actual required SDK API establishes a higher minimum; verify availability during implementation.

A main-app-only intent is simpler but does not give the same explicit background execution arrangement as Apple's documented Focus Filter example. A Device Activity monitor is unnecessary without schedules or budgets.

### Data and coordination

Persist named lists with UUID identifiers, name, FamilyActivitySelection, and a selection-valid flag. Store policy mode, list ID, origin (manual or Focus), and last apply/error status separately. Use an App Group container (proposed identifier group.com.afakeman.dumbo, subject to signing availability). Encode a versioned local document; use coordinated read-modify-write access and atomic replacement across processes. Never silently decode corrupt data as an empty library, and never fall back to an unshared container if App Group access fails.

Using ordinary app-only preferences would strand the Focus extension without list access. Serializing actual app identifiers would violate the baseline privacy model. Avoid creating a second copy of the list library in an extension.

### One effective policy

Use a named ManagedSettingsStore owned by Dumbo. Block-list mode sets shield.applications to the list's application tokens. Allow-list mode uses shield.applicationCategories = .all(except: tokens), within the documented 50-exception bound. Reset unrelated shield fields on every policy replacement so prior allow-list restrictions cannot survive a switch to block-list mode. Empty block-lists apply no restrictions; empty allow-lists are rejected. Individual app selection is sufficient for the first prototype; reject categories and websites rather than silently ignore them.

Maintain one effective policy and its source, not a stack of manual and Focus rules. New activation replaces the current policy; Focus reset removes a Focus-owned policy but preserves a later manual policy. Stop clears Dumbo's store. Foreground reconciliation refreshes status and the latest saved selection without inventing a new Focus event. Updating a list reloads current shared policy under coordination before reapplying it. A failed validation of an incoming Focus policy clears old restrictions and records the error; a failed manual edit leaves saved policy unchanged.

ManagedSettings does not offer a transaction covering storage and shields. Commit validated desired state before applying policy side effects under the same cross-process lock. A failed save leaves the old policy unchanged; foreground reconciliation reapplies the last durable intent. Stop clears restrictions before attempting persistence so a corrupt document cannot prevent escape, but reports an error if that cleared state cannot be persisted. Never display enforcement as independently confirmed merely because setters ran. On confirmed authorization denial clear the owned store, invalidate selections, and retain list names for recovery. Reauthorization does not reuse invalid tokens. Treat the initial notDetermined status as unknown, not revocation: preserve lists and initialize previously granted authorization in each process before using the status. A Focus reset does not need authorization and must not clear a later manual policy through an uninitialized permission check. Show invalid saved lists in Focus suggestions with a recovery explanation instead of silently filtering them out.

### Focus parameters and shield

Expose lists as AppEntity values resolved by UUID and suggested from the shared library. The Focus intent uses an optional selected list defaulting to nil and a mode parameter. A nil list is the reset path, with origin checked before clearing. Do not use notificationFilterPredicate to suggest it affects other apps. Missing or invalid non-nil references clear stale policy and persist a visible error.

Show the current list and mode in Dumbo, with Activate and Stop controls. The shield explains the restriction and directs the user to open Dumbo manually; the action extension returns the supported close response. No promise to launch the parent app from a shield.

### Test the product claim on device

Separate policy translation and state-transition logic from platform calls for focused tests of replacement, empty/oversized allow-lists, missing list references, manual override versus Focus reset, revocation, and storage failures. Do not mock notification behavior into a passing result. Simulator builds validate integration only; real device tests validate authorization, shields, Focus delivery, and notification surfaces.

Add docs/device-verification.md during implementation with a result matrix and all results initially marked Not tested. Include both modes, main app closed, Focus on/off/switch, list edits, relaunch, reboot, permission revocation, newly installed apps, and essential system-app exceptions. Capture test evidence without collecting private notification contents. A hiding failure is a product feasibility finding, not a reason to quietly substitute manual Focus notification configuration.

## Risks / Trade-offs

- Notification suppression may not meet the requested contract → keep notification acceptance open and present actual device findings to the user.
- Family Controls/App Groups provisioning may fail for the selected team → report the precise signing blocker; do not remove capabilities to simulate success. Distribution approval is separate from development provisioning.
- iOS can delay background Focus delivery → test latency and foreground reconciliation; do not promise instantaneous switching without evidence.
- System apps and essential functions may be exempt from shields → document measured scope, including newly installed apps.
- Individual authorization is voluntarily revocable → this prototype is self-management, not tamper-proof device administration.

## Migration Plan

No existing app data needs migration. Keep the starter's bundle identifier and selected development team. Add versioned storage and the extension targets incrementally, build before physical-device testing, and leave tests unchecked until performed. Roll back by stopping the policy to clear Dumbo's store before removing an instrumented build; retain the initial git commit as the code baseline.

# Prototype verification

## Current build status — 2026-10-31

Membership renewal is now reflected in signing. A build with provisioning updates refreshed the profiles, and the subsequent Xcode build of the implemented prototype succeeded for a generic iOS device with all three extensions embedded.

| Target | Bundle identifier | Capabilities |
| --- | --- | --- |
| Dumbo | com.afakeman.dumbo | Family Controls, App Groups |
| DumboFocus | com.afakeman.dumbo.DumboFocus | Family Controls, App Groups |
| DumboShield | com.afakeman.dumbo.DumboShield | Family Controls |
| DumboShieldAction | com.afakeman.dumbo.DumboShieldAction | Family Controls |

The signed app and embedded Focus extension both contain the Family Controls entitlement and `group.com.afakeman.dumbo`. The app and extension share one library and one named ManagedSettingsStore. Signed entitlements were inspected with `codesign -d --entitlements -`.

Implemented: permission request and status refresh, named lists with Apple's picker and system labels, local persistence, manual allow/block activation and Stop, active-list deletion protection and edit reconciliation, deny-screen configuration and close action, and a Focus Filter with stable list identifiers. Notification observations and unverified cases are tracked in this document.

The Foundation-only core suite runs with `swift test` from the repository root: 33 tests pass, covering persistence, corrupt and newer-schema documents, failed writes with no policy side effects, concurrent updates, allow-list boundaries, unsupported selections, policy replacement, missing/invalid Focus references, denied access, manual override/reset interaction, revocation, and active-list deletion protection. These tests do not simulate or validate Apple's enforcement or notifications.

An iPhone Air running iOS 27.0.1 is now connected. After refreshing device-specific provisioning profiles, the physical-device build succeeded. Dumbo was installed and launched successfully using Apple's device tools. User reports below confirm several app-access, live-edit, Focus, and notification behaviors. The matrices are a full-coverage checklist; partial observations do not establish every combination of mode, surface, and app state.

Xcode's Device Interaction tool rejected the physical device because this installation supports interaction only with simulators. Preview rendering reports no installed simulator runtime. UI screenshots and physical-device taps therefore require user participation. Installation and launch do not establish blocking or notification behavior.

Previously, the selected Personal Team could not provision Family Controls or App Groups. This signing blocker was resolved after renewal and a provisioning refresh. Development-only Family Controls warnings remain expected; distribution approval is still separate.

## Signing prerequisites

1. Enroll in the Apple Developer Program, or select an existing enrolled development team with access to the required signing resources.
2. Refresh the Apple Account in Xcode and select that team for the app and all three extensions, retaining the identifiers above where available.
3. Keep automatic signing enabled. Confirm Family Controls (Development) and the shared App Group are included in the relevant profiles.
4. Build for a connected iPhone. Resolve any remaining account, identifier, or profile errors as reported by Xcode.
5. Distribution via TestFlight or the App Store requires a separate Family Controls distribution entitlement request; development access does not establish distribution approval.

Sources: [Configuring Family Controls](https://developer.apple.com/documentation/Xcode/configuring-family-controls), [Requesting the Family Controls entitlement](https://developer.apple.com/documentation/FamilyControls/requesting-the-family-controls-entitlement).

## Recording a device run

For each run record date, device model, iOS version, app build, selected applications (avoid private notification contents), list/mode, activation source, relevant Focus/notification settings, and measured activation/reset delay. Use Pass, Fail, Unsupported, or Not tested; never treat Unsupported as Pass.

Physical-device observations are recorded below. Both allow-list and block-list columns still need independent, controlled runs before the complete matrix can be signed off.

## App access and Focus matrix

| Case | Block-list | Allow-list |
| --- | --- | --- |
| Screen Time approval and application picker | Not tested | Not tested |
| Denied permission and retry | Not tested | Not tested |
| Save, edit, rename, and reload list | Not tested | Not tested |
| Open a selected app | Not tested | Not tested |
| Open an unselected app | Not tested | Not tested |
| Deny-screen close action | Not tested | Not tested |
| Switch between disjoint lists | Not tested | Not tested |
| Switch policy modes | Not tested | Not tested |
| Stop clears only Dumbo restrictions | Not tested | Not tested |
| Active list edits and deletion protection | Not tested | Not tested |
| Empty list | Not tested | Not tested |
| 50-token and 51-token boundaries | Not tested | Not tested |
| System app exceptions and access to Dumbo | Not tested | Not tested |
| Newly installed app | Not tested | Not tested |
| Relaunch and reboot | Not tested | Not tested |
| Authorization revocation and fresh selection | Not tested | Not tested |
| Focus on/off with main app closed | Not tested | Not tested |
| Switch Focus configurations with app closed | Not tested | Not tested |
| Manual override followed by Focus reset | Not tested | Not tested |
| Manual Stop during Focus | Not tested | Not tested |
| Renamed, deleted, or invalid Focus list | Not tested | Not tested |

## Notification matrix

Repeat each case with manual activation and Focus activation/switch/reset while Dumbo is closed. Include notifications already present at activation and newly arriving notifications while restricted. Record what returns after unblocking. Also test an unrestricted app as a control to distinguish Dumbo restrictions from iOS Focus silencing.

| Surface / behavior | Block-list | Allow-list |
| --- | --- | --- |
| Incoming banner | Not tested | Not tested |
| Existing banner at activation | Not tested | Not tested |
| Incoming Lock Screen notification | Not tested | Not tested |
| Existing Lock Screen notification | Not tested | Not tested |
| Incoming Notification Center item | Not tested | Not tested |
| Existing Notification Center item | Not tested | Not tested |
| Incoming notification sound | Not tested | Not tested |
| New badge count | Not tested | Not tested |
| Existing badge count | Not tested | Not tested |
| Scheduled summary | Not tested | Not tested |
| Time Sensitive notification where supported | Not tested | Not tested |
| Critical alert where supported | Not tested | Not tested |
| Communication notification where supported | Not tested | Not tested |
| Notification reappearance/delivery after unblock | Not tested | Not tested |
| Unrestricted app control | Not tested | Not tested |

## Acceptance

Badge and Notification Center hiding have user-reported device evidence below; full notification coverage remains unverified. Passing usage-blocking tests does not satisfy all notification requirements. If public APIs fail any required hiding behavior, record the limitation and discuss it with the user before substituting manual Focus notification configuration. Full product acceptance remains open.

## Focus Filter registration fix — 2026-10-31

The user confirmed Dumbo was absent from Settings → Focus → Add Filter on iOS 27.0.1. Inspection of the installed build found no `Metadata.appintents` inside the embedded Focus extension. The extension build log reported that metadata extraction was skipped because it found no AppIntents framework dependency, even though the Swift source compiled.

Disabling `ENABLE_DEBUG_DYLIB` for the DumboFocus target makes its intent implementation visible in the extension executable to metadata extraction. The rebuilt app packages `Metadata.appintents/extract.actionsdata`, containing a discoverable DumboFocus action, the FocusConfiguration system protocol, list/mode parameters, and AppListEntity. This setting is limited to the Focus extension; the main app's preview configuration remains as before.

After building, run `python3 scripts/verify-focus-metadata.py /absolute/path/to/Dumbo.app` to verify the packaged declaration, not just compilation. This check passes for the corrected build. Presence in iOS Settings and real Focus activation still require device confirmation; task 4.1 remains unchecked until those checks pass.

## Focus list visibility and startup permission fix — 2026-10-31

User screenshots confirmed that Dumbo now appears in Focus Filters and that its mode selector renders. The app contains two named lists, but both display Select apps again, while the Focus list selector displays No options available. The earlier query filtered out invalid selections, explaining the empty picker.

The underlying bug was treating AuthorizationCenter's process-initial `.notDetermined` state as revoked access. Apple documents that this property's initial value is always notDetermined and is initialized by a successful authorization request. Both app refresh and background Focus handling had conflated unknown status with denial. See [authorizationStatus](https://developer.apple.com/documentation/familycontrols/authorizationcenter/authorizationstatus).

The corrected build distinguishes unknown, approved, and denied access. App refresh preserves stored selections during unknown startup status and restores previously granted permission with an authorization request. A configured Focus activation initializes permission in the extension before applying its policy. Focus reset does not require permission initialization and preserves a later manual policy. Confirmed denial still invalidates selections. The Focus selector now includes invalid lists with a select-apps-again explanation rather than hiding them.

Four added core regression tests verify unknown-startup preservation, reset with unknown permission, unknown activation preserving tokens without activating, and invalidation on confirmed denial. All 20 tests pass. The app and extensions build, the packaged Focus metadata check passes, and the update installed/launched on the connected iPhone.

Previously invalidated lists require fresh selection once; the fix deliberately does not revalidate old tokens without the user's selection. Recovery, subsequent relaunch preservation, Focus option discovery, renaming, and real Focus activation remain pending user verification. No notification-suppression result has been established.

## Permission recovery message — 2026-10-31

The user confirmed the selections had not yet been recreated after the startup fix; they had only reopened the app. The remaining invalid list flags therefore do not establish a new invalidation on relaunch. An unrelated UI defect kept displaying the old revoked-access error after authorization became approved.

Approved access now clears that specific obsolete warning without changing invalid selection flags or discarding other errors. When access is enabled and lists still require fresh selections, the app explains the exact recovery action. Two regression tests cover stale-warning clearing without token revalidation and preservation of unrelated Focus errors. All 20 core tests pass; the device build and metadata check pass, and the revised app was installed and launched. Selecting apps afresh and checking subsequent relaunch/Focus behavior remain pending.

## User finding: adding a filter to an already active Focus — 2026-10-31

On the connected iPhone Air (iOS 27.0.1), the user reports that adding Dumbo's filter while Personal Focus is already active does not apply its policy immediately. Turning Personal Focus off and on again applies it. The list, policy mode, exact callback timing, and app foreground/background state were not specified, so this is a partial device observation rather than a complete activation/reset test pass.

Apple's Focus Filter sample describes turning on the configured Focus to deliver parameters to perform(). It does not establish a guarantee of immediate application when adding a filter to an already active Focus. Source: https://developer.apple.com/documentation/AppIntents/defining-your-app-s-focus-filter

Current test procedure: configure the filter, then switch the Focus off and on. Before classifying this as an iOS delivery limitation, distinguish absent callback delivery from a delivered callback that failed or applied late using recorded extension execution evidence. Do not infer from the visible result alone that iOS never called the extension.

## User findings: live list edits and notification visibility — 2026-10-31

Device: connected iPhone Air, iOS 27.0.1. Evidence: direct user report. The Personal Focus was enabled with Dumbo's filter configured. The exact list/mode and notification-related iOS settings were not specified.

### Editing the active list

The user edited the allow/deny list inside Dumbo while Personal Focus remained enabled. Telegram became blocked from opening immediately, without switching Focus off/on. This confirms the reported live-edit path for this app/configuration. It does not establish behavior for every policy mode or for changes to the filter configuration in Settings.

### Notifications while shielded and after unblock

The user reports that restricted apps show no number badge and no notifications in Notification Center while blocked. Disabling Personal Focus makes badges appear and exposes the missed notifications in Notification Center.

This supports the intended behavior for the observed badge and Notification Center surfaces under that configuration. It indicates notification visibility is suppressed while restricted and missed notifications become visible after unblocking; it does not establish that push transport or delivery to the app stopped.

Still unverified: banner and Lock Screen presentation, sounds, summaries, Time Sensitive/critical/communication notifications, existing versus newly arriving items as separate cases, both policy modes, and effects of system Focus notification settings. A control run with the same apps and the same Personal Focus notification settings but no Dumbo restriction is needed to isolate shielding from ordinary Focus silencing.

Do not mark the entire notification-suppression matrix complete based on these observations. The user has established promising partial evidence, not universal coverage across iOS versions or notification classes.

## User finding: manual blocking without Focus — 2026-10-31

Following the suggested control test (manually blocking Telegram with all Focus modes off), the user confirmed that manual blocking behaves the same way as the previous Focus-driven test. On the connected iPhone Air running iOS 27.0.1, this supports app-access blocking and hiding of badges/Notification Center items while restricted, with missed notification visibility returning after unblock, independently of an enabled Focus mode.

This is user-reported evidence for the observed app and configuration. It strengthens attribution to Managed Settings shielding rather than Focus silencing. It does not establish push transport behavior, other apps or iOS versions, all policy modes, or the remaining notification surfaces/classes. Banner, Lock Screen, sound, summary, and exceptional-notification tests remain pending.

## Main screen simplification — 2026-10-31

At the user's request, removed the Use with Focus and Notifications information sections from the main screen. Focus setup instructions remain in README.md; observed notification behavior and outstanding tests remain documented here. No restriction or Focus behavior changed.

## User finding: shield appearance in the app switcher — 2026-10-31

The user supplied an app-switcher screenshot showing square background areas around the blocked Teams and Telegram cards, while other cards have rounded corners. The visible shield content has rounded edges but its background appears to extend outside those bounds.

Dumbo provides ShieldConfiguration values (background blur/color, icon, text, and button styling); iOS renders the shield and its app-switcher representation. The public ShieldConfiguration API exposes no corner radius or app-switcher clipping control. A system shield compositing/clipping issue is a plausible explanation, not a confirmed diagnosis. Comparing with Apple's default shield background would be a separate visual experiment; no workaround is verified. No code change was made for this observation.

API reference: https://developer.apple.com/documentation/managedsettingsui/shieldconfiguration

## Cards layout and app previews — 2026-10-31

The user selected the Cards design and requested previews of up to three apps per list. The main list now uses separate rounded cards, with name/count, edit button, Block/Allow segmented mode, and Start/Stop control. Changing the selected mode on an active card offers Apply; the policy does not change until that action is chosen. Adding a list moved to the plus button beside App lists; swipe-to-delete and active-list protection remain.

Previews decode the saved FamilyActivitySelection, stably order opaque token encodings, and render at most three Apple activity labels in icon-only style. A +N chip accounts for remaining selected applications. No application names or bundle identifiers are extracted. Captions distinguish Blocked apps from Allowed apps, because allow-list previews show apps kept available. Invalid selections show recovery text; unreadable previews show an unavailable state. App counts use singular wording for one app.

The signed device build and Focus metadata packaging check pass, and the updated app was installed and launched. Physical-device appearance of system-rendered preview icons, overflow, and mode controls remains pending visual confirmation. Existing core logic is unchanged.

## Final UI state before repository push — 2026-10-31

Subsequent user-directed refinements removed the intro, Focus instructions, notification status section, and verification copy from the main screen. App access hides when inactive. Both active-policy and list cards now share compact rounded styling and capsule controls. List previews show up to three icons immediately left of the edit button, with the count beneath the name and a +N overflow count when needed. Mode descriptions remain available to accessibility services. The App access section animates insertion/removal and respects Reduce Motion.

The purple elephant icon is installed as the app's 1024×1024 opaque app-icon asset. All UI changes were built and installed on the connected iPhone; the user confirmed the transition looked good. Earlier sections describe intermediate designs and test history, not the final UI. The verification matrices continue to track uncompleted combinations separately from the user-reported findings.

## Continue paused Focus restrictions — 2026-10-31

The user requested a way to resume Focus-owned restrictions after stopping them in Dumbo. The shared document now retains the last valid delivered Focus policy independently of its effective active policy. Stop clears enforcement but retains the Focus context. App access remains visible as Focus paused, with a Continue restrictions action that revalidates the latest list under the shared lock and reapplies it with Focus origin. Manual-only restrictions do not create a continuation. A later manual override leaves current Focus context available after it is stopped.

Focus reset clears retained context while preserving a later active manual policy. New Focus activation replaces the old paused context; invalid activation, authorization revocation, or deletion of its referenced list clears that context. An invalid edited selection fails continuation without applying restrictions. Old version-1 documents with an active Focus policy infer the new optional context during load. Previously stopped old policies require one new Focus activation because the earlier version discarded their configuration.

All 33 core tests pass, including 13 new pause/resume tests for persistence, live edits, manual overrides, reset/replacement, validation failure, deletion/revocation, stale UI after reset, and migration. The signed device build and packaged Focus metadata check pass, and the updated app installed and launched. Runtime Focus → Stop → Continue and the following device checks still need user confirmation:

- Pause a Focus policy, edit its list, and confirm the apps remain unrestricted until Continue is tapped.
- Continue and verify the latest saved list/mode is enforced and displayed as iOS Focus.
- Pause, reopen Dumbo, and confirm the paused card persists without restarting restrictions.
- Turn Focus off while paused and confirm its continuation disappears.
- Switch to another configured Focus while paused and confirm the new policy replaces the old one.

Focus lifecycle state follows iOS-delivered events; this feature does not introduce an API to query the system's Focus name or force callback delivery.

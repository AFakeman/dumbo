# Tasks

## 1. Target setup and signing

- [x] 1.1 Inspect current Xcode target settings, preserve com.afakeman.dumbo and the selected team, and establish the iOS deployment baseline; verify the starter still builds.
- [x] 1.2 Create Shield Configuration, Shield Action, and App Intents extension targets and shared source membership; verify extension embedding and identifier prefixes through Xcode target settings.
- [x] 1.3 Add Family Controls and the shared App Group to the targets that need them; verify a signed device build or record the precise provisioning blocker without removing required capabilities.
- [x] 1.4 Document device setup and entitlement requirements in docs/device-verification.md; verify the app and extensions use the same registered App Group identifier.

## 2. Authorization and named app lists

- [x] 2.1 Implement a versioned, coordinated App Group repository with atomic saves and explicit error reporting; verify round-trip persistence, corrupt-document handling, and failed-write behavior with focused tests.
- [ ] 2.2 Add individual authorization UI and foreground status refresh; verify approval, denial, revocation, and reauthorization on device, including invalidation of old selections while retaining names.
- [ ] 2.3 Replace the starter screen with named-list creation, editing, rename, and deletion using the system app picker; verify nonblank names, app-only selection, editor recovery after save failure, and relaunch persistence.
- [ ] 2.4 Document list and permission behavior and record device test results in docs/device-verification.md; verify app identities are represented only by opaque tokens and system labels.

## 3. Reversible app restrictions

- [x] 3.1 Implement policy validation and translation for block-lists and allow-lists; verify tests cover empty/oversized allow-lists, category/web rejection, and clearing obsolete policy fields when switching modes.
- [ ] 3.2 Implement one owned policy store with Activate and Stop controls and status reporting; verify disjoint-list replacement, persistence failures, and clearing only Dumbo-owned settings.
- [ ] 3.3 Reconcile active list edits and protect active lists from deletion; verify removal from a block-list unblocks the app and invalid allow-list edits preserve saved state.
- [ ] 3.4 Implement deny-screen configuration and the close action; verify selected apps show Dumbo's shield and its primary action closes the app without granting an exemption.
- [ ] 3.5 Record on-device allow/block results, 50-token boundary, newly installed app behavior, system exceptions, relaunch, and reboot in docs/device-verification.md; verify every result names its device and iOS version.

## 4. Focus integration

- [ ] 4.1 Expose saved lists by stable AppEntity identifier and mode through SetFocusFilterIntent in the App Intents extension; verify list discovery and configuration in iOS Settings and resolution after a rename.
- [x] 4.2 Implement shared activation/reset transitions and persisted failures; verify focused tests cover Focus-to-Focus replacement, manual override surviving reset, missing/invalid lists clearing stale policy, and denied authorization.
- [ ] 4.3 Test Focus activation, switching, and reset with Dumbo closed on a physical device; record delivery timing, manual Stop behavior, and results in docs/device-verification.md.

## 5. Notification feasibility

- [x] 5.1 Keep tested notification behavior and remaining unverified cases explicit in device-verification records; verify the main screen omits the Notifications section as requested and does not claim universal suppression.
- [x] 5.2 Prepare a device matrix for both modes covering incoming/existing notifications, banners, Lock Screen, Notification Center, sounds, badges, summaries, exceptional notification classes where available, and reappearance after unblocking; verify all unperformed cases say Not tested.
- [ ] 5.3 Execute the matrix on a physical iPhone with the main app closed and under Focus changes; record settings, device, iOS version, and pass/fail/unsupported evidence without private notification contents.
- [ ] 5.4 Evaluate results against notification-suppression requirements; verify full acceptance remains open for any failed/unverified hiding surface, and present limitations for a user decision before implementing a fallback.

## 6. Integrated prototype review

- [x] 6.1 Build the app and all embedded extensions and run focused tests; verify no new build errors and retain the test/build summary.
- [ ] 6.2 Walk through authorization, saving a list, manual activation, deny screen, Stop, Focus switching, and revocation on device; verify results match the specs and leave blocked/unperformed tasks unchecked.

## 7. Continue paused Focus restrictions

- [x] 7.1 Persist the current Focus policy separately from effective enforcement and implement Stop/Continue/reset transitions; verify migration, reopening, manual overrides, permission loss, deletion, invalid resume, and Focus replacement with focused tests.
- [x] 7.2 Add the paused Focus card with Continue restrictions and apply the latest saved selection under the shared storage lock; verify the app and embedded extensions build, core tests pass, and Focus registration metadata remains packaged.
- [ ] 7.3 Verify on iPhone that Focus → Stop → Continue reapplies the list, edits while paused take effect only on Continue, and Focus off removes continuation; record the observed results without marking unperformed cases complete.

## Workflow follow-up

- Archive only after implementation and verification are complete; preserve unresolved platform limitations explicitly.

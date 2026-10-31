# Product brief

## User intent

Create an iOS alternative to Opal centered on reusable application lists and Focus-driven restrictions.

The requested behavior is:

- Create and edit named lists of applications on the phone.
- Configure an iOS Focus Filter with a list and an allow-list or block-list mode.
- In allow-list mode, permit usage and notifications only for listed apps.
- In block-list mode, deny usage and hide notifications for listed apps.
- Show a deny screen when opening a blocked app.

These are desired outcomes. Notification behavior remains a feasibility gate rather than an assumed guarantee.

## Proposed foundation

Use native Swift and SwiftUI, Family Controls individual authorization, Managed Settings shields, and an App Intents Focus Filter. Share list selections and policy state between the app and extensions through an App Group. Keep data local for the initial version; accounts, servers, subscriptions, analytics, usage budgets, and custom schedules are outside the initial scope.

Use Apple's FamilyActivityPicker for application selection and persist opaque application tokens. Do not assume unrestricted enumeration of installed apps or access to their bundle identifiers. Newer non-tokenized Family Activity data access has additional capability and regional restrictions and is unnecessary for the baseline.

Block-list mode should shield selected application tokens. Allow-list mode should investigate the all-categories policy with application exceptions; Apple's API documents a maximum of 50 exception tokens. Validate system-app exceptions and newly installed apps on device before describing the mode as universal.

Use a system shield customized through a Shield Configuration extension for the deny screen. This is not an arbitrary full-screen overlay. Keep a clear route back to management of the policy.

The Focus Filter selects a saved list and enforcement mode. A dedicated App Intents extension should apply policies while the main app is closed. Verify activation, Focus switching, and deactivation/reset delivery on device. Use one owned ManagedSettingsStore and replace its policy rather than accumulating restrictions across lists. Clearing this store must not claim to remove restrictions imposed by other apps or Screen Time.

## Notification feasibility gate

A Focus Filter's notification predicate filters the implementing app's own notifications; it does not grant general control of other applications' notifications or their system Focus allow/silence lists.

Investigate whether applying Managed Settings shields provides the requested notification suppression on supported iOS versions. Do not assume that usage shielding alone guarantees every notification surface is hidden. Test incoming notifications, existing notifications, banners, Lock Screen, Notification Center, sounds, badges, summaries, and any exceptional notification classes separately. Check whether previously hidden notifications return after unblocking.

If public APIs cannot meet the requirement, document the exact gap and discuss it with the user before substituting manual Focus notification configuration or reducing scope. Do not silently declare notification management complete.

## First milestone: physical-device feasibility

Once Xcode is installed:

1. Set up a minimal signed app and required extensions with Family Controls and App Groups capabilities. Record signing requirements; distribution requires Apple's Family Controls entitlement approval for relevant targets.
2. Obtain individual authorization, select apps with the system picker, and persist/reload a named list.
3. Apply and remove a block-list shield; verify the deny screen while the main app is closed.
4. Apply allow-list shielding; verify exceptions, empty-list behavior, the 50-token limit, and access to essential system functionality.
5. Connect a saved policy to an iOS Focus Filter. Test Focus on/off and switching between Focus configurations while the main app is closed, including stale/deleted list references.
6. Run the notification matrix above and record iOS version, device, settings, observations, and limitations.
7. Test authorization denial/revocation. Previously issued tokens become invalid after revocation; require fresh selection rather than claiming old lists remain enforceable.

Acceptance for the full product requires evidence for both usage blocking and notification hiding. A successful shield demo alone does not satisfy the requested product.

## Open decisions

- Minimum supported iOS version and target devices, after confirming available Xcode and test hardware.
- Whether an empty allow-list should block all shieldable apps or require explicit confirmation.
- Whether edits to an active list apply immediately; proposed default is immediate reconciliation.
- What the user should see when a configured list is deleted; proposed default is prevent deletion until it is detached from active policies.
- Notification fallback, only if the feasibility milestone establishes a platform limitation.

## Primary sources

Reviewed 2026-10-31:

- [FamilyActivityPicker](https://developer.apple.com/documentation/familycontrols/familyactivitypicker): system selection and opaque representations.
- [FamilyActivitySelection](https://developer.apple.com/documentation/familycontrols/familyactivityselection): selected tokens and invalidation after authorization revocation.
- [Defining your app’s Focus filter](https://developer.apple.com/documentation/AppIntents/defining-your-app-s-focus-filter): parameters, notification predicates, reset defaults, and background extension execution.
- [Allow-list shielding policy](https://developer.apple.com/documentation/managedsettings/shieldsettings/activitycategorypolicy/all%28except%3A%29): all-category shielding with up to 50 exceptions.
- [Authorization with data access](https://developer.apple.com/documentation/FamilyControls/AuthorizationStatus/approvedWithDataAccess): additional capability and EU restrictions for non-tokenized data.

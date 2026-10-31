# Proposal

## Why

Dumbo currently opens a SwiftUI starter screen. Before investing in the full app, we need a usable prototype and device evidence that Apple's Screen Time APIs can deliver the requested app-access and notification behavior.

## What Changes

- Add individual Screen Time authorization and reusable named application lists using Apple's private-token picker.
- Add manual allow-list and block-list activation with a customizable system deny screen and a Stop control.
- Add an iOS Focus Filter that selects a saved list and mode, applying restrictions while Dumbo is closed, with manual Stop and Continue controls that preserve Focus ownership.
- Provide explicit verification status and a repeatable physical-device test matrix for notification hiding; do not claim suppression works before testing.
- Keep all selections and policy state on the device. No backend, accounts, payments, schedules, or usage budgets in this change.

## Capabilities

### New Capabilities

- `app-lists`: Authorization, local persistence, and management of named application selections.
- `app-restrictions`: Allow/block policies, replacement and removal of restrictions, and the deny screen.
- `focus-integration`: Focus configuration, background activation, switching, and reset behavior.
- `notification-suppression`: Required hiding behavior, honest verification status, and device acceptance criteria.

### Modified Capabilities

None; there are no existing capability specs.

## Impact

Affects the Dumbo SwiftUI app and adds shared model/storage/policy code, a Shield Configuration extension, and an App Intents extension. Requires Family Controls and App Groups capabilities, signing for the app and extensions, and a real iPhone for acceptance. Preserve the user's existing team and com.afakeman.dumbo bundle identifier. Notification suppression remains a feasibility gate and may require a product decision if public APIs cannot meet it.

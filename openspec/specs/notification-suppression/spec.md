# notification-suppression Specification

## Purpose
Preserve the requested distraction-free behavior and distinguish verified notification hiding from usage blocking alone.

## Requirements

### Requirement: Hide notifications from restricted applications
For full product acceptance, notifications from applications restricted by the current allow-list or block-list SHALL be hidden while that policy is active. A usage-blocking demonstration alone SHALL NOT satisfy this requirement.

#### Scenario: Notification arrives during a restriction
- **WHEN** a restricted application receives a notification during an active policy
- **THEN** it is not visible or interruptive through banners, Lock Screen, Notification Center, badges, or sound

#### Scenario: Existing notification at activation
- **WHEN** a policy activates with an existing notification from an application it restricts
- **THEN** that application's notification is hidden while the policy is active

### Requirement: Honest verification records
Dumbo's verification records SHALL distinguish tested notification behavior from unverified surfaces and SHALL NOT equate an active app-access policy with universal notification suppression. The main screen SHALL omit the Notifications information section as requested by the user.

#### Scenario: Partial notification verification
- **WHEN** the user confirms notification hiding for some surfaces
- **THEN** verification records identify those observations and retain untested surfaces as unverified without requiring a main-screen notification status section

### Requirement: Device evidence before acceptance
Verification SHALL record device, iOS version, relevant Focus and notification settings, policy mode, app state, and results for incoming and existing notifications across notification surfaces, summaries, exceptional notification classes where available, and post-unblock behavior. Unsupported cases SHALL remain explicit gaps rather than passes.

#### Scenario: Platform limitation discovered
- **WHEN** any required hiding behavior cannot be achieved through public APIs
- **THEN** the result is recorded as a limitation and full acceptance remains blocked pending a user decision

### Requirement: No silent fallback
Dumbo SHALL NOT substitute manually configured system notification lists or claim control over other apps' notification settings without agreement from the user.

#### Scenario: Usage shielding works but hiding fails
- **WHEN** testing confirms only usage restrictions
- **THEN** Dumbo reports that distinction and preserves notification hiding as an unmet requirement

# focus-integration Specification

## Purpose
Connect reusable Dumbo application policies to iOS Focus configurations, including background activation and reset.

## Requirements

### Requirement: Configure a Focus policy
Dumbo SHALL provide an iOS Focus Filter with a saved-list selector and allow-list/block-list mode. Saved lists SHALL be resolved by stable identifier so renaming does not break configured filters.

#### Scenario: Configure and rename
- **WHEN** a saved list is renamed after being selected in a Focus Filter
- **THEN** the filter still resolves that same list and applies its latest valid selection

### Requirement: Background policy changes
When iOS delivers Focus Filter activation, Dumbo SHALL apply its valid configured policy even if the main app is closed. Focus switching SHALL replace the previous policy rather than combine lists.

#### Scenario: Activate while closed
- **WHEN** iOS delivers activation for Focus A while Dumbo is closed
- **THEN** A's configured policy is applied and is visible as the active policy when Dumbo next opens

#### Scenario: Switch Focus
- **WHEN** iOS delivers a filter for Focus B after Focus A
- **THEN** B's policy replaces A's restrictions

### Requirement: Reset and manual policy interaction
A delivered Focus reset SHALL clear a Focus-owned policy. It SHALL NOT clear a manual policy selected after that Focus policy. A new delivered Focus activation SHALL replace any manual policy; manual Stop SHALL pause enforcement while retaining the current Focus policy for explicit continuation until a reset or replacement activation is delivered.

#### Scenario: Normal Focus deactivation
- **WHEN** iOS delivers the default inactive filter after a Focus-owned policy
- **THEN** Dumbo clears that policy

#### Scenario: Manual override survives reset
- **WHEN** a person manually activates a list after Focus activation and iOS later delivers Focus reset
- **THEN** the manually activated policy remains in effect

### Requirement: Invalid Focus configuration
If a delivered Focus configuration references a missing or invalid list or lacks authorization, Dumbo SHALL clear its previously applied policy, record an actionable failure, and SHALL NOT report successful activation.

#### Scenario: Deleted list reference
- **WHEN** a Focus references a list that no longer exists
- **THEN** Dumbo clears its old restrictions and explains on next launch that the Focus Filter must be reconfigured

### Requirement: Continue paused Focus restrictions
When Stop clears a policy during an active Focus, Dumbo SHALL retain the last valid delivered Focus policy and offer Continue restrictions in App access while enforcement is paused. Continue SHALL validate and apply the latest saved selection with the Focus policy's mode and Focus origin, without toggling iOS Focus. A manual-only policy SHALL NOT create a Focus continuation.

#### Scenario: Stop and continue Focus
- **WHEN** a user stops Focus-owned restrictions and then chooses Continue restrictions
- **THEN** the stored Focus list and mode are reapplied with Focus ownership

#### Scenario: Reopen while paused
- **WHEN** Dumbo is reopened after stopping a Focus policy
- **THEN** the paused Focus policy remains available to continue without restarting restrictions automatically

#### Scenario: Edit while paused
- **WHEN** a paused policy's list is edited and then continued
- **THEN** the latest saved apps are used and no restriction is applied by the edit alone

#### Scenario: Focus changes or ends
- **WHEN** iOS delivers a replacement Focus activation or reset while a policy is paused
- **THEN** the old continuation is replaced by the newly applied policy or cleared on reset

#### Scenario: Invalid or removed list
- **WHEN** the saved list is deleted, permission is revoked, or continuation validation fails
- **THEN** no invalid restriction is applied, and deleted or revoked policies are unavailable to continue

#### Scenario: Manual override during Focus
- **WHEN** a manual override replaces a Focus policy and is then stopped
- **THEN** the current Focus policy is available to continue until iOS delivers its reset

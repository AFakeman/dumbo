# App restrictions

## Purpose

Apply reversible app-access policies to saved selections and explain denied access through a system shield.

## ADDED Requirements

### Requirement: Block-list enforcement
When authorization and selection are valid, Dumbo SHALL allow activating a saved list in block-list mode, denying access to its selected applications.

#### Scenario: Open a blocked application
- **WHEN** the person opens a selected application under an active block-list policy
- **THEN** iOS presents a deny screen identifying Dumbo as the source of the restriction

### Requirement: Allow-list enforcement
Dumbo SHALL allow activating an allow-list with up to 50 selected applications, shielding other applications within the platform's supported scope. Dumbo SHALL describe system exceptions and SHALL reject empty or oversized allow-lists rather than activate an unintended policy.

#### Scenario: Allow-list exception
- **WHEN** the person opens a selected app under an active allow-list policy
- **THEN** Dumbo does not restrict that app

#### Scenario: App outside the allow-list
- **WHEN** the person opens a shieldable app outside the active allow-list
- **THEN** iOS presents the deny screen

#### Scenario: Invalid allow-list
- **WHEN** the person attempts to activate an empty list or one exceeding 50 selected applications in allow-list mode
- **THEN** activation is prevented with a clear explanation

### Requirement: Replace and stop restrictions
Dumbo SHALL own one effective policy at a time. Switching policies SHALL remove obsolete Dumbo restrictions, and Stop SHALL clear Dumbo's restrictions without claiming to remove restrictions imposed by other apps or Screen Time.

#### Scenario: Switch disjoint block-lists
- **WHEN** policy A is replaced by policy B
- **THEN** only B determines Dumbo's restrictions and apps exclusive to A are no longer restricted by Dumbo

#### Scenario: Stop from the app
- **WHEN** the person taps Stop
- **THEN** Dumbo clears its restrictions and displays a paused state with Continue restrictions when a current Focus policy is retained, or hides App access when no such policy exists

### Requirement: Active list editing
Dumbo SHALL reapply the active policy after successfully saving changes to its list. An edit that would invalidate an active allow-list SHALL be rejected without replacing the saved list or policy.

#### Scenario: Remove app from an active block-list
- **WHEN** an updated selection is successfully saved without that application
- **THEN** Dumbo removes its restriction on that application

### Requirement: Recoverable deny screen
The deny screen SHALL explain that an active Dumbo policy blocks the app and tell the person to open Dumbo to manage it. Its primary action SHALL close the shielded application; it SHALL NOT promise to launch Dumbo directly.

#### Scenario: Deny-screen action
- **WHEN** the person chooses the deny screen's primary action
- **THEN** the shielded app closes and no temporary exemption is granted

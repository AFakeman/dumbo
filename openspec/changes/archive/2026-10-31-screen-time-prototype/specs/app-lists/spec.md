# App lists

## Purpose

Let a person organize applications into reusable local lists without exposing installed-app identities to Dumbo.

## ADDED Requirements

### Requirement: Individual authorization
Dumbo SHALL request individual Screen Time authorization before selecting or restricting apps and SHALL distinguish pending, approved, and denied access.

#### Scenario: Authorization denied
- **WHEN** the person denies the request
- **THEN** Dumbo explains that blocking needs Screen Time permission and does not report an active restriction

#### Scenario: Authorization approved
- **WHEN** the person grants individual authorization
- **THEN** application selection and restriction controls become available

### Requirement: Named application selections
Dumbo SHALL allow creating, renaming, editing, and deleting named lists using the system application picker. This prototype SHALL support individual applications only and reject category or website selections with an explanation.

#### Scenario: Save and reopen
- **WHEN** a person saves a nonblank list name and application selection and relaunches Dumbo
- **THEN** the name and selection remain available for editing and activation

#### Scenario: Unsupported selection
- **WHEN** a selection contains a category or website
- **THEN** saving is prevented with instructions to select individual apps instead

### Requirement: Private durable storage
Dumbo SHALL store list identifiers, names, and opaque application selections on the device without a backend. A storage read or write failure SHALL be surfaced without silently replacing existing data with an empty collection.

#### Scenario: Persistence fails
- **WHEN** a list cannot be saved
- **THEN** Dumbo keeps the editor contents available and reports that saving failed

### Requirement: Revoked access invalidates selections
Dumbo SHALL stop reporting effective restrictions when it observes authorization revocation and SHALL require fresh application selection after authorization is restored.

#### Scenario: Reauthorization
- **WHEN** access is restored after an observed revocation
- **THEN** old list names remain but their selections require replacement before activation

### Requirement: Referenced list protection
Dumbo SHALL prevent deleting a list used by an active policy. A previously configured Focus reference to a missing list SHALL produce the missing-list behavior in the Focus integration specification.

#### Scenario: Delete active list
- **WHEN** the person tries to delete the active list
- **THEN** Dumbo explains that the policy must first be stopped or switched

### Requirement: List cards with bounded app previews
Each named list SHALL appear as a separate card with edit, blocking-mode, and activation controls. A valid selection SHALL show at most three system-rendered app icons and a remaining-app count when more apps are selected. The preview SHALL identify whether listed apps are blocked or allowed by the selected mode.

#### Scenario: Preview a large list
- **WHEN** a saved list contains 50 applications
- **THEN** its card displays three application icons and a +47 count without revealing application identities to Dumbo

#### Scenario: Preview a short list
- **WHEN** a saved list contains one application
- **THEN** its card displays that application's system-rendered icon and no overflow count

#### Scenario: Change mode on an active card
- **WHEN** the user chooses a different mode for an active list
- **THEN** the card offers Apply to explicitly activate the new mode, while Stop remains the action for the currently applied mode

import XCTest
@testable import DumboCore

final class DumboCoreTests: XCTestCase {
    func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func list(_ name: String = "Distractions") -> SavedAppList {
        SavedAppList(name: name, selectionData: Data([1, 2, 3]), applicationCount: 2)
    }

    func testLibrarySurvivesNewRepositoryInstance() throws {
        let directory = temporaryDirectory()
        let repository = LibraryRepository(directory: directory)
        let saved = list()
        let expected = try repository.update { $0.lists = [saved]; $0.wasAuthorized = true }
        XCTAssertEqual(try LibraryRepository(directory: directory).read(), expected)
    }

    func testCorruptLibraryIsNotOverwritten() throws {
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("library.json")
        let badData = Data("broken".utf8)
        try badData.write(to: file)
        let repository = LibraryRepository(directory: directory)
        XCTAssertThrowsError(try repository.read())
        XCTAssertThrowsError(try repository.update { $0.lists = [list()] })
        XCTAssertEqual(try Data(contentsOf: file), badData)
    }

    func testFailedWritePreservesLibraryAndSkipsPolicyEffect() throws {
        let directory = temporaryDirectory()
        let original = try LibraryRepository(directory: directory).update { $0.lists = [list("Original")] }
        let repository = LibraryRepository(directory: directory, writer: { _, _ in throw CocoaError(.fileWriteOutOfSpace) })
        var effectCalled = false
        XCTAssertThrowsError(try repository.update({ $0.lists = [list("Changed")] }, afterSave: { _ in effectCalled = true }))
        XCTAssertFalse(effectCalled)
        XCTAssertEqual(try repository.read(), original)
    }

    func testConcurrentRepositoryInstancesDoNotLoseUpdates() throws {
        let directory = temporaryDirectory()
        let queue = DispatchQueue(label: "test.failures")
        var failures: [String] = []
        DispatchQueue.concurrentPerform(iterations: 30) { index in
            do {
                try LibraryRepository(directory: directory).update {
                    $0.lists.append(SavedAppList(name: "List \(index)", selectionData: Data(), applicationCount: 0))
                }
            } catch { queue.sync { failures.append(error.localizedDescription) } }
        }
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: ", "))
        XCTAssertEqual(try LibraryRepository(directory: directory).read().lists.count, 30)
    }

    func testUnsupportedSchemaDoesNotOverwrite() throws {
        let directory = temporaryDirectory()
        let repository = LibraryRepository(directory: directory)
        try repository.update { $0.version = 2 }
        XCTAssertThrowsError(try repository.read())
        XCTAssertThrowsError(try repository.update { $0.version = 1 })
    }

    func testSwitchingModesDoesNotCarryOldShieldFields() throws {
        let blocked = try plan(["social"], .block)
        XCTAssertEqual(blocked.applications, ["social"])
        XCTAssertNil(blocked.allowExceptions)
        let allowed = try plan(["work"], .allow)
        XCTAssertNil(allowed.applications)
        XCTAssertEqual(allowed.allowExceptions, ["work"])
        let replacement = try plan(["video"], .block)
        XCTAssertEqual(replacement.applications, ["video"])
        XCTAssertNil(replacement.allowExceptions)
    }

    func testAllowListBoundaryAndEmptyBlockList() throws {
        XCTAssertThrowsError(try plan([], .allow))
        XCTAssertThrowsError(try plan(Set((0..<51).map(String.init)), .allow))
        XCTAssertEqual(try plan(Set((0..<50).map(String.init)), .allow).allowExceptions?.count, 50)
        XCTAssertNil(try plan([], .block).applications)
    }

    func testInvalidOrNonAppSelectionRejected() {
        XCTAssertThrowsError(try ShieldPlan(applications: Set(["one"]), categoryCount: 1, webCount: 0, valid: true, mode: .block))
        XCTAssertThrowsError(try ShieldPlan(applications: Set(["one"]), categoryCount: 0, webCount: 1, valid: true, mode: .allow))
        XCTAssertThrowsError(try ShieldPlan(applications: Set(["one"]), categoryCount: 0, webCount: 0, valid: false, mode: .block))
    }

    func testFocusResetPreservesManualOverride() {
        var document = LibraryDocument()
        let manual = ActivePolicy(listID: UUID(), mode: .allow, origin: .manual)
        document.active = manual
        document.resetFocus()
        XCTAssertEqual(document.active, manual)
        document.active = ActivePolicy(listID: UUID(), mode: .block, origin: .focus)
        document.resetFocus()
        XCTAssertNil(document.active)
    }

    func testRevocationKeepsNamesButInvalidatesEverySelection() {
        var document = LibraryDocument()
        document.lists = [list("Work"), list("Social")]
        document.active = ActivePolicy(listID: document.lists[0].id, mode: .block, origin: .focus)
        document.wasAuthorized = true
        document.revoke()
        XCTAssertNil(document.active)
        XCTAssertFalse(document.wasAuthorized)
        XCTAssertEqual(document.lists.map(\.name), ["Work", "Social"])
        XCTAssertTrue(document.lists.allSatisfy { !$0.selectionValid })
        XCTAssertNotNil(document.lastError)
    }

    func testCannotDeleteActiveList() throws {
        var document = LibraryDocument()
        let saved = list()
        document.lists = [saved]
        document.active = ActivePolicy(listID: saved.id, mode: .block, origin: .manual)
        XCTAssertThrowsError(try document.delete(saved.id))
        XCTAssertEqual(document.lists.count, 1)
        document.active = nil
        try document.delete(saved.id)
        XCTAssertTrue(document.lists.isEmpty)
    }

    func testFocusSwitchAndMissingReferenceClearOldRestrictions() throws {
        var document = LibraryDocument()
        let first = list("First")
        let second = list("Second")
        document.lists = [first, second]
        document.handleFocus(id: first.id, mode: .block, access: .approved) { _, _ in }
        XCTAssertEqual(document.active?.listID, first.id)
        document.handleFocus(id: second.id, mode: .allow, access: .approved) { _, _ in }
        XCTAssertEqual(document.active?.listID, second.id)
        XCTAssertEqual(document.active?.mode, .allow)
        document.handleFocus(id: UUID(), mode: .block, access: .approved) { _, _ in }
        XCTAssertNil(document.active)
        XCTAssertNotNil(document.lastError)
    }

    func testInvalidFocusAndDeniedAuthorizationClearPolicy() throws {
        var document = LibraryDocument()
        let saved = list()
        document.lists = [saved]
        try document.activate(ActivePolicy(listID: saved.id, mode: .block, origin: .manual)) { _, _ in }
        document.handleFocus(id: saved.id, mode: .allow, access: .approved) { _, _ in
            throw DumboError.message("Invalid selection")
        }
        XCTAssertNil(document.active)
        XCTAssertTrue(document.lastError?.contains("Invalid selection") == true)
        document.handleFocus(id: saved.id, mode: .block, access: .denied) { _, _ in XCTFail("Must not validate without permission") }
        XCTAssertNil(document.active)
        XCTAssertFalse(document.lists[0].selectionValid)
    }

    func testFailedManualActivationDoesNotReplaceExistingPolicy() throws {
        var document = LibraryDocument()
        let saved = list()
        document.lists = [saved]
        let previous = ActivePolicy(listID: saved.id, mode: .block, origin: .manual)
        try document.activate(previous) { _, _ in }
        XCTAssertThrowsError(try document.activate(ActivePolicy(listID: saved.id, mode: .allow, origin: .manual)) { _, _ in
            throw DumboError.message("Too many exceptions")
        })
        XCTAssertEqual(document.active, previous)
    }

    func testUnknownStartupAccessDoesNotInvalidateSavedListsOrPolicy() throws {
        var document = LibraryDocument()
        let saved = list()
        document.lists = [saved]
        let policy = ActivePolicy(listID: saved.id, mode: .block, origin: .manual)
        try document.activate(policy) { _, _ in }
        document.observeAccess(.unknown)
        XCTAssertTrue(document.lists[0].selectionValid)
        XCTAssertEqual(document.active, policy)
        XCTAssertTrue(document.wasAuthorized)
        document.observeAccess(.approved)
        XCTAssertTrue(document.lists[0].selectionValid)
    }

    func testFocusResetWithUnknownPermissionPreservesManualOverride() throws {
        var document = LibraryDocument()
        let saved = list()
        document.lists = [saved]
        let policy = ActivePolicy(listID: saved.id, mode: .block, origin: .manual)
        try document.activate(policy) { _, _ in }
        document.handleFocus(id: nil, mode: .block, access: .unknown) { _, _ in
            XCTFail("A reset must not validate a selection")
        }
        XCTAssertEqual(document.active, policy)
        XCTAssertTrue(document.lists[0].selectionValid)
    }

    func testUnknownFocusActivationDoesNotInvalidateAppSelections() {
        var document = LibraryDocument()
        let saved = list()
        document.lists = [saved]
        document.handleFocus(id: saved.id, mode: .block, access: .unknown) { _, _ in
            XCTFail("Unconfirmed access must not activate a policy")
        }
        XCTAssertTrue(document.lists[0].selectionValid)
        XCTAssertNil(document.active)
        XCTAssertNotNil(document.lastError)
    }

    func testConfirmedDenialStillInvalidatesSelections() {
        var document = LibraryDocument()
        document.lists = [list()]
        document.wasAuthorized = true
        document.observeAccess(.denied)
        XCTAssertFalse(document.lists[0].selectionValid)
        XCTAssertFalse(document.wasAuthorized)
    }

    func testRestoredAccessClearsStaleWarningWithoutRevalidatingTokens() {
        var document = LibraryDocument()
        document.lists = [list()]
        document.revoke()
        XCTAssertEqual(document.lastError, LibraryDocument.revokedAccessMessage)
        document.observeAccess(.approved)
        XCTAssertNil(document.lastError)
        XCTAssertTrue(document.wasAuthorized)
        XCTAssertFalse(document.lists[0].selectionValid)
    }

    func testApprovedAccessPreservesUnrelatedFocusError() {
        var document = LibraryDocument()
        document.lastError = "The Focus list no longer exists."
        document.observeAccess(.approved)
        XCTAssertEqual(document.lastError, "The Focus list no longer exists.")
    }

    func testFocusStopThenContinuePreservesModeAndOwnership() throws {
        var document = LibraryDocument()
        let saved = list()
        document.lists = [saved]
        document.handleFocus(id: saved.id, mode: .allow, access: .approved) { _, _ in }
        let expected = document.active
        document.stop()
        XCTAssertNil(document.active)
        XCTAssertEqual(document.pausedFocusPolicy, expected)
        try document.continueFocus { _, _ in }
        XCTAssertEqual(document.active, expected)
        XCTAssertEqual(document.active?.origin, .focus)
        XCTAssertNil(document.pausedFocusPolicy)
    }

    func testPausedFocusSurvivesRepositoryReloadWithoutRestarting() throws {
        let directory = temporaryDirectory()
        let saved = list()
        try LibraryRepository(directory: directory).update {
            $0.lists = [saved]
            $0.handleFocus(id: saved.id, mode: .block, access: .approved) { _, _ in }
            $0.stop()
        }
        let restored = try LibraryRepository(directory: directory).read()
        XCTAssertNil(restored.active)
        XCTAssertEqual(restored.pausedFocusPolicy?.listID, saved.id)
        XCTAssertEqual(restored.pausedFocusPolicy?.origin, .focus)
    }

    func testContinueUsesLatestListEditsWithoutActivatingWhilePaused() throws {
        var document = LibraryDocument()
        let saved = list()
        document.lists = [saved]
        document.handleFocus(id: saved.id, mode: .block, access: .approved) { _, _ in }
        document.stop()
        document.lists[0].selectionData = Data([9, 8, 7])
        document.lists[0].name = "Renamed"
        XCTAssertNil(document.active)
        var received: SavedAppList?
        try document.continueFocus { list, _ in received = list }
        XCTAssertEqual(received?.selectionData, Data([9, 8, 7]))
        XCTAssertEqual(received?.name, "Renamed")
        XCTAssertEqual(document.active?.listID, saved.id)
    }

    func testFocusResetRemovesPausedContinuation() throws {
        var document = LibraryDocument()
        let saved = list()
        document.lists = [saved]
        document.handleFocus(id: saved.id, mode: .block, access: .approved) { _, _ in }
        document.stop()
        document.handleFocus(id: nil, mode: .block, access: .unknown) { _, _ in XCTFail("Reset must not validate") }
        XCTAssertNil(document.active)
        XCTAssertNil(document.focusPolicy)
        XCTAssertThrowsError(try document.continueFocus { _, _ in })
    }

    func testFocusSwitchReplacesPausedContext() throws {
        var document = LibraryDocument()
        let first = list("First")
        let second = list("Second")
        document.lists = [first, second]
        document.handleFocus(id: first.id, mode: .block, access: .approved) { _, _ in }
        document.stop()
        document.handleFocus(id: second.id, mode: .allow, access: .approved) { _, _ in }
        XCTAssertEqual(document.active?.listID, second.id)
        XCTAssertEqual(document.focusPolicy?.listID, second.id)
        document.stop()
        try document.continueFocus { _, _ in }
        XCTAssertEqual(document.active, ActivePolicy(listID: second.id, mode: .allow, origin: .focus))
    }

    func testManualOnlyStopOffersNoFocusContinuation() throws {
        var document = LibraryDocument()
        let saved = list()
        document.lists = [saved]
        try document.activate(ActivePolicy(listID: saved.id, mode: .block, origin: .manual)) { _, _ in }
        document.stop()
        XCTAssertNil(document.pausedFocusPolicy)
        XCTAssertThrowsError(try document.continueFocus { _, _ in })
    }

    func testStoppingManualOverrideCanReturnToCurrentFocus() throws {
        var document = LibraryDocument()
        let focus = list("Focus")
        let manual = list("Manual")
        document.lists = [focus, manual]
        document.handleFocus(id: focus.id, mode: .allow, access: .approved) { _, _ in }
        try document.activate(ActivePolicy(listID: manual.id, mode: .block, origin: .manual)) { _, _ in }
        XCTAssertEqual(document.focusPolicy?.listID, focus.id)
        document.stop()
        try document.continueFocus { _, _ in }
        XCTAssertEqual(document.active, ActivePolicy(listID: focus.id, mode: .allow, origin: .focus))
        try document.activate(ActivePolicy(listID: manual.id, mode: .block, origin: .manual)) { _, _ in }
        document.resetFocus()
        XCTAssertEqual(document.active?.origin, .manual)
        document.stop()
        XCTAssertNil(document.pausedFocusPolicy)
    }

    func testRevocationAndDeletionRemovePausedContext() throws {
        var document = LibraryDocument()
        let saved = list()
        document.lists = [saved]
        document.handleFocus(id: saved.id, mode: .block, access: .approved) { _, _ in }
        document.stop()
        var revoked = document
        revoked.observeAccess(.denied)
        XCTAssertNil(revoked.focusPolicy)
        XCTAssertThrowsError(try revoked.continueFocus { _, _ in })
        try document.delete(saved.id)
        XCTAssertNil(document.focusPolicy)
        XCTAssertTrue(document.lists.isEmpty)
        XCTAssertThrowsError(try document.continueFocus { _, _ in })
    }

    func testInvalidContinueDoesNotApplyOrForgetPausedPolicy() throws {
        var document = LibraryDocument()
        let saved = list()
        document.lists = [saved]
        document.handleFocus(id: saved.id, mode: .allow, access: .approved) { _, _ in }
        document.stop()
        let previous = document.focusPolicy
        XCTAssertThrowsError(try document.continueFocus { _, _ in
            throw DumboError.message("The edited allow-list is empty")
        })
        XCTAssertNil(document.active)
        XCTAssertEqual(document.focusPolicy, previous)
    }

    func testFailedNewFocusDiscardsOldContinuation() {
        var document = LibraryDocument()
        let saved = list()
        document.lists = [saved]
        document.handleFocus(id: saved.id, mode: .block, access: .approved) { _, _ in }
        document.stop()
        document.handleFocus(id: UUID(), mode: .block, access: .approved) { _, _ in }
        XCTAssertNil(document.focusPolicy)
        XCTAssertNil(document.active)
        XCTAssertNotNil(document.lastError)
    }

    func testContinueAfterResetReadsCurrentStateUnderRepositoryLock() throws {
        let directory = temporaryDirectory()
        let repository = LibraryRepository(directory: directory)
        let saved = list()
        try repository.update {
            $0.lists = [saved]
            $0.handleFocus(id: saved.id, mode: .block, access: .approved) { _, _ in }
            $0.stop()
        }
        XCTAssertNotNil(try repository.read().pausedFocusPolicy)
        // Simulate an extension reset after the app rendered its Continue button.
        try LibraryRepository(directory: directory).update { $0.resetFocus() }
        var applied = false
        XCTAssertThrowsError(try repository.update({ try $0.continueFocus { _, _ in } }, afterSave: { _ in applied = true }))
        XCTAssertFalse(applied)
        XCTAssertNil(try repository.read().active)
    }

    func testOldActiveFocusDocumentInfersContinuationOnLoad() throws {
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var oldDocument = LibraryDocument()
        let saved = list()
        oldDocument.lists = [saved]
        oldDocument.active = ActivePolicy(listID: saved.id, mode: .allow, origin: .focus)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(oldDocument)) as? [String: Any])
        json.removeValue(forKey: "focusPolicy")
        try JSONSerialization.data(withJSONObject: json).write(to: directory.appendingPathComponent("library.json"))
        let repository = LibraryRepository(directory: directory)
        let restored = try repository.read()
        XCTAssertEqual(restored.focusPolicy, restored.active)
        try repository.update { $0.stop() }
        let paused = try repository.read()
        XCTAssertEqual(paused.pausedFocusPolicy?.listID, saved.id)
        XCTAssertNil(paused.active)
    }

    func testOldInactiveDocumentDoesNotInventAContinuation() throws {
        let document = try JSONDecoder().decode(LibraryDocument.self, from: JSONEncoder().encode(LibraryDocument()))
        XCTAssertNil(document.focusPolicy)
        XCTAssertNil(document.pausedFocusPolicy)
    }

    private func plan(_ tokens: Set<String>, _ mode: PolicyMode) throws -> ShieldPlan<String> {
        try ShieldPlan(applications: tokens, categoryCount: 0, webCount: 0, valid: true, mode: mode)
    }
}

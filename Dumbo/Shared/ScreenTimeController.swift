import Foundation
import FamilyControls
import ManagedSettings

@MainActor
final class ScreenTimeController {
    static let groupID = "group.com.afakeman.dumbo"
    private let store = ManagedSettingsStore(named: .init("dumbo-policy"))
    private let repository: LibraryRepository

    init() throws {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.groupID) else {
            throw DumboError.message("Shared storage is unavailable. Check Dumbo's App Group signing configuration.")
        }
        repository = LibraryRepository(directory: container.appendingPathComponent("Library", isDirectory: true))
    }

    var access: ScreenTimeAccess {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved: return .approved
        case .denied: return .denied
        default: return .unknown
        }
    }

    var authorized: Bool { access == .approved }

    func refresh() throws -> LibraryDocument {
        // The initial unknown state must not clear a previously active policy.
        // The OS removes enforcement itself if the user actually revokes access.
        if access == .denied { store.clearAllSettings() }
        return try repository.update({ document in
            document.observeAccess(access)
            if let policy = document.active {
                do { _ = try plan(for: policy, in: document) }
                catch { document.active = nil; document.lastError = error.localizedDescription }
            }
        }, afterSave: { if access != .unknown { apply($0) } })
    }

    func save(id: UUID, name: String, selection: FamilyActivitySelection) throws -> LibraryDocument {
        guard authorized else { throw DumboError.message("Allow Screen Time access before selecting apps.") }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DumboError.message("Give this list a name.") }
        _ = try makePlan(selection, valid: true, mode: .block)
        let data = try JSONEncoder().encode(selection)
        return try repository.update({ document in
            let saved = SavedAppList(id: id, name: trimmed, selectionData: data,
                                     applicationCount: selection.applicationTokens.count)
            if let index = document.lists.firstIndex(where: { $0.id == id }) { document.lists[index] = saved }
            else { document.lists.append(saved) }
            if let policy = document.active { _ = try plan(for: policy, in: document) }
            document.lastError = nil
        }, afterSave: { apply($0) })
    }

    func delete(_ id: UUID) throws -> LibraryDocument {
        try repository.update { try $0.delete(id) }
    }

    func activate(_ id: UUID, mode: PolicyMode, origin: PolicyOrigin) throws -> LibraryDocument {
        guard authorized else { throw DumboError.message("Allow Screen Time access before activating a policy.") }
        return try repository.update({ document in
            try document.activate(ActivePolicy(listID: id, mode: mode, origin: origin)) { list, mode in
                _ = try plan(for: list, mode: mode)
            }
        }, afterSave: { apply($0) })
    }

    func stop() throws -> LibraryDocument {
        // Always offer a way out, including when the shared document is unreadable.
        store.clearAllSettings()
        return try repository.update({ $0.active = nil; $0.lastError = nil }, afterSave: { apply($0) })
    }

    func handleFocus(id: UUID?, mode: PolicyMode) async throws {
        // Initialize AuthorizationCenter in this extension process before deciding
        // whether access is denied. Previously granted authorization needs no prompt.
        // Reset itself does not need permission and must not overwrite a manual policy.
        if id != nil, access == .unknown {
            do { try await AuthorizationCenter.shared.requestAuthorization(for: .individual) }
            catch {
                try recordFocusAccessFailure(error)
                throw error
            }
        }
        do {
            let result = try repository.update({ document in
                document.handleFocus(id: id, mode: mode, access: access) { list, mode in
                    _ = try plan(for: list, mode: mode)
                }
            }, afterSave: { document in
                if id == nil {
                    if document.active == nil { store.clearAllSettings() }
                    // A later manual policy is already applied. Do not recheck
                    // this extension's uninitialized permission state to reset it.
                } else { apply(document) }
            })
            if id != nil, let message = result.lastError { throw DumboError.message(message) }
        } catch {
            store.clearAllSettings()
            throw error
        }
    }

    private func recordFocusAccessFailure(_ error: Error) throws {
        store.clearAllSettings()
        try repository.update { document in
            if access == .denied { document.revoke() }
            else { document.active = nil }
            document.lastError = "Focus access could not be confirmed. Open Dumbo to allow Screen Time access. \(error.localizedDescription)"
        }
    }

    private func plan(for policy: ActivePolicy, in document: LibraryDocument) throws -> ShieldPlan<ApplicationToken> {
        guard let list = document.lists.first(where: { $0.id == policy.listID }) else {
            throw DumboError.message("The selected list no longer exists.")
        }
        return try plan(for: list, mode: policy.mode)
    }

    private func plan(for list: SavedAppList, mode: PolicyMode) throws -> ShieldPlan<ApplicationToken> {
        let selection = try JSONDecoder().decode(FamilyActivitySelection.self, from: list.selectionData)
        return try makePlan(selection, valid: list.selectionValid, mode: mode)
    }

    private func makePlan(_ selection: FamilyActivitySelection, valid: Bool, mode: PolicyMode) throws -> ShieldPlan<ApplicationToken> {
        try ShieldPlan(applications: selection.applicationTokens, categoryCount: selection.categoryTokens.count,
                       webCount: selection.webDomainTokens.count, valid: valid, mode: mode)
    }

    private func apply(_ document: LibraryDocument) {
        guard authorized, let active = document.active, let plan = try? plan(for: active, in: document) else {
            store.clearAllSettings()
            return
        }
        store.shield.applications = plan.applications
        store.shield.applicationCategories = plan.allowExceptions.map { .all(except: $0) }
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
    }
}

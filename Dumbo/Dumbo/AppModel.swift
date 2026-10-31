import SwiftUI
import Combine
import FamilyControls
import ManagedSettings

struct ListDraft: Identifiable {
    var id: UUID
    var name: String
    var selection: FamilyActivitySelection
}

@MainActor
final class AppModel: ObservableObject {
    @Published var document = LibraryDocument()
    @Published var error: String?
    @Published var requestingAccess = false
    @Published var ready = false
    @Published var draft: ListDraft?
    @Published var authorized = false
    private var controller: ScreenTimeController?
    private var attemptedPermissionRestore = false

    func refresh() {
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
        do {
            if controller == nil { controller = try ScreenTimeController() }
            document = try controller!.refresh()
            ready = true
            if document.wasAuthorized, !authorized, !attemptedPermissionRestore {
                attemptedPermissionRestore = true
                Task { await requestAccess() }
            }
        } catch {
            ready = false
            self.error = "The library could not be loaded. \(error.localizedDescription)"
        }
    }

    func requestAccess() async {
        guard !requestingAccess else { return }
        attemptedPermissionRestore = true
        requestingAccess = true
        defer { requestingAccess = false }
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refresh()
        } catch { self.error = error.localizedDescription; refresh() }
    }

    func edit(_ list: SavedAppList?) {
        do {
            let selection: FamilyActivitySelection
            if let list, list.selectionValid {
                selection = try JSONDecoder().decode(FamilyActivitySelection.self, from: list.selectionData)
            } else { selection = FamilyActivitySelection() }
            draft = ListDraft(id: list?.id ?? UUID(), name: list?.name ?? "", selection: selection)
        } catch { self.error = "This list cannot be opened: \(error.localizedDescription)" }
    }

    func save(_ draft: ListDraft) -> Bool {
        perform { try $0.save(id: draft.id, name: draft.name, selection: draft.selection) }
    }

    func activate(_ list: SavedAppList, mode: PolicyMode) {
        _ = perform { try $0.activate(list.id, mode: mode, origin: .manual) }
    }

    func delete(_ list: SavedAppList) { _ = perform { try $0.delete(list.id) } }

    func stop() {
        // Clearing is still available even if the library or App Group cannot be read.
        ManagedSettingsStore(named: .init("dumbo-policy")).clearAllSettings()
        if !perform({ try $0.stop() }) {
            error = "Dumbo's restrictions were cleared, but its saved status could not be updated. \(error ?? "")"
        }
    }

    private func perform(_ action: (ScreenTimeController) throws -> LibraryDocument) -> Bool {
        do {
            guard let controller else { throw DumboError.message("Shared storage is unavailable. Try loading the library again.") }
            document = try action(controller)
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
}

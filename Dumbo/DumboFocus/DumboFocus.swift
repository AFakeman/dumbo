import AppIntents
import Foundation

enum FocusPolicyMode: String, AppEnum {
    case block, allow
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Blocking mode" }
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] {
        [.block: "Block listed apps", .allow: "Allow only listed apps"]
    }
}

struct AppListEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "App list" }
    static var defaultQuery: AppListQuery { AppListQuery() }
    let id: UUID
    let name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct AppListQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [AppListEntity] {
        let lists = try await savedLists()
        // Retain unknown IDs so a deleted configured list reaches perform() as
        // an invalid reference rather than being mistaken for Focus deactivation.
        return identifiers.map { id in
            AppListEntity(id: id, name: lists.first(where: { $0.id == id }).map(displayName) ?? "Unavailable list")
        }
    }

    func suggestedEntities() async throws -> [AppListEntity] {
        try await savedLists().map { AppListEntity(id: $0.id, name: displayName($0)) }
    }

    private func displayName(_ list: SavedAppList) -> String {
        list.selectionValid ? list.name : "\(list.name) — select apps again in Dumbo"
    }

    @MainActor
    private func savedLists() throws -> [SavedAppList] {
        // Reading entities must not apply or reset restrictions.
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ScreenTimeController.groupID) else {
            throw DumboError.message("Dumbo's shared app lists are unavailable.")
        }
        return try LibraryRepository(directory: container.appendingPathComponent("Library")).read().lists
    }
}

struct DumboFocus: SetFocusFilterIntent {
    static var title: LocalizedStringResource { "App access" }
    static var description: IntentDescription { "Apply a saved Dumbo app list when this Focus is active." }

    @Parameter(title: "App list") var list: AppListEntity?
    @Parameter(title: "Mode", default: .block) var mode: FocusPolicyMode

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(list?.name ?? "No app list")", subtitle: "\(mode == .block ? "Block listed apps" : "Allow only listed apps")")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try await ScreenTimeController().handleFocus(id: list?.id, mode: mode == .block ? .block : .allow)
        return .result()
    }
}

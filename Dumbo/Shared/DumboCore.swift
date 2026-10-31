import Foundation
import Darwin

// These types contain no app identities. Selection data contains only Apple's opaque tokens.
enum PolicyMode: String, Codable, CaseIterable, Identifiable {
    case block, allow
    var id: Self { self }
    var title: String { self == .block ? "Block listed apps" : "Allow only listed apps" }
}

enum PolicyOrigin: String, Codable { case manual, focus }

// Unknown at process startup is not evidence that permission was revoked.
enum ScreenTimeAccess { case unknown, approved, denied }

struct SavedAppList: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var selectionData: Data
    var applicationCount: Int
    var selectionValid: Bool = true
}

struct ActivePolicy: Codable, Equatable {
    var listID: UUID
    var mode: PolicyMode
    var origin: PolicyOrigin
}

struct LibraryDocument: Codable, Equatable {
    static let revokedAccessMessage = "Screen Time access was removed. Allow access again and select apps afresh."

    var version = 1
    var lists: [SavedAppList] = []
    var active: ActivePolicy?
    var lastError: String?
    var wasAuthorized = false
    var updatedAt = Date()

    mutating func activate(_ policy: ActivePolicy, validate: (SavedAppList, PolicyMode) throws -> Void) throws {
        guard let list = lists.first(where: { $0.id == policy.listID }) else {
            throw DumboError.message("The selected list no longer exists.")
        }
        try validate(list, policy.mode)
        active = policy
        wasAuthorized = true
        lastError = nil
    }

    mutating func observeAccess(_ access: ScreenTimeAccess) {
        switch access {
        case .unknown: break
        case .approved:
            wasAuthorized = true
            if lastError == Self.revokedAccessMessage { lastError = nil }
        case .denied: revoke()
        }
    }

    mutating func handleFocus(id: UUID?, mode: PolicyMode, access: ScreenTimeAccess,
                              validate: (SavedAppList, PolicyMode) throws -> Void) {
        // A reset needs no authorization lookup and must preserve a later manual policy.
        guard let id else { resetFocus(); return }
        guard access == .approved else {
            if access == .denied { revoke() }
            else {
                active = nil
                lastError = "Screen Time access could not be confirmed. Open Dumbo to allow access."
            }
            return
        }
        do {
            try activate(ActivePolicy(listID: id, mode: mode, origin: .focus), validate: validate)
        } catch {
            active = nil
            lastError = "Focus policy could not be applied: \(error.localizedDescription) Reconfigure its Dumbo filter."
        }
    }

    mutating func resetFocus() {
        if active?.origin == .focus { active = nil; lastError = nil }
    }

    mutating func revoke() {
        active = nil
        wasAuthorized = false
        for index in lists.indices { lists[index].selectionValid = false }
        lastError = Self.revokedAccessMessage
    }

    mutating func delete(_ id: UUID) throws {
        guard active?.listID != id else { throw DumboError.message("Stop the active policy before deleting its list.") }
        lists.removeAll { $0.id == id }
    }
}

enum DumboError: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let text): return text } }
}

struct ShieldPlan<Token: Hashable> {
    let applications: Set<Token>?
    let allowExceptions: Set<Token>?

    init(applications: Set<Token>, categoryCount: Int, webCount: Int, valid: Bool, mode: PolicyMode) throws {
        guard valid else { throw DumboError.message("Select apps again for this list before activating it.") }
        guard categoryCount == 0, webCount == 0 else {
            throw DumboError.message("Select individual apps only. Categories and websites are not supported in this prototype.")
        }
        if mode == .allow {
            guard !applications.isEmpty else { throw DumboError.message("An allow-list needs at least one app.") }
            guard applications.count <= 50 else { throw DumboError.message("An allow-list supports at most 50 apps.") }
            self.applications = nil
            allowExceptions = applications
        } else {
            self.applications = applications.isEmpty ? nil : applications
            allowExceptions = nil
        }
    }
}

/// A stable sidecar lock serializes readers and read-modify-write operations across
/// the app and extension. Locking the JSON itself would break on atomic replacement.
final class LibraryRepository {
    let directory: URL
    private let writer: (Data, URL) throws -> Void

    init(directory: URL, writer: @escaping (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }) {
        self.directory = directory
        self.writer = writer
    }

    func read() throws -> LibraryDocument {
        try locked { try load() }
    }

    @discardableResult
    func update(_ change: (inout LibraryDocument) throws -> Void,
                afterSave: (LibraryDocument) -> Void = { _ in }) throws -> LibraryDocument {
        try locked {
            var document = try load()
            try change(&document)
            document.updatedAt = Date()
            let data = try JSONEncoder().encode(document)
            try writer(data, directory.appendingPathComponent("library.json"))
            // Keep policy side effects in the same lock as the state commit so a
            // later Focus event cannot be overwritten by an earlier UI operation.
            afterSave(document)
            return document
        }
    }

    private func load() throws -> LibraryDocument {
        let file = directory.appendingPathComponent("library.json")
        do {
            let document = try JSONDecoder().decode(LibraryDocument.self, from: Data(contentsOf: file))
            guard document.version == 1 else { throw DumboError.message("This library was saved by a newer Dumbo version.") }
            return document
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return LibraryDocument()
        }
    }

    private func locked<T>(_ operation: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent("library.lock").path
        let descriptor = Darwin.open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw DumboError.message("Could not open the shared library lock.") }
        defer { Darwin.close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw DumboError.message("Could not lock the shared library.") }
        defer { flock(descriptor, LOCK_UN) }
        return try operation()
    }
}

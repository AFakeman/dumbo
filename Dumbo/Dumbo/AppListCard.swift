import SwiftUI
import FamilyControls
import ManagedSettings

struct AppListCard: View {
    let list: SavedAppList
    let activePolicy: ActivePolicy?
    let canManage: Bool
    let edit: () -> Void
    let activate: (PolicyMode) -> Void
    let stop: () -> Void

    @State private var mode: PolicyMode = .block
    private let preview: AppListPreview

    init(list: SavedAppList, activePolicy: ActivePolicy?, canManage: Bool,
         edit: @escaping () -> Void, activate: @escaping (PolicyMode) -> Void,
         stop: @escaping () -> Void) {
        self.list = list
        self.activePolicy = activePolicy
        self.canManage = canManage
        self.edit = edit
        self.activate = activate
        self.stop = stop
        preview = AppListPreview(list: list)
    }

    private var isActive: Bool { activePolicy?.listID == list.id }
    private var canStop: Bool { isActive && activePolicy?.mode == mode }
    private var actionTitle: String {
        if canStop { return activePolicy?.origin == .focus ? "Pause" : "Stop" }
        return isActive ? "Apply" : "Start"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Button(action: edit) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(list.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Text(detailText)
                            .font(.caption)
                            .foregroundStyle(isActive ? Color.indigo : Color.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canManage)
                .accessibilityHint("Edit the list name and selected apps")

                if list.selectionValid, let tokens = preview.tokens, !tokens.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(tokens, id: \.self) { token in
                            Label(token)
                                .labelStyle(.iconOnly)
                                .frame(width: 24, height: 28)
                        }
                        if preview.remaining > 0 {
                            Text("+\(preview.remaining)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .frame(minHeight: 28)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                                .accessibilityLabel("\(preview.remaining) more selected apps")
                        }
                    }
                    .fixedSize()
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(mode == .block ? "Apps to block" : "Apps to allow")
                }

                Button(action: edit) {
                    Image(systemName: "pencil")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canManage)
                .accessibilityLabel("Edit \(list.name)")
            }

            HStack(spacing: 10) {
                HStack(spacing: 0) {
                    ForEach(PolicyMode.allCases) { option in
                        Button {
                            mode = option
                        } label: {
                            Text(option == .block ? "Block" : "Allow")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(mode == option ? Color.indigo : Color.secondary)
                                .background(mode == option ? Color.indigo.opacity(0.2) : Color.clear, in: Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.title)
                        .accessibilityAddTraits(mode == option ? .isSelected : [])
                    }
                }
                .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                .disabled(!canManage || !list.selectionValid)
                .opacity(canManage && list.selectionValid ? 1 : 0.45)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Mode for \(list.name)")

                Button {
                    if canStop { stop() }
                    else { activate(mode) }
                } label: {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 44)
                        .background(.indigo, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canStop && (!canManage || !list.selectionValid || preview.tokens == nil))
                .opacity(canStop || (canManage && list.selectionValid && preview.tokens != nil) ? 1 : 0.45)
                .accessibilityLabel(canStop ? "\(actionTitle) restrictions" : "\(actionTitle) \(mode.title.lowercased()) for \(list.name)")
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.indigo.opacity(0.4), lineWidth: 1)
            }
        }
        .onAppear { synchronizeMode() }
        .onChange(of: activePolicy) { _, _ in synchronizeMode() }
    }

    private var detailText: String {
        guard list.selectionValid else { return "Select apps again" }
        guard preview.tokens != nil else { return "App preview unavailable" }
        return isActive ? "\(preview.countText) · Active" : preview.countText
    }

    private func synchronizeMode() {
        if isActive, let activePolicy { mode = activePolicy.mode }
    }
}

private struct AppListPreview {
    let tokens: [ApplicationToken]?
    let total: Int
    var remaining: Int { max(0, total - (tokens?.count ?? 0)) }
    var countText: String { total == 1 ? "1 app" : "\(total) apps" }

    init(list: SavedAppList) {
        total = list.applicationCount
        guard list.selectionValid else { tokens = nil; return }
        do {
            let selection = try JSONDecoder().decode(FamilyActivitySelection.self, from: list.selectionData)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            // A token set has no user-defined order. Sort its opaque representation
            // for a stable preview without trying to extract application identities.
            let sorted = try selection.applicationTokens.map { token in
                (token: token, key: try encoder.encode(token))
            }.sorted { $0.key.lexicographicallyPrecedes($1.key) }
            tokens = sorted.prefix(3).map(\.token)
        } catch {
            tokens = nil
        }
    }
}

import SwiftUI
import FamilyControls

struct ContentView: View {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var showsActivePolicy: Bool {
        model.document.active != nil && model.authorized && model.ready
    }

    private var policyTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: .opacity.combined(with: .offset(y: -12)),
            removal: .opacity
        )
    }

    var body: some View {
        NavigationStack {
            List {
                if !model.authorized {
                    Section("Screen Time access") {
                        Text("Dumbo needs your permission to select and block apps on this iPhone. Your app lists stay on this device.")
                        Button {
                            Task { await model.requestAccess() }
                        } label: {
                            if model.requestingAccess { ProgressView() }
                            else { Text("Allow Screen Time access") }
                        }
                        .disabled(model.requestingAccess)
                        if AuthorizationCenter.shared.authorizationStatus == .denied {
                            Text("Access was denied. Allow Screen Time access to use app blocking.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                if let policy = model.document.active, model.authorized, model.ready {
                    Section {
                        ActivePolicyCard(
                            name: model.document.lists.first { $0.id == policy.listID }?.name ?? "Unavailable list",
                            policy: policy,
                            stop: { model.stop() }
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .transition(policyTransition)
                    } header: {
                        Text("App access")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(minHeight: 44, alignment: .leading)
                            .textCase(nil)
                            .transition(.opacity)
                    }
                    .id("active-policy-section")
                }
                if !model.ready {
                    Section("Library unavailable") {
                        Button("Try loading library again") { model.refresh() }
                        Button("Stop restrictions", role: .destructive) { model.stop() }
                    }
                }
                if let message = model.document.lastError {
                    Section {
                        Text(message).font(.footnote).foregroundStyle(.orange)
                    }
                }
                Section {
                    if model.authorized, model.document.lists.contains(where: { !$0.selectionValid }) {
                        Text("Screen Time access is enabled. Open each list marked “Select apps again”, choose its apps, and save to restore it.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if model.document.lists.isEmpty {
                        ContentUnavailableView("Your first app list", systemImage: "square.stack.3d.up",
                                               description: Text("Group the apps you want to block—or keep available."))
                    }
                    ForEach(model.document.lists) { list in
                        AppListCard(
                            list: list,
                            activePolicy: model.authorized && model.ready ? model.document.active : nil,
                            canManage: model.authorized && model.ready,
                            edit: { model.edit(list) },
                            activate: { mode in model.activate(list, mode: mode) },
                            stop: { model.stop() }
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions {
                            Button("Delete", role: .destructive) { model.delete(list) }
                        }
                    }
                } header: {
                    HStack {
                        Text("App lists")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Button { model.edit(nil) } label: {
                            Image(systemName: "plus")
                                .font(.title3)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .disabled(!model.authorized || !model.ready)
                        .accessibilityLabel("New app list")
                    }
                    .textCase(nil)
                } footer: {
                    Text("Allow-lists support 1–50 apps. Some essential system apps may remain available. Other Screen Time restrictions can still apply.")
                }
            }
            .animation(
                reduceMotion ? .easeInOut(duration: 0.18) : .spring(response: 0.35, dampingFraction: 0.9),
                value: showsActivePolicy
            )
            .navigationTitle("Dumbo")
            .tint(.indigo)
            .sheet(item: $model.draft) { draft in
                ListEditor(draft: draft) { value in
                    if model.save(value) { return nil }
                    let message = model.error ?? "The list could not be saved."
                    model.error = nil
                    return message
                }
            }
            .alert("Dumbo needs attention", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("OK") { model.error = nil }
            } message: { Text(model.error ?? "") }
            .task { model.refresh() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { model.refresh() } }
            .onReceive(AuthorizationCenter.shared.$authorizationStatus) { _ in model.refresh() }
        }
    }
}

private struct ListEditor: View {
    @State var draft: ListDraft
    let save: (ListDraft) -> String?
    @State private var saveError: String?
    @State private var showPicker = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("List name") {
                    TextField("For example, Distractions", text: $draft.name)
                }
                Section {
                    Button("Choose apps", systemImage: "apps.iphone") { showPicker = true }
                    Text("\(draft.selection.applicationTokens.count) apps selected")
                    ForEach(Array(draft.selection.applicationTokens), id: \.self) { token in
                        Label(token)
                    }
                } footer: {
                    Text("Expand categories and choose individual apps. Whole categories and websites aren't supported in this prototype.")
                }
            }
            .navigationTitle("App list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveError = save(draft)
                        if saveError == nil { dismiss() }
                    }
                        .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .familyActivityPicker(isPresented: $showPicker, selection: $draft.selection)
            .alert("Could not save list", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("OK") { saveError = nil }
            } message: { Text(saveError ?? "") }
        }
    }
}

#Preview { ContentView() }

import Contacts
import SwiftUI

/// The parts of the store that sit underneath individual contacts: containers, groups, and the
/// change-tracking surface that Swift can and cannot reach.
struct StoreInspectorView: View {
    @Environment(ContactsModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                containersSection
                groupsSection
                changeTrackingSection
            }
            .navigationTitle("Store")
            .refreshable { await model.reload() }
        }
    }

    private var containersSection: some View {
        Section {
            if model.containers.isEmpty {
                Text("No containers visible.").foregroundStyle(.secondary)
            } else {
                ForEach(model.containers, id: \.identifier) { container in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(container.name.isEmpty ? "Unnamed" : container.name)
                            if container.identifier == model.defaultContainerIdentifier {
                                Text("default")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.tint.opacity(0.15), in: .capsule)
                            }
                        }
                        Text(describe(container.type))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Containers")
        } footer: {
            Text("A container is one account's address book — the local one, an Exchange account, a CardDAV server. Saving without naming a container puts the contact in the default one.")
        }
    }

    private var groupsSection: some View {
        Section {
            if model.groups.isEmpty {
                Text("No groups visible.").foregroundStyle(.secondary)
            } else {
                ForEach(model.groups, id: \.identifier) { group in
                    Text(group.name)
                }
            }
        } header: {
            Text("Groups")
        } footer: {
            Text("iOS has no interface for creating groups, so most devices report none even when the API is working correctly.")
        }
    }

    private var changeTrackingSection: some View {
        Section {
            LabeledContent("Store-change notifications", value: "\(model.storeChangeCount)")
            LabeledContent("History token",
                           value: model.historyToken.map { "\($0.count) bytes" } ?? "none")
        } header: {
            Text("Change tracking")
        } footer: {
            Text("CNContactStoreDidChange says that something changed; the history token moves when it does. Reading what actually changed needs enumeratorForChangeHistoryFetchRequest:error:, which is marked unavailable to Swift and has no overlay replacement, so a pure-Swift app can only detect change, not describe it.")
        }
    }

    private func describe(_ type: CNContainerType) -> String {
        switch type {
        case .local: "Local"
        case .exchange: "Exchange"
        case .cardDAV: "CardDAV"
        case .unassigned: "Unassigned"
        @unknown default: "Unknown"
        }
    }
}

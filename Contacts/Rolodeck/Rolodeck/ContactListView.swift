import Contacts
import SwiftUI

struct ContactListView: View {
    @Environment(ContactsModel.self) private var model
    @State private var isCreating = false

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            Group {
                if !model.canReadContacts {
                    ContentUnavailableView(
                        "No contact access",
                        systemImage: "lock.fill",
                        description: Text(model.authorizationStatus.explanation)
                    )
                } else if model.contacts.isEmpty {
                    ContentUnavailableView(
                        model.searchText.isEmpty ? "Nothing shared yet" : "No matches",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text(model.searchText.isEmpty
                            ? "Use the Access tab to share some contacts with this app."
                            : "No visible contact matches that name.")
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Contacts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New", systemImage: "plus") { isCreating = true }
                        .disabled(!model.canReadContacts)
                }
            }
            .searchable(text: $model.searchText, prompt: "Name")
            .onChange(of: model.searchText) {
                Task { await model.reload() }
            }
            .refreshable { await model.reload() }
            .sheet(isPresented: $isCreating) {
                ContactEditorView(editing: nil)
            }
        }
    }

    private var list: some View {
        List(model.contacts, id: \.identifier) { contact in
            NavigationLink {
                ContactDetailView(identifier: contact.identifier)
            } label: {
                row(for: contact)
            }
        }
        .listStyle(.plain)
        .overlay(alignment: .top) {
            if model.isLoading {
                ProgressView().padding(8)
            }
        }
    }

    private func row(for contact: CNContact) -> some View {
        HStack(spacing: 12) {
            thumbnail(for: contact)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayName(for: contact))
                    .font(.body)

                if let subtitle = subtitle(for: contact) {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if model.recentlyGranted.contains(contact.identifier) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Shared during this launch")
            }
        }
    }

    /// `imageDataAvailable` is the cheap check: it says whether there is a picture without making
    /// the store hand over the bytes.
    @ViewBuilder
    private func thumbnail(for contact: CNContact) -> some View {
        if contact.imageDataAvailable,
           let data = contact.thumbnailImageData,
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(.circle)
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundStyle(.quaternary)
        }
    }

    private func subtitle(for contact: CNContact) -> String? {
        if let phone = contact.phoneNumbers.first {
            return phone.value.stringValue
        }
        if let email = contact.emailAddresses.first {
            return email.value as String
        }
        return contact.organizationName.isEmpty ? nil : contact.organizationName
    }
}

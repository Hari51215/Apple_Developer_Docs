import Contacts
import ContactsUI
import SwiftUI

/// The privacy half of the app: what the current authorization status is, and the two ContactsUI
/// affordances that let someone widen a limited grant without a trip to Settings.
struct AccessView: View {
    @Environment(ContactsModel.self) private var model

    @State private var query = ""
    @State private var isPickerPresented = false

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            Form {
                statusSection

                if model.authorizationStatus == .notDetermined {
                    Section {
                        Button("Request access") {
                            Task { await model.requestAccess() }
                        }
                    } footer: {
                        Text("Grant limited access when the prompt appears — that is the state the rest of this screen is built for.")
                    }
                }

                accessButtonSection
                accessPickerSection

                if !model.recentlyGranted.isEmpty {
                    Section("Granted this launch") {
                        Text("\(model.recentlyGranted.count) contact(s) became visible without a new permission prompt.")
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Access")
            .alert("Contacts error", isPresented: .constant(model.errorMessage != nil)) {
                Button("OK") { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
    }

    private var statusSection: some View {
        Section("Authorization status") {
            LabeledContent("Status", value: model.authorizationStatus.label)
            Text(model.authorizationStatus.explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
            LabeledContent("Visible contacts", value: "\(model.contacts.count)")
        }
    }

    /// `ContactAccessButton` renders nothing at all under full access, so the surrounding copy has
    /// to make sense when the button is invisible.
    private var accessButtonSection: some View {
        Section {
            TextField("Search all contacts on this device", text: $query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()

            ContactAccessButton(queryString: query) { identifiers in
                Task { await model.absorbNewlyGranted(identifiers: identifiers) }
            }
            .contactAccessButtonStyle(ContactAccessButton.Style(imageWidth: 28))
            .contactAccessButtonCaption(.phone)
            .frame(maxWidth: .infinity, alignment: .leading)
        } header: {
            Text("Contact access button")
        } footer: {
            Text("Type a name. The button searches contacts this app cannot see yet and grants access to whichever one you tap — no system prompt, no Settings trip. Under full access it disappears.")
        }
    }

    private var accessPickerSection: some View {
        Section {
            Button {
                isPickerPresented = true
            } label: {
                Label("Choose contacts to share", systemImage: "person.crop.circle.badge.plus")
            }
            .contactAccessPicker(isPresented: $isPickerPresented) { identifiers in
                Task { await model.absorbNewlyGranted(identifiers: identifiers) }
            }
        } header: {
            Text("Contact access picker")
        } footer: {
            Text("The picker always sees every contact on the device, whatever this app's status is. It reports back only the identifiers that were newly added — never the ones you took away.")
        }
    }
}

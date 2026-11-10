import Contacts
import SwiftUI

/// Creating and updating both go through `CNMutableContact` and a `CNSaveRequest`; the only
/// difference is `add(_:toContainerWithIdentifier:)` versus `update(_:)`.
struct ContactEditorView: View {
    /// `nil` means "create a new contact".
    let editing: CNContact?

    @Environment(ContactsModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var givenName = ""
    @State private var familyName = ""
    @State private var organizationName = ""
    @State private var jobTitle = ""
    @State private var phone = ""
    @State private var phoneLabel = CNLabelPhoneNumberMobile
    @State private var email = ""
    @State private var emailLabel = CNLabelHome
    @State private var street = ""
    @State private var city = ""
    @State private var postalCode = ""
    @State private var country = ""
    @State private var isSaving = false
    @State private var isConfirmingDelete = false

    private let phoneLabels = [
        CNLabelPhoneNumberMobile, CNLabelPhoneNumberiPhone,
        CNLabelPhoneNumberMain, CNLabelHome, CNLabelWork, CNLabelOther,
    ]
    private let emailLabels = [CNLabelHome, CNLabelWork, CNLabelSchool, CNLabelEmailiCloud, CNLabelOther]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Given name", text: $givenName)
                    TextField("Family name", text: $familyName)
                }

                Section("Work") {
                    TextField("Organization", text: $organizationName)
                    TextField("Job title", text: $jobTitle)
                }

                Section("Phone") {
                    TextField("Number", text: $phone)
                        .keyboardType(.phonePad)
                    labelPicker("Label", selection: $phoneLabel, options: phoneLabels)
                }

                Section("Email") {
                    TextField("Address", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    labelPicker("Label", selection: $emailLabel, options: emailLabels)
                }

                Section("Postal address") {
                    TextField("Street", text: $street)
                    TextField("City", text: $city)
                    TextField("Postal code", text: $postalCode)
                    TextField("Country", text: $country)
                }

                if editing != nil {
                    Section {
                        Button("Delete contact", role: .destructive) {
                            isConfirmingDelete = true
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "New Contact" : "Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isSaving || !hasAnythingToSave)
                }
            }
            .confirmationDialog("Delete this contact?",
                                isPresented: $isConfirmingDelete,
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) { Task { await deleteContact() } }
            } message: {
                Text("This removes the contact from the device, not just from this app.")
            }
            .task { populate() }
        }
    }

    private var hasAnythingToSave: Bool {
        !(givenName.isEmpty && familyName.isEmpty && organizationName.isEmpty)
    }

    private func labelPicker(_ title: String,
                             selection: Binding<String>,
                             options: [String]) -> some View {
        Picker(title, selection: selection) {
            ForEach(options, id: \.self) { label in
                Text(CNLabeledValue<NSString>.localizedString(forLabel: label)).tag(label)
            }
        }
    }

    private func populate() {
        guard let editing else { return }
        givenName = editing.givenName
        familyName = editing.familyName
        organizationName = editing.organizationName
        jobTitle = editing.jobTitle

        if let first = editing.phoneNumbers.first {
            phone = first.value.stringValue
            phoneLabel = first.label ?? CNLabelPhoneNumberMobile
        }
        if let first = editing.emailAddresses.first {
            email = first.value as String
            emailLabel = first.label ?? CNLabelHome
        }
        if let first = editing.postalAddresses.first {
            street = first.value.street
            city = first.value.city
            postalCode = first.value.postalCode
            country = first.value.country
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        // An existing contact is edited through a mutable copy; the original stays immutable.
        let contact: CNMutableContact
        if let editing, let copy = editing.mutableCopy() as? CNMutableContact {
            contact = copy
        } else {
            contact = CNMutableContact()
        }

        contact.givenName = givenName
        contact.familyName = familyName
        contact.organizationName = organizationName
        contact.jobTitle = jobTitle

        contact.phoneNumbers = phone.isEmpty ? [] : [
            CNLabeledValue(label: phoneLabel, value: CNPhoneNumber(stringValue: phone))
        ]
        contact.emailAddresses = email.isEmpty ? [] : [
            CNLabeledValue(label: emailLabel, value: email as NSString)
        ]

        if street.isEmpty && city.isEmpty && postalCode.isEmpty && country.isEmpty {
            contact.postalAddresses = []
        } else {
            let address = CNMutablePostalAddress()
            address.street = street
            address.city = city
            address.postalCode = postalCode
            address.country = country
            contact.postalAddresses = [CNLabeledValue(label: CNLabelHome, value: address)]
        }

        if await model.save(contact, isNew: editing == nil) {
            dismiss()
        }
    }

    private func deleteContact() async {
        guard let editing else { return }
        if await model.delete(editing) {
            dismiss()
        }
    }
}

import Contacts
import SwiftUI

/// Takes an identifier rather than a `CNContact` on purpose: the list rows were fetched with a
/// small key set, and this screen reads properties that set does not include.
struct ContactDetailView: View {
    let identifier: String

    @Environment(ContactsModel.self) private var model
    @State private var contact: CNContact?
    @State private var isEditing = false
    @State private var vCardText: String?
    @State private var roundTripCount: Int?

    private let postalFormatter: CNPostalAddressFormatter = {
        let formatter = CNPostalAddressFormatter()
        formatter.style = .mailingAddress
        return formatter
    }()

    var body: some View {
        Group {
            if let contact {
                List {
                    nameSection(contact)
                    labeledSection("Phone", contact.phoneNumbers) { $0.stringValue }
                    labeledSection("Email", contact.emailAddresses) { $0 as String }
                    postalSection(contact)
                    labeledSection("URL", contact.urlAddresses) { $0 as String }
                    labeledSection("Instant message", contact.instantMessageAddresses) {
                        "\($0.service): \($0.username)"
                    }
                    labeledSection("Social", contact.socialProfiles) {
                        "\($0.service): \($0.username)"
                    }
                    labeledSection("Related", contact.contactRelations) { $0.name }
                    datesSection(contact)
                    vCardSection(contact)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(contact.map { model.displayName(for: $0) } ?? "Contact")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
                    .disabled(contact == nil)
            }
        }
        .sheet(isPresented: $isEditing, onDismiss: load) {
            if let contact {
                ContactEditorView(editing: contact)
            }
        }
        .task { load() }
    }

    private func load() {
        contact = model.detailedContact(withIdentifier: identifier)
    }

    // MARK: - Sections

    private func nameSection(_ contact: CNContact) -> some View {
        Section("Name") {
            LabeledContent("Formatted", value: model.displayName(for: contact))
            LabeledContent("Order", value: model.nameOrderDescription(for: contact))
            LabeledContent("Delimiter",
                           value: CNContactFormatter.delimiter(for: contact)
                               .replacingOccurrences(of: " ", with: "␣"))
            if !contact.nickname.isEmpty {
                LabeledContent("Nickname", value: contact.nickname)
            }
            if !contact.jobTitle.isEmpty {
                LabeledContent("Job title", value: contact.jobTitle)
            }
            if !contact.organizationName.isEmpty {
                LabeledContent("Organization", value: contact.organizationName)
            }
            LabeledContent("Type", value: contact.contactType == .organization ? "Organization" : "Person")
        }
    }

    /// Labels arrive as opaque constants like `_$!<Home>!$_`; only `localizedString(forLabel:)`
    /// turns them into something a person should read.
    private func labeledSection<Value>(
        _ title: String,
        _ values: [CNLabeledValue<Value>],
        display: @escaping (Value) -> String
    ) -> some View {
        Group {
            if !values.isEmpty {
                Section(title) {
                    ForEach(values, id: \.identifier) { labeled in
                        LabeledContent(
                            labeled.label.map { CNLabeledValue<Value>.localizedString(forLabel: $0) } ?? "—",
                            value: display(labeled.value)
                        )
                    }
                }
            }
        }
    }

    private func postalSection(_ contact: CNContact) -> some View {
        Group {
            if !contact.postalAddresses.isEmpty {
                Section("Postal") {
                    ForEach(contact.postalAddresses, id: \.identifier) { labeled in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(labeled.label.map {
                                CNLabeledValue<CNPostalAddress>.localizedString(forLabel: $0)
                            } ?? "—")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            Text(postalFormatter.string(from: labeled.value))
                                .font(.body)
                        }
                    }
                }
            }
        }
    }

    private func datesSection(_ contact: CNContact) -> some View {
        Group {
            if contact.birthday != nil || !contact.dates.isEmpty {
                Section("Dates") {
                    if let birthday = contact.birthday {
                        LabeledContent("Birthday", value: describe(birthday))
                    }
                    ForEach(contact.dates, id: \.identifier) { labeled in
                        LabeledContent(
                            labeled.label.map {
                                CNLabeledValue<NSDateComponents>.localizedString(forLabel: $0)
                            } ?? "—",
                            value: describe(labeled.value as DateComponents)
                        )
                    }
                }
            }
        }
    }

    private func vCardSection(_ contact: CNContact) -> some View {
        Section {
            Button("Export as vCard") {
                guard let data = model.vCardData(for: contact) else { return }
                vCardText = String(data: data, encoding: .utf8)
                roundTripCount = model.contactsFromVCard(data).count
            }

            if let vCardText {
                Text(vCardText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }

            if let roundTripCount {
                LabeledContent("Parsed back", value: "\(roundTripCount) contact(s)")
            }
        } header: {
            Text("vCard")
        } footer: {
            Text("Export refetches the contact against CNContactVCardSerialization's own key descriptor, then parses the bytes straight back to prove the round trip.")
        }
    }

    private func describe(_ components: DateComponents) -> String {
        var parts: [String] = []
        if let year = components.year { parts.append(String(year)) }
        if let month = components.month { parts.append(String(format: "%02d", month)) }
        if let day = components.day { parts.append(String(format: "%02d", day)) }
        return parts.isEmpty ? "—" : parts.joined(separator: "-")
    }
}

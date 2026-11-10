import Contacts
import Observation
import SwiftUI

/// Everything Rolodeck knows about the contact store lives here.
///
/// The store is created once and reused. `CNContactStore` is documented as thread-safe, and its
/// fetch methods do file I/O, so the actual enumeration runs off the main actor and only the
/// finished arrays come back to the UI.
@Observable
final class ContactsModel {

    /// Stamped onto every save so the app can recognise its own writes in change history.
    static let transactionAuthor = "Rolodeck"

    // MARK: - Key descriptors

    /// Enough to draw a row. `CNContactFormatter` is asked which name keys it needs rather than
    /// listing givenName/familyName/prefix/suffix/nickname by hand — the set is locale-dependent.
    static let listKeys: [CNKeyDescriptor] = [
        CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactImageDataAvailableKey as CNKeyDescriptor,
        CNContactThumbnailImageDataKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
    ]

    /// Everything the detail screen and the editor touch. Reading a property that is not in this
    /// list raises `CNContactPropertyNotFetchedException`, which is not catchable from Swift.
    static let detailKeys: [CNKeyDescriptor] = listKeys + [
        CNContactTypeKey as CNKeyDescriptor,
        CNContactNamePrefixKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactMiddleNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactPreviousFamilyNameKey as CNKeyDescriptor,
        CNContactNameSuffixKey as CNKeyDescriptor,
        CNContactNicknameKey as CNKeyDescriptor,
        CNContactPhoneticGivenNameKey as CNKeyDescriptor,
        CNContactPhoneticFamilyNameKey as CNKeyDescriptor,
        CNContactJobTitleKey as CNKeyDescriptor,
        CNContactDepartmentNameKey as CNKeyDescriptor,
        CNContactPostalAddressesKey as CNKeyDescriptor,
        CNContactUrlAddressesKey as CNKeyDescriptor,
        CNContactInstantMessageAddressesKey as CNKeyDescriptor,
        CNContactSocialProfilesKey as CNKeyDescriptor,
        CNContactRelationsKey as CNKeyDescriptor,
        CNContactBirthdayKey as CNKeyDescriptor,
        CNContactNonGregorianBirthdayKey as CNKeyDescriptor,
        CNContactDatesKey as CNKeyDescriptor,
    ]

    // MARK: - Observable state

    private(set) var authorizationStatus: CNAuthorizationStatus = .notDetermined
    private(set) var contacts: [CNContact] = []
    private(set) var containers: [CNContainer] = []
    private(set) var groups: [CNGroup] = []
    private(set) var defaultContainerIdentifier: String?
    private(set) var isLoading = false

    /// Identifiers handed back by the access button or the access picker on this launch.
    private(set) var recentlyGranted: Set<String> = []

    /// Bumped every time `CNContactStoreDidChange` arrives.
    private(set) var storeChangeCount = 0
    private(set) var historyToken: Data?

    var errorMessage: String?
    var searchText = ""

    // MARK: - Private

    private let store = CNContactStore()
    private let nameFormatter: CNContactFormatter = {
        let formatter = CNContactFormatter()
        formatter.style = .fullName
        return formatter
    }()
    private var storeObserver: NSObjectProtocol?

    // MARK: - Authorization

    func refreshAuthorizationStatus() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }

    /// Only meaningful while the status is `.notDetermined`; afterwards the system remembers the
    /// answer and returns it without prompting again.
    func requestAccess() async {
        do {
            _ = try await store.requestAccess(for: .contacts)
        } catch {
            present(error)
        }
        refreshAuthorizationStatus()
        await reload()
    }

    var canReadContacts: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    // MARK: - Loading

    func reload() async {
        guard canReadContacts else {
            contacts = []
            containers = []
            groups = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        let predicate = searchText.isEmpty
            ? nil
            : CNContact.predicateForContacts(matchingName: searchText)
        let order = CNContactsUserDefaults.shared().sortOrder
        let keys = Self.listKeys

        do {
            contacts = try await Task.detached(priority: .userInitiated) { [store] in
                try Self.enumerate(store: store,
                                   predicate: predicate,
                                   keys: keys,
                                   sortOrder: order)
            }.value
        } catch {
            present(error)
        }

        loadContainersAndGroups()
        historyToken = store.currentHistoryToken
    }

    /// The access button and the access picker both hand back identifiers and nothing else, so the
    /// only way to learn anything about the newly shared contacts is to fetch them by identifier.
    func absorbNewlyGranted(identifiers: [String]) async {
        guard !identifiers.isEmpty else { return }
        recentlyGranted.formUnion(identifiers)
        refreshAuthorizationStatus()
        await reload()
    }

    func detailedContact(withIdentifier identifier: String) -> CNContact? {
        do {
            return try store.unifiedContact(withIdentifier: identifier, keysToFetch: Self.detailKeys)
        } catch {
            present(error)
            return nil
        }
    }

    private func loadContainersAndGroups() {
        do {
            containers = try store.containers(matching: nil)
            groups = try store.groups(matching: nil)
            defaultContainerIdentifier = store.defaultContainerIdentifier()
        } catch {
            present(error)
        }
    }

    private nonisolated static func enumerate(
        store: CNContactStore,
        predicate: NSPredicate?,
        keys: [CNKeyDescriptor],
        sortOrder: CNContactSortOrder
    ) throws -> [CNContact] {
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.predicate = predicate
        request.sortOrder = sortOrder
        request.unifyResults = true
        request.mutableObjects = false

        var found: [CNContact] = []
        try store.enumerateContacts(with: request) { contact, _ in
            found.append(contact)
        }
        return found
    }

    // MARK: - Saving

    func save(_ contact: CNMutableContact, isNew: Bool) async -> Bool {
        let request = CNSaveRequest()
        request.transactionAuthor = Self.transactionAuthor
        request.shouldRefetchContacts = false

        if isNew {
            request.add(contact, toContainerWithIdentifier: nil)
        } else {
            request.update(contact)
        }

        do {
            try store.execute(request)
            await reload()
            return true
        } catch {
            present(error)
            return false
        }
    }

    func delete(_ contact: CNContact) async -> Bool {
        guard let mutable = contact.mutableCopy() as? CNMutableContact else { return false }

        let request = CNSaveRequest()
        request.transactionAuthor = Self.transactionAuthor
        request.delete(mutable)

        do {
            try store.execute(request)
            await reload()
            return true
        } catch {
            present(error)
            return false
        }
    }

    // MARK: - vCard

    /// vCard serialisation has its own key requirements, so the contact is refetched against
    /// `descriptorForRequiredKeys()` rather than reusing whatever the detail screen happened to ask for.
    func vCardData(for contact: CNContact) -> Data? {
        do {
            let keys = [CNContactVCardSerialization.descriptorForRequiredKeys()]
            let full = try store.unifiedContact(withIdentifier: contact.identifier, keysToFetch: keys)
            return try CNContactVCardSerialization.data(with: [full])
        } catch {
            present(error)
            return nil
        }
    }

    /// Parses vCard bytes straight back into contacts without touching the store, which is a quick
    /// way to see that the export really round-trips.
    func contactsFromVCard(_ data: Data) -> [CNContact] {
        (try? CNContactVCardSerialization.contacts(with: data)) ?? []
    }

    // MARK: - Store change notifications

    func startObservingStoreChanges() {
        guard storeObserver == nil else { return }
        storeObserver = NotificationCenter.default.addObserver(
            forName: .CNContactStoreDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.storeChangeCount += 1
                self.historyToken = self.store.currentHistoryToken
            }
        }
    }

    // MARK: - Display helpers

    func displayName(for contact: CNContact) -> String {
        if let formatted = nameFormatter.string(from: contact), !formatted.isEmpty {
            return formatted
        }
        if !contact.organizationName.isEmpty { return contact.organizationName }
        return "No Name"
    }

    func nameOrderDescription(for contact: CNContact) -> String {
        switch CNContactFormatter.nameOrder(for: contact) {
        case .givenNameFirst: "given name first"
        case .familyNameFirst: "family name first"
        case .userDefault: "user default"
        @unknown default: "unknown"
        }
    }

    // MARK: - Errors

    private func present(_ error: Error) {
        let nsError = error as NSError
        guard nsError.domain == CNErrorDomain else {
            errorMessage = error.localizedDescription
            return
        }

        var text = "\(Self.describe(code: nsError.code)) — \(nsError.localizedDescription)"
        if let cnError = error as? CNError, let identifiers = cnError.affectedRecordIdentifiers,
           !identifiers.isEmpty {
            text += "\nAffected: \(identifiers.joined(separator: ", "))"
        }
        errorMessage = text
    }

    private static func describe(code: Int) -> String {
        switch CNError.Code(rawValue: code) {
        case .authorizationDenied: "authorizationDenied"
        case .unauthorizedKeys: "unauthorizedKeys"
        case .recordDoesNotExist: "recordDoesNotExist"
        case .insertedRecordAlreadyExists: "insertedRecordAlreadyExists"
        case .recordNotWritable: "recordNotWritable"
        case .noAccessableWritableContainers: "noAccessableWritableContainers"
        case .validationMultipleErrors: "validationMultipleErrors"
        case .policyViolation: "policyViolation"
        case .vCardMalformed: "vCardMalformed"
        default: "CNError \(code)"
        }
    }
}

extension CNAuthorizationStatus {
    var label: String {
        switch self {
        case .notDetermined: "Not determined"
        case .restricted: "Restricted"
        case .denied: "Denied"
        case .authorized: "Full access"
        case .limited: "Limited access"
        @unknown default: "Unknown"
        }
    }

    var explanation: String {
        switch self {
        case .notDetermined:
            "Nobody has been asked yet. The first call that touches contact data triggers the prompt."
        case .restricted:
            "Blocked by a device restriction. Asking again will not help."
        case .denied:
            "Access was refused. Only the Settings app can change this."
        case .authorized:
            "Every contact on the device is readable and writable."
        case .limited:
            "Only contacts that were explicitly shared, plus any this app created itself."
        @unknown default:
            "Unrecognised status."
        }
    }
}

# Rolodeck — Contacts & ContactsUI Sample Project

A buildable SwiftUI sample app demonstrating **Contacts** and **ContactsUI** together: reading the
contact store through key descriptors, handling all five `CNAuthorizationStatus` cases, widening a
limited grant in place with `ContactAccessButton` and `contactAccessPicker`, writing back through
`CNSaveRequest`, formatting names and postal addresses with the framework's own formatters, and
round-tripping a contact through vCard.

The app is deliberately pure SwiftUI — no `UIViewControllerRepresentable`, no UIKit bridge. The two
ContactsUI view controllers (`CNContactPickerViewController` and `CNContactViewController`) are
covered in the article instead, since they would have pulled a coordinator and delegate plumbing
into an app whose point is the SwiftUI-native access flow.

Everything it touches is the real contact database on the device. There is no mock store, which
means the interesting behaviour only shows up when you grant **limited** access on a real iPhone.

---

## 📁 Project Structure

```
Rolodeck/
└── Rolodeck/                       → Single app target
    ├── RolodeckApp.swift            → @main entry point, owns ContactsModel, three-tab shell
    ├── ContactsModel.swift          → CNContactStore wrapper: auth, key sets, fetch, save, vCard, notifications
    ├── AccessView.swift             → Authorization status + ContactAccessButton + contactAccessPicker
    ├── ContactListView.swift        → Fetched list, name-predicate search, thumbnails
    ├── ContactDetailView.swift      → Labeled values, postal formatting, dates, vCard export
    ├── ContactEditorView.swift      → CNMutableContact + CNSaveRequest create/update/delete
    ├── StoreInspectorView.swift     → Containers, groups, change-tracking surface
    ├── Info.plist                   → Declares NSContactsUsageDescription (required; missing it crashes)
    └── Assets.xcassets
```

---

## 🛠️ Step-by-Step Xcode Setup

### Step 1 — Create the iOS App project

1. **Xcode → File → New → Project**
2. Choose **iOS → App** → Next
3. Set:
   - **Product Name:** `Rolodeck`
   - **Interface:** SwiftUI
   - **Language:** Swift
4. Save and **Create**

### Step 2 — Delete the default file

Delete the generated **`ContentView.swift`** → Move to Trash

### Step 3 — Add the app files

Drag these files from `Rolodeck/` into your Xcode project's `Rolodeck` group (✅ Copy items if
needed, ✅ Rolodeck under "Add to targets"):

- `RolodeckApp.swift`
- `ContactsModel.swift`
- `AccessView.swift`
- `ContactListView.swift`
- `ContactDetailView.swift`
- `ContactEditorView.swift`
- `StoreInspectorView.swift`

### Step 4 — Add the contacts usage description

The app **crashes on first store access** without it, rather than failing the request. Project →
**Rolodeck target** → **Info** → add **Privacy - Contacts Usage Description**
(`NSContactsUsageDescription`) with a sentence explaining why the app wants contacts.

This project's checked-in `Info.plist` already has the key set; this step is what to do if you're
rebuilding the project from scratch.

No capability needs to be added in **Signing & Capabilities** — contacts access is a usage-description
prompt, not an entitlement.

### Step 5 — Note what is deliberately absent

There is **no `.entitlements` file**. Reading or writing a contact's `note` property needs
`com.apple.developer.contacts.notes`, which requires Apple's approval before an app can ship, so the
app never fetches or displays `CNContactNoteKey`. If you add the key to `ContactsModel.detailKeys`
without the entitlement, fetches fail with `CNError.Code.unauthorizedKeys`.

### Step 6 — Set the deployment target

Set **Minimum Deployments** under project → **Rolodeck target** → **General**. It must be **iOS 18.0
or later**, because `ContactAccessButton`, `contactAccessPicker` and `CNAuthorizationStatus.limited`
are all iOS 18 APIs. The project ships targeting iOS 26.1.

### Step 7 — Clean and build

```
Product → Clean Build Folder (⇧⌘K)
```
Then **⌘R** to run.

---

## ▶️ How to Run

Select the **Rolodeck** scheme → a **physical iPhone** (strongly preferred — see Troubleshooting) →
**⌘R**.

| Screen | What it does |
|---|---|
| **Access** | Shows the live `CNAuthorizationStatus` in plain language, a request button while the status is `.notDetermined`, a search field wired to `ContactAccessButton`, and a button carrying the `contactAccessPicker` modifier. Contacts granted during this launch get counted here. |
| **Contacts** | The contacts the app can currently see, fetched with a small key set and sorted by the device's own name-order preference. Search runs through `CNContact.predicateForContacts(matchingName:)`. A ✨ marks contacts shared during this launch. **New** opens the editor. |
| **Contact detail** | Refetches by identifier against a larger key set, then shows labeled values with localized labels, postal addresses through `CNPostalAddressFormatter`, dates, relations, social and IM profiles, and a vCard export that parses its own bytes back. |
| **Store** | Containers with the default one tagged, groups, the `CNContactStoreDidChange` count, and the current history token's size. |

---

## ✅ How to Verify It's Working

The limited-access path is the whole point, and granting full access hides it. Run this sequence on
a real iPhone with real contacts.

1. **Delete the app first** if you've run it before, so the status resets to `.notDetermined`.
   (Settings → Privacy & Security → Contacts also works.)
2. Launch, open **Access**, tap **Request access**. When the system sheet appears, choose
   **Select Contacts…** and share **two or three** contacts, not all of them.
3. The status row should read **Limited access**, and **Visible contacts** should show the number you
   picked — not your whole address book.
4. Open **Contacts**. Only the shared contacts appear. Search for the name of a contact you did
   *not* share: no result, and no error.
5. Back on **Access**, type that same unshared name into the search field. The
   **ContactAccessButton** should appear below it showing that person. Tap it — no permission prompt
   appears, and **Visible contacts** increments immediately.
6. Return to **Contacts** and pull to refresh. The newly granted contact is now in the list with a ✨.
7. On **Access**, tap **Choose contacts to share**. The picker shows every contact on the device
   regardless of what the app can see. Add one, dismiss, and confirm the count goes up again.
8. Open a contact → **Export as vCard**. A `BEGIN:VCARD` block appears, and **Parsed back** reads
   `1 contact(s)`.
9. Tap **Edit**, change the job title, **Save**. The change should survive leaving and reopening the
   detail screen, and it should be visible in the system Contacts app.
10. Tap **New**, fill in a given name, **Save**. The new contact appears in the list even though you
    never granted access to it — apps always get access to contacts they create themselves.
11. Open the system **Contacts** app, edit any contact the app can see, then return to **Store**.
    **Store-change notifications** should have incremented and the **History token** size should be
    populated.

---

## 🐛 Troubleshooting

| Problem | Fix |
|---|---|
| App crashes immediately on first contact access, no permission sheet | Missing `NSContactsUsageDescription` — see Step 4. This is a crash, not a catchable error. |
| Crash with `CNContactPropertyNotFetchedException` | A property was read that wasn't in the fetch's `keysToFetch`. Add the key to `ContactsModel.listKeys` or `detailKeys` (`ContactsModel.swift:18-53`). This is an Objective-C exception, so `do`/`catch` cannot intercept it. |
| The ContactAccessButton never appears | Expected under full access — it renders nothing when there's nothing left to grant. Check the status row says **Limited access**. Under `.denied` it shows an allow-access prompt instead. |
| "Request access" button does nothing | The system prompts only once, ever. After the first answer, `requestAccess(for:)` returns the remembered result silently. Delete the app or use Settings to reset. |
| Edits save but other fields vanish | A contact was edited from a mutable copy that only carried the list key set. The detail screen refetches with `detailKeys` first (`ContactDetailView.swift:60-62`); make sure the editor is reached from there, not from a list row. |
| vCard export fails with an error | vCard serialization has its own key requirements. The export refetches against `CNContactVCardSerialization.descriptorForRequiredKeys()` (`ContactsModel.swift:229-240`) rather than reusing the detail keys. |
| Groups section is always empty | Expected on iOS. There's no system UI for creating contact groups, so most devices report none. The call is working. |
| Store tab shows no change in the history token | `currentHistoryToken` only moves when the database actually changes. Edit a contact in the system Contacts app, not in Rolodeck. |
| Simulator shows no contacts and the access button finds nothing | A fresh simulator has an almost-empty contact database. Use a physical iPhone. |
| Search returns nothing for a partial name | `predicateForContacts(matchingName:)` matches name components, not arbitrary substrings. Compound predicates aren't supported either — filter in Swift if you need more. |

---

## 📚 What This Demonstrates

| Feature | File |
|---|---|
| Key descriptors composed from `CNContactFormatter.descriptorForRequiredKeys(for:)` plus explicit keys | `ContactsModel.swift:18-53` |
| All five `CNAuthorizationStatus` cases, with plain-language copy per state | `ContactsModel.swift:86-88`, `317-345` |
| `requestAccess(for:)` in its async form, plus re-reading the status afterwards | `ContactsModel.swift:90-100` |
| Off-main-thread `CNContactFetchRequest` + `enumerateContacts`, with `sortOrder`/`unifyResults`/`mutableObjects` set explicitly | `ContactsModel.swift:108-138`, `168-185` |
| `CNContactsUserDefaults.shared().sortOrder` driving the fetch order | `ContactsModel.swift:122` |
| `CNContact.predicateForContacts(matchingName:)` search | `ContactsModel.swift:119-121` |
| `unifiedContact(withIdentifier:keysToFetch:)` refetch for the detail screen | `ContactsModel.swift:149-156` |
| `ContactAccessButton` bound to a live query string, with both style and caption modifiers | `AccessView.swift:59-78` |
| `contactAccessPicker(isPresented:completionHandler:)` | `AccessView.swift:80-95` |
| Turning access-callback identifiers into contacts | `ContactsModel.swift:140-147` |
| `CNLabeledValue` rendering with `localizedString(forLabel:)` | `ContactDetailView.swift:86-105` |
| `CNPostalAddressFormatter` with `.mailingAddress` style | `ContactDetailView.swift:15-19`, `107-126` |
| `CNContactFormatter.nameOrder(for:)` and `delimiter(for:)` surfaced in the UI | `ContactsModel.swift:275-282`, `ContactDetailView.swift:66-84` |
| `imageDataAvailable` gating thumbnail decoding | `ContactListView.swift:93-108` |
| `mutableCopy()` → `CNMutableContact` → `CNSaveRequest` for create and update | `ContactEditorView.swift:135-173` |
| `CNSaveRequest` with `transactionAuthor` and `shouldRefetchContacts` | `ContactsModel.swift:189-208` |
| Contact deletion through `CNSaveRequest.delete(_:)` | `ContactsModel.swift:210-225` |
| Standard `CNLabel*` constants in a picker | `ContactEditorView.swift:28-31`, `102-110` |
| `CNContactVCardSerialization` export + round-trip parse, using its own key descriptor | `ContactsModel.swift:229-246`, `ContactDetailView.swift:148-170` |
| Typed `CNError` handling via the Swift overlay's `affectedRecordIdentifiers` | `ContactsModel.swift:286-314` |
| `containers(matching:)`, `groups(matching:)`, `defaultContainerIdentifier()` | `ContactsModel.swift:158-166`, `StoreInspectorView.swift:21-65` |
| `CNContactStoreDidChange` observation and `currentHistoryToken` | `ContactsModel.swift:250-263`, `StoreInspectorView.swift:67-77` |
| `NSContactsUsageDescription` — the key whose absence is a crash | `Rolodeck/Info.plist` |

One thing the app deliberately **cannot** demonstrate: reading change history.
`CNContactStore.enumeratorForChangeHistoryFetchRequest(_:)` is annotated `NS_SWIFT_UNAVAILABLE` in
the iOS 26.1 SDK with no Swift overlay replacement, so `CNChangeHistoryFetchRequest` and the
`CNChangeHistoryEventVisitor` family are unreachable without an Objective-C shim. The Store tab shows
how far pure Swift gets: it can tell *that* the database changed, never *what* changed.

This pairs with the Medium article *"Contacts on iOS: What You Fetch Is All You Get."*

# Contacts

Medium article: ["Contacts on iOS: What You Fetch Is All You Get"](https://hari51215.medium.com/contacts-on-ios-what-you-fetch-is-all-you-get-c66529d36d2f)

Sample app: [`Rolodeck/`](./Rolodeck) — a SwiftUI contacts workbench covering both Contacts and
ContactsUI: authorization status across all five `CNAuthorizationStatus` cases, `ContactAccessButton`
and `contactAccessPicker` for widening a limited grant in place, a key-descriptor-driven fetch and
detail flow, `CNSaveRequest` create/update/delete, vCard round-tripping, and a store inspector for
containers, groups and change tracking. See [`Rolodeck/README.md`](./Rolodeck/README.md) for setup
and testing instructions.

The article and the app both treat Contacts and ContactsUI as one topic rather than two. Since
iOS 18 they are hard to separate: `CNAuthorizationStatus.limited` changed what "access to contacts"
means, and the two pieces that make limited access workable — `ContactAccessButton` and the
`contactAccessPicker` view modifier — live in ContactsUI while everything they grant access to lives
in Contacts.

Three findings from building against the iOS 26.1 SDK that are worth recording, because the
documentation pages do not make any of them obvious:

- **`enumeratorForChangeHistoryFetchRequest:error:` is annotated `NS_SWIFT_UNAVAILABLE`**, and the
  Contacts Swift overlay adds no replacement. `CNChangeHistoryFetchRequest` and the whole
  `CNChangeHistoryEventVisitor` family are therefore unreachable from a pure-Swift iOS app; reading
  change history requires an Objective-C shim. A Swift app can observe `CNContactStoreDidChange` and
  watch `currentHistoryToken` move, which tells it *that* something changed but never *what*.
  `enumeratorForContactFetchRequest:error:` carries the same annotation.
- **`unifiedMeContactWithKeys(toFetch:)` is macOS-only** (`NS_AVAILABLE(10_11, NA)`). There is no
  "me card" lookup on iOS at all.
- **`CNPostalAddressFormatterStyle` has exactly one case**, `.mailingAddress`. The `style` property
  exists but there is nothing to choose between.

The notes entitlement (`com.apple.developer.contacts.notes`) requires Apple's approval before it can
ship, so the `note` property is covered in the article's prose and deliberately has no code path in
the sample app.

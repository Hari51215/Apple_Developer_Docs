# Core Data

Medium article: [Core Data in Practice: The Compiled Model, the Context Rules, and the Requests That Skip Them](https://hari51215.medium.com/core-data-in-practice-the-compiled-model-the-context-rules-and-the-requests-that-skip-them-de591e014db0)

Sample app: [`Shelfmark/`](./Shelfmark) — a reading log whose `.xcdatamodeld` was written by hand
rather than drawn in Xcode's model editor, so the schema reads in a diff. One screen is ordinary
CRUD through `viewContext`; the other imports 5,000 books on a private-queue context and deletes
them with an `NSBatchDeleteRequest`, which is the pair of operations that makes the concurrency and
merge-back rules visible. See [`Shelfmark/README.md`](./Shelfmark/README.md) for setup and testing
instructions.

Written and built against Xcode 26.1 (17B55) with the iOS 26.1 SDK on an Apple-silicon Mac. Every
availability claim in the article was checked against the 59 headers (4,201 lines) in
`CoreData.framework/Headers` and the Swift overlay beside them in `CoreData.framework/Modules`,
rather than against the documentation pages.

**Findings from comparing the headers against the documentation:**

- **The concurrency rule is three annotations, and none of them are in the docs.**
  `NSManagedObjectContext` is declared `NS_SWIFT_NONISOLATED NS_SWIFT_SENDABLE`, `NSManagedObject`
  is declared `NS_SWIFT_NONSENDABLE` by hand, and `NSManagedObjectID` is Sendable again. That is
  the entire "pass contexts and IDs, never objects" rule, stated precisely. No current Core Data
  documentation page discusses `Sendable` conformance or actor isolation at all; the prose only
  says to bind objects to their context's queue.

- **The non-isolated annotation is load-bearing for modern targets.** Because `NSManagedObject` is
  `NS_SWIFT_NONISOLATED`, generated subclasses stay off the main actor even in a target built with
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Shelfmark has that setting on and its background
  importer compiles without a single isolation diagnostic.

- **A documented section of the framework is absent from the SDK.** Apple's docs carry typed
  `NotificationCenter` message structs for Core Data — `NSManagedObjectContext.DidSaveMessage`,
  `.DidSaveObjectIDsMessage`, `.ObjectsDidChangeMessage`,
  `NSPersistentStoreCoordinator.RemoteChangeMessage` and others — stamped iOS 27. Grepping all 59
  headers in the 26.1 SDK for any of them returns nothing. The article says plainly that this
  surface is unverified.

- **`loadPersistentStores` is barred from async on purpose.** The header marks it
  `NS_SWIFT_DISABLE_ASYNC`, so Swift refuses to synthesise an `await` form. The reason is in the
  comment above it: the handler is called once for *each* store, and an `await` would have to pick
  one of those moments to resume on.

- **`momc` prints the model version checksum on every build**, which is the exact value
  `NSLightweightMigrationStage(_:)` wants for staged migration. Adding one derived attribute to
  Shelfmark's model changed it from `GnkVZUX9Jx…` to `HvRIpjVv99…`. The staged-migration docs never
  mention where to get the string.

- **The model file's `lastSavedToolsVersion` is a feature gate, not a comment.** Writing
  `lastSavedToolsVersion="26.1"` by hand made `momc` reject fetch indexes with
  `Fetch Indexes feature requires Xcode 9.0 model file format or later` — a 2017 feature refused on
  the 26.1 SDK. The field is parsed as an Xcode *build* number, so a marketing version reads as
  ancient. A real build number such as `23788` fixes it.

- **The XML store type doesn't exist on iOS.** The Swift overlay declares
  `NSPersistentStore.StoreType` with `.sqlite`, `.binary` and `.inMemory` only. The rendered docs
  list `.xml` without a platform note; it is macOS-only.

- **Core Data is at rest.** The newest additions in the SDK are iOS 17: `NSStagedMigrationManager`,
  `NSCustomMigrationStage`, `NSLightweightMigrationStage`, `NSCompositeAttributeDescription`. The
  only iOS 18 addition anywhere in the framework is one metadata key,
  `NSPersistentStoreModelVersionChecksumKey`. Nothing was added in 26.1.

- **Two merge-policy APIs still ship side by side.** The `id`-typed singletons
  (`NSMergeByPropertyObjectTrumpMergePolicy` and friends, iOS 3) and the `NSMergePolicy` class
  properties that replaced them in iOS 10 are both present and both autocomplete.
  `NSConfinementConcurrencyType` is likewise still in the enum at `0x00`, deprecated since iOS 9,
  which is what a zero-initialised concurrency type gets you.

**Verification notes:**

- Every Swift listing in the article was extracted into one throwaway file alongside the
  Core Data classes `momc` generated for Shelfmark, and typechecked with
  `swiftc -typecheck -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -target arm64-apple-ios26.1-simulator`.
  Zero diagnostics.
- Shelfmark builds clean (zero errors, zero warnings) with
  `xcodebuild -project CoreData/Shelfmark/Shelfmark.xcodeproj -scheme Shelfmark -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build`.
  It has not been run yet; the on-device pass is still to do.
- Each `API_AVAILABLE` version printed in the article was grepped out of the 26.1 headers
  individually: derived attributes iOS 13, fetch indexes iOS 11, batch insert iOS 13, persistent
  history iOS 11, remote change notifications iOS 12, secure unarchive transformer iOS 12, staged
  migration iOS 17. `@SectionedFetchRequest` iOS 15 and `@FetchRequest` iOS 13 were read out of the
  SwiftUI `.swiftinterface`.

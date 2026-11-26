# Shelfmark — Core Data Sample Project

A single-screen iPhone reading log built on Core Data. Authors own books, books carry a title, a
page count, an added date and a finished flag, and the list groups itself by author. Adding,
editing and swipe-to-delete all run through `viewContext` the ordinary way.

The second screen is the reason the app exists. It has two buttons: one imports five thousand
books on a private-queue context, the other deletes everything with an `NSBatchDeleteRequest`.
Between them they cover both halves of the concurrency story. The import shows why the view
context must not be asked to do bulk work, and the delete shows the opposite failure, where work
done correctly off the main queue stays invisible until its object IDs are merged back.

The model file was written by hand rather than drawn in Xcode's model editor, so the schema is
readable in a diff. It uses a derived attribute, a uniqueness constraint, a cascade delete rule
and two fetch indexes, which are the model features the app's behaviour actually depends on.

The app is deliberately narrow. There is no CloudKit mirroring, no persistent history reader, no
second model version to migrate between. All three were tempting and all three would have turned a
believable reading log into a feature gallery.

---

## 📁 Project Structure

```
Shelfmark/
├── Shelfmark.xcodeproj
└── Shelfmark/
    ├── ShelfmarkApp.swift            → @main, injects viewContext into the environment
    ├── PersistenceController.swift   → the stack: container, store options, merge policy
    ├── BookListView.swift            → sectioned list, swipe delete, BookRow
    ├── BookEditorView.swift          → add/edit sheet, find-or-create author, validation errors
    ├── ImportPanel.swift             → counts, bulk import, batch delete, timing
    ├── LibraryImporter.swift         → the background context and batch request work
    ├── Shelfmark.xcdatamodeld        → hand-written model: Author, Book, derived attribute,
    │                                   uniqueness constraint, two fetch indexes
    ├── Info.plist                    → portrait-only iPhone app, no capabilities required
    └── Assets.xcassets               → AccentColor + AppIcon placeholders
```

---

## 🛠️ Step-by-Step Xcode Setup

### Step 1 — Create the iOS App project
File → New → Project → iOS → App. Product Name `Shelfmark`, Interface **SwiftUI**, Language
**Swift**. Leave "Use Core Data" unchecked; the model here is hand-written and the template's
boilerplate would only have to be deleted. Save it so the `.xcodeproj` sits at `CoreData/Shelfmark/`.

### Step 2 — Add the source files
Replace the generated `ContentView.swift` with the files from this folder. The project uses
Xcode 16+ synchronised folder groups, so dropping files into the `Shelfmark/` folder is enough;
there is no file list to maintain in the project file. This applies to the `.xcdatamodeld` bundle
too, which is picked up and compiled without a project-file edit.

### Step 3 — Check the model file opens
Select `Shelfmark.xcdatamodeld` in Xcode. It should open in the graphical model editor showing two
entities. If it opens as raw XML instead, the bundle structure is wrong: it needs a
`.xccurrentversion` plist naming the current version, plus a `Shelfmark.xcdatamodel/contents` file
inside it.

### Step 4 — Target settings
- Deployment target: **iOS 26.1**
- Targeted device family: **iPhone only** (`TARGETED_DEVICE_FAMILY = 1`)
- Bundle identifier: `com.hari.Shelfmark`
- Signing: Automatic, personal team is fine

### Step 5 — No capabilities, no entitlements, no privacy strings
A local Core Data store needs none of them. The database lives in the app's own container, so
nothing here touches a protected resource. Add the iCloud capability only if you swap
`NSPersistentContainer` for `NSPersistentCloudKitContainer`, which also means accepting CloudKit's
model restrictions.

### Step 6 — Note what is deliberately absent
There is no `NSPersistentCloudKitContainerOptions` on the store description, and no second model
version in the `.xcdatamodeld`. Persistent history tracking *is* switched on even though nothing
reads the history yet, because turning it on later means the log starts empty and the first
consumer has nothing to replay from.

### Step 7 — Clean and build
Product → Clean Build Folder (⇧⌘K), then Product → Build (⌘B). The project builds with zero
warnings against the iOS 26.1 SDK. Then **⌘R** to run.

---

## ▶️ How to Run

Build to an iPhone (simulator or device) and use the two screens:

| Control | What it does |
|---|---|
| **+** (top right) | Opens the editor on a new book. Typing an author name that already exists reuses that author rather than creating a second one. |
| **Tap a row** | Opens the same editor on the existing book, resolved from its `NSManagedObjectID`. |
| **Swipe a row** | Deletes through `viewContext`, which fires the nullify delete rule on the author relationship. |
| **Library** (top left) | Opens the sheet with live counts and the two bulk operations. |
| **Import 5,000 books** | Runs on a private-queue context, saving every 500 rows. Reports elapsed time. |
| **Delete everything** | `NSBatchDeleteRequest` against both entities, with the deleted object IDs merged into `viewContext`. |

---

## ✅ How to Verify It's Working

1. **The import does not block the UI.** Tap Import and the spinner animates throughout. If the
   list freezes, the work has landed on the main queue.
2. **Authors de-duplicate.** After importing 5,000 books the author count should read **12**, not
   60,000. That is the uniqueness constraint plus an object-trump merge policy resolving the
   duplicates at save time, not any de-duplication logic in the importer.
3. **The list updates after the import** without reopening the screen, because `viewContext` has
   `automaticallyMergesChangesFromParent` set.
4. **The list empties after Delete everything.** If rows stay on screen while the counts read zero,
   the batch delete result is not being merged back.
5. **Sections are author names.** Those come from the `authorName` derived attribute, which the
   store computes on save. A book saved without an author sorts into "Unattributed".
6. **Scrolling 5,000 rows stays smooth**, which is `fetchBatchSize` doing its job inside
   `@SectionedFetchRequest`.

To watch the SQL, add `-com.apple.CoreData.SQLDebug 1` under Product → Scheme → Edit Scheme → Run →
Arguments Passed On Launch.

---

## 🐛 Troubleshooting

| Problem | Fix |
|---|---|
| `Fetch Indexes feature requires Xcode 9.0 model file format or later` | The `lastSavedToolsVersion` attribute in the model XML is read as an Xcode *build* number. A marketing version like `"26.1"` parses as pre-Xcode 9 and disables every modern model feature. Use a build number such as `"23788"`. |
| `Non-ascending elements are not compatible with the current deployment target` | Same root cause as above. A descending fetch index element needs the newer model file format. |
| `property 'viewContext' is not available due to missing import of defining module 'CoreData'` | The member import visibility upcoming feature is on. `import SwiftUI` no longer surfaces Core Data members transitively; add `import CoreData` to that file. |
| Crash at launch naming an unresolvable model | The string passed to `NSPersistentContainer(name:)` must match the `.momd` name, which comes from the `.xcdatamodeld` folder name. |
| Model opens as XML instead of the graphical editor | The `.xcdatamodeld` is missing its `.xccurrentversion` plist, or the inner `.xcdatamodel` folder name does not match what that plist names. |
| Second import batch fails with a constraint violation | The context's `mergePolicy` is still `.error`. Uniqueness constraints need a policy that resolves conflicts. |
| Rows stay on screen after Delete everything | The batch delete's `resultType` is not `.resultTypeObjectIDs`, so there are no IDs to merge back. The default result type returns a count, and a count cannot be merged. |
| `title` and `addedAt` are Optional in Swift despite being non-optional in the model | Expected. The model's optional flag is a save-time validation rule, unrelated to Swift's type system. Only scalar attributes with the scalar-value checkbox come through non-optional. |
| Memory climbing during the import | The per-batch `context.reset()` is missing, or the background context's default `undoManager` is still attached and retaining every change. |

---

## 📚 What This Demonstrates

| Feature | File |
|---|---|
| `NSPersistentContainer` set up with explicit store options | `PersistenceController.swift:15-45` |
| Persistent history + remote change notification opt-in | `PersistenceController.swift:26-27` |
| `loadPersistentStores` running once per store, with no async form | `PersistenceController.swift:31-37` |
| Merge policy chosen so uniqueness constraints resolve | `PersistenceController.swift:44` |
| Counting rows without materialising objects | `PersistenceController.swift:48-51` |
| `@SectionedFetchRequest` grouping on a derived attribute | `BookListView.swift:12-20` |
| Deleting through the context so delete rules fire | `BookListView.swift:82-87` |
| Passing a book to a sheet as an `NSManagedObjectID`, not an object | `BookListView.swift:67`, `BookEditorView.swift:7-17` |
| Resolving an object ID back with `existingObject(with:)` | `BookEditorView.swift:77`, `93` |
| Unwrapping validation errors from `NSDetailedErrorsKey` | `BookEditorView.swift:112-114` |
| Find-or-create against a case-insensitive predicate | `LibraryImporter.swift:101-112` |
| Async `performBackgroundTask` on a private-queue context | `LibraryImporter.swift:30-34` |
| Batched saves with `reset()` to bound memory | `LibraryImporter.swift:61-65` |
| Disabling the background context's undo manager | `LibraryImporter.swift:34` |
| `transactionAuthor` labelling for persistent history | `LibraryImporter.swift:32`, `82` |
| `NSBatchDeleteRequest` with `.resultTypeObjectIDs` | `LibraryImporter.swift:86-87` |
| Merging batch results back into the view context | `LibraryImporter.swift:92-95` |
| Hand-written model: derived attribute, uniqueness constraint, cascade rule, fetch indexes | `Shelfmark.xcdatamodeld/Shelfmark.xcdatamodel/contents` |

This pairs with the Medium article "Core Data in Practice: The Compiled Model, the Context Rules,
and the Requests That Skip Them".

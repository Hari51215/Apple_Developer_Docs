import CoreData

/// The two operations that exist to show what `viewContext` must not be asked to do.
enum LibraryImporter {

    enum Constants {
        static let batchSize = 500
    }

    private static let authorNames = [
        "Ursula K. Le Guin", "Italo Calvino", "Toni Morrison", "Jorge Luis Borges",
        "Shirley Jackson", "Kazuo Ishiguro", "Octavia E. Butler", "Penelope Fitzgerald",
        "W. G. Sebald", "Angela Carter", "Haruki Murakami", "Marilynne Robinson"
    ]

    private static let titleStems = [
        "The Left Bank", "Winter Light", "A Small Rebellion", "Notes on Departure",
        "The Glass Orchard", "Inventory of Weather", "Second Harvest", "The Quiet Signal"
    ]

    /// Inserts `bookCount` books on a private-queue context, saving every `batchSize` rows.
    ///
    /// The per-batch `save()` plus `reset()` is the whole point. One save of 5,000 objects holds
    /// every one of them in memory until the save completes; saving in slices lets the context
    /// drop them as it goes.
    static func importSampleLibrary(
        bookCount: Int,
        into container: NSPersistentContainer
    ) async throws {
        try await container.performBackgroundTask { context in
            context.name = "importer"
            context.transactionAuthor = "importer"
            context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
            context.undoManager = nil

            var authorsInBatch: [String: Author] = [:]
            let now = Date()

            for index in 0..<bookCount {
                let authorName = authorNames[index % authorNames.count]

                let author: Author
                if let cached = authorsInBatch[authorName] {
                    author = cached
                } else {
                    // Inserted fresh in every batch. The uniqueness constraint on `name` plus an
                    // object-trump merge policy is what collapses the duplicates at save time.
                    let fresh = Author(context: context)
                    fresh.name = authorName
                    authorsInBatch[authorName] = fresh
                    author = fresh
                }

                let book = Book(context: context)
                book.title = "\(titleStems[index % titleStems.count]) #\(index + 1)"
                book.addedAt = now.addingTimeInterval(-Double(index) * 60)
                book.pageCount = Int32(120 + (index * 7) % 540)
                book.isFinished = index % 3 == 0
                book.author = author

                if (index + 1) % Constants.batchSize == 0 {
                    try context.save()
                    context.reset()
                    authorsInBatch.removeAll()
                }
            }

            if context.hasChanges {
                try context.save()
            }
        }
    }

    /// Deletes every row with `NSBatchDeleteRequest`, then tells the view context what happened.
    ///
    /// A batch delete runs as SQL. It never loads an object, never fires a delete rule, and never
    /// notifies a context. Merging the returned object IDs back is not an optimisation; skip it
    /// and the list keeps rendering rows whose storage is already gone.
    static func removeEverything(from container: NSPersistentContainer) async throws {
        try await container.performBackgroundTask { context in
            context.name = "eraser"
            context.transactionAuthor = "eraser"

            for entityName in ["Book", "Author"] {
                let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let request = NSBatchDeleteRequest(fetchRequest: fetch)
                request.resultType = .resultTypeObjectIDs

                let result = try context.execute(request) as? NSBatchDeleteResult
                let deletedIDs = result?.result as? [NSManagedObjectID] ?? []

                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: deletedIDs],
                    into: [container.viewContext]
                )
            }
        }
    }

    /// Find-or-create, the shape every Core Data app ends up writing.
    static func author(named name: String, in context: NSManagedObjectContext) throws -> Author {
        let request = Author.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[c] %@", name)
        request.fetchLimit = 1

        if let existing = try context.fetch(request).first {
            return existing
        }

        let author = Author(context: context)
        author.name = name
        return author
    }
}

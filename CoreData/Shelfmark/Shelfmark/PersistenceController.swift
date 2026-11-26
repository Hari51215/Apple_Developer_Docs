import CoreData

/// Owns the one Core Data stack the app uses.
///
/// `NSPersistentContainer` is three objects wearing one coat: it builds the managed object model
/// from the compiled `.momd` in the bundle, hands that model to a persistent store coordinator,
/// and vends a main-queue context already wired to it.
struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Shelfmark")

        guard let store = container.persistentStoreDescriptions.first else {
            fatalError("Shelfmark expects exactly one store description.")
        }

        if inMemory {
            store.url = URL(fileURLWithPath: "/dev/null")
        }

        // Persistent history has to be asked for. Without it, a batch request's changes are
        // invisible to anything that was not the context that ran them.
        store.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        store.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // The handler runs once per store, not once overall, which is why Swift refuses to
        // synthesise an async version of this call.
        container.loadPersistentStores { description, error in
            if let error {
                let name = description.url?.lastPathComponent ?? description.type
                fatalError("Could not load store \(name): \(error)")
            }
        }

        let viewContext = container.viewContext
        viewContext.name = "viewContext"
        viewContext.transactionAuthor = "ui"
        viewContext.automaticallyMergesChangesFromParent = true
        // Author names carry a uniqueness constraint. Without a policy that resolves constraint
        // violations, the importer's second batch fails its save instead of de-duplicating.
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    /// Counts rows without materialising a single managed object.
    func count(ofEntityNamed entityName: String) -> Int {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        return (try? container.viewContext.count(for: request)) ?? 0
    }
}

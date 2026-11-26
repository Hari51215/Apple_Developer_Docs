import CoreData
import SwiftUI

@main
struct ShelfmarkApp: App {
    private let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            BookListView(persistence: persistence)
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}

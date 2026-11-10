import SwiftUI

@main
struct RolodeckApp: App {
    @State private var model = ContactsModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}

struct RootView: View {
    @Environment(ContactsModel.self) private var model

    var body: some View {
        TabView {
            Tab("Access", systemImage: "lock.shield") {
                AccessView()
            }
            Tab("Contacts", systemImage: "person.crop.circle") {
                ContactListView()
            }
            Tab("Store", systemImage: "tray.full") {
                StoreInspectorView()
            }
        }
        .task {
            model.refreshAuthorizationStatus()
            model.startObservingStoreChanges()
            await model.reload()
        }
    }
}

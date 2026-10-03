import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            EligibilityView()
                .tabItem {
                    Label("Eligibility", systemImage: "checkmark.shield")
                }

            #if ENABLE_BROWSERKIT_TRANSFER
            ExportView()
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }

            ImportView()
                .tabItem {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
            #endif
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(BrowsingDataStore())
        #if ENABLE_BROWSERKIT_TRANSFER
        .environmentObject(ExportCoordinator())
        .environmentObject(ImportCoordinator())
        #endif
}

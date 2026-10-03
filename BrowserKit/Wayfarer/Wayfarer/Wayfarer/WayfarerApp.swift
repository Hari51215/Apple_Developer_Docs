import SwiftUI
import UIKit
import BrowserKit

@main
struct WayfarerApp: App {
    @StateObject private var store = BrowsingDataStore()
    #if ENABLE_BROWSERKIT_TRANSFER
    @StateObject private var exportCoordinator = ExportCoordinator()
    @StateObject private var importCoordinator = ImportCoordinator()
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                #if ENABLE_BROWSERKIT_TRANSFER
                .environmentObject(exportCoordinator)
                .environmentObject(importCoordinator)
                .onContinueUserActivity(BEBrowserDataExportManager.userActivityType) { activity in
                    guard let token = activity.userInfo?[BEBrowserDataExportManager.exportTokenUserInfoKey] as? UUID else { return }
                    let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                    Task {
                        await exportCoordinator.handleIncomingExportRequest(token: token, store: store, scene: scene)
                    }
                }
                .onContinueUserActivity(BEBrowserDataImportManager.userActivityType) { activity in
                    guard let token = activity.userInfo?[BEBrowserDataImportManager.importTokenUserInfoKey] as? UUID else { return }
                    Task {
                        await importCoordinator.receiveImport(token: token, store: store)
                    }
                }
                #endif
        }
    }
}

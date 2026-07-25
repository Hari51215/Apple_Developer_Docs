//
//  QuickOrderApp.swift
//  QuickOrder
//
//  Main app entry point.
//  Target: QuickOrder ONLY
//

import SwiftUI

@main
struct QuickOrderApp: App {
    @StateObject private var orderManager = OrderManager()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(orderManager)
                // Handle invocation URL when full app is opened
                // via App Clip link (e.g. user taps QR while app is installed)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL {
                        orderManager.handleInvocationURL(url)
                    }
                }
        }
    }
}

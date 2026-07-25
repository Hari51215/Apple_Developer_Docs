//
//  QuickOrderClipApp.swift
//  QuickOrderClip
//
//  App Clip entry point — invoked by NFC, QR, or default App Clip link.
//
//  Invocation URL format:
//    https://yourwebsite.com/order?table=5&item=latte
//    https://appclip.apple.com/id?p=com.yourname.QuickOrder.Clip&table=5
//
//  Test in Simulator:
//    Product → Scheme → Edit Scheme → Run → Arguments
//    → Environment Variables → _XCAppClipURL =
//      https://yourwebsite.com/order?table=5&item=latte
//
//  Target: QuickOrderClip ONLY
//

import SwiftUI

@main
struct QuickOrderClipApp: App {
    @State private var invocationURL: URL? = nil

    var body: some Scene {
        WindowGroup {
            ClipRootView(invocationURL: invocationURL)
                // ✅ Key: this is how every App Clip receives its URL
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    invocationURL = activity.webpageURL
                }
        }
    }
}

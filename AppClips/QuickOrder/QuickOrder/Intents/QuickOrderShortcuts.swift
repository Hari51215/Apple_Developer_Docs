//
//  QuickOrderShortcuts.swift
//  QuickOrder
//
//  Target: QuickOrder ONLY
//

import AppIntents

struct QuickOrderShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddToOrderIntent(),
            phrases: [
                "Add \(\.$item) to my \(.applicationName) order",
                "Order \(\.$item) with \(.applicationName)"
            ],
            shortTitle: "Add to Order",
            systemImageName: "cup.and.saucer.fill"
        )
    }
}

//
//  CookingMetadata.swift
//  ChefTimer
//
//  ⚠️ SHARED FILE — Add to BOTH targets:
//     - ChefTimer (app target)
//     - ChefTimerWidgetExtension (widget target)
//
//  In Xcode: Select file → File Inspector (right panel)
//  → check BOTH targets under "Target Membership"
//

import AlarmKit
import Foundation

// MARK: - Metadata

nonisolated struct CookingMetadata: AlarmMetadata {
    let dishName: String
    let cookingMethod: String
    let emoji: String
}

// MARK: - Recipe Model (used by the app only)

struct Recipe: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let cookingMethod: String
    let emoji: String
    let durationMinutes: Int

    var durationSeconds: TimeInterval {
        TimeInterval(durationMinutes * 60)
    }

    static let catalog: [Recipe] = [
        Recipe(name: "Pasta", cookingMethod: "Boiling",  emoji: "🍝", durationMinutes: 1),
        Recipe(name: "Eggs",  cookingMethod: "Boiling",  emoji: "🥚", durationMinutes: 1),
        Recipe(name: "Steak", cookingMethod: "Grilling", emoji: "🥩", durationMinutes: 1),
        Recipe(name: "Rice",  cookingMethod: "Steaming", emoji: "🍚", durationMinutes: 1),
        Recipe(name: "Cake",  cookingMethod: "Baking",   emoji: "🎂", durationMinutes: 1),
    ]
    // NOTE: Durations are set to 1 minute for demo purposes.
    // In production, use real durations (e.g. durationMinutes: 12 for pasta).
}

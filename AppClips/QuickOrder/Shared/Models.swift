//
//  Models.swift
//  QuickOrderShared
//
//  ⚠️ SHARED FILE — Add to BOTH targets:
//     QuickOrder (main app) AND QuickOrderClip (App Clip)
//
//  File Inspector → Target Membership → check both targets
//

import Foundation

// MARK: - Menu Item

struct MenuItem: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let description: String
    let price: Double
    let emoji: String
    let category: MenuCategory

    var formattedPrice: String { String(format: "$%.2f", price) }

    static let catalog: [MenuItem] = [
        MenuItem(id: "espresso",   name: "Espresso",         description: "Rich, bold single shot",      price: 2.50, emoji: "☕️", category: .coffee),
        MenuItem(id: "latte",      name: "Latte",            description: "Espresso with steamed milk",  price: 4.50, emoji: "🥛", category: .coffee),
        MenuItem(id: "cappuccino", name: "Cappuccino",       description: "Equal parts espresso & foam", price: 4.00, emoji: "☕️", category: .coffee),
        MenuItem(id: "coldBrew",   name: "Cold Brew",        description: "Slow-steeped, smooth & cool", price: 5.00, emoji: "🧊", category: .coffee),
        MenuItem(id: "matcha",     name: "Matcha Latte",     description: "Premium ceremonial matcha",   price: 5.50, emoji: "🍵", category: .tea),
        MenuItem(id: "croissant",  name: "Croissant",        description: "Buttery, flaky pastry",       price: 3.50, emoji: "🥐", category: .food),
        MenuItem(id: "muffin",     name: "Blueberry Muffin", description: "Fresh-baked daily",           price: 3.00, emoji: "🫐", category: .food),
    ]

    static func item(for id: String?) -> MenuItem? {
        catalog.first { $0.id == id }
    }
}

enum MenuCategory: String, Codable, CaseIterable {
    case coffee = "Coffee"
    case tea    = "Tea"
    case food   = "Food"
}

// MARK: - Order

struct Order: Codable {
    var id: String = UUID().uuidString
    var tableNumber: String
    var items: [MenuItem]
    var status: OrderStatus = .pending
    var placedAt: Date = Date()

    var total: Double     { items.reduce(0) { $0 + $1.price } }
    var formattedTotal: String { String(format: "$%.2f", total) }
}

enum OrderStatus: String, Codable {
    case pending   = "Pending"
    case preparing = "Preparing"
    case ready     = "Ready"
    case completed = "Completed"
}

// MARK: - Invocation URL Parser

struct ClipInvocationURL {
    let tableNumber: String?
    let menuItemID: String?

    init(url: URL?) {
        guard let url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            tableNumber = nil
            menuItemID  = nil
            return
        }
        let items   = components.queryItems ?? []
        tableNumber = items.first { $0.name == "table" }?.value
        menuItemID  = items.first { $0.name == "item" }?.value
    }
}

// MARK: - App Groups — Shared Storage

/// Key used by both targets to share the last placed order
enum SharedStorage {
    static let suiteName = "group.com.hari.QuickOrder"
    static let lastOrderKey = "lastOrder"
    static let currentCartKey = "currentCart"

    static func saveOrder(_ order: Order) {
        let defaults = UserDefaults(suiteName: suiteName)
        if let encoded = try? JSONEncoder().encode(order) {
            defaults?.set(encoded, forKey: lastOrderKey)
        }
    }

    static func loadLastOrder() -> Order? {
        let defaults = UserDefaults(suiteName: suiteName)
        guard let data = defaults?.data(forKey: lastOrderKey) else { return nil }
        return try? JSONDecoder().decode(Order.self, from: data)
    }

    /// Live, in-progress cart — kept in sync so App Intents (Siri/Shortcuts) can
    /// read and add to the same cart the app UI shows, even if the app isn't running.
    static func saveCart(_ items: [MenuItem]) {
        let defaults = UserDefaults(suiteName: suiteName)
        if let encoded = try? JSONEncoder().encode(items) {
            defaults?.set(encoded, forKey: currentCartKey)
        }
    }

    static func loadCart() -> [MenuItem] {
        let defaults = UserDefaults(suiteName: suiteName)
        guard let data = defaults?.data(forKey: currentCartKey),
              let items = try? JSONDecoder().decode([MenuItem].self, from: data) else { return [] }
        return items
    }
}

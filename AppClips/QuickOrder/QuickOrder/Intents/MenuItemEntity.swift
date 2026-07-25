//
//  MenuItemEntity.swift
//  QuickOrder
//
//  Target: QuickOrder ONLY
//

import AppIntents

struct MenuItemEntity: AppEntity {
    let item: MenuItem

    var id: String { item.id }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(item.emoji) \(item.name)",
            subtitle: "\(item.formattedPrice)"
        )
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Menu Item"
    static var defaultQuery = MenuItemEntityQuery()
}

struct MenuItemEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [MenuItemEntity] {
        MenuItem.catalog
            .filter { identifiers.contains($0.id) }
            .map(MenuItemEntity.init)
    }

    func suggestedEntities() async throws -> [MenuItemEntity] {
        MenuItem.catalog.map(MenuItemEntity.init)
    }
}

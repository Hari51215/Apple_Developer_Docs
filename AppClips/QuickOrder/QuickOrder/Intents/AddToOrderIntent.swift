//
//  AddToOrderIntent.swift
//  QuickOrder
//
//  Target: QuickOrder ONLY
//

import AppIntents

struct AddToOrderIntent: AppIntent {
    static var title: LocalizedStringResource = "Add to QuickOrder"
    static var description = IntentDescription("Add a menu item to your current QuickOrder cart.")

    @Parameter(title: "Item")
    var item: MenuItemEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$item) to QuickOrder")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        var cart = SharedStorage.loadCart()
        cart.append(item.item)
        SharedStorage.saveCart(cart)

        let total = cart.reduce(0) { $0 + $1.price }
        let dialog = IntentDialog("Added \(item.item.name) — \(cart.count) item(s), \(String(format: "$%.2f", total)) total.")
        return .result(dialog: dialog)
    }
}

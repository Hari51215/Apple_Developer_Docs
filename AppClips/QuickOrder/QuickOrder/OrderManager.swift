//
//  OrderManager.swift
//  QuickOrder
//
//  Target: QuickOrder ONLY
//

import Combine
import SwiftUI

@MainActor
class OrderManager: ObservableObject {
    @Published var cart: [MenuItem] = [] {
        didSet { SharedStorage.saveCart(cart) }
    }
    @Published var placedOrders: [Order] = []
    @Published var deepLinkedTable: String? = nil
    @Published var deepLinkedItem: MenuItem? = nil

    init() {
        // Pick up anything an App Intent (Siri/Shortcuts) added while we weren't running
        cart = SharedStorage.loadCart()

        // On launch, check if App Clip left us an order to continue
        if let lastOrder = SharedStorage.loadLastOrder() {
            print("Resumed from App Clip — table: \(lastOrder.tableNumber)")
            deepLinkedTable = lastOrder.tableNumber
            cart = lastOrder.items
        }
    }

    func add(_ item: MenuItem) {
        cart.append(item)
    }

    func remove(_ item: MenuItem) {
        if let index = cart.firstIndex(of: item) {
            cart.remove(at: index)
        }
    }

    func placeOrder(tableNumber: String) {
        let order = Order(
            tableNumber: tableNumber,
            items: cart
        )
        placedOrders.append(order)
        SharedStorage.saveOrder(order)
        cart.removeAll()
    }

    func handleInvocationURL(_ url: URL) {
        let parsed = ClipInvocationURL(url: url)
        deepLinkedTable = parsed.tableNumber
        deepLinkedItem  = MenuItem.item(for: parsed.menuItemID)
        if let item = deepLinkedItem {
            cart.append(item)
        }
    }
}

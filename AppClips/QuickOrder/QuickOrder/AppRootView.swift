//
//  AppRootView.swift
//  QuickOrder
//
//  Target: QuickOrder ONLY
//

import SwiftUI

struct AppRootView: View {
    @EnvironmentObject var orderManager: OrderManager

    var body: some View {
        TabView {
            MenuTab()
                .tabItem { Label("Menu", systemImage: "menucard") }

            CartTab()
                .tabItem { Label("Cart", systemImage: "cart")
                    .badge(orderManager.cart.count > 0 ? "\(orderManager.cart.count)" : nil)
                }

            OrdersTab()
                .tabItem { Label("Orders", systemImage: "list.bullet.clipboard") }
        }
        .tint(.brown)
    }
}

// MARK: - Menu Tab

struct MenuTab: View {
    @EnvironmentObject var orderManager: OrderManager
    @State private var tableNumber = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Table number row
                HStack {
                    Image(systemName: "chair")
                        .foregroundStyle(.brown)
                    TextField("Table number", text: $tableNumber)
                        .keyboardType(.numberPad)
                }
                .padding()
                .background(Color(.secondarySystemBackground))

                MenuListView(items: MenuItem.catalog) { item in
                    orderManager.add(item)
                }
            }
            .navigationTitle("QuickOrder ☕️")
            .onAppear {
                // Pre-fill table from deep link / App Clip handoff
                if let table = orderManager.deepLinkedTable, tableNumber.isEmpty {
                    tableNumber = table
                }
            }
        }
    }
}

// MARK: - Cart Tab

struct CartTab: View {
    @EnvironmentObject var orderManager: OrderManager
    @State private var tableNumber = ""
    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            CartSummaryView(
                items: orderManager.cart,
                onRemove: { orderManager.remove($0) },
                onOrder: {
                    orderManager.placeOrder(tableNumber: tableNumber.isEmpty ? "?" : tableNumber)
                    showConfirmation = true
                }
            )
            .navigationTitle("Your Cart")
            .alert("Order Placed! 🎉", isPresented: $showConfirmation) {
                Button("OK") {}
            } message: {
                Text("Your order is being prepared. We'll bring it to table \(tableNumber).")
            }
        }
    }
}

// MARK: - Orders Tab

struct OrdersTab: View {
    @EnvironmentObject var orderManager: OrderManager

    var body: some View {
        NavigationStack {
            Group {
                if orderManager.placedOrders.isEmpty {
                    ContentUnavailableView(
                        "No Orders Yet",
                        systemImage: "list.bullet.clipboard",
                        description: Text("Your placed orders will appear here.")
                    )
                } else {
                    List(orderManager.placedOrders, id: \.id) { order in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Table \(order.tableNumber)")
                                    .font(.headline)
                                Spacer()
                                Text(order.status.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.brown.opacity(0.15)))
                                    .foregroundStyle(.brown)
                            }
                            Text(order.items.map { $0.emoji + " " + $0.name }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(order.formattedTotal)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Orders")
        }
    }
}

#Preview {
    AppRootView()
        .environmentObject(OrderManager())
}

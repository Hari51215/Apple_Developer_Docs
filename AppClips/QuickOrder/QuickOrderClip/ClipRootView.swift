//
//  ClipRootView.swift
//  QuickOrderClip
//
//  The main UI for the App Clip.
//  Design principle: one screen, one task, one CTA.
//
//  Target: QuickOrderClip ONLY
//

import Combine
import SwiftUI
import StoreKit
import UserNotifications

struct ClipRootView: View {
    let invocationURL: URL?

    @StateObject private var viewModel = ClipViewModel()
    @State private var showFullMenu = false
    @State private var showCart = false
    @State private var showOverlay = false
    @State private var orderPlaced = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // MARK: Header
                    ClipHeaderView(
                        tableNumber: viewModel.tableNumber,
                        itemCount: viewModel.cart.count
                    )

                    // MARK: Featured item (from URL param) or default
                    if let featured = viewModel.featuredItem {
                        FeaturedItemCard(
                            item: featured,
                            isInCart: viewModel.cart.contains(featured),
                            onAdd: { viewModel.add(featured) },
                            onRemove: { viewModel.remove(featured) }
                        )
                    }

                    // MARK: Quick picks (top 3 coffee items)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Picks")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(viewModel.quickPicks) { item in
                            QuickPickRow(
                                item: item,
                                isInCart: viewModel.cart.contains(item),
                                onAdd: { viewModel.add(item) }
                            )
                            .padding(.horizontal)
                        }
                    }

                    // MARK: See full menu button
                    Button {
                        showFullMenu = true
                    } label: {
                        Label("See Full Menu", systemImage: "menucard")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)
                    .tint(.brown)
                    .padding(.horizontal)

                    // MARK: Cart / Order CTA
                    if !viewModel.cart.isEmpty {
                        Button {
                            showCart = true
                        } label: {
                            HStack {
                                Label("View Cart (\(viewModel.cart.count) items)", systemImage: "cart.fill")
                                Spacer()
                                Text(viewModel.cartTotal)
                                    .fontWeight(.semibold)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.brown)
                        .padding(.horizontal)
                    }

                    // MARK: Get full app prompt
                    GetFullAppBanner {
                        showOverlay = true
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("QuickOrder ☕️")
            .navigationBarTitleDisplayMode(.inline)
        }
        // Full menu sheet
        .sheet(isPresented: $showFullMenu) {
            NavigationStack {
                MenuListView(items: MenuItem.catalog) { item in
                    viewModel.add(item)
                    showFullMenu = false
                }
                .navigationTitle("Full Menu")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showFullMenu = false }
                    }
                }
            }
        }
        // Cart & checkout sheet
        .sheet(isPresented: $showCart) {
            NavigationStack {
                ClipCartView(
                    viewModel: viewModel,
                    onOrderPlaced: {
                        showCart = false
                        orderPlaced = true
                        // Schedule ephemeral notification
                        Task { await viewModel.scheduleOrderReadyNotification() }
                        // Show full app overlay after order
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showOverlay = true
                        }
                    }
                )
                .navigationTitle("Your Cart")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back") { showCart = false }
                    }
                }
            }
        }
        // ✅ Recommend full app after task completes
        .appStoreOverlay(isPresented: $showOverlay) {
            SKOverlay.AppClipConfiguration(position: .bottom)
        }
        // Success toast
        .overlay(alignment: .top) {
            if orderPlaced {
                OrderSuccessBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { orderPlaced = false }
                        }
                    }
            }
        }
        .animation(.spring(), value: orderPlaced)
        .onAppear {
            viewModel.parseURL(invocationURL)
        }
        .onChange(of: invocationURL) { _, newURL in
            viewModel.parseURL(newURL)
        }
    }
}

// MARK: - Clip View Model

@MainActor
class ClipViewModel: ObservableObject {
    @Published var tableNumber: String = "—"
    @Published var featuredItem: MenuItem? = nil
    @Published var cart: [MenuItem] = []

    var quickPicks: [MenuItem] {
        MenuItem.catalog
            .filter { $0.category == .coffee }
            .prefix(3)
            .filter { $0.id != featuredItem?.id }
    }

    var cartTotal: String {
        String(format: "$%.2f", cart.reduce(0) { $0 + $1.price })
    }

    func parseURL(_ url: URL?) {
        let parsed = ClipInvocationURL(url: url)
        tableNumber  = parsed.tableNumber ?? "—"
        featuredItem = MenuItem.item(for: parsed.menuItemID)

        // Pre-add featured item to cart
        if let item = featuredItem, !cart.contains(item) {
            cart.append(item)
        }
    }

    func add(_ item: MenuItem)    { cart.append(item) }
    func remove(_ item: MenuItem) { cart.removeAll { $0.id == item.id } }

    func placeOrder() {
        let order = Order(tableNumber: tableNumber, items: cart)
        // Save to App Group so full app can continue the order
        SharedStorage.saveOrder(order)
        cart.removeAll()
    }

    // ✅ Ephemeral notification — no permission prompt needed in App Clip
    func scheduleOrderReadyNotification() async {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true
        else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your order is ready! ☕️"
        content.body  = "Table \(tableNumber) — head to the counter to collect."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5 * 60, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }
}

// MARK: - Supporting Views

struct ClipHeaderView: View {
    let tableNumber: String
    let itemCount: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "chair")
                        .foregroundStyle(.brown)
                    Text("Table \(tableNumber)")
                        .font(.headline)
                }
                Text("No download needed — order in seconds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if itemCount > 0 {
                Image(systemName: "cart.fill.badge.plus")
                    .foregroundStyle(.brown)
                    .font(.title2)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
        .padding(.top)
    }
}

struct FeaturedItemCard: View {
    let item: MenuItem
    let isInCart: Bool
    let onAdd: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Featured for your table", systemImage: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.brown)
                Spacer()
            }

            HStack(spacing: 16) {
                Text(item.emoji)
                    .font(.system(size: 52))

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(item.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.formattedPrice)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()

                Button {
                    isInCart ? onRemove() : onAdd()
                } label: {
                    Image(systemName: isInCart ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(isInCart ? .green : .brown)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
}

struct QuickPickRow: View {
    let item: MenuItem
    let isInCart: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack {
            Text(item.emoji).font(.title2).frame(width: 36)
            Text(item.name).font(.subheadline)
            Text(item.formattedPrice)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                if !isInCart { onAdd() }
            } label: {
                Image(systemName: isInCart ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundStyle(isInCart ? .green : .brown)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(isInCart)
        }
        .padding(.vertical, 4)
    }
}

struct GetFullAppBanner: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Get the QuickOrder app")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Save your preferences & order history")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.brown)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

struct OrderSuccessBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Order placed! We'll notify you when ready.")
                .font(.subheadline)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 4)
        .padding(.top, 8)
        .padding(.horizontal)
    }
}

// MARK: - Clip Cart View

struct ClipCartView: View {
    @ObservedObject var viewModel: ClipViewModel
    let onOrderPlaced: () -> Void

    var body: some View {
        CartSummaryView(
            items: viewModel.cart,
            onRemove: { viewModel.remove($0) },
            onOrder: {
                viewModel.placeOrder()
                onOrderPlaced()
            }
        )
    }
}

#Preview {
    ClipRootView(invocationURL: URL(string: "https://yourwebsite.com/order?table=5&item=latte"))
}

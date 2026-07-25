//
//  MenuView.swift
//  QuickOrderShared
//
//  ⚠️ SHARED FILE — Add to BOTH targets.
//
//  A single SwiftUI menu view reused by both the full app
//  and the App Clip to avoid code duplication.
//

import SwiftUI

// MARK: - Shared Menu List View

struct MenuListView: View {
    let items: [MenuItem]
    let onSelect: (MenuItem) -> Void

    var body: some View {
        List {
            ForEach(MenuCategory.allCases, id: \.self) { category in
                let categoryItems = items.filter { $0.category == category }
                if !categoryItems.isEmpty {
                    Section(category.rawValue) {
                        ForEach(categoryItems) { item in
                            MenuItemRow(item: item, onSelect: onSelect)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Menu Item Row

struct MenuItemRow: View {
    let item: MenuItem
    let onSelect: (MenuItem) -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text(item.emoji)
                .font(.system(size: 36))
                .frame(width: 50)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.headline)
                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(item.formattedPrice)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Button {
                    onSelect(item)
                } label: {
                    Text("Add")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.brown))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Cart Summary

struct CartSummaryView: View {
    let items: [MenuItem]
    let onRemove: (MenuItem) -> Void
    let onOrder: () -> Void

    var total: String {
        String(format: "$%.2f", items.reduce(0) { $0 + $1.price })
    }

    var body: some View {
        VStack(spacing: 0) {
            if items.isEmpty {
                ContentUnavailableView(
                    "Your Cart is Empty",
                    systemImage: "cart",
                    description: Text("Add items from the menu to get started.")
                )
            } else {
                List {
                    ForEach(items, id: \.id) { item in
                        HStack {
                            Text(item.emoji)
                            Text(item.name)
                            Spacer()
                            Text(item.formattedPrice)
                                .foregroundStyle(.secondary)
                            Button {
                                onRemove(item)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack {
                        Text("Total").fontWeight(.semibold)
                        Spacer()
                        Text(total).fontWeight(.semibold)
                    }
                    .listRowBackground(Color(.systemGray6))
                }

                Button {
                    onOrder()
                } label: {
                    Label("Place Order — \(total)", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.brown)
                .padding()
            }
        }
    }
}

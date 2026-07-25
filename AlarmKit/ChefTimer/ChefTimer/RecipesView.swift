//
//  RecipesView.swift
//  ChefTimer
//
//  Target: ChefTimer (app target only)
//

import AlarmKit
import SwiftUI

struct RecipesView: View {
    @EnvironmentObject var viewModel: AlarmViewModel
    @State private var schedulingID: UUID? = nil

    var body: some View {
        NavigationStack {
            List {
                // Authorization banner
                if viewModel.authorizationState == .denied {
                    AuthDeniedBanner()
                }

                Section("Tap a recipe to start its timer") {
                    ForEach(Recipe.catalog) { recipe in
                        RecipeRow(
                            recipe: recipe,
                            isLoading: schedulingID == recipe.id,
                            onStart: {
                                schedulingID = recipe.id
                                Task {
                                    await viewModel.scheduleTimer(for: recipe)
                                    schedulingID = nil
                                }
                            }
                        )
                    }
                }

                Section {
                    InfoRow(
                        icon: "info.circle.fill",
                        color: .blue,
                        text: "Timers are set to 1 minute for demo purposes. The alarm breaks through silent mode via AlarmKit."
                    )
                }
            }
            .navigationTitle("ChefTimer")
        }
    }
}

// MARK: - Subviews

struct RecipeRow: View {
    let recipe: Recipe
    let isLoading: Bool
    let onStart: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text(recipe.emoji)
                .font(.system(size: 36))
                .frame(width: 50)

            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.name)
                    .font(.headline)
                Text(recipe.cookingMethod)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(recipe.durationMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    onStart()
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(width: 60)
                    } else {
                        Label("Start", systemImage: "play.fill")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.orange))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AuthDeniedBanner: View {
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Alarm Access Denied")
                    .font(.subheadline).fontWeight(.semibold)
                Text("Go to Settings → Privacy → AlarmKit → ChefTimer to enable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct InfoRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    RecipesView()
        .environmentObject(AlarmViewModel())
}

//
//  ChefTimerLiveActivity.swift
//  ChefTimerWidgetExtension
//
//  Live Activity UI shown during the countdown phase.
//  AlarmKit uses ActivityConfiguration(for: AlarmAttributes.self)
//  the same way as a regular Live Activity.
//
//  Target: ChefTimerWidgetExtension ONLY
//

import AlarmKit
import WidgetKit
import SwiftUI

struct ChefTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(
            for: AlarmAttributes<CookingMetadata>.self
        ) { context in

            // MARK: Lock Screen / Banner UI
            LockScreenView(
                attributes: context.attributes,
                state: context.state
            )

        } dynamicIsland: { context in

            DynamicIsland {
                // MARK: Expanded (long-press)
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Text(context.attributes.metadata?.emoji ?? "🍳")
                            .font(.title2)
                        Text(context.attributes.metadata?.dishName ?? "Timer")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if case .countdown(let info) = context.state.mode {
                        Text(info.fireDate, style: .timer)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if let metadata = context.attributes.metadata {
                        Text("\(metadata.cookingMethod) • \(metadata.dishName)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

            } compactLeading: {
                // MARK: Compact — left pill
                Text(context.attributes.metadata?.emoji ?? "🍳")

            } compactTrailing: {
                // MARK: Compact — right pill
                if case .countdown(let info) = context.state.mode {
                    Text(info.fireDate, style: .timer)
                        .font(.caption2)
                        .frame(width: 44)
                }

            } minimal: {
                // MARK: Minimal — single icon
                Text(context.attributes.metadata?.emoji ?? "🍳")
            }
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let attributes: AlarmAttributes<CookingMetadata>
    let state: AlarmPresentationState

    var body: some View {
        HStack(spacing: 16) {
            Text(attributes.metadata?.emoji ?? "🍳")
                .font(.system(size: 44))

            VStack(alignment: .leading, spacing: 6) {
                Text(attributes.metadata?.dishName ?? "Cooking Timer")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(attributes.metadata?.cookingMethod ?? "")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))

                // Show timer if in countdown mode
                if case .countdown(let info) = state.mode {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.caption)
                        Text(info.fireDate, style: .timer)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.orange)
                } else if case .alert = state.mode {
                    Label("Ready to eat!", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                } else if case .paused = state.mode {
                    Label("Paused", systemImage: "pause.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .activityBackgroundTint(Color.black.opacity(0.8))
    }
}

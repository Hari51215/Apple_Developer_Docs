//
//  ActiveTimersView.swift
//  ChefTimer
//
//  Target: ChefTimer (app target only)
//
//  Alarm.State in iOS 26 has exactly four cases (no associated values):
//    .scheduled  → waiting to fire
//    .countdown  → actively counting down
//    .paused     → countdown paused by user
//    .alerting   → alarm is currently firing
//  Stopped alarms simply disappear from AlarmManager.alarms.
//

import AlarmKit
import SwiftUI

struct ActiveTimersView: View {
    @EnvironmentObject var viewModel: AlarmViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.activeAlarms.isEmpty {
                    ContentUnavailableView(
                        "No Active Timers",
                        systemImage: "timer",
                        description: Text("Start a cooking timer from the Recipes tab.")
                    )
                } else {
                    List {
                        ForEach(viewModel.activeAlarms, id: \.id) { alarm in
                            AlarmRow(alarm: alarm)
                        }
                    }
                }
            }
            .navigationTitle("Active Timers")
        }
    }
}

// MARK: - Alarm Row

struct AlarmRow: View {
    @EnvironmentObject var viewModel: AlarmViewModel
    let alarm: Alarm

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(viewModel.labelFor(alarm))
                    .font(.headline)
                Spacer()
                StateBadge(state: alarm.state)
            }

            // State-specific info row
            switch alarm.state {
            case .countdown:
                Label("Counting down — check Lock Screen or Dynamic Island", systemImage: "timer")
                    .font(.caption)
                    .foregroundStyle(.orange)

            case .alerting:
                Label("Alarm is firing!", systemImage: "bell.fill")
                    .font(.caption)
                    .foregroundStyle(.red)

            case .paused:
                Label("Paused — tap Resume to continue", systemImage: "pause.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)

            case .scheduled:
                Label("Scheduled — waiting to fire", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.blue)

            @unknown default:
                EmptyView()
            }

            // Controls
            HStack(spacing: 10) {
                // Pause — only when counting down
                if alarm.state == .countdown {
                    ControlButton(title: "Pause", icon: "pause.fill", color: .orange) {
                        viewModel.pause(alarm: alarm)
                    }
                }

                // Resume — only when paused
                if alarm.state == .paused {
                    ControlButton(title: "Resume", icon: "play.fill", color: .green) {
                        viewModel.resume(alarm: alarm)
                    }
                }

                // Stop — always available
                ControlButton(title: "Stop", icon: "stop.fill", color: .red) {
                    viewModel.stop(alarm: alarm)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - State Badge

struct StateBadge: View {
    let state: Alarm.State

    var label: String {
        switch state {
        case .scheduled:  return "Scheduled"
        case .countdown:  return "Running"
        case .alerting:   return "Firing 🔔"
        case .paused:     return "Paused"
        @unknown default: return "Unknown"
        }
    }

    var color: Color {
        switch state {
        case .scheduled:  return .blue
        case .countdown:  return .orange
        case .alerting:   return .red
        case .paused:     return .gray
        @unknown default: return .gray
        }
    }

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }
}

// MARK: - Control Button

struct ControlButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(color.opacity(0.12)))
                .foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ActiveTimersView()
        .environmentObject(AlarmViewModel())
}

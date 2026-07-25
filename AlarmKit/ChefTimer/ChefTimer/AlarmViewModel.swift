//
//  AlarmViewModel.swift
//  ChefTimer
//
//  Central manager for all AlarmKit interactions.
//  Corrected for iOS 26.1 SDK:
//    - manager.alarms is a throwing property → use try
//    - AlarmPresentation.Alert title requires LocalizedStringResource
//    - .snooze behaviour → .countdown (snooze removed in 26.1)
//    - manager.snooze() removed → use stop() instead
//    - Fixed generic inference for scheduleFixedAlarm
//  Target: ChefTimer (app target only)
//

import AlarmKit
import Combine
import SwiftUI

@MainActor
class AlarmViewModel: ObservableObject {

    private let manager = AlarmManager.shared

    @Published var authorizationState: AlarmManager.AuthorizationState = .notDetermined
    @Published var activeAlarms: [Alarm] = []
    @Published var errorMessage: String? = nil
    @Published var alarmLabels: [UUID: String] = [:]

    init() {
        authorizationState = manager.authorizationState
        activeAlarms = (try? manager.alarms) ?? []
    }

    // MARK: - Helpers

    private func refreshAlarms() {
        activeAlarms = (try? manager.alarms) ?? []
    }

    func labelFor(_ alarm: Alarm) -> String {
        alarmLabels[alarm.id] ?? "⏱ Timer"
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        switch manager.authorizationState {
        case .notDetermined:
            do {
                let state = try await manager.requestAuthorization()
                authorizationState = state
            } catch {
                errorMessage = "Authorization failed: \(error.localizedDescription)"
            }
        case .authorized:
            authorizationState = .authorized
        case .denied:
            authorizationState = .denied
            errorMessage = "Alarm access denied. Enable it in Settings → Privacy → AlarmKit → ChefTimer."
        @unknown default:
            break
        }
    }

    // MARK: - Schedule a cooking countdown timer

    func scheduleTimer(for recipe: Recipe) async {
        guard authorizationState == .authorized
        else {
            await requestAuthorization()
            guard authorizationState == .authorized
            else {
                return
            }
            print(recipe)
            return
        }

        let id = UUID()

        // Buttons — title uses LocalizedStringResource in iOS 26.1
        let stopButton = AlarmButton(
            text: LocalizedStringResource(stringLiteral: "Dismiss"),
            textColor: .white,
            systemImageName: "stop.circle.fill"
        )
        let repeatButton = AlarmButton(
            text: LocalizedStringResource(stringLiteral: "Repeat"),
            textColor: .white,
            systemImageName: "repeat.circle.fill"
        )
        let pauseButton = AlarmButton(
            text: LocalizedStringResource(stringLiteral: "Pause"),
            textColor: .orange,
            systemImageName: "pause.fill"
        )
        let resumeButton = AlarmButton(
            text: LocalizedStringResource(stringLiteral: "Resume"),
            textColor: .orange,
            systemImageName: "play.fill"
        )

        // Alert state — .countdown behaviour (snooze removed in iOS 26.1)
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: "\(recipe.emoji) \(recipe.name) Ready!"),
            secondaryButton: repeatButton,
            secondaryButtonBehavior: .countdown
        )

        let countdownPresentation = AlarmPresentation.Countdown(
            title: LocalizedStringResource(stringLiteral: "Cooking \(recipe.name)"),
            pauseButton: pauseButton
        )

        let pausedPresentation = AlarmPresentation.Paused(
            title: LocalizedStringResource(stringLiteral: "Paused — \(recipe.name)"),
            resumeButton: resumeButton
        )

        let presentation = AlarmPresentation(
            alert: alert,
            countdown: countdownPresentation,
            paused: pausedPresentation
        )

        let metadata = CookingMetadata(
            dishName: recipe.name,
            cookingMethod: recipe.cookingMethod,
            emoji: recipe.emoji
        )

        let attributes = AlarmAttributes<CookingMetadata>(
            presentation: presentation,
            metadata: metadata,
            tintColor: .orange
        )

        let duration = Alarm.CountdownDuration(
            preAlert: recipe.durationSeconds,
            postAlert: 2 * 60
        )

        let configuration = AlarmManager.AlarmConfiguration<CookingMetadata>(
            countdownDuration: duration,
            attributes: attributes
        )

        do {
            _ = try await manager.schedule(id: id, configuration: configuration)
            alarmLabels[id] = "\(recipe.emoji) \(recipe.name)"
            refreshAlarms()
            errorMessage = nil
        } catch {
            errorMessage = "Failed to schedule: \(error.localizedDescription)"
        }
    }

    // MARK: - Fixed date/time alarm

    func scheduleFixedAlarm(date: Date, title: String) async {
        guard authorizationState == .authorized else {
            await requestAuthorization()
            guard authorizationState == .authorized
            else {
                return
            }
            return
        }

        let id = UUID()

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: title),
            secondaryButton: AlarmButton(
                text: LocalizedStringResource(stringLiteral: "Repeat"),
                textColor: .white,
                systemImageName: "repeat.circle.fill"
            ),
            secondaryButtonBehavior: .countdown
        )

        let attributes = AlarmAttributes<CookingMetadata>(
            presentation: AlarmPresentation(alert: alert),
            tintColor: .indigo
        )

        // Must specify generic type explicitly to help the compiler
        let configuration = AlarmManager.AlarmConfiguration<CookingMetadata>(
            schedule: .fixed(date),
            attributes: attributes
        )

        do {
            _ = try await manager.schedule(id: id, configuration: configuration)
            alarmLabels[id] = "⏰ \(title)"
            refreshAlarms()
            errorMessage = nil
        } catch {
            errorMessage = "Failed to schedule alarm: \(error.localizedDescription)"
        }
    }

    // MARK: - Controls

    func stop(alarm: Alarm) {
        do {
            try manager.stop(id: alarm.id)
            refreshAlarms()
        } catch {
            errorMessage = "Stop failed: \(error.localizedDescription)"
        }
    }

    func pause(alarm: Alarm) {
        do {
            try manager.pause(id: alarm.id)
            refreshAlarms()
        } catch {
            errorMessage = "Pause failed: \(error.localizedDescription)"
        }
    }

    func resume(alarm: Alarm) {
        do {
            try manager.resume(id: alarm.id)
            refreshAlarms()
        } catch {
            errorMessage = "Resume failed: \(error.localizedDescription)"
        }
    }

    // snooze() removed in iOS 26.1 — stopping is the fallback
    func snooze(alarm: Alarm) {
        do {
            try manager.stop(id: alarm.id)
            refreshAlarms()
        } catch {
            errorMessage = "Stop failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Observe alarm state changes

    func observeAlarmUpdates() async {
        for await updatedAlarms in manager.alarmUpdates {
            activeAlarms = updatedAlarms
        }
    }
}

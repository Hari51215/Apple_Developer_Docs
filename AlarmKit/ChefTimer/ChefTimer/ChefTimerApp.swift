//
//  ChefTimerApp.swift
//  ChefTimer
//
//  Target: ChefTimer (app target only)
//

import SwiftUI

@main
struct ChefTimerApp: App {
    @StateObject private var viewModel = AlarmViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .task {
                    await viewModel.observeAlarmUpdates()
                }
        }
    }
}

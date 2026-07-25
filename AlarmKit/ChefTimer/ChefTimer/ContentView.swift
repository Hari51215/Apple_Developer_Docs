//
//  ContentView.swift
//  ChefTimer
//
//  Target: ChefTimer (app target only)
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AlarmViewModel

    var body: some View {
        TabView {
            RecipesView()
                .tabItem {
                    Label("Recipes", systemImage: "fork.knife")
                }

            ActiveTimersView()
                .tabItem {
                    Label("Timers", systemImage: "timer")
                }

            ScheduleAlarmView()
                .tabItem {
                    Label("Alarm", systemImage: "alarm")
                }
        }
        .task {
            await viewModel.requestAuthorization()
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AlarmViewModel())
}

//
//  ScheduleAlarmView.swift
//  ChefTimer
//
//  Fixed date/time alarm scheduling.
//  Target: ChefTimer (app target only)
//

import SwiftUI

struct ScheduleAlarmView: View {
    @EnvironmentObject var viewModel: AlarmViewModel
    @State private var selectedDate = Date().addingTimeInterval(60)
    @State private var alarmTitle = "Meal is ready!"
    @State private var isScheduling = false
    @State private var didSchedule = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Alarm Settings") {
                    DatePicker(
                        "Fire at",
                        selection: $selectedDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    TextField("Title", text: $alarmTitle)
                }

                Section {
                    InfoRow(
                        icon: "info.circle.fill",
                        color: .blue,
                        text: "This schedules a fixed alarm using AlarmKit. It will break through silent mode and appear on the Lock Screen and Dynamic Island."
                    )
                }

                Section {
                    Button {
                        isScheduling = true
                        Task {
                            await viewModel.scheduleFixedAlarm(
                                date: selectedDate,
                                title: alarmTitle
                            )
                            isScheduling = false
                            didSchedule = true
                        }
                    } label: {
                        HStack {
                            if isScheduling { ProgressView().tint(.white) }
                            Text("Schedule Alarm")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(isScheduling || alarmTitle.isEmpty)
                }
            }
            .navigationTitle("Schedule Alarm")
            .alert("Alarm Scheduled!", isPresented: $didSchedule) {
                Button("OK") {}
            } message: {
                Text("\"\(alarmTitle)\" will fire at \(selectedDate.formatted(date: .omitted, time: .shortened)).")
            }
        }
    }
}

#Preview {
    ScheduleAlarmView()
        .environmentObject(AlarmViewModel())
}

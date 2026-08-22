//
// ContentView.swift
// ARDrop
//

import SwiftUI

struct ContentView: View {
    @StateObject private var controller = PlacementController()

    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(controller: controller)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Text(controller.statusMessage)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)

                HStack {
                    Text("Placed: \(controller.placedCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Reset", role: .destructive) {
                        controller.reset()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding()
        }
    }
}

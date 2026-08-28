//
//  JinglePlayerView.swift
//  PixelJingle
//

import SwiftUI

struct JinglePlayerView: View {
    @StateObject private var jingleManager = JingleSequenceManager()
    @State private var selectedPreset: JinglePreset = .victory

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Picker("Preset", selection: $selectedPreset) {
                    ForEach(JinglePreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Button(jingleManager.isPlaying ? "Stop" : "Play") {
                    if jingleManager.isPlaying {
                        jingleManager.stop()
                    } else {
                        jingleManager.play()
                    }
                }
                .buttonStyle(.borderedProminent)
                .font(.title2)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)
                    Text(jingleManager.noteDescriptions.joined(separator: " → "))
                        .font(.system(.body, design: .monospaced))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Jingle Player")
            .onAppear {
                jingleManager.load(selectedPreset)
            }
            .onChange(of: selectedPreset) { _, newPreset in
                jingleManager.load(newPreset)
            }
        }
    }
}

#Preview {
    JinglePlayerView()
}

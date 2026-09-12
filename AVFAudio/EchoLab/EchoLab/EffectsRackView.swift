import SwiftUI

struct EffectsRackView: View {
    @EnvironmentObject private var engine: AudioEngineManager

    var body: some View {
        NavigationStack {
            Form {
                Section("Now Playing") {
                    if let recording = engine.selectedRecording {
                        Text(recording.displayName)
                    } else {
                        Text("Pick a recording on the Record tab")
                            .foregroundStyle(.secondary)
                    }
                    Button(engine.isPlaying ? "Stop" : "Play") {
                        if engine.isPlaying {
                            engine.stopPlayback()
                        } else if let recording = engine.selectedRecording {
                            engine.play(recording)
                        }
                    }
                    .disabled(engine.selectedRecording == nil)
                }

                Section("EQ — 1 kHz band") {
                    Slider(value: $engine.eqGain, in: -24...24, step: 1)
                    Text("\(Int(engine.eqGain)) dB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Reverb") {
                    Toggle("Enabled", isOn: $engine.reverbEnabled)
                    Slider(value: $engine.reverbWetDryMix, in: 0...100, step: 1)
                        .disabled(!engine.reverbEnabled)
                }

                Section("Pitch") {
                    Slider(value: $engine.pitchCents, in: -1200...1200, step: 50)
                    Text("\(Int(engine.pitchCents)) cents")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Distortion") {
                    Toggle("Enabled", isOn: $engine.distortionEnabled)
                    Slider(value: $engine.distortionMix, in: 0...100, step: 1)
                        .disabled(!engine.distortionEnabled)
                }
            }
            .navigationTitle("Effects Rack")
        }
    }
}

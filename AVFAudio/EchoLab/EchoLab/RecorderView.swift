import SwiftUI

struct RecorderView: View {
    @EnvironmentObject private var engine: AudioEngineManager
    @State private var permissionDenied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Button {
                    toggleRecording()
                } label: {
                    Image(systemName: engine.isRecording ? "stop.circle.fill" : "record.circle")
                        .font(.system(size: 72))
                        .foregroundStyle(engine.isRecording ? .red : .accentColor)
                }
                .padding(.top, 24)

                Text(engine.isRecording ? "Recording…" : "Tap to record a clip")
                    .foregroundStyle(.secondary)

                Divider()

                RecordingsListView()
            }
            .navigationTitle("EchoLab")
            .alert("Microphone access denied", isPresented: $permissionDenied) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Enable microphone access for EchoLab in Settings to record a clip.")
            }
        }
    }

    private func toggleRecording() {
        if engine.isRecording {
            engine.stopRecording()
            return
        }
        engine.requestMicrophonePermission { granted in
            if granted {
                engine.startRecording()
            } else {
                permissionDenied = true
            }
        }
    }
}

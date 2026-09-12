import SwiftUI

struct RecordingsListView: View {
    @EnvironmentObject private var engine: AudioEngineManager

    var body: some View {
        List(engine.recordings) { recording in
            Button {
                engine.selectedRecording = recording
            } label: {
                HStack {
                    Image(systemName: recording.id == engine.selectedRecording?.id ? "checkmark.circle.fill" : "waveform")
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading) {
                        Text(recording.displayName)
                            .font(.body)
                        if recording.id == engine.selectedRecording?.id {
                            Text("Selected for playback")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
        .overlay {
            if engine.recordings.isEmpty {
                ContentUnavailableView(
                    "No recordings yet",
                    systemImage: "waveform",
                    description: Text("Tap the record button above to make your first clip.")
                )
            }
        }
    }
}

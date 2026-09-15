import SwiftUI

enum FlowStep {
    case record
    case playback(clip: URL)
    case narrate(clip: URL)
    case export(clip: URL, narration: URL)
}

struct ContentView: View {
    @StateObject private var capture = CaptureManager()
    @State private var step: FlowStep = .record

    var body: some View {
        Group {
            switch step {
            case .record:
                RecordView { clip in step = .playback(clip: clip) }
                    .environmentObject(capture)

            case .playback(let clip):
                PlaybackView(clipURL: clip) { step = .narrate(clip: clip) }

            case .narrate(let clip):
                NarrateView(clipURL: clip) { narration in
                    step = .export(clip: clip, narration: narration)
                }

            case .export(let clip, let narration):
                ExportView(videoURL: clip, narrationURL: narration)
            }
        }
    }
}

#Preview {
    ContentView()
}

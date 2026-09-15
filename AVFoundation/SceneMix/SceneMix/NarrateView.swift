import SwiftUI
import AVFoundation

struct NarrateView: View {
    let clipURL: URL
    var onContinue: (URL) -> Void

    @StateObject private var narration = NarrationRecorder()
    @State private var mutedPlayer: AVPlayer?

    var body: some View {
        VStack(spacing: 20) {
            if let mutedPlayer {
                PlayerContainerView(player: mutedPlayer)
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text(narration.isRecording
                 ? "Recording narration over the muted clip…"
                 : "Play the clip back and talk over it.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button(narration.isRecording ? "Stop Narrating" : "Start Narrating") {
                if narration.isRecording {
                    narration.stop()
                    mutedPlayer?.pause()
                } else {
                    let player = AVPlayer(url: clipURL)
                    player.isMuted = true
                    player.seek(to: .zero)
                    mutedPlayer = player
                    narration.start()
                    player.play()
                }
            }
            .buttonStyle(.borderedProminent)

            if let narrationURL = narration.narrationURL, !narration.isRecording {
                Button("Continue to Export") {
                    onContinue(narrationURL)
                }
            }
        }
        .padding()
    }
}

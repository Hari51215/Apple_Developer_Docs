import SwiftUI
import AVFoundation

struct PlaybackView: View {
    let clipURL: URL
    var onContinue: () -> Void

    @State private var player: AVPlayer

    init(clipURL: URL, onContinue: @escaping () -> Void) {
        self.clipURL = clipURL
        self.onContinue = onContinue
        _player = State(initialValue: AVPlayer(url: clipURL))
    }

    var body: some View {
        VStack(spacing: 20) {
            PlayerContainerView(player: player)
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 24) {
                Button("Play") { player.play() }
                Button("Replay") {
                    player.seek(to: .zero)
                    player.play()
                }
            }
            .buttonStyle(.bordered)

            Button("Add Narration") {
                player.pause()
                onContinue()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

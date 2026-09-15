import AVFoundation

enum CompositionBuilder {
    enum BuildError: Error {
        case missingVideoTrack
    }

    /// Lays the recorded video and the narration audio onto a single timeline. The video track's
    /// `preferredTransform` has to be copied over explicitly — otherwise a portrait clip recorded
    /// on the device plays back sideways once it's inside the composition.
    static func makeComposition(videoURL: URL, narrationURL: URL) async throws -> AVMutableComposition {
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: videoURL)
        let narrationAsset = AVURLAsset(url: narrationURL)

        guard let sourceVideoTrack = try await videoAsset.loadTracks(withMediaType: .video).first,
              let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
              ) else {
            throw BuildError.missingVideoTrack
        }

        let videoDuration = try await videoAsset.load(.duration)
        let videoRange = CMTimeRange(start: .zero, duration: videoDuration)
        try compositionVideoTrack.insertTimeRange(videoRange, of: sourceVideoTrack, at: .zero)
        compositionVideoTrack.preferredTransform = try await sourceVideoTrack.load(.preferredTransform)

        if let sourceAudioTrack = try await narrationAsset.loadTracks(withMediaType: .audio).first,
           let compositionAudioTrack = composition.addMutableTrack(
             withMediaType: .audio,
             preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            let narrationDuration = try await narrationAsset.load(.duration)
            let audioRange = CMTimeRange(start: .zero, duration: min(narrationDuration, videoDuration))
            try compositionAudioTrack.insertTimeRange(audioRange, of: sourceAudioTrack, at: .zero)
        }

        return composition
    }
}

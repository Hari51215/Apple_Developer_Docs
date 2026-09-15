import AVFoundation
import Combine

@MainActor
final class NarrationRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var narrationURL: URL?

    private var recorder: AVAudioRecorder?

    func start() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("narration-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        guard let newRecorder = try? AVAudioRecorder(url: url, settings: settings) else { return }
        newRecorder.record()
        recorder = newRecorder
        narrationURL = url
        isRecording = true
    }

    func stop() {
        recorder?.stop()
        recorder = nil
        isRecording = false
    }
}

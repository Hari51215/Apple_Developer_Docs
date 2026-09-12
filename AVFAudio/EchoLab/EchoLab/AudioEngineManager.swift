import Combine
import Foundation
import AVFAudio

@MainActor
final class AudioEngineManager: ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordings: [Recording] = []
    @Published var selectedRecording: Recording?

    @Published var eqGain: Float = 0 {
        didSet { eq.bands[0].gain = eqGain }
    }
    @Published var reverbEnabled = true {
        didSet { reverb.wetDryMix = reverbEnabled ? reverbWetDryMix : 0 }
    }
    @Published var reverbWetDryMix: Float = 40 {
        didSet { reverb.wetDryMix = reverbEnabled ? reverbWetDryMix : 0 }
    }
    @Published var pitchCents: Float = 0 {
        didSet { timePitch.pitch = pitchCents }
    }
    @Published var distortionEnabled = false {
        didSet { distortion.wetDryMix = distortionEnabled ? distortionMix : 0 }
    }
    @Published var distortionMix: Float = 50 {
        didSet { distortion.wetDryMix = distortionEnabled ? distortionMix : 0 }
    }

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 1)
    private let reverb = AVAudioUnitReverb()
    private let timePitch = AVAudioUnitTimePitch()
    private let distortion = AVAudioUnitDistortion()

    private var recorder: AVAudioRecorder?

    private let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    init() {
        configureSession()
        buildGraph()
        observeInterruptions()
        loadRecordings()
    }

    // MARK: - Session

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("EchoLab: session configuration failed — \(error)")
        }
    }

    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        }
    }

    // MARK: - Engine graph

    private func buildGraph() {
        engine.attach(playerNode)
        engine.attach(eq)
        engine.attach(reverb)
        engine.attach(timePitch)
        engine.attach(distortion)

        eq.bands[0].filterType = .parametric
        eq.bands[0].frequency = 1000
        eq.bands[0].bandwidth = 1.0
        eq.bands[0].gain = eqGain
        eq.bands[0].bypass = false

        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = reverbEnabled ? reverbWetDryMix : 0

        distortion.loadFactoryPreset(.multiEcho1)
        distortion.wetDryMix = distortionEnabled ? distortionMix : 0

        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.connect(playerNode, to: eq, format: format)
        engine.connect(eq, to: reverb, format: format)
        engine.connect(reverb, to: timePitch, format: format)
        engine.connect(timePitch, to: distortion, format: format)
        engine.connect(distortion, to: engine.mainMixerNode, format: format)

        engine.prepare()
    }

    // MARK: - Recording

    func startRecording() {
        stopPlayback()

        let url = documentsURL.appendingPathComponent("\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.record()
            recorder = newRecorder
            isRecording = true
        } catch {
            print("EchoLab: recording failed to start — \(error)")
        }
    }

    func stopRecording() {
        guard let recorder else { return }
        recorder.stop()
        recordings.insert(Recording(url: recorder.url, date: Date()), at: 0)
        selectedRecording = recordings.first
        self.recorder = nil
        isRecording = false
    }

    private func loadRecordings() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        recordings = files
            .filter { $0.pathExtension == "m4a" }
            .compactMap { url -> Recording? in
                let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
                return Recording(url: url, date: date)
            }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Playback

    func play(_ recording: Recording) {
        do {
            let file = try AVAudioFile(forReading: recording.url)
            if !engine.isRunning {
                try engine.start()
            }
            playerNode.scheduleFile(file, at: nil) { [weak self] in
                Task { @MainActor in
                    self?.isPlaying = false
                }
            }
            playerNode.play()
            isPlaying = true
        } catch {
            print("EchoLab: playback failed — \(error)")
        }
    }

    func stopPlayback() {
        playerNode.stop()
        isPlaying = false
    }

    // MARK: - Interruptions & route changes

    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc private nonisolated func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        Task { @MainActor in
            switch type {
            case .began:
                self.playerNode.pause()
                self.isPlaying = false
            case .ended:
                guard let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    try? self.engine.start()
                }
            @unknown default:
                break
            }
        }
    }

    @objc private nonisolated func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        guard reason == .oldDeviceUnavailable else { return }
        Task { @MainActor in
            self.playerNode.pause()
            self.isPlaying = false
        }
    }
}

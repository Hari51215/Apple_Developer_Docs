import AVFoundation
import Combine

@MainActor
final class CaptureManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordedClipURL: URL?
    @Published var permissionDenied = false

    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var isConfigured = false

    func requestPermissionsAndConfigure() {
        AVCaptureDevice.requestAccess(for: .video) { videoGranted in
            AVCaptureDevice.requestAccess(for: .audio) { audioGranted in
                Task { @MainActor in
                    guard videoGranted && audioGranted else {
                        self.permissionDenied = true
                        return
                    }
                    self.configureSessionIfNeeded()
                }
            }
        }
    }

    private func configureSessionIfNeeded() {
        guard !isConfigured else { return }

        session.beginConfiguration()
        session.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let cameraInput = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(cameraInput) else {
            session.commitConfiguration()
            return
        }
        session.addInput(cameraInput)

        if let microphone = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: microphone),
           session.canAddInput(micInput) {
            session.addInput(micInput)
        }

        guard session.canAddOutput(movieOutput) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(movieOutput)
        session.commitConfiguration()
        isConfigured = true

        // AVCaptureSession.startRunning() blocks the calling thread, so it never runs on the
        // main actor — a background Task keeps the preview responsive while the session spins up.
        Task.detached(priority: .userInitiated) { [session] in
            session.startRunning()
        }
    }

    func startRecording() {
        guard !movieOutput.isRecording else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mov")
        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecording = true
    }

    func stopRecording() {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
    }
}

extension CaptureManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            self.isRecording = false
            if error == nil {
                self.recordedClipURL = outputFileURL
            }
        }
    }
}

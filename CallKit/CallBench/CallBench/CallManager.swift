import AVFoundation
import CallKit
import Combine
import UIKit

/// Owns the CXProvider/CXCallController pair and stands in for a real VoIP stack.
/// Calls are entirely local: nothing here talks to a server or another device.
final class CallManager: NSObject, ObservableObject {
    @Published private(set) var calls: [Call] = []
    @Published private(set) var observedCalls: [UUID: CXCall] = [:]
    @Published var lastError: String?

    private let provider: CXProvider
    private let callController = CXCallController()
    private let callObserver = CXCallObserver()
    private let audioEngine = AVAudioEngine()
    private var toneNode: AVAudioSourceNode?

    override init() {
        provider = CXProvider(configuration: Self.makeConfiguration())
        super.init()
        provider.setDelegate(self, queue: .main)
        callObserver.setDelegate(self, queue: .main)
    }

    private static func makeConfiguration() -> CXProviderConfiguration {
        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = false
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.generic]
        configuration.iconTemplateImageData = UIImage(systemName: "phone.fill")?.pngData()
        return configuration
    }

    /// CallKit activates the audio session itself once a transaction is under way;
    /// this only needs to describe how the session *should* be configured beforehand.
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .duckOthers])
    }

    // MARK: - Actions initiated from inside this app

    func simulateIncomingCall(callerName: String = "Ada Rivera") {
        let callID = UUID()
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: callerName)
        update.localizedCallerName = callerName
        update.hasVideo = false
        update.supportsHolding = true
        update.supportsDTMF = true
        update.supportsGrouping = false
        update.supportsUngrouping = false

        configureAudioSession()

        provider.reportNewIncomingCall(with: callID, update: update) { [weak self] error in
            guard let self else { return }
            if let error {
                self.lastError = "Couldn't report incoming call: \(error.localizedDescription)"
                return
            }
            self.calls.append(Call(id: callID, handle: callerName, direction: .incoming))
        }
    }

    func startOutgoingCall(to handle: String) {
        let callID = UUID()
        configureAudioSession()

        let startAction = CXStartCallAction(call: callID, handle: CXHandle(type: .generic, value: handle))
        callController.requestTransaction(with: startAction) { [weak self] error in
            guard let self else { return }
            if let error {
                self.lastError = "Couldn't place outgoing call: \(error.localizedDescription)"
                return
            }
            self.calls.append(Call(id: callID, handle: handle, direction: .outgoing, state: .connecting))
        }
    }

    func answer(_ callID: UUID) {
        request(CXAnswerCallAction(call: callID))
    }

    func end(_ callID: UUID) {
        request(CXEndCallAction(call: callID))
    }

    func setHeld(_ callID: UUID, onHold: Bool) {
        request(CXSetHeldCallAction(call: callID, onHold: onHold))
    }

    func setMuted(_ callID: UUID, muted: Bool) {
        request(CXSetMutedCallAction(call: callID, muted: muted))
    }

    private func request(_ action: CXAction) {
        callController.requestTransaction(with: action) { [weak self] error in
            guard let self, let error else { return }
            self.lastError = "Couldn't complete \(type(of: action)): \(error.localizedDescription)"
        }
    }

    // MARK: - Local state helpers

    private func updateCall(_ callID: UUID, _ mutate: (inout Call) -> Void) {
        guard let index = calls.firstIndex(where: { $0.id == callID }) else { return }
        mutate(&calls[index])
    }

    // MARK: - Tone generator, standing in for real call audio

    private func startTone() {
        guard toneNode == nil else { return }
        let format = audioEngine.outputNode.inputFormat(forBus: 0)
        var phase: Double = 0
        let phaseIncrement = 2 * Double.pi * 440 / format.sampleRate

        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let sample = Float(sin(phase)) * 0.15
                phase += phaseIncrement
                if phase > 2 * Double.pi { phase -= 2 * Double.pi }
                for buffer in buffers {
                    let bufferPointer = UnsafeMutableBufferPointer<Float>(buffer)
                    bufferPointer[frame] = sample
                }
            }
            return noErr
        }

        toneNode = node
        audioEngine.attach(node)
        audioEngine.connect(node, to: audioEngine.mainMixerNode, format: format)
        audioEngine.prepare()
        try? audioEngine.start()
    }

    private func stopTone() {
        guard let node = toneNode else { return }
        audioEngine.stop()
        audioEngine.disconnectNodeInput(node)
        audioEngine.detach(node)
        toneNode = nil
    }
}

// MARK: - CXProviderDelegate

extension CallManager: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        stopTone()
        calls.removeAll()
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
            self.updateCall(action.callUUID) {
                $0.state = .connected
                $0.connectedAt = Date()
            }
        }

        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        updateCall(action.callUUID) {
            $0.state = .connected
            $0.connectedAt = Date()
        }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        calls.removeAll { $0.id == action.callUUID }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        updateCall(action.callUUID) { $0.state = action.isOnHold ? .held : .connected }
        audioEngine.mainMixerNode.outputVolume = action.isOnHold ? 0 : 1
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        updateCall(action.callUUID) { $0.isMuted = action.isMuted }
        audioEngine.mainMixerNode.outputVolume = action.isMuted ? 0 : 1
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        startTone()
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        stopTone()
    }
}

// MARK: - CXCallObserverDelegate

extension CallManager: CXCallObserverDelegate {
    /// Fires for calls this app reports *and* calls placed elsewhere in the system,
    /// independent of whichever CXAction actually drove the change.
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        if call.hasEnded {
            observedCalls.removeValue(forKey: call.uuid)
        } else {
            observedCalls[call.uuid] = call
        }
    }
}

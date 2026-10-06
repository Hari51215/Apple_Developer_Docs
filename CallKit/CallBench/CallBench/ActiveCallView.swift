import SwiftUI

struct ActiveCallView: View {
    let callID: UUID
    @EnvironmentObject private var callManager: CallManager

    private var call: Call? {
        callManager.calls.first { $0.id == callID }
    }

    var body: some View {
        VStack(spacing: 24) {
            if let call {
                Text(call.handle)
                    .font(.largeTitle.bold())
                Text(stateLabel(for: call))
                    .foregroundStyle(.secondary)

                HStack(spacing: 32) {
                    Button {
                        callManager.setMuted(callID, muted: !call.isMuted)
                    } label: {
                        Label(call.isMuted ? "Unmute" : "Mute", systemImage: call.isMuted ? "mic.slash.fill" : "mic.fill")
                    }

                    Button {
                        callManager.setHeld(callID, onHold: call.state != .held)
                    } label: {
                        Label(call.state == .held ? "Resume" : "Hold", systemImage: call.state == .held ? "play.fill" : "pause.fill")
                    }
                }
                .buttonStyle(.bordered)

                if call.direction == .incoming, call.state == .ringing {
                    Button("Answer") {
                        callManager.answer(callID)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("End Call", role: .destructive) {
                    callManager.end(callID)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Text("Call ended")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .navigationTitle("Active Call")
    }

    private func stateLabel(for call: Call) -> String {
        switch call.state {
        case .ringing: "Ringing…"
        case .connecting: "Connecting…"
        case .connected: "Connected"
        case .held: "On Hold"
        case .ended: "Ended"
        }
    }
}

#Preview {
    NavigationStack {
        ActiveCallView(callID: UUID())
            .environmentObject(CallManager())
    }
}

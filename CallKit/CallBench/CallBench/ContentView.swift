import CallKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var callManager: CallManager
    @State private var outgoingHandle = "Being Hari"

    var body: some View {
        NavigationStack {
            List {
                Section("Simulate a call") {
                    Button("Simulate Incoming Call") {
                        callManager.simulateIncomingCall()
                    }

                    HStack {
                        TextField("Name or number", text: $outgoingHandle)
                        Button("Call") {
                            callManager.startOutgoingCall(to: outgoingHandle)
                        }
                        .disabled(outgoingHandle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                if !callManager.calls.isEmpty {
                    Section("Active calls") {
                        ForEach(callManager.calls) { call in
                            NavigationLink(value: call.id) {
                                CallRow(call: call)
                            }
                        }
                    }
                }

                if !callManager.observedCalls.isEmpty {
                    Section("System call observer") {
                        ForEach(Array(callManager.observedCalls.values), id: \.uuid) { systemCall in
                            SystemCallRow(call: systemCall)
                        }
                    }
                }
            }
            .navigationTitle("CallBench")
            .navigationDestination(for: UUID.self) { callID in
                ActiveCallView(callID: callID)
            }
            .alert(
                "CallKit Error",
                isPresented: Binding(
                    get: { callManager.lastError != nil },
                    set: { if !$0 { callManager.lastError = nil } }
                )
            ) {
                Button("OK") { callManager.lastError = nil }
            } message: {
                Text(callManager.lastError ?? "")
            }
        }
    }
}

private struct CallRow: View {
    let call: Call

    var body: some View {
        VStack(alignment: .leading) {
            Text(call.handle).font(.headline)
            Text("\(call.direction == .incoming ? "Incoming" : "Outgoing") · \(stateLabel)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var stateLabel: String {
        switch call.state {
        case .ringing: "Ringing"
        case .connecting: "Connecting"
        case .connected: "Connected"
        case .held: "On Hold"
        case .ended: "Ended"
        }
    }
}

private struct SystemCallRow: View {
    let call: CXCall

    var body: some View {
        VStack(alignment: .leading) {
            Text(call.uuid.uuidString.prefix(8))
                .font(.caption.monospaced())
            Text("connected: \(call.hasConnected ? "yes" : "no") · onHold: \(call.isOnHold ? "yes" : "no") · outgoing: \(call.isOutgoing ? "yes" : "no")")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

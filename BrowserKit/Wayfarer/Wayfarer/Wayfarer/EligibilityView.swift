import SwiftUI
import BrowserKit

enum EligibilityResult {
    case unknown
    case eligible
    case notEligible
    case failed(String)
}

struct EligibilityView: View {
    @State private var result: EligibilityResult = .unknown
    @State private var isChecking = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: symbolName)
                .font(.system(size: 56))
                .foregroundStyle(symbolColor)

            Text("Alternative Browser Engine Eligibility")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(description)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await checkEligibility() }
            } label: {
                if isChecking {
                    ProgressView()
                } else {
                    Text("Check This Device")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isChecking)

            Text("This calls BEAvailability.isEligible(for:.webBrowser) directly — no entitlement required to ask the question, only to act on a \"yes\".")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func checkEligibility() async {
        isChecking = true
        defer { isChecking = false }

        let outcome: Result<Bool, Error> = await withCheckedContinuation { continuation in
            BEAvailability.isEligible(for: .webBrowser) { isEligible, error in
                if let error {
                    continuation.resume(returning: .failure(error))
                } else {
                    continuation.resume(returning: .success(isEligible))
                }
            }
        }

        switch outcome {
        case .success(let eligible):
            result = eligible ? .eligible : .notEligible
        case .failure(let error):
            result = .failed(error.localizedDescription)
        }
    }

    private var symbolName: String {
        switch result {
        case .unknown: return "questionmark.circle"
        case .eligible: return "checkmark.circle.fill"
        case .notEligible: return "xmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var symbolColor: Color {
        switch result {
        case .unknown: return .secondary
        case .eligible: return .green
        case .notEligible: return .orange
        case .failed: return .red
        }
    }

    private var description: String {
        switch result {
        case .unknown:
            return "Tap below to ask the system whether this device is eligible to run an app with an alternative browser engine."
        case .eligible:
            return "This device is eligible. That's separate from whether this app is entitled to actually ship one."
        case .notEligible:
            return "This device isn't currently eligible — commonly because of region or device management restrictions."
        case .failed(let message):
            return "The check itself failed: \(message)"
        }
    }
}

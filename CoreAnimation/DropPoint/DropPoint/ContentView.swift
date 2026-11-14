import SwiftUI

struct ContentView: View {

    @State private var phase: UploadPhase = .idle
    @State private var simulateFailure = false
    @State private var animationSettled = true
    @State private var upload: Task<Void, Never>?

    private var isUploading: Bool {
        if case .uploading = phase { return true }
        return false
    }

    /// The button stays disabled until the ring has finished playing, not until
    /// the upload finishes. Those are two different moments.
    private var isBusy: Bool { isUploading || !animationSettled }

    var body: some View {
        VStack(spacing: 28) {
            Text("DropPoint")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            fileRow

            ProgressRing(phase: phase) { animationSettled = true }
                .frame(width: 190, height: 190)
                .padding(.vertical, 8)

            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .animation(.default, value: statusText)

            Spacer()

            Toggle("Make this upload fail", isOn: $simulateFailure)
                .disabled(isBusy)

            Button(action: primaryAction) {
                Text(buttonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isBusy)
        }
        .padding(24)
        .onDisappear { upload?.cancel() }
    }

    private var fileRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("quarterly-report.pdf").font(.body.weight(.medium))
                Text("8.4 MB").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private var statusText: String {
        switch phase {
        case .idle: return "Ready to upload."
        case .uploading: return "Uploading to DropPoint…"
        case .succeeded: return "Upload complete."
        case .failed: return "The connection dropped at 68%."
        }
    }

    private var buttonTitle: String {
        switch phase {
        case .idle: return "Upload"
        case .uploading: return "Uploading…"
        case .succeeded: return "Upload another"
        case .failed: return "Try again"
        }
    }

    private func primaryAction() {
        switch phase {
        case .idle, .uploading:
            startUpload()
        case .succeeded, .failed:
            phase = .idle
        }
    }

    private func startUpload() {
        upload?.cancel()
        animationSettled = false
        phase = .uploading(0)

        upload = Task {
            var sent = 0.0
            while sent < 1.0 {
                try? await Task.sleep(for: .milliseconds(200))
                if Task.isCancelled { return }

                sent = min(sent + Double.random(in: 0.07...0.15), 1.0)

                if simulateFailure && sent > 0.68 {
                    phase = .failed
                    return
                }
                phase = .uploading(sent)
            }
            phase = .succeeded
        }
    }
}

#Preview {
    ContentView()
}

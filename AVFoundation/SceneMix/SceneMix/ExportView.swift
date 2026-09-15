import SwiftUI
import AVFoundation
import Photos

struct ExportView: View {
    let videoURL: URL
    let narrationURL: URL

    @State private var progress: Float = 0
    @State private var isExporting = false
    @State private var didFinish = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            if didFinish {
                Label("Saved to Photos", systemImage: "checkmark.circle.fill")
                    .font(.title2)
            } else if isExporting {
                ProgressView(value: progress)
                    .frame(width: 220)
                Text("Exporting… \(Int(progress * 100))%")
            } else {
                Button("Mix & Export") {
                    Task { await export() }
                }
                .buttonStyle(.borderedProminent)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
        .padding()
    }

    private func export() async {
        isExporting = true
        errorMessage = nil

        do {
            let composition = try await CompositionBuilder.makeComposition(
                videoURL: videoURL,
                narrationURL: narrationURL
            )

            guard let exportSession = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetHighestQuality
            ) else {
                errorMessage = "Could not create an export session for this composition."
                isExporting = false
                return
            }

            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("SceneMix-\(UUID().uuidString).mov")

            let progressTask = Task {
                for await state in exportSession.states(updateInterval: 0.25) {
                    if case .exporting(let progress) = state {
                        self.progress = Float(progress.fractionCompleted)
                    }
                }
            }

            try await exportSession.export(to: outputURL, as: .mov)
            progressTask.cancel()

            try await saveToPhotos(url: outputURL)
            didFinish = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isExporting = false
    }

    private func saveToPhotos(url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotosError.accessDenied
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }

    enum PhotosError: Error, LocalizedError {
        case accessDenied
        var errorDescription: String? { "Photos access was denied — enable it in Settings to save the export." }
    }
}

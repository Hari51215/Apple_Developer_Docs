import SwiftUI

struct RecordView: View {
    @EnvironmentObject var capture: CaptureManager
    var onFinishedRecording: (URL) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            CameraPreviewView(session: capture.session)
                .ignoresSafeArea()

            if capture.permissionDenied {
                Text("Camera and microphone access are required. Enable them in Settings.")
                    .padding()
                    .background(.black.opacity(0.6))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 120)
            }

            Button {
                capture.isRecording ? capture.stopRecording() : capture.startRecording()
            } label: {
                Circle()
                    .fill(capture.isRecording ? Color.red : Color.white)
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(.white, lineWidth: 4).padding(4))
            }
            .padding(.bottom, 40)
        }
        .onAppear { capture.requestPermissionsAndConfigure() }
        .onChange(of: capture.recordedClipURL) { _, newValue in
            if let newValue {
                onFinishedRecording(newValue)
            }
        }
    }
}

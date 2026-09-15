# SceneMix — AVFoundation Sample Project

A buildable SwiftUI sample app demonstrating **AVFoundation**'s video side: capturing a clip
with `AVCaptureSession`, reviewing it with `AVPlayer`, narrating over it, then mixing video and
narration into one file with `AVMutableComposition` and exporting it with `AVAssetExportSession`.

---

## 📁 Project Structure

```
SceneMix/
└── SceneMix/                      → Single app target
    ├── SceneMixApp.swift          → @main entry point
    ├── ContentView.swift          → Drives the 4-step flow (Record → Playback → Narrate → Export)
    ├── CaptureManager.swift       → AVCaptureSession setup, device input, movie file output
    ├── CameraPreviewView.swift    → UIViewRepresentable hosting AVCaptureVideoPreviewLayer
    ├── RecordView.swift           → "Record" screen UI
    ├── PlayerContainerView.swift  → UIViewRepresentable hosting AVPlayerLayer
    ├── PlaybackView.swift         → "Playback" screen UI
    ├── NarrationRecorder.swift    → AVAudioRecorder-based voice-over capture
    ├── NarrateView.swift          → "Narrate" screen UI — plays the muted clip while recording
    ├── CompositionBuilder.swift   → AVMutableComposition track assembly
    ├── ExportView.swift           → AVAssetExportSession + progress UI + save to Photos
    └── Assets.xcassets
```

---

## 🛠️ Step-by-Step Xcode Setup

### Step 1 — Create the iOS App project

1. **Xcode → File → New → Project**
2. Choose **iOS → App** → Next
3. Set:
   - **Product Name:** `SceneMix`
   - **Interface:** SwiftUI
   - **Language:** Swift
4. Save and **Create**

### Step 2 — Delete the default file

Delete the generated **`ContentView.swift`** → Move to Trash

### Step 3 — Add the app files

Drag these files from `SceneMix/` into your Xcode project's `SceneMix` group (✅ Copy items if
needed, ✅ SceneMix under "Add to targets"):

- `SceneMixApp.swift`
- `ContentView.swift`
- `CaptureManager.swift`
- `CameraPreviewView.swift`
- `RecordView.swift`
- `PlayerContainerView.swift`
- `PlaybackView.swift`
- `NarrationRecorder.swift`
- `NarrateView.swift`
- `CompositionBuilder.swift`
- `ExportView.swift`

### Step 4 — Add the privacy usage descriptions

Project → **SceneMix target** → **Info** tab → add three keys:

| Key | Value |
|---|---|
| `Privacy - Camera Usage Description` (`NSCameraUsageDescription`) | "SceneMix needs the camera to record the video clip you'll narrate and export." |
| `Privacy - Microphone Usage Description` (`NSMicrophoneUsageDescription`) | "SceneMix needs the microphone to capture the clip's audio and to record your narration." |
| `Privacy - Photo Library Additions Usage Description` (`NSPhotoLibraryAddUsageDescription`) | "SceneMix saves the exported video with your narration mixed in to your Photos library." |

Without these, requesting camera/microphone access or saving to Photos crashes the app instead
of showing the system permission prompt.

### Step 5 — Set the deployment target

`AVAssetExportSession`'s `states(updateInterval:)` and `export(to:as:)` async APIs used in
`ExportView.swift` need a recent iOS version. Set the minimum deployment under project →
**SceneMix target** → **General** → **Minimum Deployments** to match your installed SDK.

### Step 6 — Clean and build

```
Product → Clean Build Folder (⇧⌘K)
```
Then **⌘R** to run — on a physical device (see Troubleshooting for why the Simulator can't
fully exercise this app).

---

## ▶️ How to Run

Select the **SceneMix** scheme → a physical iPhone or iPad (**required** for the Record step) →
**⌘R**. The app walks through 4 steps in order:

| Step | What it does |
|---|---|
| **Record** | Live camera preview with a record button. Tap to start, tap again to stop. |
| **Playback** | Review the clip with Play/Replay, then continue to add narration. |
| **Narrate** | Plays the clip back muted while recording a voice-over through the microphone. |
| **Export** | Mixes the video and narration into one file via `AVMutableComposition`, exports it with a progress bar, and saves the result to Photos. |

---

## ✅ How to Verify It's Working

1. On **Record**, grant camera and microphone permissions, record a few seconds of video, tap
   stop — the app advances to **Playback**.
2. Tap **Play** and **Replay** — the clip should play back correctly oriented (not sideways).
3. Tap **Add Narration**, then **Start Narrating** — the clip should play muted while you talk;
   tap **Stop Narrating** when done.
4. Tap **Continue to Export**, then **Mix & Export** — watch the progress bar move to 100%.
5. Once it reports "Saved to Photos," open the Photos app and confirm the exported clip has
   both the original video and your narration audio, correctly oriented and full-length.

---

## 🐛 Troubleshooting

| Problem | Fix |
|---|---|
| App crashes immediately when requesting camera/mic access | Missing `NSCameraUsageDescription`/`NSMicrophoneUsageDescription` in Info — see Step 4 |
| No camera preview, or `AVCaptureDevice.default` returns `nil` | Expected on the Simulator — it has no real camera; use a physical device for Record |
| Exported clip plays back sideways | `preferredTransform` wasn't copied onto the composition's video track — see `CompositionBuilder.swift:24-27` |
| Export fails or hangs, no error shown | Confirm both a video URL and a narration URL were actually produced before calling `export()` — check `ContentView.swift`'s step transitions |
| "Saved to Photos" never appears despite export completing | Missing `NSPhotoLibraryAddUsageDescription`, or the user denied the Photos prompt — see `ExportView.swift:81-89` |
| Narration is silent in the final export | Confirm the audio session was actually activated before `AVAudioRecorder.record()` — see `NarrationRecorder.swift:11-13` |

---

## 📚 What This Demonstrates

| Feature | File |
|---|---|
| `AVCaptureSession` configuration: device input, `AVCaptureMovieFileOutput` | `CaptureManager.swift:28-54` |
| `AVCaptureFileOutputRecordingDelegate` handling a finished recording | `CaptureManager.swift:76-90` |
| `AVCaptureVideoPreviewLayer` hosted in SwiftUI via `UIViewRepresentable` | `CameraPreviewView.swift` |
| `AVPlayer` / `AVPlayerLayer` playback hosted in SwiftUI | `PlayerContainerView.swift`, `PlaybackView.swift` |
| `AVAudioRecorder` narration capture over a muted `AVPlayer` | `NarrationRecorder.swift`, `NarrateView.swift:25-37` |
| `AVMutableComposition` / `AVMutableCompositionTrack.insertTimeRange` | `CompositionBuilder.swift:16-37` |
| `AVAssetExportSession` with async progress via `states(updateInterval:)` | `ExportView.swift:61-69` |
| Saving a video to Photos with `PHPhotoLibrary.performChanges` | `ExportView.swift:81-89` |

This pairs with the Medium article *"AVFoundation in SwiftUI — Capturing, Playing Back, and Exporting Video"*.

**[SCREENSHOT: Record screen — camera preview with record button]**
**[SCREENSHOT: Playback screen — reviewing the recorded clip]**
**[SCREENSHOT: Narrate screen — recording voice-over over the muted clip]**
**[SCREENSHOT: Export screen — progress bar and "Saved to Photos" confirmation]**

# EchoLab — AVFAudio Sample Project

A buildable SwiftUI sample app demonstrating **AVFAudio**: audio session configuration, voice
recording with `AVAudioRecorder`, an `AVAudioEngine` node graph, and four live `AVAudioUnit`
effects (EQ, reverb, pitch, distortion) applied to playback in real time.

---

## 📁 Project Structure

```
EchoLab/
└── EchoLab/                      → Single app target
    ├── EchoLabApp.swift          → @main entry point
    ├── ContentView.swift         → TabView shell (2 tabs), owns AudioEngineManager
    ├── AudioEngineManager.swift  → Session, engine graph, recording, playback, interruptions
    ├── RecorderView.swift        → "Record" tab UI
    ├── RecordingsListView.swift  → List of saved clips, selectable for playback
    ├── EffectsRackView.swift     → "Effects" tab UI — sliders/toggles for all 4 effects
    ├── Recording.swift           → Plain model for a saved clip
    └── Assets.xcassets
```

---

## 🛠️ Step-by-Step Xcode Setup

### Step 1 — Create the iOS App project

1. **Xcode → File → New → Project**
2. Choose **iOS → App** → Next
3. Set:
   - **Product Name:** `EchoLab`
   - **Interface:** SwiftUI
   - **Language:** Swift
4. Save and **Create**

### Step 2 — Delete the default file

Delete the generated **`ContentView.swift`** → Move to Trash

### Step 3 — Add the app files

Drag these files from `EchoLab/` into your Xcode project's `EchoLab` group (✅ Copy items if
needed, ✅ EchoLab under "Add to targets"):

- `EchoLabApp.swift`
- `ContentView.swift`
- `AudioEngineManager.swift`
- `RecorderView.swift`
- `RecordingsListView.swift`
- `EffectsRackView.swift`
- `Recording.swift`

### Step 4 — Add the microphone usage description

Project → **EchoLab target** → **Info** tab → add a `Privacy - Microphone Usage Description`
(`NSMicrophoneUsageDescription`) key with a string explaining why the app records audio.
Without this key, calling `AVAudioApplication.requestRecordPermission` crashes the app
immediately instead of showing the system permission prompt.

### Step 5 — Set the deployment target

`AVAudioApplication.requestRecordPermission` requires iOS 17+; the code falls back to the
older `AVAudioSession.requestRecordPermission` on earlier versions, but iOS 17 is the
simplest floor to target. Set it under project → **EchoLab target** → **General** →
**Minimum Deployments**.

### Step 6 — Clean and build

```
Product → Clean Build Folder (⇧⌘K)
```
Then **⌘R** to run.

---

## ▶️ How to Run

Select the **EchoLab** scheme → a physical iPhone (recommended — see Troubleshooting) →
**⌘R**. The app launches with 2 tabs:

| Tab | What it does |
|---|---|
| **Record** | Tap the mic button to record a clip; tap again to stop. Recordings list below, newest first. Tap a recording to select it for playback. |
| **Effects** | Play/stop the selected recording through a live chain of EQ, reverb, pitch, and distortion. Move any slider while it's playing — the change is audible immediately. |

---

## ✅ How to Verify It's Working

1. On **Record**, tap the mic button, grant the microphone permission prompt, speak for a
   few seconds, tap stop. The clip appears at the top of the list.
2. Switch to **Effects**, tap the new recording in the list (back on Record), then **Play**
   on the Effects tab.
3. Drag the EQ gain slider fully positive, then fully negative, while it's playing — the
   tone should audibly brighten and dull.
4. Enable **Reverb** and push its mix slider up — the voice should sound like it's in a
   larger room.
5. Enable **Distortion** and push its mix up — you should hear an obvious multi-echo/distortion
   character underneath the voice.
6. Drag the **Pitch** slider to an extreme and back to 0 while playing — pitch should shift
   up or down without changing playback speed.
7. Start a phone call (or trigger Do Not Disturb's "Silence" test call) while a clip is
   playing — playback should pause, then resume once the call ends.

---

## 🐛 Troubleshooting

| Problem | Fix |
|---|---|
| App crashes immediately when recording starts | Missing `NSMicrophoneUsageDescription` in Info — see Step 4 |
| Recording produces a silent/empty file | Confirm the session category was set successfully — check the Xcode console for "session configuration failed" |
| No microphone in Simulator | Expected — the Simulator has no real audio input route; use a physical device for anything recording-related |
| Effects sliders do nothing while playing | Confirm the recording was actually selected (checkmark icon in the list) before tapping Play |
| App silent after a phone call ends | Confirm `AVAudioSession.interruptionNotification` handling is wired up — see `AudioEngineManager.swift:177-224` |
| `required condition is false: !_active` on launch | The engine's graph was rewired (attach/detach) while running — build the full node chain once in `buildGraph()`, never mid-session |

---

## 📚 What This Demonstrates

| Feature | File |
|---|---|
| `AVAudioSession` category/mode configuration, activation | `AudioEngineManager.swift:51-59` |
| `AVAudioApplication.requestRecordPermission` (iOS 17+, with fallback) | `AudioEngineManager.swift:61-71` |
| `AVAudioEngine` node graph: `attach`, `connect`, `mainMixerNode`, `prepare` | `AudioEngineManager.swift:75-102` |
| `AVAudioRecorder` with an AAC/.m4a settings dictionary | `AudioEngineManager.swift:106-125` |
| `AVAudioPlayerNode` + `AVAudioFile` scheduled playback | `AudioEngineManager.swift:152-168` |
| `AVAudioUnitEQ`, `AVAudioUnitReverb`, `AVAudioUnitTimePitch`, `AVAudioUnitDistortion` | `AudioEngineManager.swift:12-29`, `82-92` |
| Interruption and route-change handling | `AudioEngineManager.swift:177-224` |
| SwiftUI effects rack UI (sliders/toggles bound to `@Published` engine state) | `EffectsRackView.swift` |

This pairs with the Medium article *"AVFAudio in SwiftUI — Recording, Live Effects, and the
Rest of Apple's Audio Stack"*.

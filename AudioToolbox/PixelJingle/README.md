# PixelJingle — Audio Toolbox Sample Project

A buildable SwiftUI sample app demonstrating **Audio Toolbox** — specifically Audio Services
(short system-sound playback) and Music Player Services (a hand-built `MusicSequence` played
through `MusicPlayer`). Everything in this app is built on `import AudioToolbox` alone; no
AVFoundation, no entitlements, no usage-description Info.plist keys.

---

## 📁 Project Structure

```
PixelJingle/
└── PixelJingle/                      → Single app target
    ├── PixelJingleApp.swift          → @main entry point
    ├── ContentView.swift             → TabView shell (2 tabs)
    ├── SFXBoardView.swift            → "SFX Board" tab UI
    ├── JinglePlayerView.swift        → "Jingle Player" tab UI
    ├── SystemSoundManager.swift      → Audio Services logic
    ├── JingleSequenceManager.swift   → MusicSequence/MusicTrack/MusicPlayer/MusicEventIterator logic
    ├── JinglePreset.swift            → Pure note-pattern data, no AudioToolbox calls
    ├── Sounds/                       → coin.caf, jump.caf, powerUp.caf, error.caf, gameOver.caf
    └── Assets.xcassets
```

---

## 🛠️ Step-by-Step Xcode Setup

### Step 1 — Create the iOS App project

1. **Xcode → File → New → Project**
2. Choose **iOS → App** → Next
3. Set:
   - **Product Name:** `PixelJingle`
   - **Interface:** SwiftUI
   - **Language:** Swift
4. Save and **Create**

### Step 2 — Delete the default file

Delete the generated **`ContentView.swift`** → Move to Trash

### Step 3 — Add the app files

Drag these files from `PixelJingle/` into your Xcode project's `PixelJingle` group (✅ Copy
items if needed, ✅ PixelJingle under "Add to targets"):

- `PixelJingleApp.swift`
- `ContentView.swift`
- `SFXBoardView.swift`
- `JinglePlayerView.swift`
- `SystemSoundManager.swift`
- `JingleSequenceManager.swift`
- `JinglePreset.swift`

### Step 4 — Add the sound effects

The app plays 5 short retro tone-blips: `coin.caf`, `jump.caf`, `powerUp.caf`, `error.caf`,
`gameOver.caf`. They're synthesized (square-wave/sine-sweep tone blips, no third-party sound
packs, no licensing to track) rather than sourced, so the whole app stays self-contained.

If you don't already have `PixelJingle/Sounds/*.caf` on disk, regenerate them:

1. Write short PCM WAV files for each effect (any tool works — a synth, a DAW export, or a
   quick script; each file should be well under 1 second).
2. Convert each to a System-Sound-compatible `.caf`, since `AudioServicesCreateSystemSoundID`
   only accepts PCM or IMA4 audio inside a Core Audio Format container:
   ```
   afconvert -f caff -d LEI16 coin.wav coin.caf
   ```
   (repeat for jump, powerUp, error, gameOver)
3. Drag the resulting `.caf` files into a `Sounds` group inside the `PixelJingle` target,
   ✅ Copy items if needed, ✅ PixelJingle under "Add to targets".

### Step 5 — Set the deployment target

No AudioToolbox API used here has an unusually high floor — iOS 16+ is plenty. Set it under
project → **PixelJingle target** → **General** → **Minimum Deployments**.

### Step 6 — Clean and build

```
Product → Clean Build Folder (⇧⌘K)
```
Then **⌘R** to run.

---

## ▶️ How to Run

Select the **PixelJingle** scheme → any iPhone simulator → **⌘R**. The app launches with 2 tabs:

| Tab | What it does |
|---|---|
| **SFX Board** | 5 buttons (Coin, Jump, Power-Up, Error, Game Over) — each plays a bundled `.caf` via Audio Services; Game Over also triggers device vibration |
| **Jingle Player** | Segmented picker across 3 presets (Victory, Level Up, Game Over Jingle), a Play/Stop button, and a live note-list readout built by reading the `MusicSequence` back with `MusicEventIterator` |

---

## ✅ How to Verify It's Working

1. On **SFX Board**, tap each button — you should hear the corresponding tone and the button
   should briefly flash on the completion callback.
2. Tap **Game Over** on a real device — you should feel a vibration in addition to the sound
   (Simulator can't vibrate, so this step is device-only).
3. On **Jingle Player**, switch between the 3 presets — the "Notes" readout should update
   immediately (e.g. Victory shows `C4 → E4 → G4 → C5`).
4. Tap **Play** — you should hear the jingle; tap **Stop** mid-playback and confirm it stops
   cleanly rather than finishing the phrase.
5. Toggle the hardware mute switch on a device and hit **Play** again — the jingle goes silent.
   That's expected: no `AVAudioSession` category is set (on purpose, to stay AudioToolbox-only),
   so playback defaults to the "ambient" route, which respects the mute switch.

---

## 🐛 Troubleshooting

| Problem | Fix |
|---|---|
| No sound in Simulator | Check the Simulator's own volume — `Sound → Output Volume` or the Mac's volume keys with the Simulator window focused |
| Game Over doesn't vibrate | Vibration only works on a physical device — Simulator silently no-ops `kSystemSoundID_Vibrate` |
| Jingle silent with mute switch on | Expected — no `AVAudioSession` category is set, so playback uses the default "ambient" route |
| `Cannot find 'kSystemSoundID_Vibrate' in scope` | Confirm `import AudioToolbox` is at the top of the file |
| SFX button does nothing | Confirm the matching `.caf` file is in the `PixelJingle` target's `Sounds/` group with correct target membership |

---

## 📚 What This Demonstrates

| Feature | File |
|---|---|
| `AudioServicesCreateSystemSoundID` / `AudioServicesDisposeSystemSoundID` | `SystemSoundManager.swift` |
| `AudioServicesPlaySystemSoundWithCompletion` | `SystemSoundManager.swift` |
| `kSystemSoundID_Vibrate` | `SystemSoundManager.swift` |
| `NewMusicSequence` / `MusicSequenceNewTrack` / `MusicTrackNewMIDINoteEvent` | `JingleSequenceManager.swift` |
| `NewMusicPlayer` / `MusicPlayerSetSequence` / `MusicPlayerPreroll` / `MusicPlayerStart` / `MusicPlayerStop` | `JingleSequenceManager.swift` |
| `NewMusicEventIterator` / `MusicEventIteratorGetEventInfo` / `MusicEventIteratorNextEvent` | `JingleSequenceManager.swift` |
| Pure preset data (no AudioToolbox calls) | `JinglePreset.swift` |

This pairs with the Medium article *"Audio Toolbox: What's Still Worth Learning in Apple's
Oldest Audio Framework"*.

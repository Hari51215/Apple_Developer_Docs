# DropPoint — Core Animation Sample Project

A single-screen iPhone app that puts a Core Animation progress ring inside a SwiftUI view. It
simulates uploading a file, fills a `CAShapeLayer` ring as the upload progresses, draws a
checkmark on success, and shakes the ring on failure.

The animation exists because SwiftUI could not express it. `Circle().trim(to:)` restarts each
transition from the model value, so overlapping progress updates make the stroke jump backwards
before moving forwards again. Reading `presentation()?.strokeEnd` and animating from there is
the fix, and it is the reason the ring is layer-backed rather than a SwiftUI shape.

The app is deliberately narrow. There is no shimmer placeholder, no confetti emitter and no
replicator-based loading indicator, even though all three would have been easy to add. They
would have turned a believable upload screen into a gallery of unrelated effects.

---

## 📁 Project Structure

```
DropPoint/
├── DropPoint.xcodeproj
└── DropPoint/
    ├── DropPointApp.swift       → @main entry point, one WindowGroup
    ├── ContentView.swift        → upload screen, phase state machine, simulated upload task
    ├── ProgressRingView.swift   → UploadPhase, RingView (all the CALayer work),
    │                              and the UIViewRepresentable bridge
    ├── Info.plist               → portrait-only iPhone app, no capabilities required
    └── Assets.xcassets          → AccentColor + AppIcon placeholders
```

---

## 🛠️ Step-by-Step Xcode Setup

### Step 1 — Create the iOS App project
File → New → Project → iOS → App. Product Name `DropPoint`, Interface **SwiftUI**, Language
**Swift**. Save it so the `.xcodeproj` sits at `CoreAnimation/DropPoint/`.

### Step 2 — Add the source files
Replace the generated `ContentView.swift` with the one here and add `ProgressRingView.swift` to
the app target. The project uses Xcode 16+ synchronised folder groups, so dropping files into
the `DropPoint/` folder is enough; there is no file list to maintain in the project file.

### Step 3 — Target settings
- Deployment target: **iOS 26.1**
- Targeted device family: **iPhone only** (`TARGETED_DEVICE_FAMILY = 1`)
- Bundle identifier: `com.hari.DropPoint`
- Signing: Automatic, personal team is fine

### Step 4 — No capabilities, no entitlements, no privacy strings
Core Animation needs none of them. Nothing in this app touches a protected resource, so the
Info.plist carries only the standard bundle keys and a portrait-only orientation list.

### Step 5 — Note what is deliberately absent
There is no `CADisableMinimumFrameDurationOnPhone` key. The app never asks for a frame rate
above the system default, so unlocking 120Hz would only cost power. Add it if you extend the
app with a `CADisplayLink` that wants a `preferredFrameRateRange` above 60Hz.

### Step 6 — Clean and build
Product → Clean Build Folder, then Product → Build. The project builds with zero warnings
against the iOS 26.1 SDK.

---

## ▶️ How to Run

Build to an iPhone (simulator or device) and use the single screen:

| Control | What it does |
|---|---|
| **Upload** | Starts the simulated upload. Progress arrives in random 7–15% jumps every 200 ms, which is what makes the interruption handling visible. |
| **Make this upload fail** | When on, the upload aborts just past 68% and the ring shakes and turns red instead of completing. |
| **Upload another / Try again** | Resets to the idle phase, clearing all animations and restoring the default colours. |

The button is disabled while `isBusy` is true, and `isBusy` stays true until the *animation*
reports it has settled, not until the upload finishes. Those are different moments, and the gap
between them is handled by a transaction completion block.

---

## ✅ How to Verify It's Working

1. **Interruption**: tap Upload and watch the ring during the jumps. The stroke should never
   retreat. If it snaps backwards, the animation is starting from the model value instead of
   the presentation layer.
2. **Sequencing**: on success the ring closes to 100%, then the checkmark draws itself in.
   The gap is produced by `beginTime` and `.backwards` fill, not by a dispatch-after.
3. **Completion timing**: the button re-enables only once the checkmark has finished drawing,
   roughly half a second after the upload itself completed.
4. **Failure path**: turn the toggle on and upload. The ring should stop near 68%, turn red,
   shake horizontally and settle back to centre.
5. **Dark mode**: switch appearance while a result is on screen. The track, stroke and text
   colours should re-resolve. If they freeze, the trait-change registration is not firing.
6. **Text crispness**: the percentage readout should be sharp. A soft readout means
   `contentsScale` has reverted to its 1.0 default.

---

## 🐛 Troubleshooting

| Problem | Fix |
|---|---|
| Ring jumps backwards on each progress update | The animation's `fromValue` is reading the model value. Use `progressLayer.presentation()?.strokeEnd` instead. |
| Whole ring morphs whenever the view resizes | `path`/`frame` assignments in `layoutSubviews` are running outside a disabled-action transaction. |
| Percentage text looks blurry | `CATextLayer.contentsScale` defaults to 1.0. Set it from `traitCollection.displayScale`. |
| Percentage text cross-fades on every tick | Assigning `string` triggers an implicit `contents` animation. Wrap it in `CATransaction.setDisableActions(true)`. |
| Checkmark visible before the ring finishes | `fillMode` is not `.backwards`, so the layer shows its model value during the `beginTime` delay. |
| Layer colours stay light after switching to dark mode | `CGColor` is a resolved snapshot. Re-resolve it inside `registerForTraitChanges`. |
| Track covers the progress stroke | Sublayers always composite above their host layer's content. The backing layer must be the track, with the progress stroke added as a sublayer. |
| Button re-enables before the animation ends | The completion handler is wired to the upload task rather than to `CATransaction.setCompletionBlock`. |
| Build fails on `registerForTraitChanges` | That API is iOS 17+. Check the deployment target. |

---

## 📚 What This Demonstrates

| Feature | File |
|---|---|
| `layerClass` override so the view's backing layer *is* a shape layer | `ProgressRingView.swift:21` |
| Shape, text and checkmark sublayers on one host | `ProgressRingView.swift:24-26` |
| Re-resolving `CGColor` on interface-style changes | `ProgressRingView.swift:66-68`, `235-243` |
| Disabling implicit actions during layout | `ProgressRingView.swift:76-105` |
| `CATextLayer` with a correct `contentsScale` | `ProgressRingView.swift:102` |
| Phase-driven animation dispatch from SwiftUI state | `ProgressRingView.swift:118-140` |
| `CABasicAnimation` on `strokeEnd` starting from the presentation layer | `ProgressRingView.swift:142-166` |
| `beginTime` + `.backwards` fill to sequence two animations | `ProgressRingView.swift:168-195` |
| `CATransaction.setCompletionBlock` reporting back to SwiftUI | `ProgressRingView.swift:191`, `214` |
| `CAKeyframeAnimation` on the `position.x` key path | `ProgressRingView.swift:197-217` |
| A reusable disabled-actions transaction helper | `ProgressRingView.swift:245-250` |
| `UIViewRepresentable` bridge for a layer-backed view | `ProgressRingView.swift:254-268` |
| Animation-settled vs upload-finished button state | `ContentView.swift:17`, `27` |
| Simulated upload with uneven progress jumps | `ContentView.swift:96-117` |

This pairs with the Medium article "Core Animation, Layer by Layer: A SwiftUI Developer's Tour
of QuartzCore".

# ARDrop — ARKit Sample Project

A buildable SwiftUI sample app demonstrating **ARKit**'s core world-tracking loop: detect a
horizontal surface, tap it, drop a cube on it. Small on purpose — it's the concrete code
walkthrough for the broader ARKit article, not a stand-in for the whole framework.

---

## ⚠️ Important: Requires a Physical Device

ARKit's world tracking needs a real camera feed. The iOS Simulator has no camera passthrough,
so this app will build in Simulator but plane detection will never produce anything meaningful
there. **Run it on a real iPhone or iPad** (rear camera, A12 chip or later) to see it work, and
take your screenshots from that device build.

---

## 📁 Project Structure

```
ARDrop/
└── ARDrop/                      → Single app target
    ├── ARDropApp.swift          → @main entry point
    ├── ContentView.swift        → SwiftUI root: AR view + status text + reset button
    ├── ARViewContainer.swift    → UIViewRepresentable wrapping ARSCNView, starts the AR session
    ├── PlacementController.swift → ARSCNViewDelegate: plane visualization, tap hit-testing,
    │                               cube placement, reset
    └── Assets.xcassets/         → AppIcon, AccentColor
```

No widget/extension target here — ARKit's core loop is single-target, so there's nothing to
share across targets.

---

## 🛠️ Step-by-Step Xcode Setup

### Step 1 — Create the iOS App project

1. **Xcode → File → New → Project**
2. Choose **iOS → App** → Next
3. Set:
   - **Product Name:** `ARDrop`
   - **Interface:** SwiftUI
   - **Language:** Swift
4. Save and **Create**

### Step 2 — Delete the default file

Delete the generated **`ContentView.swift`** → Move to Trash (we're replacing it with the one
from this repo).

### Step 3 — Add the source files

Drag these files from this repo's `ARDrop/ARDrop/` folder into your Xcode project's `ARDrop`
group:

- `ARDropApp.swift`
- `ContentView.swift`
- `ARViewContainer.swift`
- `PlacementController.swift`

In the "Choose options" sheet:
- ✅ Copy items if needed
- ✅ ARDrop under "Add to targets"

### Step 4 — Add the camera usage description

1. Select the **ARDrop** target → **Info** tab
2. Click **+** to add a new key
3. Key: `Privacy - Camera Usage Description` (`NSCameraUsageDescription`)
4. Value: `ARDrop uses the camera to track the world around you and detect flat surfaces to place objects on.`

(If you build straight from this repo's `.xcodeproj`, this is already set as a build setting —
this step is only needed if you're wiring the files into a project you created yourself.)

### Step 5 — Set the deployment target

`ARSCNView`/`ARWorldTrackingConfiguration` are available from iOS 11+, but this project targets
**iOS 17.0** to match the rest of this repo's samples:

Project → **ARDrop target** → **General** → **Minimum Deployments** → **iOS 17.0**

### Step 6 — Build

```
Product → Clean Build Folder (⇧⌘K)
```
Then connect a physical device and **⌘R**.

---

## ▶️ How to Run

Select the **ARDrop** scheme → pick your connected iPhone/iPad (not a simulator) → **⌘R**.

1. Point the camera at a flat surface (a table or floor works well) and move the device slowly.
2. Once a surface is found, a translucent blue plane appears and the status text updates.
3. Tap anywhere on the highlighted plane to drop an orange cube there.
4. Keep tapping to place more cubes — the counter at the bottom tracks how many.
5. Tap **Reset** to clear every cube and restart plane detection from scratch.

---

## 📚 What This Demonstrates

| Feature | Where to find it |
|---|---|
| `ARSCNView` bridged into SwiftUI | `ARViewContainer.swift` (`UIViewRepresentable`) |
| `ARWorldTrackingConfiguration` + horizontal plane detection | `ARViewContainer.swift`, `PlacementController.reset()` |
| Visualizing `ARPlaneAnchor`s as they're added/updated/removed | `PlacementController.renderer(_:didAdd:for:)` / `didUpdate:` / `didRemove:` |
| Tap → raycast hit-test against existing plane geometry | `PlacementController.handleTap(_:)` |
| Placing an `SCNNode` at a raycast result's world transform | `PlacementController.handleTap(_:)` (`simdTransform`) |
| Resetting an `ARSession` (`.resetTracking`, `.removeExistingAnchors`) | `PlacementController.reset()` |

---

## 🐛 Troubleshooting

| Problem | Fix |
|---|---|
| No planes ever appear | You're likely in Simulator — ARKit needs a real device. On-device, try better lighting and a surface with visible texture (plain white tables can be slow to detect). |
| App crashes immediately on launch | Missing `NSCameraUsageDescription` — see Step 4. |
| Camera permission denied | Settings → Privacy & Security → Camera → enable ARDrop, then relaunch. |
| Cubes appear far from where you tapped | Make sure you're tapping on the highlighted blue plane, not empty space — the raycast only hits `existingPlaneGeometry`. |
| Build fails with "no such module 'ARKit'" | Confirm you're building for an iOS device/simulator destination, not "My Mac" — ARKit isn't available on macOS. |

---

This pairs with the Medium article *"ARKit, Explained: How Apple's AR Framework Works — and a
Plane-Detection App to Prove It"*.

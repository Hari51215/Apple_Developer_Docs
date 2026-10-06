# CallBench — CallKit Sample Project

A buildable SwiftUI sample app demonstrating **CallKit**: reporting simulated incoming and
outgoing calls through `CXProvider`/`CXCallController`, driving mute/hold/answer/end from both
the system's native call UI and the app's own screen, observing system-wide call state with
`CXCallObserver`, and handling the `AVAudioSession` handoff CallKit performs around every call.

Every call in this app is entirely local — there's no VoIP push, no server, no real audio peer.
Calls are triggered by tapping a button, and a synthesized tone stands in for real call audio so
the audio-session handoff has something audible to prove it's working.

---

## 📁 Project Structure

```
CallBench/
└── CallBench/                    → Single app target
    ├── CallBenchApp.swift         → @main entry point, owns CallManager
    ├── CallManager.swift          → CXProvider/CXCallController/CXCallObserver, tone generator
    ├── ContentView.swift          → Call list + "simulate a call" controls
    ├── ActiveCallView.swift       → In-call screen: mute, hold, answer, end
    ├── Call.swift                 → Local model mirroring the state CXCall exposes
    ├── Info.plist                 → Declares UIBackgroundModes: [voip], required by CXProvider
    └── Assets.xcassets
```

---

## 🛠️ Step-by-Step Xcode Setup

### Step 1 — Create the iOS App project

1. **Xcode → File → New → Project**
2. Choose **iOS → App** → Next
3. Set:
   - **Product Name:** `CallBench`
   - **Interface:** SwiftUI
   - **Language:** Swift
4. Save and **Create**

### Step 2 — Delete the default file

Delete the generated **`ContentView.swift`** → Move to Trash

### Step 3 — Add the app files

Drag these files from `CallBench/` into your Xcode project's `CallBench` group (✅ Copy items
if needed, ✅ CallBench under "Add to targets"):

- `CallBenchApp.swift`
- `CallManager.swift`
- `ContentView.swift`
- `ActiveCallView.swift`
- `Call.swift`

### Step 4 — Add the Voice-over-IP background mode

`CXProvider` refuses to report calls at all unless the app declares the **Voice over IP**
background mode — this is required even for a purely foreground, in-app-triggered call like the
ones CallBench simulates, not just for apps that wake via a real VoIP push. Project → **CallBench
target** → **Signing & Capabilities** → **+ Capability** → **Background Modes** → check **Voice
over IP**. (This project's checked-in `Info.plist` already has `UIBackgroundModes: [voip]` set;
this step is what to do if you're rebuilding the project from scratch.)

No microphone usage description is needed — CallBench's "call audio" is a locally generated tone,
not a microphone recording — and no VoIP push entitlement is needed since it never registers for
`PushKit`.

### Step 5 — Set the deployment target

Set the **Minimum Deployments** target under project → **CallBench target** → **General**. Any
recent iOS version works; the project ships targeting iOS 26.1.

### Step 6 — Clean and build

```
Product → Clean Build Folder (⇧⌘K)
```
Then **⌘R** to run.

---

## ▶️ How to Run

Select the **CallBench** scheme → a **physical iPhone** (required — see Troubleshooting) →
**⌘R**.

| Screen | What it does |
|---|---|
| **CallBench** (list) | "Simulate Incoming Call" reports a fake call from "Ada Rivera" through the system's native call UI. The text field + "Call" button places a fake outgoing call to whatever name you type. Active calls and the raw `CXCallObserver` feed both show up as sections once a call exists. |
| **Active Call** | Mute, hold, answer (for a still-ringing incoming call), and end — each one drives a real `CXAction` through `CXCallController`. |

---

## ✅ How to Verify It's Working

1. Tap **Simulate Incoming Call**. The real iOS incoming-call screen should appear (not a view
   inside the app) — accept or decline it from there, or from the lock screen if you back out
   and lock the device first.
2. Tap **Accept** — the system dismisses its call UI, and CallBench's own active-call screen
   should show "Connected" with an audible tone starting within about a second.
3. Tap **Hold** — the tone should stop and the system call UI should reflect the hold state;
   tap **Resume** and the tone should return.
4. Tap **Mute** — the tone should stop without changing the call's connected/held state.
5. Tap **End Call** — the tone stops, the call disappears from both the active-calls list and
   the system call observer section.
6. Repeat using the **Call** button for an outgoing call: it should show "Connecting…" for about
   1.5 seconds, then flip to "Connected" on its own, matching how a real outgoing VoIP call
   reports its own connection progress.

---

## 🐛 Troubleshooting

| Problem | Fix |
|---|---|
| Tapping "Simulate Incoming Call" does nothing, no alert, no system call UI | Almost always a missing **Voice over IP** background mode — see Step 4. Confirm `UIBackgroundModes` contains `voip` in the built app's Info.plist; without it `reportNewIncomingCall`'s completion handler receives an error instead of showing the call UI. |
| An alert titled "CallKit Error" appears instead of the call UI | The error message is the actual `CXError` — the app now surfaces `lastError` instead of failing silently (`CallManager.swift:58-65`, `73-81`, `99-104`). Read the message; it names exactly what CallKit rejected. |
| No incoming-call screen appears, or it looks like a plain in-app view | You're likely running in Simulator — CallKit's native call UI and audio-session behavior are unreliable there. Use a physical device. |
| Tone never starts after answering | Check that `provider(_:didActivate:)` actually fired — see `CallManager.swift:199-201`; if the audio session category failed to set, `configureAudioSession()` (`CallManager.swift:38-41`) is the place to check for a thrown error. |
| Call UI stays on screen after tapping End | Every `CXAction` must call `fulfill()` or `fail()` — see the delegate methods in `CallManager.swift:153-206`; a path that returns early before either call will strand the system UI. |
| Second call's system UI behaves oddly | CallKit expects exactly one `CXProvider` per process — confirm `CallManager` is only ever instantiated once, as a `@StateObject` in `CallBenchApp.swift:5`. |
| Outgoing call never reports "Connected" | The 1.5-second simulated connect delay lives in `CallManager.swift:162-169` — if you shortened or removed it, make sure `reportOutgoingCall(with:connectedAt:)` still runs. |

---

## 📚 What This Demonstrates

| Feature | File |
|---|---|
| `CXProviderConfiguration` setup (video support, call/group limits, handle types, icon) | `CallManager.swift:26-34` |
| Configuring `AVAudioSession` ahead of CallKit's own activation | `CallManager.swift:38-41` |
| Reporting a simulated incoming call with `CXCallUpdate`/`CXHandle` | `CallManager.swift:45-66` |
| Placing an outgoing call via `CXStartCallAction` + `CXCallController` | `CallManager.swift:68-81` |
| Requesting answer/end/hold/mute actions from in-app UI, surfacing `CXError` to the UI | `CallManager.swift:83-104` |
| `CXProviderDelegate`: fulfilling actions, `providerDidReset` | `CallManager.swift:153-206` |
| Audio session handoff (`didActivate`/`didDeactivate`) driving a synthesized tone | `CallManager.swift:115-148`, `199-205` |
| `CXCallObserver`/`CXCallObserverDelegate` for system-wide call state | `CallManager.swift:210-220` |
| `UIBackgroundModes: [voip]` — the capability CallKit requires to report calls at all | `CallBench/Info.plist` |
| SwiftUI screens bound to `@Published` call state, including error alerts | `ContentView.swift`, `ActiveCallView.swift` |

This pairs with the Medium article *"Letting iOS Handle Your App's Calls with CallKit."*

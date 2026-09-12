# AVFAudio in SwiftUI — Recording, Live Effects, and the Rest of Apple's Audio Stack

*Subtitle: Building a voice-effects app surfaced the parts of AVFAudio worth knowing: engine graphs, sessions, MIDI, spatial audio, and speech.*

AVFAudio's own documentation summarizes itself in one sentence: play, record, and process audio, and configure your app's system audio behavior. That single sentence hides a surprising amount of ground — a full node-based engine, four flavors of audio unit, a 3D spatial mixer, a MIDI sequencer, and a speech synthesizer, all living under one import. Most apps that touch audio use maybe 10% of it. This piece tries to cover the other 90% too, not just the slice a typical sample app needs.

This article was researched and drafted with help from Claude (Anthropic's AI assistant), then reviewed and edited by me before publishing — in the interest of being upfront about how it came together.

## What AVFAudio covers

No mention of video, no mention of composition or export in that opening sentence — because those stayed behind in AVFoundation. AVFAudio has been documented as its own importable module since iOS/iPadOS 14.5, which means you can write `import AVFAudio` instead of the much heavier `import AVFoundation` if all you need is sound. For a small utility app that never touches a camera or a video track, that's a meaningfully smaller dependency surface.

The framework's own topic map splits into five areas: system audio (sessions, interruptions, routing), basic playback and recording (`AVAudioPlayer`, `AVAudioRecorder`, `AVMIDIPlayer`), advanced audio processing (the engine, nodes, MIDI, spatial audio), speech synthesis, and a scattering of Swift macros. The sections below walk through all five, roughly in the order most apps run into them.

The class names still carry the `AV` prefix from AVFoundation's Objective-C days, and the API underneath hasn't been rewritten to hide that — completion handlers instead of `async`/`await` on the engine and player types, `NSObject`-based delegate patterns in a couple of corners, notification-center observing for session events instead of a `Combine` publisher. None of that is a complaint exactly; it's a framework old enough to predate Swift itself, still doing real-time audio work where a decade of stability matters more than a modern-looking call signature.

## Audio sessions: the part everyone skips until it bites

`AVAudioSession` isn't optional plumbing. Apple's default session for any app allows playback but blocks recording outright, mutes on the Ring/Silent switch, and silences audio the moment the screen locks. Opting into anything else means setting a category and activating the session before touching a recorder or a player:

```swift
let session = AVAudioSession.sharedInstance()
try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
try session.setActive(true)
```

`.playAndRecord` opts into both directions at once; `.defaultToSpeaker` keeps output on the speaker instead of the earpiece when no headphones are connected, which matters for anything that isn't a phone-call app. Skip the category call entirely and `AVAudioRecorder` throws before it records a single sample.

The session also has to survive the outside world interrupting it — a phone call, Siri, another app grabbing the audio hardware. That means observing two notifications: `AVAudioSession.interruptionNotification` and `AVAudioSession.routeChangeNotification`. A reasonable handler pauses playback when an interruption begins, restarts the engine when it ends with `.shouldResume` set in the notification's payload, and pauses again if a route change reports `.oldDeviceUnavailable` — the case where headphones get pulled out mid-playback. None of this is exotic code, but it's the difference between an app that survives a phone call and one that silently stops working and never tells you why.

## Recording: AVAudioRecorder is still the right tool

For a straightforward "record to a file" job, `AVAudioRecorder` beats reaching for the engine's input node — no tap callback, no manual buffer-to-file writing, just a settings dictionary and `.record()`:

```swift
let settings: [String: Any] = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVSampleRateKey: 44_100,
    AVNumberOfChannelsKey: 1,
    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
]
let recorder = try AVAudioRecorder(url: url, settings: settings)
recorder.record()
```

Mono AAC at 44.1kHz is plenty for a spoken voice memo and keeps files small; a music app would reach for stereo and possibly a higher sample rate or a lossless format. The only real gotcha is sequencing — construct the recorder before the session is active, and the initializer throws instead of quietly falling back to defaults.

## The engine graph: wired once, adjusted forever

`AVAudioEngine` is the framework's real workhorse — a graph of `AVAudioNode` objects you attach, connect, and let run. A minimal chain looks like this:

```swift
engine.attach(playerNode)
engine.attach(reverbUnit)
engine.connect(playerNode, to: reverbUnit, format: format)
engine.connect(reverbUnit, to: engine.mainMixerNode, format: format)
engine.prepare()
```

Every graph ends at `mainMixerNode`, which the engine creates lazily — you can query its `outputFormat(forBus:)` before the engine has ever started and get back a sensible default, useful as the common format for every connection in the chain.

The rule worth internalizing before writing a single line of graph code: the topology can only change while the engine is stopped. Attach, detach, or reconnect a node while it's running, and the engine throws `required condition is false: !_active` immediately. Think of it the way a sound engineer patches a mixing desk before a show starts, not mid-song — every input goes to a fixed channel, and what changes afterward is gain and sends, never the cabling. Practically, that means designing for every node you might ever need to be permanently wired in from the start, then turning effects on and off by adjusting parameters like `wetDryMix` or `bypass` rather than by touching the graph itself.

## Playback: AVAudioPlayerNode vs. AVAudioPlayer

`AVAudioPlayer` is the simpler API and it's fine for "play this file, no processing." The moment audio needs to pass through even one `AVAudioUnit`, it has to enter an `AVAudioEngine` graph instead, which means `AVAudioPlayerNode`:

```swift
let file = try AVAudioFile(forReading: url)
playerNode.scheduleFile(file, at: nil) { [weak self] in
    Task { @MainActor in
        self?.isPlaying = false
    }
}
playerNode.play()
```

That completion handler fires on a non-main thread — the engine's render thread doesn't know or care about SwiftUI's `@MainActor` requirement — so any UI state it touches needs an explicit hop back to the main actor. Forgetting that hop is a common way to get a SwiftUI runtime warning that has nothing to do with the audio itself.

## Effects: four Audio Units, one shared pattern

`AVAudioUnitEQ`, `AVAudioUnitReverb`, `AVAudioUnitTimePitch`, and `AVAudioUnitDistortion` all live under the framework's "Audio effects" and "Time effects" groupings, alongside siblings like `AVAudioUnitDelay` and `AVAudioUnitVarispeed`. Two of the most commonly used ones ship factory presets, which is worth knowing before writing parameter-tuning code from scratch:

```swift
reverb.loadFactoryPreset(.mediumHall)
distortion.loadFactoryPreset(.multiEcho1)
```

`AVAudioUnitReverb` has fourteen presets from `.smallRoom` to `.cathedral`; `AVAudioUnitDistortion` has twenty, split across drum, multi-effect, and speech categories. Starting from a preset and exposing only `wetDryMix` as a single slider gets a usable-sounding effect in a fraction of the code that hand-tuning every parameter would take. `AVAudioUnitEQ` works differently — it's built from one or more parametric bands, each with its own frequency, bandwidth, gain, and bypass flag, so a single-band EQ centered around 1kHz with a gain slider is a common, simple starting point. Pitch shifting through `AVAudioUnitTimePitch.pitch` works in cents; a range of roughly ±1200 covers a full octave in either direction, which is usually enough to sound obviously different without turning a voice into something unrecognizable.

## What else lives in the framework

Formats and buffers sit underneath everything above. `AVAudioFormat` wraps Core Audio's `AudioStreamBasicDescription` and is immutable once created; `AVAudioPCMBuffer` and `AVAudioFile` are what you'd reach for the moment you need raw sample access — writing a custom visualizer, doing sample-accurate editing, or streaming audio you're generating rather than reading from disk. `AVAudioConverter` handles resampling and format conversion when two parts of a pipeline don't agree on sample rate or channel count. Scheduling a whole file onto a player node sidesteps needing any of this, which is exactly the point where a lot of tutorials quietly stop.

Spatial audio is the part of the engine built for games and immersive apps: `AVAudioEnvironmentNode` places sounds in 3D space using `AVAudio3DMixing`, `AVAudio3DPoint`, and orientation types that track a listener's position and facing direction. It's a legitimately deep sub-API, and also one I wouldn't reach for outside a spatial or gaming context — wiring a plain voice app through a 3D environment node would be solving a problem nobody has.

MIDI support runs from the simple end (`AVMIDIPlayer`, which just plays a MIDI file through a sound bank) to the elaborate end (`AVAudioSequencer` for building and arranging MIDI tracks programmatically, `AVAudioUnitSampler` for turning MIDI events into sampled instrument audio, `AVAudioUnitMIDIInstrument` as the base class instruments build on). Anyone building a music-creation or backing-track app lives in this corner of the framework.

Speech synthesis is the one piece of AVFAudio worth reaching for outside everything above — `AVSpeechSynthesizer` and `AVSpeechUtterance` turn a string into spoken audio in a handful of lines, no session juggling required beyond what the system already handles for you. It's easy to forget this lives in the same framework as the entire engine and node graph, because the two barely overlap in complexity.

## Pitfalls that cost real debugging time

A few things worth knowing before they cost you an afternoon:

- **Configure the session before anything else.** `AVAudioRecorder` and engine playback both fail — sometimes silently, sometimes with an opaque `OSStatus` error — if the category isn't set and active first.
- **The Simulator lies about hardware.** It has no real microphone route and won't simulate a genuine interruption; test recording and interruption handling on a physical device before trusting either.
- **Don't do real work in a render callback.** Anything that runs on the engine's audio thread — a tap block, a custom `AVAudioSourceNode` — needs to avoid locks, allocations, and Swift concurrency hops. Do that work off the audio thread and hand the result back asynchronously instead.
- **Restart the engine after an interruption ends.** It doesn't resume on its own even when `.shouldResume` is set; that's your app's job, and skipping it is why some players go silent after a phone call ends.

## Building EchoLab

Everything above got exercised while building EchoLab, the sample app for this piece — a two-tab SwiftUI app that records a clip on one tab and runs it through a live effects rack on the other. Recording plus a chain of four Audio Units touches session configuration, the engine's node graph, and playback in one coherent flow, which is more ground than a plain memo-and-playback app would cover.

**[Screenshot: EchoLab's Record tab, mid-recording, with the red stop button visible]**

The effects rack is where the graph rule from earlier stopped being theoretical. The first version toggled effects by attaching and detaching nodes on demand — reverb on, `attach` and reconnect; reverb off, `detach` and reconnect around the gap. It ran for exactly one tap before crashing with `required condition is false: !_active`. The fix ended up simpler than the thing it replaced: build the entire chain once, at launch —

```swift
engine.attach(playerNode)
engine.attach(eq)
engine.attach(reverb)
engine.attach(timePitch)
engine.attach(distortion)

engine.connect(playerNode, to: eq, format: format)
engine.connect(eq, to: reverb, format: format)
engine.connect(reverb, to: timePitch, format: format)
engine.connect(timePitch, to: distortion, format: format)
engine.connect(distortion, to: engine.mainMixerNode, format: format)
```

— and drive every toggle in the UI through `wetDryMix`, `gain`, and `bypass` instead of the topology. Flipping an effect on the rack is instant and glitch-free now, because the graph itself never moves after launch. That one crash taught me more about how AVAudioEngine wants to be used than any doc page did.

**[Screenshot: EchoLab's Effects tab, showing all four effect sections and their sliders]**

Getting the project to a state where a clean build reported `BUILD SUCCEEDED` was the easy part. The Simulator has no real input device, so recording, the permission prompt, and interruption handling all needed a physical iPhone before I trusted any of it — a green build tells you the Swift compiles, not that the microphone route works. Testing the interruption path meant recording a clip, starting playback with an effect on, then taking a phone call mid-clip and confirming playback paused and picked back up cleanly once the call ended.

**[Screenshot: EchoLab's recordings list with one clip selected for playback]**

## Resources

- [AVFAudio](https://developer.apple.com/documentation/avfaudio) — the framework's top-level documentation
- [Audio Engine](https://developer.apple.com/documentation/avfaudio/audio-engine) — nodes, mixing, spatial audio, MIDI
- [Audio Units](https://developer.apple.com/documentation/avfaudio/audio-units) — the effects and time-effects classes used in EchoLab
- [AVAudioSession](https://developer.apple.com/documentation/avfaudio/avaudiosession) — categories, modes, interruption handling
- [AVAudioFormat](https://developer.apple.com/documentation/avfaudio/avaudioformat) — the immutable format type behind every buffer and file
- [EchoLab source](./EchoLab) — the full sample project this article references

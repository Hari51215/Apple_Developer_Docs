# Core Audio

Medium article: [Core Audio in Swift: Formats, Buffers, and the Half of It Your iPhone Never Gets](https://hari51215.medium.com/core-audio-in-swift-formats-buffers-and-the-half-of-it-your-iphone-never-gets-d6166e83bbd2)

No sample app for this topic. Core Audio's hardware layer is macOS-only, and the one test device
here is an iPhone, so a SwiftUI demo could only show the types half — which is a handful of structs
that the article's own listings explain better than a screen would. The parts worth seeing are
device trees, stream formats and compiler diagnostics, none of which are UI. Everything was instead
verified with a throwaway read-only Swift command-line harness, which is where every number below
came from.

Written and verified against Xcode 26.1 (17B55), macOS 26.7 (25G229), Swift 6.2.1, on Apple silicon.
Availability claims were checked against the SDK headers and the `.swiftinterface` files rather than
against developer.apple.com, which mattered a great deal here.

**Findings from comparing the headers against the documentation:**

- **The documentation's platform line is close to fiction.** The Core Audio landing page claims
  iOS 2.0, iPadOS, Mac Catalyst, macOS, tvOS, visionOS and watchOS. `CoreAudio.framework` in
  `iPhoneOS26.1.sdk` ships exactly one header, a 4-line stub that re-exports CoreAudioTypes. All
  nine real headers — `AudioHardware.h`, `AudioHardwareBase.h`, `AudioHardwareTapping.h`,
  `CATapDescription.h`, `AudioServerPlugIn.h`, `HostTime.h`, `AudioHardwareDeprecated.h`,
  `AudioDriverPlugIn.h`, `CoreAudio.h` — exist only in the macOS SDK. The iOS module map is five
  lines long.

- **Apple shipped a full Swift HAL API in macOS 15 and documented it almost nowhere.**
  `AudioHardwareSystem`, `AudioHardwareDevice`, `AudioHardwareStream`, `AudioHardwareClock`,
  `AudioHardwareControl`, `AudioHardwareBox`, `AudioHardwarePlugin`, `AudioHardwareProcess`,
  `AudioHardwareTap`, `AudioHardwareAggregateDevice`, plus `AudioHardwareError: LocalizedError`
  and the `PropertyListenerDelegate` protocol. It lives in the Swift overlay
  (`usr/lib/swift/CoreAudio.swiftmodule/*.swiftinterface`), not in any header, which is probably
  why it is invisible. Every property is `get throws`; every class is `@unchecked Sendable`.
  `AudioHardwareDevice` subclasses `AudioHardwareClock`, not `AudioHardwareObject` — a device is
  modelled as a clock that also does I/O.

- **The real-time contract became compiler-checkable in the 26 SDK.** `CA_REALTIME_API`, new since
  the 15.4 SDK, expands to Clang's `[[clang::nonblocking]]`, and is applied to the
  `AudioDeviceIOProc` typedef, the block form, `AudioDeviceGetCurrentTime`,
  `AudioDeviceTranslateTime` and all five `HostTime.h` functions. Verified by building a
  deliberately bad I/O proc with `-Wfunction-effects`: clang diagnosed `malloc`,
  `pthread_mutex_lock`, `pthread_mutex_unlock` and `free`, and correctly left `memset` alone. The
  attribute must be repeated on the definition, not only the declaration, or you get a mismatch
  warning instead of the analysis.

- **`HostTime.h` claims iOS availability in a header iOS has never shipped.** All five functions
  carry `__OSX_AVAILABLE_STARTING(__MAC_10_0, __IPHONE_2_0)`. `CATapDescription` is marked
  `ios(15.0)` and `CATapMuteBehavior` `ios(16.0)`, in a file absent from the iOS SDK entirely.

- **Host time is not nanoseconds.** `AudioGetHostClockFrequency()` returned 24,000,000 on this
  machine, so one tick is 41.67 ns. Treating the raw value as nanoseconds is off by a factor of
  ~42. The header deliberately never names a unit, because the ratio differs across Intel and
  Apple silicon.

- **CoreAudioTypes carries zero availability annotations.** No `API_AVAILABLE`, `API_DEPRECATED`
  or `API_UNAVAILABLE` anywhere in `CoreAudioBaseTypes.h` (1621 lines), including on recent
  additions like `kAudioFormatAPAC` and the CICP immersive tags. The only version marker is
  `#define COREAUDIOTYPES_VERSION 20211130`, a 2021 stamp still shipping in the 26.1 SDK. The whole
  tap *property* surface is unannotated too; only the two tap functions carry `macos(14.2)`.

- **Shipping doc bugs in the headers.** `kAudioFormatFlagIsPacked` documents a field
  `mBitsPerSample` that does not exist (the struct has `mBitsPerChannel`).
  `kAudioChannelLayoutTag_SMPTE_DTV` references `kAudioChannelLayoutTag_ITU_5_1`, a symbol that was
  never defined. `kAudioFormatMPEG4AAC_ELD_V2` is in the enum but missing from the doc block above
  it.

**From running the harness rather than reading anything:**

- `usesVariableBufferFrameSizes` is documented without qualification and threw
  `kAudioHardwareUnknownPropertyError` (`who?`) on all five devices on this Mac. Aggregate devices
  threw the same for `modelUID` and `hogModePID`. The system object threw it for `baseClassID`.
- `AudioHardwareError.errorDescription` only resolves the HAL four-char codes. `kAudio_ParamError`
  (-50) and `kAudio_MemFullError` (-108) come back with an empty string.
- Virtual and physical stream formats genuinely differ in the wild: an iPhone attached by
  Continuity Capture reported an interleaved virtual format and a non-interleaved physical one.
  Its input latency is 6000 frames, an eighth of a second at 48 kHz.
- `ManagedAudioChannelLayout(tag:)` reports the right `numberOfChannels` but
  `channelDescriptions.count` of 1, because the flexible array is declared with one element and a
  tag-based layout never fills it. Don't iterate it unless the tag says to.
- `AudioBufferList.sizeInBytes(maximumBuffers:)` is 8 bytes of header plus 16 per buffer: 24, 40,
  136 for 1, 2 and 8.
- A third-party `AudioServerPlugIn` was already installed (a Microsoft Teams loopback device,
  transport type `virt`, zero latency and zero safety offset), which made a useful real example of
  a virtual device next to the built-in hardware.

Taps and aggregate devices are covered in the article from the headers and Apple's sample only. The
harness was deliberately read-only, since creating them changes system state and triggers a
system-audio-recording permission prompt.

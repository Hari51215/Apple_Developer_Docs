# Core Bluetooth

Medium article: [Core Bluetooth from the Headers Up: Roles, GATT, and the Parts the Docs Skip](https://hari51215.medium.com/core-bluetooth-from-the-headers-up-roles-gatt-and-the-parts-the-docs-skip-e1192c67cdfd)

No sample app for this topic. Every interesting thing Core Bluetooth does needs a second radio on
the other end: a central has nothing to scan for without a peripheral, a peripheral has nobody to
serve, and the one test device here is a single iPhone. The Simulator has no Bluetooth hardware at
all, so even a two-process setup isn't possible. A demo would amount to a permission prompt and an
empty list, which the article's own listings explain better than a screen would.

Written and verified against Xcode 26.1 (17B55) on Apple silicon. Every API claim in the article was
read out of `CoreBluetooth.framework/Headers` in `iPhoneOS26.1.sdk` — all 18 headers, 2,649 lines,
plus `CoreBluetooth.apinotes` — rather than from developer.apple.com, and every Swift listing was
typechecked against the iOS SDK with `swiftc -typecheck` before publishing.

**Findings from comparing the headers against the documentation:**

- **Channel Sounding is on the landing page and absent from the SDK.** Apple's Core Bluetooth
  documentation lists a whole Channel Sounding section — `CBChannelSoundingSessionConfiguration`,
  `CBChannelSoundingProcedureResults`, `CBPeripheral.startChannelSoundingSession(_:)`,
  `CBCentralManager.supports(.channelSounding)`. `grep -ri sounding` across all 18 headers in the
  26.1 SDK returns nothing. It's iOS 27, and it additionally needs an iPhone 17 or later, an
  accessory supporting Bluetooth 6.3, and AccessorySetupKit pairing, which the system requires
  before it will start a session. The article says plainly that this section is unverified.

- **There is a third Bluetooth privacy key that Apple never documented.**
  `INFOPLIST_KEY_NSBluetoothWhileInUseUsageDescription` ships as a real build setting in Xcode
  26.1's `CoreBuildSystem.xcspec`, displayed as "Privacy - Bluetooth While In Use Usage
  Description". It's the only Bluetooth key in that file whose `Description` contains no
  developer.apple.com link, because no page exists. The documented
  `NSBluetoothAlwaysUsageDescription` page doesn't mention it either.

- **The Swift name of a delegate callback doesn't match the header, and the compiler is strict
  about it.** The header declares `peripheralIsReadyToSendWriteWithoutResponse:`; Swift renamed it
  to `peripheralIsReady(toSendWriteWithoutResponse:)` in Swift 3. Writing the header's spelling
  gives `'peripheralIsReadyToSendWriteWithoutResponse' has been renamed to …`, not an
  unknown-method error. Caught by the typecheck pass after it went into the first draft.

- **The peripheral role is iOS and macOS only, which the landing page doesn't say.** Both
  designated initializers of `CBPeripheralManager`, and the initializers of `CBMutableService`,
  `CBMutableCharacteristic` and `CBMutableDescriptor`, all carry
  `API_UNAVAILABLE(watchos, tvos)` and `API_UNAVAILABLE(visionos)`. Only the central role is
  genuinely cross-platform.

- **The GATT database and the advertising channel are system-wide**, stated only in the
  `CBPeripheralManager` header comment: each app gets "sandboxed access to the shared GATT
  database", and advertising "is managed at the system level and shared by all applications. This
  means that even if you aren't advertising at the moment, someone else might be!"

- **`CBManager.authorization` had a one-point-release life as an instance property.** It arrived in
  iOS 13.0 and was deprecated in 13.1 in favour of the class property of the same name. Both are
  still in `CBManager.h`, so both still autocomplete.

- **L2CAP PSM discovery has a hardcoded well-known UUID in the header**, not in the docs:
  `CBUUIDL2CAPPSMCharacteristicString` is `ABDD3056-28FA-441D-A470-55A75A52553A`, holding a
  little-endian `UInt16`. Channels aren't discoverable on their own, so this is the convention for
  publishing a PSM to clients.

- **Two of the `CBError` cases are watchOS-only despite sitting in the shared enum.**
  `CBErrorLeGattExceededBackgroundNotificationLimit` and `…NearBackgroundNotificationLimit` are
  marked `API_AVAILABLE(watchos(9.0)) API_UNAVAILABLE(macos, ios, tvos)`.

- **`CoreBluetooth.apinotes` is six lines long** and does exactly one thing: maps `CBError` to
  `CBErrorDomain` and `CBATTError` to `CBATTErrorDomain`, which is what gives Swift the two
  distinct error types.

- Smaller header-only details that never reached the rendered docs: an `RSSI` of `127` in
  `didDiscover` is a reserved "not available" sentinel; a `nil` service list when scanning is
  "strongly discouraged" and forbidden outright in the background; notifications longer than
  `CBCentral.maximumUpdateValueLength` are truncated silently rather than rejected; batched write
  requests must be applied atomically or not at all.

**Verification notes:**

- Swift listings were concatenated into one throwaway file and built with
  `swiftc -typecheck -sdk $(xcrun --sdk iphoneos --show-sdk-path) -target arm64-apple-ios18.0`.
  It found one real error in the draft, the renamed delegate callback above. Nothing was run and
  nothing from the harness landed in this folder.
- `NSBluetoothWhileInUseUsageDescription` was located by grepping
  `Xcode.app/Contents/SharedFrameworks/.../CoreBuildSystem.xcspec` and cross-checked against the
  `NSBluetoothAlwaysUsageDescription` documentation page, which doesn't list it.

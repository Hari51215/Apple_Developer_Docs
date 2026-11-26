# Core Foundation

Medium article: [A Walk Through Core Foundation: From CFTypeRef to the Darwin Notify Center](https://hari51215.medium.com/a-walk-through-core-foundation-from-cftyperef-to-the-darwin-notify-center-36ab4e6b0c1f)

Sample app: none. Core Foundation is a C substrate that Swift code reaches into for a handful of
specific jobs, and the four that still matter (a Darwin notification, a tokenizer attribute, a
forced-preference check, a file descriptor on a run loop) are each one function call. A SwiftUI
demo would be a button wired to `CFNotificationCenterPostNotification`, which teaches less than the
snippets in the article already do.

The article is organised bottom-up, as the user asked: `CFTypeRef` and the polymorphic functions,
then the Create/Get ownership rule and its Swift form (`Unmanaged`), then allocators, then toll-free
bridging, and only then the catalog — collections, strings and text, dates and locales, URLs and
bundles and property lists and preferences, the run loop, notifications and IPC, streams and
sockets, and the leftovers. Coverage spans all 54 opaque types, all 6 utility groups, and the 7
reference pages on the framework's landing page.

Written against Xcode 26.1 with the iOS 26.1 SDK on an Apple-silicon Mac. Every availability and
deprecation claim in the article was checked against the 47 headers in
`iPhoneOS26.1.sdk/System/Library/Frameworks/CoreFoundation.framework/Headers`, not against the
rendered documentation pages.

**Findings from comparing the headers against the documentation:**

- **Two of the six "Utilities" groups on the landing page are deprecated in full.** Eight of the
  nine functions in Time Utilities (`CFGregorianDate`, `CFGregorianUnits`,
  `CFAbsoluteTimeGetDayOfWeek`, `CFAbsoluteTimeGetWeekOfYear`, and the rest) carry
  `API_DEPRECATED("Use CFCalendar or NSCalendar API instead", macos(10.4,10.10), ios(2.0,8.0))`.
  `CFAbsoluteTimeGetCurrent()` is the only survivor. Every exported symbol in URL Access Utilities
  went in `ios(2.0,7.0)` — `CFURLAccess.h` has 12 `CF_EXPORT` lines and 13 `API_DEPRECATED`
  attributes. Neither group page shows any of this, because the deprecation lives on the individual
  symbols.

- **The framework's newest work is absent from the docs entirely.** `CFBase.h` gained
  `CFAllocatorAllocateTyped`, `CFAllocatorReallocateTyped`, `CFAllocatorAllocateBytes` and
  `CFAllocatorReallocateBytes` in `macos(15.0), ios(18.0)`, with a header comment saying they exist
  "to either serve as rewrite targets for the compiler, or to be invoked internally to
  Foundation/CoreFoundation." Plain `CFAllocatorAllocate` now carries
  `_CF_TYPED_ALLOC(CFAllocatorAllocateTyped, 2)`. That is type-segregated heap allocation
  retrofitted into a 2001-era C API. `developer.apple.com/.../corefoundation/cfallocatorallocatetyped`
  returns 404, and the rendered CFAllocator page lists only the six pre-2001 memory functions.

- **iOS 26 added eleven calendar identifiers that have no documentation pages.**
  `kCFBanglaCalendar`, `kCFGujaratiCalendar`, `kCFKannadaCalendar`, `kCFMalayalamCalendar`,
  `kCFMarathiCalendar`, `kCFOdiaCalendar`, `kCFTamilCalendar`, `kCFTeluguCalendar`,
  `kCFVikramCalendar`, `kCFDangiCalendar` and `kCFVietnameseCalendar` are all
  `API_AVAILABLE(macos(26.0), ios(26.0), …)` in `CFLocale.h`; their doc URLs 404. Grepping
  `ios(26.0)` across the 47 headers returns 14 symbols: those 11, plus
  `CFAttributedStringGetStatisticalWritingDirections` and the two `kCFURLUbiquitousItem…`
  sync keys — which are exactly the three the landing page does list, under "Functions" and
  "Variables".

- **The authoritative toll-free bridging table is a macro, not a documentation page.**
  `CF_BRIDGED_TYPE(NSString)` on `CFStringRef`, `CF_BRIDGED_TYPE(NSNumber)` on `CFBooleanRef`,
  `CF_BRIDGED_TYPE(NSInputStream)` on `CFReadStreamRef`, `CF_BRIDGED_TYPE(NSTimer)` on
  `CFRunLoopTimerRef`, and so on. Types bridged only to `id` — `CFBundle`, `CFRunLoop`,
  `CFRunLoopSource`, `CFRunLoopObserver`, `CFSocket`, `CFNotificationCenter`, `CFBag`,
  `CFBinaryHeap`, `CFBitVector`, `CFTree`, `CFUUID`, `CFStringTokenizer`, `CFDateFormatter`,
  `CFNumberFormatter`, `CFPlugIn`, `CFURLEnumerator`, `CFUserNotification` — have no Foundation
  class to cast into at all. That distinction is the real answer to "when would I reach for CF."

- **The run loop is explicitly fenced off from Swift concurrency.** `CFRunLoopGetCurrent`,
  `CFRunLoopRun` and `CFRunLoopRunInMode` are each marked
  `CF_SWIFT_UNAVAILABLE_FROM_ASYNC("… cannot be used from async contexts.")` in `CFRunLoop.h`
  (lines 58, 70, 73), which expands to `@_unavailableFromAsync`. No documentation page mentions it.

- **`CFStringCreateStringWithValidatedFormat` is Swift-unavailable by design.** `CFString.h:239`
  and `:242` carry `CF_SWIFT_UNAVAILABLE("Use string interpolations instead")`.

- **`CFUserNotification` is macOS-only and the docs don't say so.** Every function in
  `CFUserNotification.h` is `API_AVAILABLE(macos(10.0)) API_UNAVAILABLE(ios, watchos, tvos)`, yet it
  sits in the landing page's opaque-type list with no platform note.

- **CF networking has been handed to the Network framework.**
  `CFStreamCreatePairWithSocket`, `CFStreamCreatePairWithSocketToHost` and
  `CFStreamCreatePairWithPeerSocketSignature` all carry
  `API_DEPRECATED("Use nw_connection_t in Network framework instead", …, API_TO_BE_DEPRECATED)`.

- **The Darwin notify center's constraints exist only as a header comment.**
  `CFNotificationCenter.h:45–60` lists them: no notification objects, no `userInfo`, no suspension
  behaviours, `object` ignored on add and post, `name` may not be `NULL`, system-wide with no
  per-user sessions, and the main run loop must be running in a common mode for delivery. All of it
  is silently ignored rather than diagnosed.

- **`CFXMLParser`/`CFXMLNode`/`CFXMLTree` were deprecated in `ios(2.0,6.0)`** and are still listed
  as current opaque types on the landing page.

**Verification notes:**

- All seven Swift listings in the article were extracted into one throwaway file and typechecked
  with `swiftc -typecheck -sdk $(xcrun --sdk iphonesimulator --show-sdk-path) -target
  arm64-apple-ios26.1-simulator`. Zero diagnostics.
- The topic inventory (6 utility groups, 54 opaque types, 7 reference pages, 2 variables, 1
  function) was read from `developer.apple.com/tutorials/data/documentation/corefoundation.json`,
  the JSON behind the rendered landing page, rather than scraped from HTML.
- Missing-documentation claims were checked by requesting each symbol's doc JSON directly and
  recording the HTTP status: `cfallocatortypeid` → 200, `cfallocatorallocatetyped` → 404,
  `cfallocatorallocatebytes` → 404, `kcfbanglacalendar` → 404.
- Style pass on the final draft: 3,646 words (~14 min read), 5 em-dashes across 69 prose
  paragraphs and bullets, one "actually" and no other intensifiers, no tables, no cross-references
  to other topics in this repo.
- No root `README.md` table row was added. Every other C-topic folder here is an unpublished draft
  with no table row; the row goes in once the article is live and has a Medium URL.

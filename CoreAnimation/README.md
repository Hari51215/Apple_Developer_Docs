# Core Animation

Medium article: [Core Animation, Layer by Layer: A SwiftUI Developer's Tour of QuartzCore](https://hari51215.medium.com/core-animation-layer-by-layer-a-swiftui-developers-tour-of-quartzcore-72445b45a95d)

Sample app: [`DropPoint/`](./DropPoint) — a one-screen upload flow whose progress ring is a
`CAShapeLayer` driven by explicit `strokeEnd` animations, so overlapping progress updates
interrupt cleanly instead of snapping back the way `Circle().trim(to:)` does. See
[`DropPoint/README.md`](./DropPoint/README.md) for setup and testing instructions.

Written and built against Xcode 26.1 (17B55) with the iOS 26.1 SDK on an Apple-silicon Mac.
Every availability claim in the article was checked against the QuartzCore headers in
`iPhoneOS26.1.sdk` rather than against the documentation pages, which turned out to matter.

**Four things worth recording from that comparison:**

- **The landing page lists three macOS-only symbols without saying so.** `CALayoutManager`,
  `CAConstraint` and `CAConstraintLayoutManager` appear under "Layer Basics" with no platform
  note. `CAConstraintLayoutManager.h` wraps the entire file in
  `API_UNAVAILABLE_BEGIN(ios, tvos, watchos, visionos)`. They are macOS and Mac Catalyst only.

- **`CARenderer`'s abstract describes a path that no longer exists on iOS.** It still reads
  "render a layer tree into a Core OpenGL context", but the OpenGL initialiser is macOS-only and
  deprecated, while `CARenderer(mtlTexture:options:)` has been on iOS since iOS 11. Rendering a
  layer tree into a Metal texture off-screen is useful on iPhone and the summary hides it.

- **HDR on a layer has been rewritten twice in three releases.** `wantsExtendedDynamicRangeContent`
  (a Bool) → `toneMapMode` in iOS 18 → `preferredDynamicRange` in iOS 26, which takes a
  `CADynamicRange` of `.automatic`, `.standard`, `.constrainedHigh` or `.high`, with a companion
  `contentsHeadroom`. The iOS 26 header deprecates the original Bool outright. The header
  comments are more opinionated about which value to choose than the documentation is.

- **`QCCompositionLayer` is on the Core Animation landing page but not in the iOS SDK.** It hosts
  a Quartz Composer composition, which is macOS-only and long unmaintained. `CARemoteLayerClient`
  and `CARemoteLayerServer` are in the same category: listed, legacy, macOS-only.

Two further findings came out of building the sample app rather than reading anything. Sublayers
always composite above their host layer's own content, so a progress ring built on a `layerClass`
override has to make the backing layer the *track* and add the animated stroke on top. And a
`CGColor` is a resolved snapshot that does not follow the interface style the way a `UIColor` on
a view does, so layer colours silently freeze when the user switches to dark mode unless you
re-resolve them on a trait change.

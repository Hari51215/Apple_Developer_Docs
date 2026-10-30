# ColorSync

Medium article: ["Nearly Half of Display P3 Falls Outside sRGB, and Other Things ColorSync Will Tell You"](https://hari51215.medium.com/nearly-half-of-display-p3-falls-outside-srgb-and-other-things-colorsync-will-tell-you-ce489df973d5)

No sample app for this topic — ColorSync is a Core Foundation C API with no interface of its own,
and the half of it that would justify a UI doesn't exist on iPhone. Device registration, display
profile assignment, VCGT gamma tables, profile installation and CMM plug-ins are all macOS-only,
and absent from the iOS SDK headers entirely rather than merely unavailable. What remains on iOS
is profiles, tags, transforms, gamut checks and code fragments: buffer-in, buffer-out arithmetic
that reads better as a dozen lines of Swift in the article than as a screenshot of a colour swatch.

The article's numbers were produced by running ColorSync directly from short Swift programs on
macOS 26.1 rather than by building an app — the full 24-bit gamut sweeps, the per-intent and
black-point-compensation comparisons, the profile/tag inventory of all fifteen built-in profiles,
the code-fragment decomposition and the throughput measurements. The Headroom Adaptive Gain Curve
API is iOS/macOS 27 and is not present in the SDK installed here, so that section is documented
from Apple's reference and flagged as uncompiled in the article itself.

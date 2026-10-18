# Cinematic

Medium article: ["Focus Decisions, Not Keyframes: Editing Cinematic Mode Video in Swift"](https://hari51215.medium.com/focus-decisions-not-keyframes-editing-cinematic-mode-video-in-swift-dccefafcb9e2)

No sample app for this topic — Cinematic cannot demonstrate anything without a movie recorded in
Cinematic mode on an iPhone 13 or later, and the effect it produces is only visible on a physical
device. A demo app would build and launch on any machine and show an empty picker on most of them,
so the pipeline (composition, custom `AVVideoCompositing` conformance, `CNRenderingSession` per
frame, weak/strong `CNDecision` edits) is shown as code in the article instead.

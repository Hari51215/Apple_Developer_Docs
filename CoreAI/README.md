# Core AI

Medium article: [Core AI: Everything Expensive Happens Before Your First Inference](https://hari51215.medium.com/core-ai-everything-expensive-happens-before-your-first-inference-744064e40fd0)

Sample app: none. Core AI's runtime surface is meaningless without a converted `.aimodel`, and
producing one is a Python/PyTorch job rather than a SwiftUI one. A demo app would have been a text
field wrapped around someone else's exported model, which teaches less than the walkthrough does.

The article is organised around **specialization** — the device-specific compile step between the
portable `.aimodel` file and the first inference. That one idea explains the async initializer, the
cache and its purge policies, bookmark data, ahead-of-time compilation, and three of the four
debugging tools, so the piece follows it rather than walking the symbol list top to bottom.

Coverage spans the whole documentation tree: `AIModel`, `AIModelAsset` and its metadata/summary
types, `AIModelCache` with `Policy` and `PurgeConditions`, `SpecializationOptions`,
`ComputeUnitKind`, `InferenceFunction` with both `run` overloads plus `encode`/`ComputeStream`/
`AsyncValue`, `InferenceFunctionDescriptor`, `InferenceValue`, `ImageDescriptor`, `NDArray` with its
views, scalar types and `InterleaveLayout`, `NDArrayDescriptor`, `AssetError`, the `coreai-build`
ahead-of-time path, the background-inference entitlement, the debug gauge / Instruments template /
Core AI Debugger, and the Foundation Models and Evaluations hand-offs.

Four things worth recording from the documentation, because none of them are obvious from the
symbol list:

- **`run(inputs:states:outputViews:)` changes its own return value.** Any output you supply a
  pre-allocated view for is written in place and is *absent* from the returned `Outputs`. Adding a
  buffer pool to a working call site empties the dictionary the caller was reading, with no type
  change to signal it.
- **`loadFunction(named:)` splits failure across two channels.** It throws when loading fails and
  returns `nil` when no function carries that name.
- **`.persistent` is not a guarantee.** It blocks purging under storage pressure and source-model
  changes only; an OS update always invalidates specialized assets regardless of policy. It is also
  unavailable on tvOS.
- **The background-inference entitlement is broader than its name.**
  `com.apple.developer.background-tasks.continued-processing.inference` gates *any* background
  Neural Engine access, continued-processing task or not, and applies to Core ML and Metal
  Performance Shaders Graph as much as to Core AI.

Core AI requires version 27.0 across iOS, iPadOS, macOS, Mac Catalyst, tvOS, watchOS and visionOS.
Ahead-of-time compilation narrows further, to Apple Intelligence hardware only (A17 Pro, M1, or M2
on Vision Pro), and is absent on tvOS and watchOS. Building any target containing a `.aimodel` also
needs the Metal Toolchain, which Xcode does not install by default.

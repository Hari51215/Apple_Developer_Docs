# Background Assets: Apple's Answer to the Slow First Launch

**Subtitle:** How Managed and Self-Hosted asset packs let iOS and macOS apps pull content down after install instead of stalling on it before.

---

The first time I ran Apple's Background Assets tooling, it failed in under a second with this:

```
Error: The specified item could not be found in the keychain.
```

I'd asked `ba-serve` (the command-line tool that stands in for App Store Connect while you test locally) to serve an asset pack over HTTPS using whatever identity it could find automatically. It found nothing, because I hadn't created a certificate yet. No fallback to plain HTTP, no "did you mean to skip encryption for testing." Background Assets simply refuses to hand you a download URL that isn't HTTPS, even on your own Mac, talking to your own simulator. That single error told me more about how seriously Apple treats this framework than any paragraph in the documentation did.

Background Assets exists to solve a problem every app with meaningful content runs into eventually: what do you do when the thing people need doesn't fit in the initial download? A game with a few gigabytes of character models. A course app with video lessons. A camera app shipping a machine learning model that's too large to bundle for every user on every platform. Before this framework, your options were bundling everything into the app binary and making the App Store download bigger for everyone, or writing your own `URLSession`-based downloader and hoping it survives being backgrounded, killed, and relaunched days later. Background Assets is Apple's answer to the second option — a system service that owns the download lifecycle so your code doesn't have to babysit it.

## Essential, Prefetch, and On-Demand

Every asset pack declares a download policy, and the three options map surprisingly well onto moving into a new apartment. **Essential** assets are the boxes you need unpacked before you can function: they download during installation and count toward the progress bar people watch on the App Store, TestFlight, or the Home Screen. **Prefetch** assets are what the movers keep bringing in while you're already living there. Download starts at install time too, but it keeps running in the background after the app is usable, instead of blocking anything. **On-demand** assets are the storage unit across town — nothing moves until you specifically ask for it, by ID, from your own code.

Get this classification wrong and you feel it immediately. Mark a level-ten unlock as essential and you've just made every new player wait for content they might never reach. Mark the tutorial as on-demand and new users hit a loading spinner exactly when you want them least annoyed.

## Two Ways to Host: Managed and Self-Hosted

Background Assets forks into two architectures, and picking between them is really a question about who owns your CDN.

With **Apple-Hosted, Managed** asset packs, you upload compressed `.aar` archives to App Store Connect the same way you'd upload a build, and Apple's infrastructure handles delivery, resumable downloads, storage-aware eviction, and version updates — all without a build resubmission. The ceiling is generous: up to 200GB of compressed assets per app, on every platform except watchOS. If you don't already run backend infrastructure for content delivery, this is the obvious default.

With **Self-Hosted, Unmanaged**, you keep your own server, write your own manifest format, and your app extension is responsible for turning that manifest into download requests. The appeal isn't nostalgia for running servers — it's that some teams already have a CDN serving the same assets to Android, web, or a game console, and standing up a second, Apple-only distribution pipeline through App Store Connect would just be duplicated infrastructure. If that's not your situation, self-hosting mostly buys you extra plumbing to maintain.

## Building a Managed Pack

The workflow starts with a template:

```sh
xcrun ba-package template -o Manifest.json
```

One thing caught me off guard: the output is JSON with `//` comments baked in, explaining each field inline.

```json
{
    "assetPackID": "[Asset-Pack ID]",
    "downloadPolicy": {
        "essential": {
            "installationEventTypes": [
                "firstInstallation",
                "subsequentUpdate"
            ]
        }
    },
    "fileSelectors": [
        { "file": "[Path to File]" },
        { "directory": "[Path to Directory]" }
    ],
    "platforms": ["iOS", "macOS", "tvOS", "visionOS"]
}
```

That's not valid JSON by any strict parser's definition, but `ba-package` reads it fine — it's meant to be edited by a human, once, and stripped down to something real before it ships. I filled mine in for a single video file and one download policy:

```json
{
    "assetPackID": "Tutorial",
    "downloadPolicy": {
        "essential": {
            "installationEventTypes": ["firstInstallation"]
        }
    },
    "fileSelectors": [
        { "file": "Videos/Introduction.m4v" }
    ],
    "platforms": ["iOS", "macOS"]
}
```

Packaging it took one command and ran in well under a second for a small test file:

```sh
xcrun ba-package Manifest.json -o Tutorial.aar
```

The resulting `.aar` is what you upload independently of your app binary — through Transporter, `altool`, or the App Store Connect API — and submit for review alongside a TestFlight build or App Store release. Paths inside `fileSelectors` are resolved relative to wherever you run the command, which matters if your asset directory sits somewhere other than next to the manifest.

On the app side, everything routes through `AssetPackManager`:

```swift
let pack = try await AssetPackManager.shared.assetPack(withID: "Tutorial")
try await AssetPackManager.shared.ensureLocalAvailability(of: pack)

for await update in AssetPackManager.shared.statusUpdates(forAssetPackWithID: "Tutorial") {
    switch update {
    case .downloading(_, let progress):
        updateProgressBar(progress.fractionCompleted)
    case .finished:
        playIntroVideo()
    case .failed(_, let error):
        showDownloadError(error)
    default:
        break
    }
}
```

`ensureLocalAvailability` is worth calling even for essential packs, since a flaky network at install time can leave a pack short and this call quietly finishes the job or confirms it's already done. Every asset pack you download shares one namespace, so once a file is local you reach it by path (`contents(at:)` or `descriptor(for:)`) without tracking which pack it came from. When you're done with a pack, `remove(assetPackWithID:)` frees the space; nothing stops you from calling `ensureLocalAvailability` again later if the user comes back for it.

If you need to filter which devices get which assets — skipping 4K textures on older hardware, say — a `ManagedDownloaderExtension` lets you override `shouldDownload(_:)` and veto individual files at request time.

## Going It Alone: The Self-Hosted Path

The self-hosted flow trades convenience for control, and it's a stricter deal than I expected the first time I read through it. Adding a "Self-Hosted, Unmanaged" Background Download extension target requires an App Group shared between the app and the extension (plus App Sandbox on macOS), and a handful of Info.plist keys on the app target: `BAManifestURL` for where your manifest lives, `BAEssentialMaxInstallSize` and `BAMaxInstallSize` capping uncompressed sizes, and `BAInitialDownloadRestrictions` — a nested dictionary controlling compressed download allowances (`BADownloadAllowance`, `BAEssentialDownloadAllowance`) and which domains are even allowed to serve assets (`BADownloadDomainAllowList`, wildcards included).

The part that actually surprised me is how much control the system takes away from you here. On install or update, the app doesn't get to launch first and fetch things lazily — the system fetches your manifest from `BAManifestURL`, launches your extension (which conforms to `BADownloaderExtension`) with that manifest's location, and only lets the app open once the extension has turned the manifest into `BAURLDownload` requests and the essential ones have resolved. Your extension itself gets suspended while the actual transfer happens; the system wakes it again to hand back completed or failed downloads through `BADownloadManager`, which owns the whole queue. This isn't a background convenience API bolted onto your existing launch sequence — for essential content, it *is* your launch sequence.

That's also the biggest risk of the self-hosted path: get your size estimates wrong in `BAInitialDownloadRestrictions` and you've built a mechanism that can hold your own app hostage at every cold start until a network condition resolves.

## Testing It Without Shipping It

Which brings me back to that keychain error. Apple doesn't let Background Assets fall back to HTTP for local testing, so `ba-serve` needs a real certificate chain before it'll serve anything. The actual setup, once I did it properly, was: create a self-signed root CA in Keychain Access, issue a leaf SSL certificate whose common name matches the exact hostname or IP the test device will hit, install the root CA on the device through an Apple Configurator profile, and mark it trusted (Settings → Developer on iOS, Keychain Access' trust panel on macOS). Only then does

```sh
xcrun ba-serve --host localhost Tutorial.aar
```

have an identity to pick from, and only then does pointing the test device at it (via Settings → Developer → Background Assets Testing on iOS, or `xcrun ba-serve url-override` on macOS) pull the pack down. It's more ceremony than most local-testing workflows ask for, but it matches how seriously the framework treats the network path in production, where a spoofed or downgraded connection to your asset server is a real attack surface.

## When Downloads Fail

Errors surface through `ManagedBackgroundAssetsError` on the managed side and `BAErrorDomain`/`BAErrorCode` on the self-hosted side, but the one worth knowing about ahead of time is `AssetPackManager.LocalAvailabilityError`. Batch calls to `ensureLocalAvailability(of:)` with multiple packs don't fail all-or-nothing — the error carries separate `successes` and `failures` collections, so a single bad pack ID or a mid-download network drop doesn't have to sink assets that already downloaded fine.

## Which One I'd Reach For

For a new project with no existing content pipeline, Managed is the easy call — Apple already runs the CDN, handles compression, and gives you a 200GB budget most apps won't get near. I'd only reach for self-hosted if I were already running the infrastructure for another platform and adding App Store Connect as a second source of truth would cost more than the control is worth. Either way, the local testing setup is not optional homework — skip it and the first time you'll discover a manifest or size-restriction mistake is when a real device refuses to launch your app after an update.

**Resources**

- [Background Assets documentation](https://developer.apple.com/documentation/backgroundassets)
- [Creating managed asset packs](https://developer.apple.com/documentation/backgroundassets/creating-managed-asset-packs)
- [Configuring an unmanaged Background Assets project](https://developer.apple.com/documentation/backgroundassets/configuring-an-unmanaged-background-assets-project)
- [Testing asset packs locally](https://developer.apple.com/documentation/backgroundassets/testing-asset-packs-locally)

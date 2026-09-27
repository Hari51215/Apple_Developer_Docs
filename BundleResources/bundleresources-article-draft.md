# Bundle Resources: The Metadata Layer Every App Ships With

*Subtitle: Info.plist, entitlements, privacy manifests, and bundle structure: four pieces of app metadata, each failing in its own distinct way.*

Of the four things that make up an app's metadata layer, exactly one of them stops your build cold when it's wrong. The other three fail quietly, sometimes days later, in a review rejection or a feature that simply never turns on, in ways that rarely point back to their real cause. That asymmetry is basically the whole story of Bundle Resources. It's why the framework rewards understanding the mechanism rather than memorizing key names.

Xcode hides most of this behind checkboxes: turn on a capability, type a usage-description string, drag a file into the project navigator. It works, right up until something doesn't turn on, or App Store Connect rejects a submission with a message that doesn't name the file responsible. At that point you're reading raw property lists, and it helps enormously to already know what each one is for.

## What a bundle is, structurally

Before any of the specific files matter, it's worth being clear on what a bundle even is. It's a directory with a fixed, platform-defined layout that the system reads as a single unit: code, resources, and metadata addressed together. Apps, frameworks, plug-ins, and app extensions are all bundles, and a bundle can nest other bundles inside it, which is exactly what happens when an app embeds an extension.

Each content type has exactly one correct home. Resources go under `Resources`, plug-ins under `PlugIns`, embedded frameworks under `Frameworks`, and the rules shift slightly by platform. A macOS app bundle looks like `MyApp.app/Contents/MacOS/`, `Contents/Resources/`, `Contents/Frameworks/`, while an iOS bundle is flatter, without the `Contents` layer at all. macOS frameworks add one more wrinkle. A proper framework bundle keeps its actual binaries and resources inside a versioned `Versions/A/` directory, with a `Versions/Current` symlink pointing at whichever version is live, so multiple framework versions can theoretically coexist inside one bundle.

Get any of this wrong by hand, say, placing a resource where a plug-in belongs, and the failure doesn't show up in Xcode's build log. It shows up during code signing or, worse, during notarization, well after the point where the mistake was made, with an error that talks about signature validity rather than file placement. Bundles without any executable code at all, pure resource or data bundles, still have to follow the same layout and still get signed. There's no exemption for "it's just assets."

## Info.plist: the dictionary that configures everything

`Info.plist` is the file most developers touch first and think about least. It's a property list, a plain dictionary, that tells the system what a bundle is and how to treat it: its identifier, its version, what UI it presents, what background behavior it's allowed, what protected data it wants to touch.

Apple groups Info.plist keys into a handful of real categories: bundle configuration (identity, version, executable name), user interface (scenes, storyboards, launch configuration, supported orientations), app execution (launch and termination behavior), and then a services layer covering protected resources, data and storage, and app-specific services. A single app usually only ever touches a small slice of this:

```xml
<key>CFBundleIdentifier</key>
<string>com.example.fieldnotes</string>
<key>CFBundleShortVersionString</key>
<string>2.1</string>
<key>LSApplicationCategoryType</key>
<string>public.app-category.productivity</string>
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
</array>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Field Notes tags each entry with where it was written.</string>
```

Two of those categories are worth a second look, since most day-to-day Info.plist work happens inside them rather than the identity keys at the top. The user-interface category covers things like `UILaunchScreen` (the storyboard or dictionary shown before your first frame renders), `UISupportedInterfaceOrientations`, and `UIRequiredDeviceCapabilities`, a list of hardware features (`arm64`, `nfc`, `armv7`) the App Store uses to decide which devices can even install the app in the first place, silently, with no runtime error to explain why an older device never sees it in search. The app-execution category is where `CFBundleURLTypes` and `LSApplicationQueriesSchemes` live: the first registers a custom URL scheme your app can be opened with, the second declares which other apps' schemes you're allowed to check for with `canOpenURL(_:)`. iOS caps that query list at fifty entries per app, and going over it doesn't produce a build warning; every scheme past the cap just quietly reports as unopenable at runtime.

That `NSLocationWhenInUseUsageDescription` key is the one entry in this whole framework that behaves the way you'd want everything else to behave: leave it out, call the corresponding API, and the app crashes immediately, with a console message naming the exact key that's missing. Every other protected-resource key follows the same pattern, a usage-description string paired with a system permission prompt, and it's the one place in Bundle Resources where a misconfiguration is loud instead of silent. It's tempting to assume the rest of the framework works the same way. It doesn't.

## Entitlements: permissions that live in the signature, not the plist

Entitlements look similar to Info.plist keys, key-value pairs in a property list, but they don't work the same way at all. An entitlement isn't read out of a plist at runtime; it's baked into the binary's code signature at build time, and the system checks the signature, not a file on disk, when deciding whether an app is allowed to do something.

You almost never hand-write this file. Adding a capability in Xcode's Signing & Capabilities tab is what populates it, and Xcode maintains the `.entitlements` file alongside your project as a record of what you asked for:

```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:fieldnotes.example.com</string>
</array>
<key>com.apple.security.app-sandbox</key>
<true/>
```

There are well over two hundred of these scattered across the SDK: HomeKit, CarPlay, Wallet pass types, App Sandbox, hardware VM access, hypervisor control, and increasingly narrow slices for things like ARKit camera-region access or foveated streaming on visionOS. Nobody memorizes the list; you look up the one your feature needs, add the capability, and Xcode does the plumbing. The part worth understanding is the failure mode: request `com.apple.developer.healthkit` in code without the capability enabled in Xcode, and HealthKit doesn't throw an entitlement error. It just returns denied authorization, indistinguishable from a user who tapped "Don't Allow." You can burn an afternoon assuming it's a permissions-UI bug before checking the signature.

That same gap shows up with `com.apple.developer.in-app-payments`, or with keychain access groups shared between an app and its extensions: the capability toggle and the actual runtime behavior are two separate promises, and Xcode only automates the first one. `com.apple.security.app-sandbox` sits a level above all of them on macOS. It's its own entitlement, and it decides whether the rest of your entitlements mean anything at all, since a sandboxed app is confined to a container unless another entitlement explicitly widens a specific door.

## Privacy manifest files: the newest, least optional piece

`PrivacyInfo.xcprivacy` is the youngest file in this group, and the only one Apple actively enforces at submission time rather than at runtime. It declares two separate things: what categories of user data the app or any bundled third-party SDK collects, and which "required reason" APIs the code calls (file timestamps, `UserDefaults`, disk space checks, a handful of others), each paired with a declared reason code from Apple's fixed list.

```xml
<key>NSPrivacyCollectedDataTypes</key>
<array>
    <dict>
        <key>NSPrivacyCollectedDataType</key>
        <string>NSPrivacyCollectedDataTypeUserID</string>
        <key>NSPrivacyCollectedDataTypeLinked</key>
        <false/>
        <key>NSPrivacyCollectedDataTypeTracking</key>
        <false/>
        <key>NSPrivacyCollectedDataTypePurposes</key>
        <array>
            <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
        </array>
    </dict>
</array>
<key>NSPrivacyAccessedAPITypes</key>
<array>
    <dict>
        <key>NSPrivacyAccessedAPIType</key>
        <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
        <key>NSPrivacyAccessedAPITypeReasons</key>
        <array>
            <string>CA92.1</string>
        </array>
    </dict>
</array>
```

My honest read on this one: it's the right idea, implemented in a properly tedious way. Forcing a declaration of exactly why an SDK reads `UserDefaults` closes off a real category of quiet, undisclosed data collection that no App Store review process was ever going to catch by reading source code. But the reason codes are opaque four-character strings you look up in a table, the required-reason API list keeps expanding to cover APIs that are mundane to use for reasons that have nothing to do with tracking, and a manifest can be technically valid while saying almost nothing useful to a user who might actually read it. It's the kind of compliance mechanism that works (App Store Connect will reject a submission over a missing or incomplete manifest) without being the kind of transparency mechanism its name implies.

## Universal links and the one piece that isn't in the bundle at all

`applinks` is the smallest pillar here, and it's an outlier for a specific reason: it doesn't live inside your app's bundle. It's the root key of an `apple-app-site-association` file, hosted on your web domain, that tells iOS which paths on that domain should open your app instead of Safari.

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["ABCDE12345.com.example.fieldnotes"],
        "components": [
          { "/": "/entry/*", "comment": "Deep link into a single journal entry" }
        ]
      }
    ]
  }
}
```

Hosting rules for that file are strict and mostly invisible until violated: it has to be served over HTTPS, from the domain root or `.well-known/`, with no redirects along the way, and Apple's own crawler fetches it, caches it, and does not respect standard cache-control headers on your side. Publish a fix to a broken AASA file and it can take real time to propagate to devices, since there's no way to force an immediate re-fetch from the client. A CDN silently rewriting a redirect in front of that file is a common way for universal links to fail in production while working perfectly from a developer's own machine.

What ties this back to everything above it: the AASA file only does anything if the app also carries the `com.apple.developer.associated-domains` entitlement pointing at that same domain, the exact key from the earlier example. Bundle Resources isn't four unrelated files; the pieces interlock. An entitlement grants the capability, a hosted JSON file describes what to do with it, and neither one works without the other.

## Where this framework bites people

- **The failure modes aren't consistent, and that's the trap.** A missing usage-description string crashes immediately. A missing entitlement produces a silent denial that looks exactly like a user declining a prompt. A missing or malformed privacy manifest doesn't surface until App Store Connect rejects the build, sometimes days into a review. Debugging any of this starts with figuring out which category you're even in.
- **Content placed in the wrong bundle location fails at signing or notarization, not at build time.** By the time the error appears, the mistake, a resource dropped in the wrong directory, is easy to forget you made.
- **Enabling a capability in Xcode and calling the matching API are two separate steps**, and only one of them has UI. It's easy to toggle HealthKit on, get distracted, and never notice the entitlement was never exercised or, worse, was needed somewhere the toggle didn't reach.
- **Associated Domains is a two-file promise.** The entitlement lives in the app; the AASA file lives on the server. Rotate a Team ID or add a new path pattern on just one side, and universal links quietly stop resolving, with nothing in the app's logs pointing at a web server file it never asked to see.
- **Required-reason API categories in privacy manifests apply to every third-party SDK you link, not just your own code.** An outdated dependency missing its manifest becomes your rejection, not the SDK author's.

## Where I landed

If there's one habit worth taking from all of this, it's checking a feature's behavior against its permission grant before assuming a bug exists somewhere else. A blank map, a HealthKit query returning nothing, a universal link opening Safari instead of the app: in each case the first suspect should be the metadata layer, not the feature code, because that's where these four files fail without saying so. Info.plist earns the benefit of the doubt; it tends to tell you when something's missing. Entitlements, bundle placement, and privacy manifests don't extend the same courtesy, and building the habit of checking them first saves the hours usually spent doubting perfectly correct application code instead.

## Resources

- [Bundle Resources documentation](https://developer.apple.com/documentation/bundleresources)
- [Information Property List](https://developer.apple.com/documentation/bundleresources/information-property-list)
- [Entitlements](https://developer.apple.com/documentation/bundleresources/entitlements)
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
- [Placing content in a bundle](https://developer.apple.com/documentation/bundleresources/placing_content_in_a_bundle)
- WWDC sessions on privacy manifests and app signing, available through Apple's Developer app

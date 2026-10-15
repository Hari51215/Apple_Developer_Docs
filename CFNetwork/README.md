# CFNetwork

Medium article: ["The C Layer Under URLSession: A Close Look at CFNetwork"](https://hari51215.medium.com/the-c-layer-under-urlsession-a-close-look-at-cfnetwork-b0641c7cf751)

No sample app for this topic — CFNetwork is a C API with no UI surface, and the parts that survived
the iOS 27 deprecations are a wire-format parser, an authentication state machine, proxy-resolution
dictionaries, and an error-code table. All of that is better shown as call sites in the article than
wrapped in a SwiftUI app that would spend its screen space displaying dictionary dumps. Anything a
demo app would legitimately want to do over the network belongs in URLSession or Network framework,
which is exactly the point the article makes.

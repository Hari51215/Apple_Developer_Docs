# AuthenticationServices

Medium article: [Inside Apple's Authentication Services: How Apple Secures Identity Across Apple's Ecosystem](https://hari51215.medium.com/inside-apples-authentication-services-how-apple-secures-identity-across-apple-s-ecosystem-c298293554f3)

No sample app for this topic — AuthenticationServices spans several independent sign-in flows
(native Sign in with Apple, browser-based OAuth via `ASWebAuthenticationSession`, passkey/security-key
authorization, and AutoFill credential provider extensions) that would each need their own demo
target to show properly, so there's no single coherent app that demonstrates the framework as a
whole. The article covers all of them with inline Swift code instead.

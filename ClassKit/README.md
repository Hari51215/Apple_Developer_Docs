# ClassKit

Medium article: ["ClassKit: Contexts, Activities, and the Save That Quietly Does Nothing"](https://hari51215.medium.com/classkit-contexts-activities-and-the-save-that-quietly-does-nothing-0d4c66e33442)

No sample app for this topic — ClassKit is gated twice over, and neither gate can be worked around
locally. The `com.apple.developer.ClassKit-environment` entitlement cannot be provisioned by a free
personal team, so Xcode refuses to build to a device at all ("Personal development teams ... do not
support the ClassKit capability"). And the other half of every ClassKit workflow is Apple's
Schoolwork app, which is iPad-only, so even with a paid account there is no way to create an
assignment, follow a deep link, or see a single activity recorded without an iPad on the desk. An
app here would be a project nobody could run and I could not honestly claim to have tested, so the
context hierarchy, the data store delegate, nested activities, the activity items and the context
provider extension are shown as code in the article instead.

# ClockKit

Medium article: ["ClockKit After the Deprecation Notice: How Complications Worked and How to Get Off Them"](https://hari51215.medium.com/clockkit-after-the-deprecation-notice-how-complications-worked-and-how-to-get-off-them-ef2fdbe9ca2f)

No sample app for this topic — ClockKit is a watchOS framework whose complication API is deprecated
in favour of WidgetKit, so a demo would be a watch-only project teaching an API Apple tells you not
to adopt. Building it also needs a watchOS target paired to a real Apple Watch, which is outside the
iPhone-only test setup here. The one part of the framework that is neither deprecated nor
watch-exclusive, `CLKWatchFaceLibrary`, is a single method that imports a `.watchface` file, and a
whole app around one call would teach less than the call does on its own. The descriptor model, the
timeline data source, the template families, the data providers, the SwiftUI templates, face sharing
and the widget migrator are all shown as code in the article instead.

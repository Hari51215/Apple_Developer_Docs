# Background Tasks

Medium article: [Background Tasks in iOS: What BGTaskScheduler Actually Promises (and What It
Doesn't)](https://hari51215.medium.com/background-tasks-in-ios-what-bgtaskscheduler-actually-promises-and-what-it-doesnt-2c248d26ffbe)

No sample app for this topic — a real demo would need days of idle device time to honestly show
whether `BGAppRefreshTask` and `BGProcessingTask` fire on the OS's own schedule, since neither
runs on a predictable timer, and a throwaway project can't demonstrate that any better than the
article's code and the documented lldb simulation command already do.

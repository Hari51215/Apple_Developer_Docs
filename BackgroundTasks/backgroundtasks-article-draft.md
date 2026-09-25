# Background Tasks in iOS: What BGTaskScheduler Actually Promises (and What It Doesn't)

*Subtitle: BGTaskScheduler, BGProcessingTask, and the newer BGContinuedProcessingTask API — what each one guarantees, and what it quietly doesn't.*

The first thing worth saying about the BackgroundTasks framework is that it will not do what you want, when you want it, no matter how carefully you configure it. That's not a criticism — it's the entire design. Every API in this framework exists because iOS decided, around 2019, that apps were no longer allowed to just run in the background whenever they felt like it, and the operating system would decide instead. Once that idea settles in, the rest of the framework's oddities stop looking like bugs and start looking like consequences.

## The problem this framework is solving

Before `BGTaskScheduler` existed, background execution on iOS was a patchwork of `beginBackgroundTask(expirationHandler:)` calls, silent push notifications nudging apps awake, and background fetch intervals that iOS mostly ignored anyway. None of it gave the system enough information to reason about battery impact across hundreds of installed apps. `BackgroundTasks`, introduced in iOS 13, replaced that patchwork with a single scheduler that apps register intents with ahead of time. Based on battery level, charging state, and usage patterns, the OS decides when, or whether, to honor them at all.

That trade means you stop thinking in terms of "run this in 15 minutes" and start thinking in terms of "here's a task I'd like done eventually, under these conditions." It's a shift in mental model more than an API to memorize, and it's the thing that trips people up first.

## Registering before you're allowed to ask for anything

Every task your app wants to use has to be registered with `BGTaskScheduler.shared` before `application(_:didFinishLaunchingWithOptions:)` returns. Miss that window and the registration silently does nothing — there's no runtime error telling you that you registered too late.

```swift
func application(_ application: UIApplication,
                  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.example.app.refresh",
        using: nil
    ) { task in
        self.handleAppRefresh(task: task as! BGAppRefreshTask)
    }

    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.example.app.cleanup",
        using: nil
    ) { task in
        self.handleProcessing(task: task as! BGProcessingTask)
    }

    return true
}
```

Each identifier passed to `register(forTaskWithIdentifier:using:launchHandler:)` has to also appear in the app's Info.plist under `BGTaskSchedulerPermittedIdentifiers`, and the app needs the relevant `UIBackgroundModes` entry (`fetch` for refresh tasks, `processing` for processing tasks) — three places that all have to agree on the same string, with nothing to catch a typo across them except a task that simply never fires.

## BGAppRefreshTask: short, opportunistic, no guarantees

`BGAppRefreshTaskRequest` is for quick, best-effort work — refreshing a feed, pre-warming a cache, checking for new content. You submit a request with an earliest date it's allowed to run, and iOS treats that as a lower bound, not a schedule:

```swift
func scheduleAppRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "com.example.app.refresh")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)
    try? BGTaskScheduler.shared.submit(request)
}
```

What surprised me testing this is just how loosely "earliest" gets interpreted. Four hours out doesn't mean the task fires four hours later. It means the task becomes eligible then, and the system might still wait another day if it decides your app isn't a priority based on how often it gets opened. Apple's documentation says this plainly, but it doesn't land until you've watched a device sit idle overnight with your refresh task never once triggering.

Handling one means doing real work fast and always calling completion:

```swift
func handleAppRefresh(task: BGAppRefreshTask) {
    scheduleAppRefresh()

    let operation = RefreshFeedOperation()
    task.expirationHandler = {
        operation.cancel()
    }

    operation.completionBlock = {
        task.setTaskCompleted(success: !operation.isCancelled)
    }

    OperationQueue().addOperation(operation)
}
```

Re-scheduling at the top of the handler, not the bottom, matters — if the task expires or the process is killed before you get to the end, you still want the next request queued.

## BGProcessingTask: longer, heavier, conditional

`BGProcessingTaskRequest` is the other half of the classic scheduler API, meant for maintenance-style work that can take minutes rather than seconds — database compaction, indexing, large downloads. It supports conditions the refresh request doesn't:

```swift
func scheduleDatabaseCleanup() {
    let request = BGProcessingTaskRequest(identifier: "com.example.app.cleanup")
    request.requiresNetworkConnectivity = false
    request.requiresExternalPower = true
    request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60)
    try? BGTaskScheduler.shared.submit(request)
}
```

Setting `requiresExternalPower` to `true` is basically an admission that this work is expensive enough that you don't want it competing with a user's battery life, and iOS will hold off until the phone is plugged in and probably charging overnight. That's a reasonable trade for compaction jobs; it's a bad one if your task also needs to finish before the user opens the app again tomorrow morning, because there's no way to force it earlier.

## Checking what's already queued

Submitting a request isn't the end of the story, because you can't just fire requests and forget them. `BGTaskScheduler` keeps a pending queue, and it's worth inspecting rather than assuming:

```swift
BGTaskScheduler.shared.getPendingTaskRequests { requests in
    print(requests.map(\.identifier))
}
```

One detail that isn't obvious from the method names alone: submitting a new request with an identifier that already has a pending request queued doesn't create a second entry, it replaces the first one outright. That matters if your app calls `scheduleAppRefresh()` from several places — `applicationDidEnterBackground`, a completion handler, a settings change — expecting them to stack. They don't. The last submission wins, silently discarding whatever begin date or conditions the earlier one carried.

Cancelling is just as direct, useful when a condition that justified the task no longer applies:

```swift
BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "com.example.app.cleanup")
// or, to clear everything at once
BGTaskScheduler.shared.cancelAllTaskRequests()
```

## BGContinuedProcessingTask: the newer, user-initiated path

The scheduler tasks above share one assumption: the user isn't watching. `BGContinuedProcessingTask`, added more recently to the framework, is built for the opposite situation. The user just tapped a button expecting a long operation, say exporting a large project or transcoding video, to run to completion even if they background the app.

```swift
func startExport() {
    let request = BGContinuedProcessingTaskRequest(
        identifier: "com.example.app.export",
        title: "Exporting Project",
        subtitle: "Preparing files"
    )
    request.strategy = .fail

    Task {
        try await BGTaskScheduler.shared.submit(request)
    }
}
```

The system shows the user a persistent, Live Activity–style progress indicator for the task, and crucially, this one isn't subject to the same "maybe tomorrow" scheduling heuristics as `BGAppRefreshTask` or `BGProcessingTask`, because the user's own action is the trigger, not a guess about opportunity. The conceptual split is worth holding onto: scheduler tasks answer "what should happen while nobody's looking," continued processing answers "how do I keep doing what the user just asked for." Routing a genuine user-initiated export through `BGProcessingTask` instead, just because it's the API you already know, gets you a task that silently waits for a charger instead of finishing the job someone is sitting there waiting on.

## Testing without waiting for the OS to feel like it

None of this is testable by just waiting around — nobody has the patience to leave a device untouched for a day to see if a refresh task fires. Apple's own answer is a debugger command, run while paused at a breakpoint after registration has happened:

```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.example.app.refresh" completion:nil]
```

The first time I ran this I expected some kind of dedicated Xcode UI for it, given how central background execution testing should be to any app that uses this framework. There isn't one. It's an underscore-prefixed private method invoked through an lldb expression, which is a strange place to land for what is otherwise a fully public, documented API surface — but it's also the only way to exercise `expirationHandler` logic without waiting for genuine background windows, so it's worth keeping a note with the exact syntax somewhere you won't lose it.

## Where this framework bites people

A few things worth knowing before you build around this:

- **Registration timing is unforgiving.** Register after `didFinishLaunchingWithOptions` returns and the handler is simply never called — no crash, no log, just silence.
- **The three identifier lists have to match exactly** — Info.plist's `BGTaskSchedulerPermittedIdentifiers`, the string passed to `register(forTaskWithIdentifier:using:launchHandler:)`, and the identifier on the request object. A mismatch anywhere fails the same way: quietly.
- **Submitting too often backfires.** Requesting a refresh task every time the app enters the background, rather than once when one is needed, reads to the system as an app trying to game the scheduler, and Apple's heuristics are explicitly built to throttle exactly that pattern.
- **`setTaskCompleted(success:)` isn't optional.** Skip it and the OS assumes the task is still running until it eventually times it out, which counts against your app's standing for future scheduling — every uncompleted task is data the system uses against you.
- **None of these APIs run in the simulator the way they do on a device.** The debugger simulation trick above works in both, but real production timing only ever shows up on hardware.
- **The user has a kill switch you'll never see fire.** Settings → General → Background App Refresh lets someone disable this for your app entirely, or for every app on the device at once, and there's no API to detect that it happened — your submitted requests just quietly stop running.

## Where I landed on this

For anything opportunistic, syncing, prefetching, light cleanup, `BGAppRefreshTask` is the right tool, and the honest expectation to set is that it's a nice-to-have, never a promise. For heavier maintenance work that can tolerate being deferred a day, `BGProcessingTask` earns its keep, particularly with `requiresExternalPower` set for anything CPU-intensive. The one I'd reach for least is forcing user-facing, time-sensitive work through either scheduler API just because it's the established pattern. That's what `BGContinuedProcessingTask` exists to fix, and using the wrong one produces a task that's technically running the framework correctly while completely failing the person waiting on it.

## Resources

- [BackgroundTasks framework documentation](https://developer.apple.com/documentation/backgroundtasks)
- [BGTaskScheduler](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler)
- [BGProcessingTask](https://developer.apple.com/documentation/backgroundtasks/bgprocessingtask)
- [BGContinuedProcessingTask](https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask)
- WWDC sessions on background execution and task scheduling, available through Apple's Developer app

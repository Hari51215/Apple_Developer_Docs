# ChefTimer — AlarmKit Sample Project

A buildable SwiftUI sample app demonstrating **AlarmKit** — Apple's new framework (iOS 26 / WWDC25) for scheduling prominent alarms and countdown timers that break through silent mode.

---

## ⚠️ Important: AlarmKit Requires a Special Entitlement

AlarmKit requires **Apple approval** before it can be used in a production app — similar to how CallKit and certain HealthKit capabilities work.

To request the entitlement, go to:
👉 https://developer.apple.com/contact/request/alarmkit

Without the entitlement, the app will build successfully but `AlarmManager.requestAuthorization()` will throw an error at runtime. The UI, navigation, and code structure are all fully testable regardless.

---

## 📁 Project Structure

```
ChefTimer/
├── ChefTimer/                        → Main app target
│   ├── ChefTimerApp.swift            → @main entry point
│   ├── ContentView.swift             → Tab shell (3 tabs)
│   ├── AlarmViewModel.swift          → All AlarmKit logic
│   ├── CookingMetadata.swift         → ⚠️ SHARED — add to BOTH targets
│   ├── RecipesView.swift             → Recipe list → start timers
│   ├── ActiveTimersView.swift        → Live timer list + controls
│   └── ScheduleAlarmView.swift       → Fixed date/time alarm
│
└── ChefTimerWidget/                  → Widget Extension target
    ├── ChefTimerWidgetBundle.swift   → @main for widget
    └── ChefTimerLiveActivity.swift   → Countdown Live Activity UI
```

---

## 🛠️ Step-by-Step Xcode Setup

### Step 1 — Create the iOS App project

1. **Xcode → File → New → Project**
2. Choose **iOS → App** → Next
3. Set:
   - **Product Name:** `ChefTimer`
   - **Interface:** SwiftUI
   - **Language:** Swift
4. Save and **Create**

### Step 2 — Delete the default file

Delete the generated **`ContentView.swift`** → Move to Trash

### Step 3 — Add app target files

Drag these files from `ChefTimer/` into your Xcode project's `ChefTimer` group:

- `ChefTimerApp.swift`
- `ContentView.swift`
- `AlarmViewModel.swift`
- `CookingMetadata.swift`
- `RecipesView.swift`
- `ActiveTimersView.swift`
- `ScheduleAlarmView.swift`

In the "Choose options" sheet:
- ✅ Copy items if needed
- ✅ ChefTimer under "Add to targets"

### Step 4 — Add the Widget Extension target

1. **File → New → Target**
2. Choose **Widget Extension** → Next
3. Set:
   - **Product Name:** `ChefTimerWidget`
   - ✅ **Include Live Activity**
   - ❌ Uncheck "Include Configuration App Intent"
4. Click **Finish** → **Activate** when prompted

Delete any Swift files Xcode auto-generates inside the `ChefTimerWidget` group (keep the folder, delete the `.swift` files).

### Step 5 — Add widget target files

Drag from `ChefTimerWidget/` into the `ChefTimerWidget` Xcode group:

- `ChefTimerWidgetBundle.swift`
- `ChefTimerLiveActivity.swift`

In the "Choose options" sheet:
- ✅ Copy items if needed
- ✅ **ChefTimerWidgetExtension** under "Add to targets" (NOT the app target)

### Step 6 — Share CookingMetadata.swift with the widget ⚠️

This is the most important step — both targets need the same `CookingMetadata` type:

1. Click `CookingMetadata.swift` in the Project Navigator
2. Open **File Inspector** (right panel, first tab)
3. Under **Target Membership**, check **BOTH**:
   - ✅ ChefTimer
   - ✅ ChefTimerWidgetExtension

### Step 7 — Add NSAlarmKitUsageDescription to Info.plist

1. Select the **ChefTimer** target → **Info** tab
2. Click **+** to add a new key
3. Key: `NSAlarmKitUsageDescription`
4. Value: `ChefTimer uses AlarmKit to alert you when your cooking timer completes, even when your phone is on silent.`

### Step 8 — Set deployment targets

AlarmKit requires **iOS 26+**:

1. Select project → **ChefTimer target** → **General** → **Minimum Deployments** → **iOS 26.0**
2. Repeat for **ChefTimerWidgetExtension target**

### Step 9 — Clean and build

```
Product → Clean Build Folder (⇧⌘K)
```
Then **⌘R** to run.

---

## ▶️ How to Run

Select the **ChefTimer** scheme → pick an **iPhone 16 Pro simulator** (for Dynamic Island) → **⌘R**.

The app launches with 3 tabs:

| Tab | What it does |
|---|---|
| **Recipes** | 5 recipes — tap Start to begin a 1-minute countdown timer |
| **Timers** | Live list of active alarms with Pause/Resume/Stop/Snooze controls |
| **Alarm** | Schedule a one-off fixed alarm at a specific date and time |

---

## ✅ How to Verify It's Working

### Without the AlarmKit entitlement (most developers)

1. Build and run — the app will launch and display all tabs correctly
2. Tap **Start** on any recipe
3. `AlarmManager.requestAuthorization()` will throw — you'll see the error alert explaining the entitlement requirement
4. All UI flows, navigation, and view code are testable this way

### With the AlarmKit entitlement

1. Tap any recipe → **Start** → authorization prompt appears
2. Grant permission
3. **Lock the device** (⌘L in Simulator)
4. After 1 minute, the alarm fires on the Lock Screen with "Dismiss" and "Repeat" buttons
5. On iPhone 16 Pro simulator: watch the **Dynamic Island** show the emoji + countdown timer
6. Open the **Timers** tab while the timer is running to see the state card
7. Tap **Pause** → card shows "Paused"; **Resume** → countdown continues
8. When the alarm fires, tap **Snooze** to see the snoozed state

---

## 🐛 Troubleshooting

| Problem | Fix |
|---|---|
| `Cannot find type 'AlarmKit'` | Confirm deployment target is iOS 26.0+ |
| `Cannot find 'CookingMetadata'` in widget | Step 6 — add CookingMetadata.swift to widget target membership |
| Authorization throws immediately | AlarmKit entitlement not yet granted — expected |
| No Dynamic Island visible | Use iPhone 14 Pro or newer simulator |
| Widget extension build errors | Confirm `ChefTimerWidgetBundle.swift` is in the widget target ONLY (not app target) |
| `AlarmManager.AlarmConfiguration` type error | Ensure `typealias` or explicit generic type is used — `AlarmManager.AlarmConfiguration<CookingMetadata>` |

---

## 📚 What This Demonstrates

- `AlarmManager.requestAuthorization()` — all 3 states
- `AlarmManager.AlarmConfiguration` with `countdownDuration` (preAlert + postAlert)
- `AlarmManager.AlarmConfiguration` with `schedule: .fixed(date)`
- `AlarmPresentation` — all 3 states: `.Alert`, `.Countdown`, `.Paused`
- `AlarmButton` with text, color, SF Symbol
- `AlarmMetadata` — custom `CookingMetadata` carried through Live Activity
- `AlarmManager.pause/resume/stop/snooze(id:)`
- `AlarmManager.alarmUpdates` — async stream for state observation
- `ActivityConfiguration(for: AlarmAttributes<CookingMetadata>.self)` — Live Activity widget
- Dynamic Island compact leading/trailing + expanded regions
- Lock Screen Live Activity layout during countdown

This pairs with the Medium article *"AlarmKit in SwiftUI — Native Alarms That Break Through Silent Mode"*.

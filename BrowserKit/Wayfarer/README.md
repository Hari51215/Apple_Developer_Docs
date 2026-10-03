# Wayfarer — BrowserKit Sample Project

A SwiftUI sample app demonstrating **BrowserKit** — Apple's framework for checking alternative-browser-engine eligibility and moving bookmarks, history, reading-list items, and extensions between browsers.

---

## ⚠️ Important: Read This Before You Build

**What genuinely works with no special access, on any personal developer account, on a real device:**
- The **Eligibility** tab — calls `BEAvailability.isEligible(for: .webBrowser)` live and shows the real answer for the device it's running on.

**What is fully implemented but gated by Apple:**
- The **Export** and **Import** tabs use `BEBrowserDataExportManager` / `BEBrowserDataImportManager` exactly as Apple documents them. They will raise the real system transfer sheet on a real device. But Apple's own docs state that using these managers requires your app to meet the same bar as [qualifying for the default-browser entitlement](https://developer.apple.com/documentation/xcode/preparing-your-app-to-be-the-default-browser) (`com.apple.developer.web-browser`) — something a personal account cannot obtain. Without it, expect the sheet to appear but an actual cross-app transfer to go nowhere. **That's Apple's restriction, not a bug in this project.**

**SDK gap — the Export/Import code is behind a build flag by default.** `BEBrowserDataExportManager` and `BEBrowserDataImportManager` are documented at iOS/iPadOS **26.4+**. Most currently-installed copies of Xcode (26.1 and earlier) don't ship an SDK with those types at all — not "available but gated," genuinely absent, so referencing them is a compile error, not a runtime one. To keep the project buildable out of the box, every reference to those two managers (in `WayfarerApp.swift`, `ContentView.swift`, `Models/SampleBrowsingData.swift`, and both files in `DataTransfer/`) is wrapped in `#if ENABLE_BROWSERKIT_TRANSFER`. With the flag **off** (the default), the project builds and runs with just the Eligibility tab. Once you're on an Xcode version whose SDK actually declares these types, flip the flag on (Step 5 below) to compile in the Export/Import tabs too. `BEAvailability` itself only needs iOS **18.4+** and is present in current SDKs, so the Eligibility tab is unaffected either way.

---

## 📁 Project Structure

```
Wayfarer/
└── Wayfarer/                          → Single app target (no extension needed)
    ├── WayfarerApp.swift              → @main entry point; Export/Import wiring behind #if ENABLE_BROWSERKIT_TRANSFER
    ├── ContentView.swift              → Tab shell; Export/Import tabs behind #if ENABLE_BROWSERKIT_TRANSFER
    ├── EligibilityView.swift          → BEAvailability.isEligible(for:) demo — always builds
    ├── Models/
    │   └── SampleBrowsingData.swift   → Mock bookmarks/history/reading-list/extensions
    ├── DataTransfer/
    │   ├── ExportView.swift           → BEBrowserDataExportManager wiring — entire file behind the flag
    │   └── ImportView.swift           → BEBrowserDataImportManager wiring — entire file behind the flag
    └── Info.plist                     → NSUserActivityTypes for the transfer handshake (see Step 4)
```

---

## 🛠️ Step-by-Step Xcode Setup

### Step 1 — Create the iOS App project

1. **Xcode → File → New → Project**
2. Choose **iOS → App** → Next
3. Set:
   - **Product Name:** `Wayfarer`
   - **Interface:** SwiftUI
   - **Language:** Swift
4. Save and **Create**

### Step 2 — Delete the default file

Delete the generated **`ContentView.swift`** → Move to Trash (you'll add the one from this repo).

### Step 3 — Add the source files

Drag these files/folders from `Wayfarer/Wayfarer/` into your Xcode project's `Wayfarer` group, preserving the `Models/` and `DataTransfer/` subfolders:

- `WayfarerApp.swift`
- `ContentView.swift`
- `EligibilityView.swift`
- `Models/SampleBrowsingData.swift`
- `DataTransfer/ExportView.swift`
- `DataTransfer/ImportView.swift`

In the "Choose options" sheet:
- ✅ Copy items if needed
- ✅ Create groups
- ✅ Wayfarer under "Add to targets"

### Step 4 — Add NSUserActivityTypes (needed only once you enable Export/Import in Step 5)

Modern Xcode projects auto-generate `Info.plist` from build settings (`GENERATE_INFOPLIST_FILE = YES`) — there's no physical file in the project by default. **Don't just drag this repo's `Info.plist` into the project as a resource**; if you do, you'll get `Multiple commands produce '.../Info.plist'`, because the auto-generated one and the dragged-in one both try to write the same output file.

Do it either of these ways instead:

- **Easiest — Info tab:** Select the **Wayfarer target → Info** tab → hover any existing row → click **+** → add key `NSUserActivityTypes` as an **Array** → add two **String** items, `BEBrowserDataExchangeExportActivity` and `BEBrowserDataExchangeImportActivity`. Xcode writes these into the auto-generated Info.plist for you, no physical file involved.
- **Or — merge a custom file:** Copy this folder's `Info.plist` into your project *without* adding it to "Copy Bundle Resources" (uncheck target membership if Xcode offers to add it there), then in **Build Settings** search for **"Info.plist File"** and set it to the file's path (e.g. `Wayfarer/Info.plist`), leaving `GENERATE_INFOPLIST_FILE` set to **Yes**. Xcode merges your custom keys into the generated plist instead of producing two conflicting outputs — this is the same pattern this repo's `ChefTimerWidget` target already uses.

If you already hit the "Multiple commands produce" error: open **Build Phases → Copy Bundle Resources** on the Wayfarer target and remove `Info.plist` from that list, then apply one of the two options above.

### Step 5 — Set the deployment target, and decide whether to enable Export/Import

- For the **Eligibility** tab alone (the default, and what builds today on most Xcode installs): iOS **18.4** is enough, no extra flags needed.
- To also compile the **Export/Import** tabs: your Xcode's SDK must actually declare `BEBrowserDataExportManager`/`BEBrowserDataImportManager` (documented at iOS/iPadOS **26.4+** — check **Xcode → Settings → Platforms** for your installed SDK version; Xcode 26.1's SDK does **not** have them). If it does:
  1. Set **Minimum Deployments** to iOS 26.4 (project → **Wayfarer target** → **General**).
  2. Go to **Build Settings → Swift Compiler - Custom Flags → Other Swift Flags**, and add `-DENABLE_BROWSERKIT_TRANSFER`.
  3. Complete Step 4's Info.plist addition if you skipped it.

### Step 6 — Clean and build

```
Product → Clean Build Folder (⇧⌘K)
```
Then **⌘R** to run.

---

## ▶️ How to Run

**Real device required.** Apple's docs describe the transfer sheet as relying on system inter-app communication that isn't available in Simulator, and the Eligibility check is also meant to reflect a real device's actual region/configuration.

| Tab | What to expect |
|---|---|
| **Eligibility** | Tap "Check This Device" — see a live true/false (or an error) from `BEAvailability`. Present regardless of the build flag. |
| **Export** *(only visible with `-DENABLE_BROWSERKIT_TRANSFER` and a 26.4+ SDK)* | Tap "Start Export" — the system sheet should appear, listing your mock data counts; completing a real hand-off to another browser needs the entitlement described above |
| **Import** *(same requirement)* | Tap "Start Import" — the system sheet should appear letting you pick a source browser or a file; same entitlement caveat applies to a live app-to-app transfer |

---

## 📚 What This Demonstrates

- `BEAvailability.isEligible(for:)` — real, unrestricted device eligibility check
- `BEExportMetadata` / `BEImportMetadata` — describing available data before the sheet appears
- `BEBrowserDataExportManager.requestExport(for:token:)` and `exportBrowserData(_:)` streaming an `AsyncStream<BEBrowserData>`
- `BEBrowserDataImportManager.requestImport(for:)` and `importBrowserData(token:)` consuming an `AsyncThrowingStream`
- The full `NSUserActivityTypes` continuation handshake — `userActivityType` and the `exportTokenUserInfoKey` / `importTokenUserInfoKey` constants — wired through `onContinueUserActivity`
- Every `BEBrowserData` model type: `BEBrowserDataBookmark`, `BEBrowserDataHistoryVisit`, `BEBrowserDataReadingListItem`, `BEBrowserDataExtension`
- The file-based fallback path (`exportOptions.exportToFiles` / `importOptions.importFromFiles`)

---

## 🐛 Troubleshooting

| Problem | Fix |
|---|---|
| `Multiple commands produce '.../Info.plist'` | You added `Info.plist` as a bundle resource on top of Xcode's auto-generated one. Remove it from **Build Phases → Copy Bundle Resources**, then follow Step 4 (Info tab, or set the **Info.plist File** build setting instead of leaving it as a resource) |
| `Cannot find 'BEBrowserDataExportManager'` / `'BEExportMetadata'` / `'BEImportMetadata'` in scope | Expected by default — those symbols are wrapped in `#if ENABLE_BROWSERKIT_TRANSFER`, which is off until your Xcode has a 26.4+ SDK. Don't add `-DENABLE_BROWSERKIT_TRANSFER` until it does; if you already added it, remove it, or update Xcode first |
| `Cannot find 'BEAvailability' in scope` | Confirm deployment target is iOS 18.4+ and the BrowserKit framework is linked |
| Export/Import sheet appears then nothing happens | Expected without Apple's `com.apple.developer.web-browser` entitlement — see the callout above |
| Nothing happens in Simulator | Expected — run on a real device |
| `onContinueUserActivity` handler never fires | Only fires when the system relaunches the app as part of a real cross-app handoff, which itself needs the entitlement above |

---

This pairs with the Medium article *"BrowserKit: Apple's Quiet Framework for Moving Bookmarks Between Rivals"*.

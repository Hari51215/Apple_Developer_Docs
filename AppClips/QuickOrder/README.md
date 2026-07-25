# QuickOrder — App Clips Sample Project

A buildable SwiftUI sample demonstrating **App Clips** — a full coffee ordering app
with an App Clip that lets users order from a table QR code without downloading the app.

---

## Project Structure

```
QuickOrder/
├── QuickOrder/                       → Main app target (full app)
│   ├── QuickOrderApp.swift           → @main + deep link handling
│   ├── OrderManager.swift            → State management + App Group read
│   └── AppRootView.swift             → Tab view: Menu / Cart / Orders
│
├── QuickOrderClip/                   → App Clip target
│   ├── QuickOrderClipApp.swift       → @main + NSUserActivity handler
│   └── ClipRootView.swift            → Clip UI + ClipViewModel + all subviews
│
└── QuickOrderShared/                 → Shared between BOTH targets
    ├── Models.swift                  → MenuItem, Order, ClipInvocationURL, SharedStorage
    └── MenuView.swift                → MenuListView, CartSummaryView (reused by both)
```

`QuickOrder/Intents/` (QuickOrder app target ONLY — not the Clip) adds **App Intents**:
- `MenuItemEntity.swift` → `AppEntity` + `EntityQuery` wrapping `MenuItem.catalog`
- `AddToOrderIntent.swift` → parameterized `AppIntent` that adds an item to the shared cart
- `QuickOrderShortcuts.swift` → `AppShortcutsProvider` exposing it to Siri/Shortcuts/Spotlight

---

## Step-by-Step Xcode Setup

### Step 1 — Create the iOS App project

1. **Xcode → File → New → Project → iOS → App**
2. Product Name: `QuickOrder`
3. Interface: SwiftUI, Language: Swift
4. Save and **Create**
5. Delete the generated `ContentView.swift`

### Step 2 — Add main app files

Drag from `QuickOrder/` into the `QuickOrder` group:
- `QuickOrderApp.swift` (replace existing)
- `OrderManager.swift`
- `AppRootView.swift`

Options: ✅ Copy items if needed, ✅ QuickOrder target

### Step 3 — Add the App Clip target

1. **File → New → Target → App Clip** → Next
2. Product Name: `QuickOrderClip`
3. **Finish** → **Activate**
4. Delete any generated Swift files Xcode creates inside the `QuickOrderClip` group

### Step 4 — Add App Clip files

Drag from `QuickOrderClip/` into the `QuickOrderClip` group:
- `QuickOrderClipApp.swift`
- `ClipRootView.swift`

Options: ✅ Copy items if needed, ✅ **QuickOrderClipExtension** target ONLY

### Step 5 — Add shared files to BOTH targets ⚠️

Drag `QuickOrderShared/` folder (both files) into the project:
- `Models.swift`
- `MenuView.swift`

For EACH file, open **File Inspector (right panel) → Target Membership**:
- ✅ QuickOrder
- ✅ QuickOrderClipExtension

This is the most important step — both targets must compile these files.

### Step 6 — Add App Intents files to the QuickOrder target

Drag the `Intents/` folder from `QuickOrder/` into the `QuickOrder` group:
- `MenuItemEntity.swift`
- `AddToOrderIntent.swift`
- `QuickOrderShortcuts.swift`

Options: ✅ Copy items if needed, ✅ **QuickOrder** target ONLY — do NOT add these to
`QuickOrderClipExtension`.

No extra capability or entitlement is needed — `AppShortcutsProvider` is auto-discovered by
the system once it's built into the app target.

### Step 7 — Configure Associated Domains

Add to **QuickOrder target** → **Signing & Capabilities → + → Associated Domains**:
```
appclips:yourwebsite.com
applinks:yourwebsite.com
```

Add to **QuickOrderClipExtension target** → **Signing & Capabilities → + → Associated Domains**:
```
appclips:yourwebsite.com
```

> For the demo to work in Simulator, you DON'T need a real domain.
> Use the _XCAppClipURL environment variable (Step 8) to test locally.

### Step 8 — Add App Groups capability

Add to **BOTH** targets → **Signing & Capabilities → + → App Groups**:
```
group.com.yourname.QuickOrder
```

Then update `SharedStorage.suiteName` in `Models.swift` to match this exactly.

### Step 9 — Set minimum deployment target

Both targets → **General → Minimum Deployments → iOS 16.0**

### Step 10 — Add NSAppClip key to App Clip Info.plist

App Clip target → **Info tab → +**:
```
Key:   NSAppClip
Type:  Dictionary
  Key: NSAppClipRequestEphemeralUserNotification
  Type: Boolean
  Value: YES
```

### Step 11 — Clean and build

```
Product → Clean Build Folder (⇧⌘K)
```

Select the **QuickOrder** scheme → ⌘R to run the full app.
Select the **QuickOrderClipExtension** scheme → ⌘R to run the App Clip.

---

## Testing the App Clip

### In Simulator — via environment variable (easiest)

1. Select the **QuickOrderClipExtension** scheme
2. **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**
3. Add:
   - Name:  `_XCAppClipURL`
   - Value: `https://yourwebsite.com/order?table=5&item=latte`
4. **⌘R** — the App Clip launches with table 5 and a latte pre-selected

Try different URLs:
```
https://yourwebsite.com/order?table=12&item=espresso
https://yourwebsite.com/order?table=3&item=matcha
https://yourwebsite.com/order?table=7
https://yourwebsite.com/order
```

### On Device — via Local Experience

1. Go to **Settings → Developer → Local Experiences**
2. Tap **Register Local Experience**
3. Fill in:
   - URL Prefix: `https://yourwebsite.com/order`
   - Bundle ID: `com.yourname.QuickOrder.Clip`
   - Title: `QuickOrder`
   - Subtitle: `Order from your table`
   - Action: `Order`
4. Open the Camera app and scan any QR code that encodes:
   `https://yourwebsite.com/order?table=5&item=latte`

---

## Testing App Intents

1. Build and run the **QuickOrder** scheme once (⌘R) so the system registers the App Shortcut.
2. Open the **Shortcuts** app → search "QuickOrder" → you should see **Add to Order**. Build a
   shortcut with it, picking any menu item from the list.
3. Force-quit QuickOrder (swipe it away), then run the shortcut — it should report the item
   added and the new cart total, entirely without the app running.
4. Launch QuickOrder and check the **Cart** tab — the item added via the shortcut should be there.
5. On a real device, try asking Siri: *"Add a Latte to my QuickOrder order."*

---

## What This Sample Demonstrates

| Feature | Where to find it |
|---|---|
| App Clip `@main` entry point | `QuickOrderClipApp.swift` |
| `NSUserActivityTypeBrowsingWeb` handling | `QuickOrderClipApp.swift` |
| URL parsing with `URLComponents` | `Models.swift → ClipInvocationURL` |
| URL-driven UI (table number + featured item) | `ClipRootView.swift → ClipViewModel.parseURL` |
| Focused single-task clip UI | `ClipRootView.swift` |
| Shared code between app and clip | `QuickOrderShared/` |
| App Groups shared storage | `Models.swift → SharedStorage` |
| App Clip handoff to full app | `OrderManager.init()` reads `SharedStorage` |
| `AppStoreOverlay` to recommend full app | `ClipRootView.swift → .appStoreOverlay` |
| Ephemeral notifications | `ClipViewModel.scheduleOrderReadyNotification()` |
| _XCAppClipURL simulator testing | Step 8 in setup |
| Pre-loading featured item from URL | `ClipViewModel.parseURL` |
| `AppEntity` + `EntityQuery` for the menu catalog | `Intents/MenuItemEntity.swift` |
| Parameterized `AppIntent` (add item to cart) | `Intents/AddToOrderIntent.swift` |
| `AppShortcutsProvider` Siri/Shortcuts phrases | `Intents/QuickOrderShortcuts.swift` |
| Live cart shared with App Intents via App Group | `Models.swift → SharedStorage.saveCart/loadCart`, `OrderManager.cart` `didSet` |

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `Cannot find type 'MenuItem'` in App Clip | Step 5 — add shared files to both target memberships |
| App Clip scheme not in list | Product → Scheme → Manage Schemes → check visible |
| URL never received in `onContinueUserActivity` | Confirm `_XCAppClipURL` env var is set in App Clip scheme (not main app scheme) |
| `AppStoreOverlay` does nothing in Simulator | Expected — overlay only works on real device with App Store access |
| App Group not sharing data | Confirm both targets have exactly the same App Group ID in capabilities |
| "Add to Order" shortcut doesn't appear in Shortcuts app | Run the QuickOrder app at least once after adding the `Intents/` files so the system registers the `AppShortcutsProvider` |
| Cart added via Siri doesn't show up in the app | Confirm `Intents/*.swift` files have **QuickOrder** target membership (not the Clip) and that `OrderManager.init()` calls `SharedStorage.loadCart()` |
| Build error: `@main` found in both | Each target has exactly one `@main` — never add both app entry points to the same target |

---

## Invocation URL Format

```
Custom domain:   https://yourwebsite.com/order?table=5&item=latte
Default link:    https://appclip.apple.com/id?p=com.yourname.QuickOrder.Clip&table=5&item=latte
```

Supported `item` values match `MenuItem.id` in `Models.swift`:
`espresso`, `latte`, `cappuccino`, `coldBrew`, `matcha`, `croissant`, `muffin`

This pairs with the Medium article *"App Clips in SwiftUI — Instant Experiences Without Installation"*.

---
id: m44-l01
title: Widgets with WidgetKit
description: "A widget is a timeline of SwiftUI snapshots that the system renders for you, not a small app that keeps running. You add a widget extension, write a TimelineProvider that plans entries ahead, choose a reload policy, and stay inside the refresh budget Apple documents. You support several widget families, share data with the app through an App Group, and make the widget interactive with App Intents on iOS 17."
module: m44
order: 1
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m37-l06, m21-l04]
objectives:
  - Explain why a widget extension isn't running while its widget is on screen, and what WidgetKit asks the provider for instead.
  - Write a TimelineProvider with a placeholder, a quick snapshot and a timeline, and plan entries for predictable changes.
  - Choose between the atEnd, after(_:) and never reload policies, and reload from the app only when displayed data changes.
  - State the refresh budget and the exemptions as Apple documents them.
  - Support several widget families and share data with the app through an App Group container.
  - Add a button or toggle to a widget with an App Intent and describe what happens when it runs.
terms:
  - term: Widget extension
    definition: "A separate target, embedded in the app, whose code WidgetKit runs in its own process to produce timelines and views. It isn't continually active, even while the widget is on screen."
  - term: Timeline
    definition: "An array of TimelineEntry values, each with a date and the data to show from that date on, plus a TimelineReloadPolicy that says when WidgetKit should ask for the next timeline."
  - term: Reload policy
    definition: "TimelineReloadPolicy: .atEnd (ask again after the last entry's date), .after(date) (ask again after a specific date) or .never (wait until the app calls WidgetCenter)."
  - term: Reload budget
    definition: "The dynamic number of reloads WidgetKit grants each configured widget over a 24-hour window. Apple says a frequently viewed widget typically gets 40 to 70."
  - term: Widget family
    definition: "A size and shape the widget supports, such as systemSmall, systemMedium, systemLarge or the accessory families for the Lock Screen. Declared with supportedFamilies(_:) and read from the widgetFamily environment value."
  - term: App Group
    definition: "An entitlement that gives apps and extensions from the same team a shared container, identified by a string starting with group., reachable through containerURL(forSecurityApplicationGroupIdentifier:) or UserDefaults(suiteName:)."
mastery:
  - Turn a day's delivery windows into timeline entries spaced at least 5 minutes apart, with the right reload policy.
  - Pick the reload policy for a widget whose next change is known, unknown, or far in the future.
  - Decide which widget kinds to reload after an app event, and when to reload all of them.
  - Write the provider, the configuration and a family-aware view for a static widget.
  - Store widget data in an App Group container and read it from the provider.
  - Add a Toggle backed by an App Intent and explain why it updates optimistically.
resources: [widgetkit-keeping-up-to-date, widgetkit-timelineprovider, widgetkit-interactivity, xcode-app-groups, hig, foundation-userdefaults, foundation-jsondecoder, information-property-list]
cards:
  - id: m44-l01-c1
    front: What are the three timeline reload policies, and when does each fit?
    back: ".atEnd: ask for a new timeline after the last entry's date, when more changes are coming. .after(date): ask at a specific date, such as when a market opens on Monday. .never: don't ask until the app calls WidgetCenter.shared.reloadTimelines(ofKind:), when future changes can't be predicted."
  - id: m44-l01-c2
    front: What does Apple say about a widget's reload budget?
    back: "Each configured widget gets its own budget over a 24-hour window tuned to the person's usage. A frequently viewed widget typically gets 40 to 70 refreshes, roughly every 15 to 60 minutes. Entries should be at least about 5 minutes apart. The limit isn't imposed while debugging in Xcode."
  - id: m44-l01-c3
    front: Name four situations in which a reload doesn't count against the widget's budget.
    back: "The app is in the foreground; the app has an active audio or navigation session or is the Now Playing app; the widget performs an app intent (a button or toggle); the widget animates; the system locale, Dynamic Type or accessibility settings change."
  - id: m44-l01-c4
    front: How do the app and its widget share data?
    back: "Both targets join the same App Group (an entitlement with an id starting with group.). The app writes to the group container, from containerURL(forSecurityApplicationGroupIdentifier:) or UserDefaults(suiteName:), and the provider reads from it. UserDefaults.standard is per target and isn't shared."
  - id: m44-l01-c5
    front: What happens when someone taps a widget Toggle backed by an App Intent?
    back: "The Toggle flips its appearance immediately (optimistically), the system runs the intent's perform() (in the widget extension's process by default), and when perform() returns, WidgetKit reloads the timeline. Interactions always guarantee a reload."
---

## The idea in one sentence

A widget is **a schedule of pre-rendered SwiftUI snapshots** that WidgetKit displays for you: your code runs briefly to plan that schedule, then exits, so everything about widgets comes down to planning entries ahead and asking for as few reloads as possible.

> [!note] Sources and what was checked
> Behavior and limits come from Apple's WidgetKit documentation, read in November 2026: "Creating a widget extension", "Keeping a widget up to date", `TimelineProvider`, `TimelineReloadPolicy`, `WidgetFamily`, `WidgetCenter`, "Displaying dynamic dates", "Adding interactivity to widgets and Live Activities", and Xcode's "Configuring app groups". The Xcode steps are quoted from those pages and weren't performed for this lesson. The WidgetKit, SwiftUI and App Intents blocks are type-checked against the iOS SDK, not run; nothing here was tested on a device. The timeline and reload models are plain Swift, compiled and run with Swift 6.3.

## How a widget actually runs

Everything you've built so far in SwiftUI (Modules 34 to 37) runs in your app's process: state changes, `body` recomputes, the screen updates. A widget breaks that model. Apple's description: "WidgetKit renders the views on your behalf in a separate process. As a result, your widget extension is not continually active, even if the widget is onscreen."

So the sequence is:

1. WidgetKit launches your **widget extension** and asks its timeline provider for a timeline.
2. The provider returns entries ("from 10:00 show this, from 11:00 show that") and a reload policy.
3. WidgetKit renders the view for each entry, archives the result, and lets the extension go.
4. As each entry's date arrives, the system shows the matching rendering. Your code isn't running.
5. When the policy says so, or when the app asks, WidgetKit goes back to step 1.

That has consequences you'll see all through this lesson. There's no `@State` that survives, no timer, no `onAppear` that fires when someone looks at the Home Screen, and no network call when the widget comes into view. Bindings don't work either: Apple's interactivity article says "the system can't run your code or update data bindings at the time it renders your widget."

### Adding the target

From "Creating a widget extension" (not performed here): File > New > Target, choose **Widget Extension** in the Application Extension group, name it, and deselect "Include Live Activity" and "Include Configuration App Intent" for a static widget. The template gives you a widget, a provider and an entry. Apple also notes that "a person must launch the app that contains the widget at least once after the app is installed" before the widget shows up in the gallery, which matters when you test a fresh install.

## The pieces of a widget

Pantry, the grocery app from Module 43, wants a "Next delivery" widget. Here are the three parts: an entry, a provider and the widget's configuration.

```swift ios
import WidgetKit
import SwiftUI

struct DeliveryEntry: TimelineEntry {
    let date: Date
    let headline: String
}

struct DeliveryProvider: TimelineProvider {
    /// Shown while the real content loads. Must return immediately, with no I/O.
    func placeholder(in context: Context) -> DeliveryEntry {
        DeliveryEntry(date: .now, headline: "Next: #0000 at 10:00")
    }

    /// Used in transient places such as the widget gallery. Use sample data when context.isPreview is true.
    func getSnapshot(in context: Context, completion: @escaping @Sendable (DeliveryEntry) -> Void) {
        completion(DeliveryEntry(date: .now, headline: "Next: #1042 at 10:00"))
    }

    /// The schedule: entries for every known change, and when to ask again.
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<DeliveryEntry>) -> Void) {
        let entries = [
            DeliveryEntry(date: .now, headline: "Next: #1042 at 10:00"),
            DeliveryEntry(date: .now.addingTimeInterval(3_600), headline: "Arriving: #1042 until 11:00"),
        ]
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct NextDeliveryView: View {
    let entry: DeliveryEntry

    var body: some View {
        Text(entry.headline)
            .font(.headline)
            .containerBackground(.background, for: .widget)
    }
}

struct NextDeliveryWidget: Widget {
    let kind = "NextDelivery"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DeliveryProvider()) { (entry: DeliveryEntry) in
            NextDeliveryView(entry: entry)
        }
        .configurationDisplayName("Next delivery")
        .description("When your next Pantry order arrives.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
```

Line by line:

- **`DeliveryEntry`** conforms to `TimelineEntry`, whose one requirement is `date`. Everything else is whatever the view needs. Keep it small and already formatted: the view shouldn't compute.
- **`placeholder(in:)`** is synchronous and returns right away. Apple: "When WidgetKit displays your widget for the first time, it renders the widget's view as a placeholder," a generic version of the content. It's also used when people hide sensitive information on the Lock Screen.
- **`getSnapshot(in:completion:)`** is for "transient situations, such as when the user is adding a widget." Apple: "If `context.isPreview` is true, the widget appears in the widget gallery and requires a quick response from your provider." If real data isn't at hand, use sample data.
- **`getTimeline(in:completion:)`** is the real work. Both completion handlers are `@Sendable` in the SDK, so you can call them from any thread after asynchronous work. Apple: "store a reference to the completion handler and call it when you are done with your asynchronous work."
- **`kind`** identifies the widget. The app uses the same string to reload it.
- **`containerBackground(_:for: .widget)`** configures the widget's background (iOS 17). Set it on the widget's root view rather than drawing your own full-bleed background.
- **`supportedFamilies`** lists the sizes people can pick.

The extension's entry point is a `@main` type. With one widget it's the widget itself; with several, a `WidgetBundle`:

```swift illustrative
@main
struct PantryWidgets: WidgetBundle {
    var body: some Widget {
        NextDeliveryWidget()
        ShoppingListWidget()
    }
}
```

That fragment isn't compiled here because `@main` can't appear in a type-checked snippet, and `ShoppingListWidget` stands for a second widget you'd define the same way.

## Planning a timeline

The provider's job is to predict. Apple: "If your widget can predict points in time that it should reload, the best approach is to generate a timeline for as many future dates as possible." A delivery widget is a good fit, because the delivery windows are known in advance. Every window start and end is a moment when the text changes.

Apple also gives a floor: "Your timeline provider should create timeline entries that are at least about 5 minutes apart." When two changes fall closer than that, Pantry keeps the earlier time and shows the later state, a couple of minutes early.

Here's the planner, with minutes since midnight instead of `Date` so the output is deterministic:

```swift
struct DeliveryWindow {
    let order: String
    let start: Int      // minutes since midnight
    let end: Int
}

struct Entry {
    let minute: Int
    var text: String
}

enum ReloadPolicy {
    case atEnd
    case after(minute: Int)
    case never
}

func clock(_ minute: Int) -> String {
    let hours = minute / 60, minutes = minute % 60
    return (hours < 10 ? "0" : "") + "\(hours):" + (minutes < 10 ? "0" : "") + "\(minutes)"
}

/// What the widget shows at `minute`, given today's windows sorted by start.
func status(at minute: Int, _ windows: [DeliveryWindow]) -> String {
    for window in windows where minute < window.end {
        if minute >= window.start { return "Arriving: \(window.order) until \(clock(window.end))" }
        return "Next: \(window.order) at \(clock(window.start))"
    }
    return "No more deliveries today"
}

func timeline(now: Int, windows: [DeliveryWindow], ordersAfterToday: Bool) -> (entries: [Entry], policy: ReloadPolicy) {
    // Every start and end in the future is a moment when the text changes.
    var moments = [now]
    for window in windows {
        if window.start > now { moments.append(window.start) }
        if window.end > now { moments.append(window.end) }
    }
    var entries: [Entry] = []
    for minute in moments.sorted() {
        let text = status(at: minute, windows)
        if let last = entries.last, minute - last.minute < 5 {
            entries[entries.count - 1].text = text     // too close: the later state wins, a little early
        } else {
            entries.append(Entry(minute: minute, text: text))
        }
    }
    let policy: ReloadPolicy = ordersAfterToday ? .after(minute: 24 * 60) : .never
    return (entries, policy)
}

let today = [
    DeliveryWindow(order: "#1042", start: 600, end: 660),
    DeliveryWindow(order: "#1043", start: 662, end: 720),
    DeliveryWindow(order: "#1044", start: 900, end: 960),
]
let plan = timeline(now: 550, windows: today, ordersAfterToday: false)
for entry in plan.entries {
    print(clock(entry.minute), entry.text)
}
print("policy:", plan.policy)
```

```output
09:10 Next: #1042 at 10:00
10:00 Arriving: #1042 until 11:00
11:00 Arriving: #1043 until 12:00
12:00 Next: #1044 at 15:00
15:00 Arriving: #1044 until 16:00
16:00 No more deliveries today
policy: never
```

- **One timeline covers the whole day.** Six entries, one reload. Without planning, the widget would need a reload at each change, and the budget (next section) wouldn't allow it.
- **11:00 and 11:02 are two minutes apart**, so they collapse into one entry at 11:00 that already shows order #1043 arriving. "Next: #1043 at 11:02" for two minutes isn't worth an entry.
- **The policy is `.never`** because nothing after 16:00 is predictable: the next change happens when the person places an order, and the app will tell WidgetKit then. If there were orders for tomorrow, `.after(midnight)` would schedule the next plan without the app's help.
- In the provider, `minute` becomes a `Date` and `ReloadPolicy` becomes `TimelineReloadPolicy`. The logic is the part worth testing.

### Choosing the reload policy

| Policy | When WidgetKit asks again | Apple's examples |
| --- | --- | --- |
| `.atEnd` (default) | After the last entry's date | A game character healing hourly: four entries, then a new timeline |
| `.after(date)` | After `date`, which can be before or after the last entry | A dragon appearing in 2 hours might change the plan; a stock widget at Friday's close asks again at Monday's open |
| `.never` | Only when the app calls `WidgetCenter` | Health at 100% won't change on its own; the person isn't signed in |

`.after` is a request, not an alarm. Apple warns that "WidgetKit tries to respect the date you specify, which may cause a significant increase in server load when multiple devices reload your widget at around the same time": if every Pantry widget fetches from the server at exactly 08:00, the backend sees a spike. Spread the date or have the app prefetch.

For dates the view can count by itself, don't reload at all. `Text(date, style: .timer)`, `.relative` and `ProgressView(timerInterval:countsDown:)` keep updating "even if your widget extension isn't running" ("Displaying dynamic dates"). A countdown to the end of a delivery window needs one entry, not one per minute.

## The reload budget

Apple's numbers, from "Keeping a widget up to date":

- "A widget's budget applies to a 24-hour period," tuned to the person's daily usage, so it "doesn't necessarily reset at exactly midnight."
- "For a widget the user frequently views, a daily budget typically includes from 40 to 70 refreshes. This rate roughly translates to widget reloads every 15 to 60 minutes."
- The budget is per configured widget: two instances of the same widget have two budgets. It depends on how often the widget is visible, when it last reloaded, and whether the app is active.
- Reloads that **don't count**: the app is in the foreground; the app has an active audio or navigation session; the app is the current Now Playing app; "the widget performs an app intent, such as when the user taps a button or toggles a switch"; the widget animates; the locale, Dynamic Type or accessibility settings change.
- For appearance and locale changes, "don't request a timeline reload from your app. The system updates your widgets automatically."
- "WidgetKit does not impose this limit when debugging your widget in Xcode," so a widget that refreshes perfectly under the debugger can starve in real use. Test outside the debugger too.

None of these are guarantees: Apple says intervals "vary due to the many factors involved," and the system may reload on its own, for example when a rarely visited Home Screen page becomes visible.

### Reloading from the app

When the app changes data a widget shows, it calls `WidgetCenter.shared.reloadTimelines(ofKind:)` for that kind, or `reloadAllTimelines()` when everything changed, such as on sign-out. Apple's rule is to call it "only when information the widget is currently displaying changes." Pantry has two widgets: the next delivery, and the first four items of the shopping list. The cart isn't on either.

```swift
struct WidgetData: Equatable {
    var nextDelivery: String?
    var listItems: [String]
    var cartCount: Int
    var signedIn: Bool
}

/// The widget kinds whose displayed content changed, or every kind when the account changed.
func kindsToReload(from old: WidgetData, to new: WidgetData) -> [String] {
    if old.signedIn != new.signedIn { return ["*"] }          // reloadAllTimelines()
    var kinds: [String] = []
    if old.nextDelivery != new.nextDelivery { kinds.append("NextDelivery") }
    // The list widget shows at most four items.
    if Array(old.listItems.prefix(4)) != Array(new.listItems.prefix(4)) { kinds.append("ShoppingList") }
    return kinds
}

var data = WidgetData(nextDelivery: "#1042 at 10:00", listItems: ["Milk", "Eggs"], cartCount: 3, signedIn: true)
let events: [(String, (inout WidgetData) -> Void)] = [
    ("add to cart", { $0.cartCount += 1 }),
    ("add Bread to list", { $0.listItems.append("Bread") }),
    ("reschedule delivery", { $0.nextDelivery = "#1042 at 11:00" }),
    ("add Rice and Tea to list", { $0.listItems += ["Rice", "Tea"] }),
    ("add Salt to list", { $0.listItems.append("Salt") }),
    ("sign out", { $0.signedIn = false; $0.nextDelivery = nil }),
]
for (name, change) in events {
    var updated = data
    change(&updated)
    print(name, "→", kindsToReload(from: data, to: updated))
    data = updated
}
```

```output
add to cart → []
add Bread to list → ["ShoppingList"]
reschedule delivery → ["NextDelivery"]
add Rice and Tea to list → ["ShoppingList"]
add Salt to list → []
sign out → ["*"]
```

- **The cart never reloads anything.** Pantry's old code called `reloadAllTimelines()` in the cart's `didSet`, which spent budget on every tap.
- **"Rice and Tea" reloads** because Rice becomes the fourth visible item. **Salt doesn't**: it's sixth, and the widget can't show it.
- **Sign-out reloads everything**, as in Apple's example, so no widget keeps showing an account's data.
- While the app is in the foreground these reloads don't count against the budget, but comparing first is still right: it keeps the rule in one place and the same code runs when the app updates in the background.

## Widget families

`WidgetFamily` lists the sizes: `systemSmall`, `systemMedium`, `systemLarge`, `systemExtraLarge` (iPad) and `systemExtraLargePortrait` (new in iOS 27), plus the accessory families `accessoryCircular`, `accessoryRectangular` and `accessoryInline` for the Lock Screen, and `accessoryCorner` on watchOS. Apple: "The sizes of widgets may vary across devices. Your widget content should be flexible and avoid using fixed values." The view reads the family from the environment:

```swift ios
import SwiftUI
import WidgetKit

struct ShoppingListWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let items: [String]

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(items.count) items to buy")
        case .systemSmall:
            Text(items.first ?? "List is empty")
        default:
            VStack(alignment: .leading) {
                ForEach(items.prefix(4), id: \.self) { (item: String) in
                    Text(item)
                }
            }
        }
    }
}
```

The provider gets the family too, as `context.family`, so it can skip work the small size won't show. Apple describes the inline family as "a flat widget that contains a single row of text and an optional image"; plan its wording first, because it's the strictest.

## Sharing data through an App Group

The extension is a separate process with its own container (Module 21's sandbox). It can't read the app's files or its `UserDefaults.standard`. To share, both targets join an **App Group**. From Xcode's "Configuring app groups" (not performed here): add the App Groups capability to each target, click +, and enter an identifier that "must begin with `group.` and then a custom string." Apple lists the APIs for the shared container:

- `UserDefaults(suiteName:)` for "preferences and other limited data."
- `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)` for files.
- `sharedContainerIdentifier` on a background `URLSession` configuration, to download straight into the group container (lesson 5).

Apple's advice for widgets is to "have the containing app prepare data for the widget in advance of when the widget needs it. Use a shared group container to store the data." Pantry writes a small JSON file that the provider reads:

```swift ios
import Foundation

struct DeliverySnapshot: Codable, Sendable {
    var order: String
    var windowStart: Date
    var windowEnd: Date
}

enum SharedStore {
    static let appGroup = "group.com.example.pantry"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("deliveries.json")
    }

    /// Called by the app. The caller decides which widget kinds to reload afterward.
    static func save(_ deliveries: [DeliverySnapshot]) throws {
        guard let url = fileURL else { return }
        let data = try JSONEncoder().encode(deliveries)
        try data.write(to: url, options: .atomic)
    }

    /// Called by the timeline provider. Missing or unreadable data means "nothing scheduled".
    static func load() -> [DeliverySnapshot] {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([DeliverySnapshot].self, from: data)) ?? []
    }
}
```

- **`containerURL` returns nil** when the entitlement is missing or the identifier is wrong. Both targets need the same group; a typo in one of them silently gives the widget an empty list.
- **`.atomic`** writes to a temporary file and moves it into place, so the provider never reads half a file while the app is writing.
- **The provider never hits the network** in this design. Widgets *can* make requests ("Making network requests in a widget extension"), but data the app already prepared is faster and doesn't depend on the widget's time to run.
- After saving, the app runs `kindsToReload` and calls `WidgetCenter` for the kinds that changed.

## Interactive widgets with App Intents

Since iOS 17, widgets can contain `Button` and `Toggle`. Because the extension isn't running when the widget is on screen, a button can't call a closure. Instead it carries an **App Intent** (lesson 4 covers them fully): a value describing an action, which the system can run later. Apple lists the families that support buttons and toggles: the system sizes, plus `accessoryCircular` and `accessoryRectangular` on iPhone and iPad. On a locked device they're inactive until the person authenticates.

Pantry's shopping list gets a toggle to check off an item:

```swift ios
import AppIntents
import SwiftUI
import WidgetKit

struct ToggleListItemIntent: AppIntent {
    static var title: LocalizedStringResource { "Check Off Item" }

    @Parameter(title: "Item ID")
    var itemID: String

    init() {}

    init(itemID: String) {
        self.itemID = itemID
    }

    func perform() async throws -> some IntentResult {
        await ShoppingList.shared.toggle(itemID)
        return .result()
    }
}

actor ShoppingList {
    static let shared = ShoppingList()
    private var checked: Set<String> = []

    func toggle(_ id: String) {
        if checked.contains(id) { checked.remove(id) } else { checked.insert(id) }
        // In the app: write to the App Group container, which the provider reads.
    }
}

struct ListItem: Identifiable {
    let id: String
    let name: String
    let isChecked: Bool
}

struct ListItemRow: View {
    let item: ListItem

    var body: some View {
        Toggle(isOn: item.isChecked, intent: ToggleListItemIntent(itemID: item.id)) {
            Text(item.name)
        }
    }
}
```

What happens on a tap, from Apple's article:

1. **The toggle flips immediately.** "Toggle updates its appearance optimistically and indicates its new state immediately — without waiting for the result of the performed action." `isOn` takes a `Bool`, not a `Binding`.
2. **The system runs `perform()`**, by default "in the same process as the widget extension." Apple tells you to add an `AppIntent` to both the extension and the app targets. (Intents conforming to `LiveActivityIntent` and a few other protocols run in the app's process instead; lesson 2.)
3. **When `perform()` returns, WidgetKit reloads the timeline.** "Interactions with a toggle or button always guarantee a timeline reload," and they don't count against the budget. So finish writing before you return: `await` the save, then return.
4. **If the action fails**, the next timeline must show the real state. A toggle that showed "checked" optimistically has to flip back, with a message, if the server rejected it. Apple: "handle errors instead of rethrowing them."

`init(itemID:)` is how the widget pre-fills the parameter. Apple: "widgets don't resolve parameters for app intents," so every parameter must already have a value when the button is rendered. The empty `init()` is still required by the protocol. For views waiting on the result, Apple suggests `invalidatableContent()`, used sparingly. A `Link` or `widgetURL(_:)` is the tool when the tap should just open the app.

## Common mistakes

> [!error] Treating the widget like a small app
> Timers, `onAppear`, `@State` and `.task` don't run while the widget is on screen. Everything the widget shows must be in a timeline entry. Live countdowns use `Text(_:style:)` with `.timer` or `.relative`.

> [!error] One entry, policy .after(15 minutes), forever
> Polling every 15 minutes uses up to 96 reloads a day, more than the 40 to 70 Apple says a frequently viewed widget typically gets, and most reloads produce the same content. Plan entries for known changes and reload from the app when data actually changes.

> [!error] Reading UserDefaults.standard in the widget
> The extension has its own defaults and container. Without a shared App Group, the provider reads empty data and the widget shows its placeholder forever.

> [!error] Slow placeholder and snapshot
> `placeholder(in:)` must return immediately, and a snapshot with `isPreview` must be quick. A network call there leaves the widget gallery blank. Use sample data.

> [!error] Returning from perform() before the data is saved
> WidgetKit reloads the timeline as soon as `perform()` returns. If the write is still in flight, the provider reads old data and the optimistic toggle snaps back.

> [!error] Trusting reload timing seen in the debugger
> WidgetKit doesn't apply the budget while debugging in Xcode. Check the widget's real behavior outside the debugger, over a day.

## Exercises

````exercise
id: m44-l01-e1
type: prediction
prompt: "A smaller version of the planner: keep a moment only if it's at least `minimumGap` minutes after the last one kept. What does it print?"
code: |
  func merged(_ moments: [Int], minimumGap: Int) -> [Int] {
      var kept: [Int] = []
      for minute in moments.sorted() {
          if let last = kept.last, minute - last < minimumGap { continue }
          kept.append(minute)
      }
      return kept
  }

  let moments = [600, 540, 603, 660, 664, 669, 720]
  print(merged(moments, minimumGap: 5))
  print(merged(moments, minimumGap: 30))
  print(merged([], minimumGap: 5).count)
output: |
  [540, 600, 660, 669, 720]
  [540, 600, 660, 720]
  0
hints:
  - "Sort first: 540, 600, 603, 660, 664, 669, 720."
  - "Each comparison is against the last moment kept, not the last one seen."
solution: |
  ```output
  [540, 600, 660, 669, 720]
  [540, 600, 660, 720]
  0
  ```

  - With a 5-minute gap: 603 is 3 after 600, dropped. 664 is 4 after 660, dropped. **669 is 9 after 660** (the last *kept*), so it stays, even though it's only 5 after 664.
  - With 30 minutes, 669 is dropped too, and 720 is 60 after 660.
  - An empty list stays empty. A real provider always includes an entry for "now", so its timeline is never empty.
````

````exercise
id: m44-l01-e2
type: comprehension
prompt: "Pantry's local-store widget shows \"Open until 21:00\" or \"Opens at 08:00\". The store is closed from Saturday 20:00 to Monday 08:00, and the hours never change otherwise. It's Saturday 20:00. Which reload policy fits the timeline the provider returns now?"
choices:
  - text: ".after(Monday 08:00), with one entry for now saying it opens Monday at 08:00."
    correct: true
    why: "Nothing changes until Monday morning, like Apple's stock-market example with its Monday open."
  - text: ".atEnd, with one entry for now."
    correct: false
    why: "With one entry dated now, .atEnd asks for a new timeline almost immediately, then again and again, spending budget on identical content."
  - text: ".never, because store hours don't change."
    correct: false
    why: "The displayed text does change on Monday. Unless the app reloads on Monday, the widget would say \"closed\" all week."
  - text: ".after(15 minutes), to stay fresh."
    correct: false
    why: "About 140 reloads over the 36 hours for content that can't change."
solution: |
  `.after(_:)` can point past the end of the timeline. Apple's example is exactly this: "a stock market widget could create a timeline at the close of the market on Friday with an `after(_:)` refresh policy specifying the time the market opens on Monday." A better provider also includes the Monday 08:00 entry ("Open until 21:00") in the timeline, so the widget is right at 08:00 even if the reload comes a bit later.
````

````exercise
id: m44-l01-e3
type: fill-in
prompt: "Complete the provider and the app-side save so the widget reads shared data and reloads only its own kind."
code: |
  func getSnapshot(in context: Context, completion: @escaping @Sendable (DeliveryEntry) -> Void) {
      if context.[[1]] {
          completion(DeliveryEntry(date: .now, headline: "Next: #1042 at 10:00"))
      } else {
          completion(entry(for: SharedStore.load(), at: .now))
      }
  }

  func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<DeliveryEntry>) -> Void) {
      let entries = plannedEntries(SharedStore.load())
      completion(Timeline(entries: entries, policy: [[2]]))   // the app reloads when an order is placed
  }

  // In the app, after saving:
  let url = FileManager.default.[[3]](forSecurityApplicationGroupIdentifier: "group.com.example.pantry")
  WidgetCenter.shared.[[4]](ofKind: "NextDelivery")
blanks:
  - id: "1"
    answers: ["isPreview"]
  - id: "2"
    answers: [".never"]
  - id: "3"
    answers: ["containerURL"]
  - id: "4"
    answers: ["reloadTimelines"]
solution: |
  - `context.isPreview` is true in the widget gallery, where Apple asks for a quick response with sample data.
  - `.never`: the provider can't predict the next order, so it waits for the app.
  - `containerURL(forSecurityApplicationGroupIdentifier:)` returns the App Group container both targets can read.
  - `reloadTimelines(ofKind:)` with the widget's `kind` reloads only that widget; `reloadAllTimelines()` is for changes that affect all of them.
````

````exercise
id: m44-l01-e4
type: find-errors
prompt: "A teammate's first version of the shopping-list widget. Mark every real problem."
code: |
  struct ListProvider: TimelineProvider {
      func placeholder(in context: Context) -> ListEntry {
          let items = try! Data(contentsOf: URL(string: "https://api.example.com/list")!)
          return ListEntry(date: .now, items: decode(items))
      }

      func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<ListEntry>) -> Void) {
          let items = UserDefaults.standard.stringArray(forKey: "list") ?? []
          let entries = (0..<60).map { minute in
              ListEntry(date: .now.addingTimeInterval(Double(minute) * 60), items: items)
          }
          completion(Timeline(entries: entries, policy: .atEnd))
      }
      // getSnapshot omitted
  }

  // In the app's cart model:
  var cart: [Product] = [] {
      didSet { WidgetCenter.shared.reloadAllTimelines() }
  }
choices:
  - text: "The placeholder does a synchronous network request; it must return immediately with sample data."
    correct: true
  - text: "UserDefaults.standard in the extension isn't the app's defaults; the list must come from an App Group."
    correct: true
  - text: "Sixty identical entries one minute apart: below Apple's 5-minute spacing, and nothing changes between them."
    correct: true
  - text: "Reloading all timelines on every cart change spends budget, and the cart isn't shown by any widget."
    correct: true
  - text: "Timeline entries must all have dates in the future, so the first entry can't be .now."
    correct: false
    why: "Apple's examples start with an entry for the current date."
rubric:
  - I flagged the network call in the placeholder.
  - I flagged UserDefaults.standard.
  - I flagged the one-minute identical entries.
  - I flagged the reload on every cart change.
solution: |
  - **Placeholder:** synchronous, no I/O. A `try!` on a network request also crashes the extension offline. Return sample items.
  - **Shared data:** `UserDefaults(suiteName: "group.com.example.pantry")` or a file in the group container, in both targets.
  - **Entries:** the list only changes when the person edits it, so one entry for now and `.never` is the right plan; the app reloads when the list changes. Entries closer than about 5 minutes go against Apple's guidance anyway.
  - **Reload:** compare what the widgets display before and after, and reload only the kinds that changed (`kindsToReload` from the lesson).
````

````exercise
id: m44-l01-e5
type: solve
prompt: |
  Write `storeTimeline(now:opens:closes:)` for the local-store widget. Times are minutes since midnight, and the store opens and closes once a day. Return the entries for the rest of today (one for `now`, plus one at each of `opens` and `closes` that's still in the future) with the text "Open until HH:MM" while open and "Opens at HH:MM" otherwise, and return the minute to reload after: tomorrow's opening, counted from today's midnight. Use the `clock` function given.

  Expected output:

  ```output
  07:00 Opens at 08:00
  08:00 Open until 21:00
  21:00 Opens at 08:00
  reload after tomorrow 08:00
  12:30 Open until 21:00
  21:00 Opens at 08:00
  reload after tomorrow 08:00
  22:00 Opens at 08:00
  reload after tomorrow 08:00
  ```
starter: |
  func clock(_ minute: Int) -> String {
      let day = minute >= 24 * 60 ? "tomorrow " : ""
      let m = minute % (24 * 60)
      let hours = m / 60, minutes = m % 60
      return day + (hours < 10 ? "0" : "") + "\(hours):" + (minutes < 10 ? "0" : "") + "\(minutes)"
  }

  func storeTimeline(now: Int, opens: Int, closes: Int) -> (entries: [(Int, String)], reloadAfter: Int) {
      // your code
      return ([], 0)
  }

  for now in [7 * 60, 12 * 60 + 30, 22 * 60] {
      let plan = storeTimeline(now: now, opens: 8 * 60, closes: 21 * 60)
      for (minute, text) in plan.entries {
          print(clock(minute), text)
      }
      print("reload after", clock(plan.reloadAfter))
  }
hints:
  - "Write a nested function that returns the text for any minute; then call it for now and for each boundary."
  - "Only boundaries strictly after now get their own entry."
rubric:
  - The first entry is always now, with the right text.
  - Adds entries only for future boundaries, in order.
  - The reload date is tomorrow's opening, so no reload happens overnight.
solution: |
  ```swift
  func clock(_ minute: Int) -> String {
      let day = minute >= 24 * 60 ? "tomorrow " : ""
      let m = minute % (24 * 60)
      let hours = m / 60, minutes = m % 60
      return day + (hours < 10 ? "0" : "") + "\(hours):" + (minutes < 10 ? "0" : "") + "\(minutes)"
  }

  func storeTimeline(now: Int, opens: Int, closes: Int) -> (entries: [(Int, String)], reloadAfter: Int) {
      func text(at minute: Int) -> String {
          minute >= opens && minute < closes ? "Open until \(clock(closes))" : "Opens at \(clock(opens))"
      }
      var entries = [(now, text(at: now))]
      for boundary in [opens, closes] where boundary > now {
          entries.append((boundary, text(at: boundary)))
      }
      return (entries, 24 * 60 + opens)
  }

  for now in [7 * 60, 12 * 60 + 30, 22 * 60] {
      let plan = storeTimeline(now: now, opens: 8 * 60, closes: 21 * 60)
      for (minute, text) in plan.entries {
          print(clock(minute), text)
      }
      print("reload after", clock(plan.reloadAfter))
  }
  ```

  ```output
  07:00 Opens at 08:00
  08:00 Open until 21:00
  21:00 Opens at 08:00
  reload after tomorrow 08:00
  12:30 Open until 21:00
  21:00 Opens at 08:00
  reload after tomorrow 08:00
  22:00 Opens at 08:00
  reload after tomorrow 08:00
  ```

  One timeline covers the rest of the day, and `.after(tomorrow 08:00)` means no reloads overnight, when nothing changes. Holidays would come from the app: when the hours change, it reloads the widget's kind. A finer version would also add tomorrow's 08:00 entry to the timeline, so the widget flips to "Open" on time even if the reload runs late.
````

````exercise
id: m44-l01-e6
type: design
prompt: "Product wants a Pantry widget that shows \"Deals near you\": three discounted products from the person's usual store, which change when the store publishes new deals (usually once a day, sometimes more), plus a button to add a deal to the cart. Plan the widget: families, data flow, timeline and reloads, and the button."
rubric:
  - Chooses families based on content (three deals need medium or larger; small shows one; an accessory family only if there's a useful one-line version).
  - The app or a background task fetches deals into the App Group; the provider reads them and doesn't depend on the network.
  - The timeline uses known expiry times of deals and .never or .after with the next known change; the app reloads the kind when new deals arrive, with care for server load.
  - The add-to-cart button is an App Intent with a pre-filled parameter, saves before returning, and the next timeline reflects the result or an error.
solution: |
  - **Families:** `systemMedium` and `systemLarge` show three deals; `systemSmall` shows the best one. No accessory family: a deal needs a name and a price, and an inline line like "3 deals" isn't useful.
  - **Data:** a background refresh task (lesson 5) or a server push fetches deals and writes them to the App Group container. The provider reads that file, so it's fast and works offline.
  - **Timeline:** each deal has an end time. Entries at each expiry, so expired deals disappear without a reload, and `.never` after the last; the app reloads `"Deals"` when it stores new deals, if the three shown deals actually changed. If you choose `.after(nextMorning)`, add jitter to avoid every device hitting the server at once.
  - **Button:** `Button(intent: AddDealToCartIntent(dealID: deal.id))`. `perform()` writes the cart change (to the shared store and the server) and returns only after the write. On failure, the next entry shows "Couldn't add, try in the app." The interaction's reload doesn't count against the budget.
  - **Measure:** check outside the debugger that the widget updates the morning after new deals.
````

## Summary

- A widget extension runs only to produce timelines. WidgetKit renders the entries, archives them and shows each at its date; no state, timers or bindings survive.
- A `TimelineProvider` has a synchronous `placeholder`, a quick `getSnapshot` (sample data when `isPreview`), and `getTimeline`, which plans entries for every known change, at least about 5 minutes apart.
- Reload policies: `.atEnd` for more known changes, `.after(date)` for a known next change (even past the last entry), `.never` when only the app knows. Text styles like `.timer` avoid reloads for countdowns.
- Apple: a frequently viewed widget typically gets 40 to 70 reloads a day, per widget, tuned to usage. Foreground app, intents, animations and some system changes don't count. The debugger doesn't apply the budget.
- Reload from the app with `WidgetCenter.shared.reloadTimelines(ofKind:)` only when displayed data changes; `reloadAllTimelines()` for account-wide changes.
- Support families deliberately and read `widgetFamily`. Share data through an App Group container that the app writes and the provider reads.
- Interactive widgets (iOS 17) use `Button(intent:)` and `Toggle(isOn:intent:)`. The toggle updates optimistically, `perform()` runs, and the timeline reloads when it returns, so save first and show failures in the next timeline.

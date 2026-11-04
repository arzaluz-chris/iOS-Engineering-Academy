---
id: m44-l02
title: Live Activities with ActivityKit
description: "A Live Activity shows one ongoing event, like a delivery on its way, on the Lock Screen and in the Dynamic Island. You split its data into static ActivityAttributes and a dynamic ContentState, build every presentation Apple requires, and start, update and end it from the app with ActivityKit. You learn the limits Apple documents (eight hours active, up to twelve on the Lock Screen, 4 KB of data), how push updates work and what they cost, and how to keep the activity's state consistent with the order's."
module: m44
order: 2
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m44-l01]
objectives:
  - Explain how a Live Activity differs from a widget and a notification, and when it's the right tool.
  - Define ActivityAttributes and a ContentState, and keep their combined size inside Apple's 4 KB limit.
  - Build the Lock Screen, compact, minimal and expanded presentations with ActivityConfiguration and DynamicIsland.
  - Start, update and end a Live Activity with ActivityKit, using staleDate, relevance and dismissal policies correctly.
  - Describe ActivityKit push notifications, their headers and payload, and how priority affects the update budget.
  - Map an order's lifecycle to Live Activity commands, including the eight-hour limit.
terms:
  - term: Live Activity
    definition: "A glanceable, continuously updated view of one ongoing task or event, shown on the Lock Screen, in the Dynamic Island and in other places the system chooses. Its UI lives in the widget extension; ActivityKit manages its lifecycle."
  - term: ActivityAttributes
    definition: "The protocol for a Live Activity's data. The conforming type's properties are static for the activity's whole life; its nested ContentState type (Codable and Hashable) holds the data that changes."
  - term: ContentState
    definition: "The dynamic part of a Live Activity. Each update or end call sends a new ContentState, wrapped in an ActivityContent with an optional staleDate and relevanceScore."
  - term: Dynamic Island presentations
    definition: "Compact (leading and trailing views around the camera), minimal (one small view when several activities compete) and expanded (shown on touch and hold and briefly for updates). An app must support all of them plus the Lock Screen presentation."
  - term: Dismissal policy
    definition: "ActivityUIDismissalPolicy passed to end(_:dismissalPolicy:): .default keeps the ended activity on the Lock Screen for up to four hours, .immediate removes it, .after(date) removes it at that date or after four hours, whichever comes first."
  - term: ActivityKit push notification
    definition: "A push sent through APNs with apns-push-type liveactivity and a topic of <bundle ID>.push-type.liveactivity, carrying an event (start, update or end) and a content-state that the system decodes into ContentState."
mastery:
  - Decide whether a feature needs a Live Activity, a widget or a notification.
  - Measure the encoded size of attributes plus state and say what doesn't belong in them.
  - Write the ActivityConfiguration with all four presentations and a stale indicator.
  - Translate order events into start, update with or without alert, and end with the right dismissal policy.
  - Compute when an ended Live Activity leaves the Lock Screen for each dismissal policy.
  - Choose apns-priority 5 or 10 for each push update and explain the budget.
resources: [hig, foundation-jsondecoder, foundation-encoding-custom-types, information-property-list]
cards:
  - id: m44-l02-c1
    front: How long can a Live Activity run, and how long can it stay visible?
    back: "Up to eight hours active, unless the app or person ends it. Then the system ends it and removes it from the Dynamic Island, but it can stay on the Lock Screen up to four more hours, so twelve hours at most."
  - id: m44-l02-c2
    front: What's the size limit for a Live Activity's data?
    back: "Apple: static and dynamic data, including data for ActivityKit updates and push notifications, can't exceed a combined size of 4 KB. Images go in the widget extension's assets, not in the state."
  - id: m44-l02-c3
    front: Where can a Live Activity be started, updated and ended?
    back: "Started from the app in the foreground (or from a LiveActivityIntent, or by push-to-start from iOS 17.2). Updated and ended from the app, including in the background, or by ActivityKit push. The Live Activity itself can't use the network or location."
  - id: m44-l02-c4
    front: What are the three dismissal policies for an ended Live Activity?
    back: ".default: stays on the Lock Screen up to four hours. .immediate: removed right away. .after(date): removed at that date or four hours after ending, whichever comes first. Always pass the final ContentState when ending."
  - id: m44-l02-c5
    front: How does apns-priority affect ActivityKit pushes?
    back: "Priority 10 (the default) is delivered immediately and counts toward an hourly budget; exceeding it can throttle updates. Priority 5 doesn't count toward the budget. NSSupportsLiveActivitiesFrequentUpdates allows more frequent updates, and people can turn that off in Settings."
---

## The idea in one sentence

A Live Activity is a widget-like view of **one event in progress** that your app starts, updates and ends explicitly, with data small enough to fit in a push notification, for a few hours at most.

> [!note] Sources and what was checked
> Limits and behavior come from Apple's ActivityKit documentation, read in November 2026: "Displaying live data with Live Activities", "Starting and updating Live Activities with ActivityKit push notifications", `Activity`, `ActivityAttributes`, `ActivityContent`, `ActivityState`, `ActivityUIDismissalPolicy`, and WidgetKit's "Adding interactivity to widgets and Live Activities". Xcode steps are quoted from those pages and weren't performed; no Live Activity was run on a device or simulator. The ActivityKit and WidgetKit blocks are type-checked against the iOS SDK, not run. The size, lifecycle, dismissal and priority models are plain Swift, compiled and run with Swift 6.3.

## When a Live Activity is the right tool

Pantry has three ways to tell someone their groceries are coming:

| Tool | Good for | Pantry's use |
| --- | --- | --- |
| Widget (lesson 1) | Information that's always relevant, refreshed on a budget | "Next delivery: Thursday 10:00" |
| Notification (lesson 3) | A single moment that needs attention | "Your order was delivered" |
| Live Activity | One event with a start and an end, changing over minutes or hours | The courier is 3 stops away, arriving 11:10 to 11:40 |

A Live Activity fits when the person would otherwise keep opening the app to check progress, and when the event ends within hours. A grocery order from placing to delivery fits; "items on sale this week" doesn't.

Apple's description of where it appears: on the Lock Screen of iPhone and iPad and in StandBy, as a banner on devices without the Dynamic Island, in the Dynamic Island, and on a paired Apple Watch, CarPlay or the Mac's menu bar. "To add support for Live Activities to your app, you must support all presentations. The system automatically chooses the best presentation for each location."

## The limits

These are Apple's, from "Displaying live data with Live Activities":

- **Duration.** "A Live Activity can be active for up to eight hours unless its app or a person ends it before this limit. After the eight-hour limit, the system automatically ends the Live Activity, and immediately removes it from the Dynamic Island. However, the Live Activity remains on the Lock Screen until a person removes it or for up to four additional hours." So twelve hours on the Lock Screen at most.
- **Data size.** "Static and dynamic data for a Live Activity, including data for ActivityKit updates and ActivityKit push notifications, can't exceed a combined size of 4 KB."
- **No network or location.** "Each Live Activity runs in its own sandbox, and, unlike a widget, a Live Activity can't access the network or receive location updates." Updates come from the app or from push.
- **Images.** Assets must use "a resolution that's smaller or equal to the size of the presentation for a device," or the system "might fail to start the Live Activity."
- **Height.** "The system may truncate a Live Activity if its height exceeds 160 points" on the Lock Screen.
- **How many.** The number an app can run "may depend on a variety of factors," and starting can fail when the device "reached its limit of active and scheduled Live Activities." Apple gives no number, so handle the error.

## Static and dynamic data

`ActivityAttributes` splits the data in two: properties of the attributes type never change for the life of the activity; the nested `ContentState` is what each update replaces.

```swift ios
import ActivityKit
import Foundation

struct DeliveryAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
        var arrival: ClosedRange<Date>
        var stopsAway: Int
    }

    var orderNumber: String
    var itemCount: Int
}
```

- **The order number and item count are static**: they're fixed once the order is placed.
- **Status, arrival window and stops are dynamic.** `ClosedRange<Date>` lets the view count down with `Text(timerInterval:countsDown:)` without any update, the same trick as widgets' dynamic dates.
- `ContentState` must be `Codable` and `Hashable`: the system encodes it to move it between your app, the extension and APNs.

### Staying inside 4 KB

Everything that crosses into the Live Activity is encoded, and the limit applies to attributes plus state together. A JSON model of Pantry's types, with integers standing in for dates (a `Date` encodes as a number with the default strategy anyway), shows where the bytes go:

```swift
import Foundation

struct DeliveryAttributes: Codable {
    var orderNumber: String
    var storeName: String
    var itemCount: Int
}

struct DeliveryState: Codable, Hashable {
    var status: String
    var arrivalStart: Int
    var arrivalEnd: Int
    var stopsAway: Int
}

func encodedSize<T: Encodable>(_ value: T) throws -> Int {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    return try encoder.encode(value).count
}

let limit = 4_096
let attributes = DeliveryAttributes(orderNumber: "1042", storeName: "Pantry Market Street", itemCount: 23)
let state = DeliveryState(status: "On the way", arrivalStart: 815_000_000, arrivalEnd: 815_001_800, stopsAway: 3)
let total = try encodedSize(attributes) + encodedSize(state)
print("attributes:", try encodedSize(attributes), "bytes")
print("state:", try encodedSize(state), "bytes")
print("total:", total, "of", limit, total <= limit ? "fits" : "too big")

// A teammate wants the item names in the state "so the expanded view can list them".
struct HeavyState: Codable, Hashable {
    var base: DeliveryState
    var itemNames: [String]
}
let names = (1...23).map { "Organic product number \($0), family size" }
let heavy = try encodedSize(attributes) + encodedSize(HeavyState(base: state, itemNames: names))
print("with item names:", heavy, heavy <= limit ? "fits" : "too big")
let names200 = (1...200).map { "Organic product number \($0), family size" }
let heavier = try encodedSize(attributes) + encodedSize(HeavyState(base: state, itemNames: names200))
print("with 200 item names:", heavier, heavier <= limit ? "fits" : "too big")
```

```output
attributes: 72 bytes
state: 85 bytes
total: 157 of 4096 fits
with item names: 1114 fits
with 200 item names: 8472 too big
```

- **The real data is 157 bytes.** That's the normal case: a status, a time window, a count.
- **Item names fit for this order and fail for a large one.** A design that works in testing with small orders breaks for the customer doing a monthly shop. Apple doesn't say exactly how it counts the 4 KB, so this check treats it as 4,096 bytes of JSON, and the real encoding may differ; leave a wide margin.
- **What doesn't belong in the state**: lists, images, HTML, anything that grows with the order. The expanded view shows "23 items", and tapping opens the app for the list.

## The presentations

The UI lives in the widget extension. When you add the extension, Apple says to select "Include Live Activity"; and the app's Info.plist needs `NSSupportsLiveActivities` set to YES (both steps quoted, not performed). An `ActivityConfiguration` provides the Lock Screen view and a `DynamicIsland`:

```swift ios
import ActivityKit
import SwiftUI
import WidgetKit

struct DeliveryAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
        var arrival: ClosedRange<Date>
        var stopsAway: Int
    }

    var orderNumber: String
    var itemCount: Int
}

struct DeliveryLockScreenView: View {
    let context: ActivityViewContext<DeliveryAttributes>

    var body: some View {
        VStack(alignment: .leading) {
            Text("Order \(context.attributes.orderNumber)")
                .font(.headline)
            Text(context.state.status)
            if context.isStale {
                Text("Waiting for an update")
                    .font(.caption)
            }
        }
        .padding()
    }
}

struct DeliveryLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DeliveryAttributes.self) { (context: ActivityViewContext<DeliveryAttributes>) in
            DeliveryLockScreenView(context: context)
        } dynamicIsland: { (context: ActivityViewContext<DeliveryAttributes>) in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "bag")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.arrival, countsDown: true)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.status)
                }
            } compactLeading: {
                Image(systemName: "bag")
            } compactTrailing: {
                Text(timerInterval: context.state.arrival, countsDown: true)
                    .frame(width: 44)
            } minimal: {
                Image(systemName: "bag")
            }
        }
    }
}
```

- **Lock Screen**: the first closure. It also serves as the banner on devices without a Dynamic Island, and it's scaled up in StandBy.
- **Compact** (`compactLeading` and `compactTrailing`): used when this is the only Live Activity. The two views sit on either side of the camera and "form a cohesive view," so the bag icon and the countdown read as one thing. A tap opens the app.
- **Minimal**: when several apps have Live Activities, yours may be reduced to one small view, attached to or detached from the island.
- **Expanded**: on touch and hold, and "briefly for Live Activity updates." Regions are `.leading`, `.trailing`, `.center` and `.bottom`.
- **`context.isStale`** turns true at the `staleDate` you pass with the content. Showing it is how the activity admits its data is old.

Apple's layout details worth remembering: when the island is narrow (two activities on some iPhones, landscape), fit the compact view "inside a circle that's 28 points in diameter" and check `isDynamicIslandLimitedInWidth`; the system ignores your animation modifiers and uses its own timing; and on Always-On displays it doesn't animate at all.

## Starting, updating and ending

The app drives the lifecycle. From `Activity`'s documentation: "You can update or end a Live Activity while your app is in the background, but you can only start a Live Activity while the app is in the foreground, unless you adopt AppIntents and start the Live Activity using a `LiveActivityIntent`."

```swift ios
import ActivityKit
import Foundation

struct DeliveryAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
        var arrival: ClosedRange<Date>
        var stopsAway: Int
    }

    var orderNumber: String
    var itemCount: Int
}

enum DeliveryActivityError: Error {
    case disabled
}

/// Call while the app is in the foreground, right after the order is placed.
func startDeliveryActivity(order: String, items: Int, arrival: ClosedRange<Date>) throws -> Activity<DeliveryAttributes> {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw DeliveryActivityError.disabled }
    let attributes = DeliveryAttributes(orderNumber: order, itemCount: items)
    let state = DeliveryAttributes.ContentState(status: "Order placed", arrival: arrival, stopsAway: 0)
    let content = ActivityContent(state: state, staleDate: arrival.upperBound.addingTimeInterval(15 * 60))
    return try Activity.request(attributes: attributes, content: content, pushType: .token)
}

func updateDelivery(_ activity: Activity<DeliveryAttributes>, to state: DeliveryAttributes.ContentState, alert: Bool) async {
    let content = ActivityContent(state: state, staleDate: state.arrival.upperBound.addingTimeInterval(15 * 60))
    if alert {
        let config = AlertConfiguration(title: "Delivery update", body: "\(state.status)", sound: .default)
        await activity.update(content, alertConfiguration: config)
    } else {
        await activity.update(content)
    }
}

func endDelivery(_ activity: Activity<DeliveryAttributes>, finalStatus: String) async {
    var state = activity.content.state
    state.status = finalStatus
    let content = ActivityContent(state: state, staleDate: nil)
    await activity.end(content, dismissalPolicy: .after(.now.addingTimeInterval(60 * 60)))
}
```

- **`areActivitiesEnabled`** first: people can turn Live Activities off per app in Settings. If it's false, don't show a "Track on Lock Screen" button at all. The `activityEnablementUpdates` stream reports changes.
- **`request(attributes:content:pushType:)`** throws: the device may be at its limit, or the image assets too large. Catch it and carry on; the order still exists without a Live Activity.
- **`staleDate`**: if no update arrives by then, the state becomes `.stale` and the view's `isStale` turns true. Pantry sets it 15 minutes past the end of the arrival window and pushes it forward with every update.
- **`relevanceScore`** (not used here) decides which of your own activities takes the Dynamic Island when you run several: highest wins; equal scores mean the first started.
- **Alerts** are for important updates. On iPhone the system doesn't show a regular alert; it shows the expanded presentation, or the Lock Screen view as a banner on devices without a Dynamic Island.
- **End with the final state.** Apple: "Always include an updated `ContentState` to ensure the Live Activity shows the latest and final content update after it ends," because it can stay on the Lock Screen for hours.

`ActivityState` tracks where an activity is: `.pending` (scheduled, iOS 26), `.active`, `.stale`, `.ended` and `.dismissed` (the person or system removed it). A person removing it from the Lock Screen ends the activity but, as Apple puts it about a pizza, "this doesn't cancel the pizza order." Pantry's order logic must never depend on the activity existing.

### From order events to commands

Pantry's backend reports events for an order. The app turns them into ActivityKit calls, and the rules are easier to get right as a value type than spread across callbacks:

```swift
enum OrderEvent {
    case placed
    case packed
    case outForDelivery(eta: String)
    case delayed(eta: String)
    case delivered
    case canceled
}

enum Command: CustomStringConvertible {
    case start(String)
    case update(String, alert: Bool)
    case end(String, dismissal: String)
    case ignore(String)

    var description: String {
        switch self {
        case .start(let status): "start: \(status)"
        case .update(let status, let alert): "update: \(status)" + (alert ? " (alert)" : "")
        case .end(let status, let dismissal): "end: \(status), dismissal \(dismissal)"
        case .ignore(let reason): "ignore: \(reason)"
        }
    }
}

struct DeliveryActivityTracker {
    private var startedAt: Int?
    private var ended = false
    let maximumMinutes = 8 * 60          // Apple: active for up to eight hours

    mutating func handle(_ event: OrderEvent, at minute: Int, appInForeground: Bool) -> Command {
        if ended { return .ignore("already ended") }
        if let start = startedAt, minute - start >= maximumMinutes {
            ended = true
            return .ignore("system ended it after 8 hours")
        }
        switch event {
        case .placed:
            guard startedAt == nil else { return .ignore("already running") }
            guard appInForeground else { return .ignore("the app is in the background") }
            startedAt = minute
            return .start("Order placed")
        case .packed:
            return .update("Packed", alert: false)
        case .outForDelivery(let eta):
            return .update("On the way, arrives \(eta)", alert: true)
        case .delayed(let eta):
            return .update("Delayed, now \(eta)", alert: true)
        case .delivered:
            ended = true
            return .end("Delivered", dismissal: "default")
        case .canceled:
            ended = true
            return .end("Canceled", dismissal: "immediate")
        }
    }
}

func run(_ events: [(Int, OrderEvent, Bool)]) {
    var tracker = DeliveryActivityTracker()
    for (minute, event, foreground) in events {
        print(minute, tracker.handle(event, at: minute, appInForeground: foreground))
    }
}

run([
    (0, .placed, true),
    (25, .packed, false),
    (40, .outForDelivery(eta: "11:10"), false),
    (55, .delayed(eta: "11:30"), false),
    (90, .delivered, false),
    (95, .packed, false),
])
print("--")
run([
    (0, .placed, false),
    (10, .placed, true),
    (500, .outForDelivery(eta: "18:30"), false),
])
```

```output
0 start: Order placed
25 update: Packed
40 update: On the way, arrives 11:10 (alert)
55 update: Delayed, now 11:30 (alert)
90 end: Delivered, dismissal default
95 ignore: already ended
--
0 ignore: the app is in the background
10 start: Order placed
500 ignore: system ended it after 8 hours
```

- **Alerts only for what the person must notice**: the courier leaving and a delay. "Packed" updates silently.
- **Delivered ends with `.default`**, so "Delivered" stays on the Lock Screen for a while; **canceled ends with `.immediate`**, because there's nothing left to glance at.
- **A late event after the end is ignored.** Push and app updates can arrive out of order; Apple notes the system ignores ActivityKit pushes that arrive after the activity ends. The `timestamp` in push payloads exists for the same reason.
- **A placed order with the app in the background can't start an activity.** In the second run the order was placed from a widget button while the app was suspended, so the activity starts only when the app comes to the foreground. (A `LiveActivityIntent` would have allowed starting it from the intent.)
- **After eight hours** the system has already ended the activity. Same-day groceries rarely hit that, but a scheduled order placed in the morning for an evening slot would. Start the activity when the delivery is near, not when the order is placed.

When the app launches, Apple suggests checking `Activity<DeliveryAttributes>.activities` and ending "any Live Activity that's no longer relevant," for example after a crash left one running.

## Updating by push

The app isn't running for most of a delivery, so Pantry's server sends updates directly. From "Starting and updating Live Activities with ActivityKit push notifications":

1. Add the Push Notifications capability. You don't register with UserNotifications for this: ActivityKit gives you the token.
2. Request the activity with `pushType: .token`. The token isn't available right away: observe `pushTokenUpdates`, send each token to your server, and invalidate the old one, because "the push token for a Live Activity may change throughout its duration."
3. The server sends to APNs with `apns-push-type: liveactivity`, `apns-topic: <your bundle ID>.push-type.liveactivity`, and `apns-priority` 5 or 10.

```swift ios
import ActivityKit
import Foundation

struct DeliveryAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
        var arrival: ClosedRange<Date>
        var stopsAway: Int
    }

    var orderNumber: String
    var itemCount: Int
}

func forwardPushTokens(for activity: Activity<DeliveryAttributes>) async {
    for await token in activity.pushTokenUpdates {
        let hex = token.map { String(format: "%02x", $0) }.joined()
        await registerToken(hex, order: activity.attributes.orderNumber)
    }
}

/// Sends the token to Pantry's server, replacing the previous one for this order.
func registerToken(_ token: String, order: String) async {
    // POST to the server.
}
```

An update payload looks like this (values invented, structure from Apple's example):

```json
{
  "aps": {
    "timestamp": 1793000000,
    "event": "update",
    "content-state": {
      "status": "3 stops away",
      "arrival": [815000000, 815001800],
      "stopsAway": 3
    },
    "stale-date": 1793002700
  }
}
```

- **`content-state` must decode into your `ContentState`** with the default strategies. Apple: "don't use any custom JSON encoding strategies to encode your data." Keys match property names, and a `Date` inside the state decodes with `Date`'s default `Codable` form, a number of seconds since January 1, 2001, not a Unix timestamp. The `arrival` array assumes `ClosedRange` encodes as `[lower, upper]`, which is how the standard library's `Codable` conformance encodes it; check your server's output against what the app's own encoder produces.
- **`timestamp`, `stale-date` and `dismissal-date`** in `aps` are seconds since 1970.
- **`event`** is `update`, `end` (include the final state) or `start`.
- **Push-to-start** (iOS 17.2 and later) uses a separate token from `Activity<DeliveryAttributes>.pushToStartTokenUpdates`; the start payload needs `attributes-type`, `attributes` and an `alert` "to make sure the system notifies a person about the newly started Live Activity."
- **Broadcast channels** (iOS 18) update many devices following the same event, such as a sports game. Pantry's deliveries are one-to-one, so tokens fit.

### The update budget

Apple: "The system allows for a certain budget of ActivityKit push notifications per hour." Priority 10, the default, is delivered immediately and counts toward it; "if you exceed the budget, the system may throttle your ActivityKit push notifications." Priority 5 doesn't count, and Apple suggests considering it first. Apps that need many updates a minute (a basketball game) add `NSSupportsLiveActivitiesFrequentUpdates` to the Info.plist, and people can turn frequent updates off in Settings (`frequentPushesEnabled` tells you). Apple doesn't publish the budget's size, so Pantry's server caps its own priority-10 pushes; the solve exercise builds that rule.

Apple also points out that a push may never arrive, for example without network coverage, so "update your Live Activity from your app in addition to push notifications" whenever the app gets the chance.

## Common mistakes

> [!error] Putting lists or images in ContentState
> The 4 KB limit covers attributes and state together, including pushes. A list that grows with the order works in testing and fails for big orders. Keep counts and short strings in the state; ship images in the extension's assets.

> [!error] Trying to start from the background
> `Activity.request` from a background task or a push handler fails. Start in the foreground, from a `LiveActivityIntent`, or by push-to-start.

> [!error] Ending without final content
> `end(nil, ...)` leaves the last update on the Lock Screen, maybe "3 stops away", for hours after the delivery. Pass the final state.

> [!error] Every push at priority 10
> High priority counts toward an hourly budget and can get throttled exactly when the important update comes. Use 5 for routine progress, 10 for what needs attention.

> [!error] Custom date encoding on the server
> The system decodes `content-state` with default strategies. An ISO 8601 string where the app's `ContentState` has a `Date` fails to decode, and the update is lost.

> [!error] Tying the order to the activity
> People can remove the Live Activity at any time, and the system ends it after eight hours. The order's state lives in the app and server; the activity only displays it.

## Exercises

````exercise
id: m44-l02-e1
type: prediction
prompt: "A model of when an ended Live Activity leaves the Lock Screen, in minutes. `requested` is nil for the default policy. What does it print?"
code: |
  func removalMinute(endedAt: Int, requested: Int?) -> Int {
      let systemLimit = endedAt + 4 * 60
      guard let requested else { return systemLimit }     // .default
      return min(max(requested, endedAt), systemLimit)
  }

  print(removalMinute(endedAt: 600, requested: nil))
  print(removalMinute(endedAt: 600, requested: 660))
  print(removalMinute(endedAt: 600, requested: 1_200))
  print(removalMinute(endedAt: 600, requested: 0))
output: |
  840
  660
  840
  600
hints:
  - "Four hours is 240 minutes."
  - "A date in the past is clamped to the end time: that's an immediate removal."
solution: |
  ```output
  840
  660
  840
  600
  ```

  - **Default:** up to four hours after the end, 600 + 240 = 840 (the person can remove it sooner).
  - **After 660:** inside the four-hour window, so it's used.
  - **After 1,200:** Apple says the system removes it "after the given date or after four hours from the moment the Live Activity ends — whichever comes first," so 840.
  - **A date in the past** behaves like `.immediate`. Apple's push documentation uses exactly that: a past `dismissal-date` dismisses it right away.
````

````exercise
id: m44-l02-e2
type: comprehension
prompt: "Pantry's courier app wants the customer's Live Activity to show the courier's position on a small map, refreshed every 10 seconds by the Live Activity itself. What's wrong with that plan?"
choices:
  - text: "A Live Activity can't access the network or receive location updates; all data must come from the app or ActivityKit pushes."
    correct: true
    why: "Apple says so directly, and pushes every 10 seconds would also need frequent-updates support and a budget plan."
  - text: "Live Activities can't show images."
    correct: false
    why: "They can, from the extension's assets, within size limits."
  - text: "Live Activities only last one hour."
    correct: false
    why: "Up to eight hours active, twelve on the Lock Screen."
  - text: "Nothing; a Live Activity is a widget and can fetch data in its timeline."
    correct: false
    why: "Live Activities don't use timelines, and unlike widgets they can't use the network."
solution: |
  The Live Activity runs sandboxed without network or location. Any change has to arrive as a new `ContentState`, from the app (which is usually suspended during a delivery) or from the server by push. A position every 10 seconds means many pushes: priority 5 for most, `NSSupportsLiveActivitiesFrequentUpdates` if that's truly needed, and a fallback when the person turns frequent updates off. "3 stops away" with a countdown is usually what people want anyway.
````

````exercise
id: m44-l02-e3
type: fill-in
prompt: "Complete Pantry's start and end calls."
code: |
  guard ActivityAuthorizationInfo().[[1]] else { return }
  let content = ActivityContent(state: initialState, [[2]]: windowEnd.addingTimeInterval(15 * 60))
  let activity = try Activity.request(attributes: attributes, content: content, pushType: [[3]])

  // Later, when the order is delivered:
  await activity.end(ActivityContent(state: deliveredState, staleDate: nil), dismissalPolicy: [[4]])
blanks:
  - id: "1"
    answers: ["areActivitiesEnabled"]
  - id: "2"
    answers: ["staleDate"]
  - id: "3"
    answers: [".token"]
  - id: "4"
    answers: [".default"]
solution: |
  - `areActivitiesEnabled`: the person may have turned Live Activities off for Pantry.
  - `staleDate`: when the content should be considered outdated if no update arrives.
  - `.token`: ask for a push token so the server can update the activity.
  - `.default`: "Delivered" stays on the Lock Screen for up to four hours. `.immediate` fits a canceled order.
````

````exercise
id: m44-l02-e4
type: find-errors
prompt: "A review of Pantry's first Live Activity code. Mark every real problem."
code: |
  struct DeliveryAttributes: ActivityAttributes {
      struct ContentState: Codable, Hashable {
          var status: String
          var items: [CartItem]          // name, price and thumbnail Data for each item
      }
      var orderNumber: String
  }

  // In the push handler, when the server says the courier left:
  func didReceiveCourierLeft(order: String) throws {
      _ = try Activity.request(attributes: DeliveryAttributes(orderNumber: order),
                               content: .init(state: state, staleDate: nil))
  }

  // When the order is delivered:
  await activity.end(nil, dismissalPolicy: .default)

  // Server: dates in content-state are ISO 8601 strings, every push at apns-priority 10.
choices:
  - text: "Items with thumbnail data in the state can exceed the 4 KB limit for attributes plus state."
    correct: true
  - text: "Starting the activity from a push handler runs in the background, where request isn't allowed."
    correct: true
  - text: "Ending with nil content leaves the last update showing on the Lock Screen."
    correct: true
  - text: "ISO 8601 strings won't decode with the default strategies the system uses."
    correct: true
  - text: "Sending every push at priority 10 counts each toward the hourly budget and risks throttling."
    correct: true
  - text: "ContentState must be a class so it can be updated."
    correct: false
    why: "It's a Codable, Hashable value; each update sends a new one."
rubric:
  - I flagged the oversized state.
  - I flagged the background start.
  - I flagged ending without final content.
  - I flagged the date encoding and the priority.
solution: |
  - **State size:** keep `itemCount` and a short status; the list stays in the app.
  - **Background start:** start when the order is placed and the app is in front, use push-to-start (iOS 17.2+), or a `LiveActivityIntent`.
  - **End:** pass the final state, "Delivered at 11:24".
  - **Server:** encode `content-state` exactly as the app's default `JSONEncoder` would, and use priority 5 for routine progress, 10 for "courier left" and "delayed".
````

````exercise
id: m44-l02-e5
type: solve
prompt: |
  Apple doesn't publish the size of the hourly push budget, so Pantry's server caps itself. Write `priorities(for:maxHighPerHour:)`: for each update, in order, return 10 if it needs attention and fewer than `maxHighPerHour` priority-10 pushes were sent in the previous 60 minutes (an earlier push at minute `m` counts while `update.minute - m < 60`); otherwise return 5.

  Expected output:

  ```output
  0 Packed 5
  10 On the way 10
  15 5 stops away 5
  20 Delayed 10
  30 Delayed again 5
  50 1 stop away 5
  75 Delivered 10
  ```
starter: |
  struct Update {
      let minute: Int
      let status: String
      let needsAttention: Bool
  }

  func priorities(for updates: [Update], maxHighPerHour: Int) -> [Int] {
      // your code
      return []
  }

  let updates = [
      Update(minute: 0, status: "Packed", needsAttention: false),
      Update(minute: 10, status: "On the way", needsAttention: true),
      Update(minute: 15, status: "5 stops away", needsAttention: false),
      Update(minute: 20, status: "Delayed", needsAttention: true),
      Update(minute: 30, status: "Delayed again", needsAttention: true),
      Update(minute: 50, status: "1 stop away", needsAttention: true),
      Update(minute: 75, status: "Delivered", needsAttention: true),
  ]
  for (update, priority) in zip(updates, priorities(for: updates, maxHighPerHour: 2)) {
      print(update.minute, update.status, priority)
  }
hints:
  - "Keep the minutes of the priority-10 pushes you've already chosen."
  - "At minute 75, the push at 10 is 65 minutes old and no longer counts."
rubric:
  - Routine updates always get 5.
  - Counts only priority-10 pushes inside the trailing 60 minutes.
  - Downgrades to 5 instead of dropping the update.
solution: |
  ```swift
  struct Update {
      let minute: Int
      let status: String
      let needsAttention: Bool
  }

  func priorities(for updates: [Update], maxHighPerHour: Int) -> [Int] {
      var highMinutes: [Int] = []
      var result: [Int] = []
      for update in updates {
          let recentHigh = highMinutes.filter { update.minute - $0 < 60 }.count
          if update.needsAttention && recentHigh < maxHighPerHour {
              highMinutes.append(update.minute)
              result.append(10)
          } else {
              result.append(5)
          }
      }
      return result
  }

  let updates = [
      Update(minute: 0, status: "Packed", needsAttention: false),
      Update(minute: 10, status: "On the way", needsAttention: true),
      Update(minute: 15, status: "5 stops away", needsAttention: false),
      Update(minute: 20, status: "Delayed", needsAttention: true),
      Update(minute: 30, status: "Delayed again", needsAttention: true),
      Update(minute: 50, status: "1 stop away", needsAttention: true),
      Update(minute: 75, status: "Delivered", needsAttention: true),
  ]
  for (update, priority) in zip(updates, priorities(for: updates, maxHighPerHour: 2)) {
      print(update.minute, update.status, priority)
  }
  ```

  ```output
  0 Packed 5
  10 On the way 10
  15 5 stops away 5
  20 Delayed 10
  30 Delayed again 5
  50 1 stop away 5
  75 Delivered 10
  ```

  "Delayed again" and "1 stop away" still go out, at priority 5, which doesn't count toward Apple's budget; they may arrive a little later. By minute 75 the push at minute 10 has aged out, so "Delivered" goes at 10. The cap of 2 per hour is Pantry's choice, not an Apple number.
````

````exercise
id: m44-l02-e6
type: design
prompt: "Pantry adds scheduled deliveries: a customer orders at 08:00 for a 18:00 to 19:00 slot. Product wants a Live Activity \"from the moment you order until the groceries arrive.\" Design when the activity starts, what's in its attributes and state, how it's updated, and how it ends. Use Apple's limits."
rubric:
  - Notices that 08:00 to 19:00 exceeds the eight-hour limit and moves the start closer to the delivery.
  - Keeps attributes and state small, with an arrival range for countdowns and a stale date.
  - Uses pushes (with a token or push-to-start) because the app won't be running, and plans priorities.
  - Ends with final content and an appropriate dismissal policy, and handles cancellation and a removed activity.
solution: |
  - **Start:** not at 08:00. From 08:00 to the end of the slot is eleven hours, and the system ends an activity after eight. Start it when the order is packed or the courier is assigned, around 17:00. The app may not be open then, so use push-to-start (iOS 17.2+) with a start payload that includes an alert, or a notification at 17:00 that opens the app, which starts it in the foreground. Until then, the widget from lesson 1 shows "Today 18:00 to 19:00".
  - **Data:** attributes `orderNumber`, `itemCount`; state `status`, `arrival: ClosedRange<Date>`, `stopsAway`. Far below 4 KB. `staleDate` 15 minutes past the window's end, advanced with each update.
  - **Updates:** server pushes with the activity's token; priority 5 for "4 stops away", 10 for "courier left" and "delayed", with Pantry's own cap. The app also updates whenever it runs.
  - **End:** "Delivered at 18:41" with `.default`; "Canceled" with `.immediate`. If the person removed the activity, nothing about the order changes, and the server stops pushing when APNs reports the token invalid.
````

## Summary

- A Live Activity shows one event in progress on the Lock Screen and in the Dynamic Island. Its UI lives in the widget extension; ActivityKit manages its life. You must support Lock Screen, compact, minimal and expanded presentations.
- Apple's limits: active up to eight hours, on the Lock Screen up to twelve; attributes plus state, including pushes, at most 4 KB; no network or location inside the activity; truncation above 160 points.
- `ActivityAttributes` holds static data; its `ContentState` holds what changes. Use a date range for countdowns, a `staleDate` to flag old data, and `relevanceScore` to rank several activities.
- Start in the foreground (or with a `LiveActivityIntent` or push-to-start), update and end from anywhere in the app, and always end with final content. `.default` keeps it up to four hours, `.immediate` removes it, `.after(date)` is capped at four hours.
- ActivityKit pushes use `apns-push-type: liveactivity` and the `.push-type.liveactivity` topic, default-decoded `content-state`, and an hourly budget for priority 10. Priority 5 doesn't count. Observe `pushTokenUpdates`, because tokens change.
- The order's state lives in the app and server. Model event-to-command rules as a value type and test them, including late events and the eight-hour limit.

---
id: m44-l03
title: Notifications
description: "Notifications are the one feature where a bad first impression is permanent: the system asks for permission once. You learn when and how to ask, how provisional authorization lets people try notifications before deciding, how to schedule local notifications with time and calendar triggers and keep them in sync, how categories and actions let people respond without opening the app, and how to route those responses. Then remote notifications at a high level: APNs, device tokens, payload limits, background pushes, and a Notification Service Extension that edits a push before it's shown."
module: m44
order: 3
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m44-l02, m21-l04]
objectives:
  - Ask for notification permission in context, use provisional authorization, and check settings before scheduling.
  - Schedule, replace and cancel local notifications with calendar and time-interval triggers.
  - Keep notifications out of quiet hours and keep pending requests in sync with app data.
  - Declare categories and actions at launch and handle responses in a UNUserNotificationCenterDelegate.
  - Describe how remote notifications reach the device, the payload limits, and what background pushes can and can't do.
  - Explain what a Notification Service Extension can change and its time limit.
terms:
  - term: Provisional authorization
    definition: "Requested with the .provisional option. No prompt appears; the app is authorized right away to deliver notifications quietly to Notification Center, where each one offers Keep and Turn Off buttons."
  - term: Notification request
    definition: "UNNotificationRequest: an identifier, content (UNMutableNotificationContent) and a trigger. Adding a request with an existing identifier replaces the pending one."
  - term: Trigger
    definition: "The delivery condition for a local notification: UNTimeIntervalNotificationTrigger (after a number of seconds), UNCalendarNotificationTrigger (matching date components) or UNLocationNotificationTrigger. No trigger means deliver now."
  - term: Notification category
    definition: "UNNotificationCategory: an identifier and the actions (buttons) for one type of notification. Registered at launch; the notification's categoryIdentifier (or the aps category key) selects it."
  - term: Device token
    definition: "The address APNs uses to reach one app on one device. The app gets it on every launch after registerForRemoteNotifications() and forwards it to its server; it changes after restores, reinstalls and new devices."
  - term: Notification Service Extension
    definition: "An app extension that receives a remote notification with mutable-content set to 1 before it's displayed, and has about 30 seconds to modify its content, for example to decrypt it or attach media."
mastery:
  - Decide, from the authorization status and the moment in the app, whether to ask, ask provisionally, schedule, or point to Settings.
  - Write the request for a calendar-triggered reminder with a stable identifier, and cancel it.
  - Move a notification out of quiet hours that wrap past midnight.
  - Compute which pending requests to remove and which to add when the app's data changes.
  - Register a category with actions and route each response to the right app action.
  - Write a remote payload that uses a category, a thread and mutable-content, and say what the service extension must do in time.
resources: [usernotifications-asking-permission, usernotifications-scheduling-local, usernotifications-actionable, requesting-protected-resources, hig, app-review-guidelines, foundation-notificationcenter]
cards:
  - id: m44-l03-c1
    front: When should an app request notification permission?
    back: "In context, after the person does something that shows why notifications help (Apple's example: after scheduling a first task), not at first launch. The system prompts only the first time; later requests return the recorded answer. Provisional authorization is the exception that can be requested at launch."
  - id: m44-l03-c2
    front: What does provisional authorization give you?
    back: "No prompt. Notifications are delivered quietly to Notification Center history only (no sound, banner or Lock Screen), with Keep and Turn Off buttons. Status is .provisional until the person chooses."
  - id: m44-l03-c3
    front: How do you change or cancel a scheduled local notification?
    back: "Add a new request with the same identifier to replace it; call removePendingNotificationRequests(withIdentifiers:) to cancel. Use stable identifiers derived from app data (slot-1042), not random UUIDs."
  - id: m44-l03-c4
    front: Where must you set the UNUserNotificationCenter delegate, and why?
    back: "Before the app finishes launching (application(_:willFinishLaunchingWithOptions:) or didFinishLaunching). A delegate set later can miss the response that launched the app."
  - id: m44-l03-c5
    front: Limits for remote notifications?
    back: "Payload 4 KB (VoIP 5 KB). Background pushes (content-available 1) are low priority, may be throttled, and Apple says not to send more than two or three per hour; the app gets up to 30 seconds. A service extension has about 30 seconds to modify content."
---

## The idea in one sentence

A notification interrupts someone who isn't using your app, so **you earn the right to send them** by asking at the moment the value is obvious, sending only what the person asked for, and letting them act without opening the app.

> [!note] Sources and what was checked
> Behavior and limits come from Apple's UserNotifications documentation, read in November 2026: "Asking permission to use notifications", "Scheduling a notification locally from your app", "Declaring your actionable notification types", "Handling notifications and notification-related actions", "Registering your app with APNs", "Generating a remote notification", "Sending notification requests to APNs", "Pushing background updates to your app", "Modifying content in newly delivered notifications", and the pages for `UNNotificationRequest`, the triggers and `UNUserNotificationCenterDelegate`. Xcode steps are quoted, not performed, and no notification was delivered to a device for this lesson. The UserNotifications and UIKit blocks are type-checked against the iOS SDK, not run. The permission, quiet-hours, sync and routing models are plain Swift, compiled and run with Swift 6.3.

## Asking for permission

Module 21 covered protected resources: check the status, ask when the feature is used, handle every answer. Notifications follow the same pattern with two differences: there's no purpose string, and there's a gentler option.

Apple: "The first time your app makes this authorization request, the system prompts the person to grant or deny the request and records that response. Subsequent authorization requests don't prompt the person." One prompt, ever (until the person changes it in Settings). And on timing: "Make the request in a context that helps people understand why your app needs authorization. In a task-tracking app that sends reminder notifications, you might make the request after the person schedules a first task."

### Provisional authorization

With `.provisional` in the options, "this code doesn't prompt the person for permission." The app is authorized immediately, but quietly: provisional notifications "don't interrupt the person with a sound or banner, or appear on the lock screen. Instead, they only appear in the notification center's history," with **Keep** and **Turn Off** buttons. Keep leads to "Deliver Immediately" (still quiet: no alerts, sounds or badges) or "Deliver in Scheduled Summary." Because there's no prompt, Apple says "you can request authorization when your app first launches."

### Pantry's plan

- **First launch:** ask provisionally. Delivery updates appear quietly in Notification Center, and the person sees what Pantry sends before deciding.
- **First order placed:** the order screen says "We'll let you know when your groceries are on the way," with a button that triggers the real request. That's the explained, in-context ask.
- **Restock reminders turned on:** the person explicitly asked for interruptions, so a provisional status isn't enough; ask for full authorization.
- **Denied:** never nag. If the person turns on a feature that needs notifications, explain and link to Settings (Module 21's pattern).

As a function, so the rules live in one tested place:

```swift
enum AuthorizationStatus {
    case notDetermined, denied, authorized, provisional
}

enum Moment {
    case firstLaunch
    case placedFirstOrder          // "We'll tell you when it's on the way"
    case turnedOnRestockReminders  // the person asked for reminders
    case openedSettingsScreen
}

enum PermissionStep: Equatable {
    case nothing
    case askProvisionally
    case explainThenAsk            // the app's own screen, then the system prompt
    case schedule
    case offerSettingsLink
}

func step(for status: AuthorizationStatus, at moment: Moment) -> PermissionStep {
    switch (status, moment) {
    case (.notDetermined, .firstLaunch):
        return .askProvisionally                      // no prompt; quiet trial delivery
    case (.notDetermined, .placedFirstOrder), (.notDetermined, .turnedOnRestockReminders),
         (.provisional, .turnedOnRestockReminders):
        return .explainThenAsk
    case (.authorized, .placedFirstOrder), (.authorized, .turnedOnRestockReminders),
         (.provisional, .placedFirstOrder):
        return .schedule
    case (.denied, .turnedOnRestockReminders), (.denied, .openedSettingsScreen):
        return .offerSettingsLink
    default:
        return .nothing
    }
}

let cases: [(AuthorizationStatus, Moment)] = [
    (.notDetermined, .firstLaunch),
    (.provisional, .placedFirstOrder),
    (.provisional, .turnedOnRestockReminders),
    (.notDetermined, .placedFirstOrder),
    (.denied, .placedFirstOrder),
    (.denied, .turnedOnRestockReminders),
    (.authorized, .firstLaunch),
]
for (status, moment) in cases {
    print(status, moment, "→", step(for: status, at: moment))
}
```

```output
notDetermined firstLaunch → askProvisionally
provisional placedFirstOrder → schedule
provisional turnedOnRestockReminders → explainThenAsk
notDetermined placedFirstOrder → explainThenAsk
denied placedFirstOrder → nothing
denied turnedOnRestockReminders → offerSettingsLink
authorized firstLaunch → nothing
```

- **Provisional is enough for delivery updates** (they're useful even quietly) **but not for reminders**, which only work if they interrupt. Asking for full authorization from `.provisional` does show the prompt, because the person hasn't answered yet.
- **Denied and placing an order does nothing.** Interrupting a purchase to complain about settings is the nagging Apple's guidance warns against. The Settings link appears only when the person turns on a feature that can't work without notifications.
- `UNAuthorizationStatus` also has `.ephemeral` (App Clips). The real switch must handle it, and `@unknown default`.

The framework side is small:

```swift ios
import UserNotifications

enum NotificationPermission {
    /// At first launch: no prompt; notifications arrive quietly in Notification Center.
    static func requestProvisional() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge, .provisional])
    }

    /// Right after the person asks for something that needs notifications. Prompts only once.
    static func requestFull() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Check before every scheduling pass: people change settings at any time.
    static func canSchedule() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }
}
```

Apple: "Always check your app's authorization status before scheduling local notifications," and the settings also say which interactions are allowed (`alertSetting`, `soundSetting`, `badgeSetting`), so you can adapt. Specify every interaction type you'll use in the request ("Specify all of the interaction types that your app employs"): a badge you didn't ask for won't appear.

## Local notifications

A local notification is a request the app hands to the system: content, a trigger, and an identifier. The system delivers it at the right time even if the app isn't running. Apple: "Always use local notifications to convey important information that the user wants."

```swift ios
import Foundation
import UserNotifications

/// One reminder per order. The identifier comes from the order, so rescheduling replaces it.
func scheduleSlotReminder(orderID: String, remindAt: DateComponents) async throws {
    let content = UNMutableNotificationContent()
    content.title = "Delivery slot soon"
    content.body = "Your Pantry order arrives within the next hour."
    content.categoryIdentifier = "DELIVERY"
    content.threadIdentifier = "order-\(orderID)"
    content.userInfo = ["orderID": orderID]

    let trigger = UNCalendarNotificationTrigger(dateMatching: remindAt, repeats: false)
    let request = UNNotificationRequest(identifier: "slot-\(orderID)", content: content, trigger: trigger)
    try await UNUserNotificationCenter.current().add(request)
}

func cancelSlotReminder(orderID: String) {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["slot-\(orderID)"])
}

/// Every 7 days from now, for a product the person buys weekly.
func scheduleRestockReminder(productID: String, productName: String) async throws {
    let content = UNMutableNotificationContent()
    content.title = "Running low on \(productName)?"
    content.categoryIdentifier = "RESTOCK"
    content.userInfo = ["productID": productID]

    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 7 * 24 * 60 * 60, repeats: true)
    let request = UNNotificationRequest(identifier: "restock-\(productID)", content: content, trigger: trigger)
    try await UNUserNotificationCenter.current().add(request)
}
```

- **Identifiers are stable.** `UNNotificationRequest`'s documentation: "If you use the same identifier when scheduling a new notification, the system removes the previously scheduled notification with that identifier and replaces it with the new one." A random UUID, as in Apple's introductory sample, makes rescheduling create duplicates.
- **`UNCalendarNotificationTrigger`** fires when the date components match. Give a full date (year, month, day, hour, minute) for a one-time reminder; give only weekday and hour with `repeats: true` for "every Tuesday at 14:00".
- **`UNTimeIntervalNotificationTrigger`** fires after a number of seconds, which "must be greater than zero"; with `repeats: true` it "must be 60 seconds or greater." A repeating request keeps firing until you remove it.
- **`threadIdentifier`** groups notifications for the same order in Notification Center.
- **`userInfo`** carries the ids the response handler needs. Keep it to identifiers; the app looks up the rest.
- **`interruptionLevel`** (iOS 15) sets importance: `.passive` adds the notification "without lighting up the screen or playing a sound"; `.timeSensitive` can "break through system controls such as Notification Summary and Focus." Pantry's restock reminders are a good fit for `.passive`.

### Respecting quiet hours

Pantry lets people set quiet hours, by default 22:00 to 07:00. A reminder computed for 23:30 should wait until 07:00 the next day. The window wraps past midnight, which is where the bugs are:

```swift
struct QuietHours {
    let start: Int   // minutes since midnight, 22:00 = 1320
    let end: Int     // 07:00 = 420; may be earlier than start (wraps midnight)

    func contains(_ minuteOfDay: Int) -> Bool {
        start <= end
            ? (minuteOfDay >= start && minuteOfDay < end)
            : (minuteOfDay >= start || minuteOfDay < end)
    }
}

/// Moves a delivery time (minutes since the start of today) out of quiet hours.
func deliveryMinute(for requested: Int, quiet: QuietHours) -> Int {
    let day = 24 * 60
    let minuteOfDay = requested % day
    guard quiet.contains(minuteOfDay) else { return requested }
    let dayStart = requested - minuteOfDay
    // Before midnight in a wrapping window, the end is tomorrow.
    let endsTomorrow = quiet.start > quiet.end && minuteOfDay >= quiet.start
    return dayStart + quiet.end + (endsTomorrow ? day : 0)
}

func clock(_ minute: Int) -> String {
    let day = minute / (24 * 60), m = minute % (24 * 60)
    let text = (m / 60 < 10 ? "0" : "") + "\(m / 60):" + (m % 60 < 10 ? "0" : "") + "\(m % 60)"
    return day == 0 ? text : "\(text) (+\(day)d)"
}

let night = QuietHours(start: 22 * 60, end: 7 * 60)
for requested in [9 * 60, 21 * 60 + 59, 22 * 60, 23 * 60 + 30, 2 * 60, 7 * 60] {
    print(clock(requested), "→", clock(deliveryMinute(for: requested, quiet: night)))
}
let siesta = QuietHours(start: 14 * 60, end: 16 * 60)
print(clock(15 * 60), "→", clock(deliveryMinute(for: 15 * 60, quiet: siesta)))
```

```output
09:00 → 09:00
21:59 → 21:59
22:00 → 07:00 (+1d)
23:30 → 07:00 (+1d)
02:00 → 07:00
07:00 → 07:00
15:00 → 16:00
```

- **Start is inclusive, end is exclusive**: 22:00 is quiet, 07:00 isn't.
- **23:30 moves to tomorrow**, but **02:00 moves to today's 07:00**: it's already after midnight. That asymmetry is the bug that appears when the check is written as `minute >= 22:00 && minute < 07:00`, a condition that's never true.
- **A non-wrapping window** (14:00 to 16:00) uses the simple comparison.
- In the app, the result becomes `DateComponents` for a calendar trigger. This is for the app's own reminders; delivery updates the person is waiting for go out when they happen, and Focus modes let people silence them system-wide.

### Keeping requests in sync

Scheduled requests are copies of app data held by the system. When the data changes (an order is rescheduled, a product removed from restock reminders), the pending requests must follow. A function that compares what's pending with what should be pending keeps that logic testable; the solve exercise writes it.

## Categories and actions

Actionable notifications let people respond "without launching the corresponding app." The steps, from "Declaring your actionable notification types": declare categories at launch, attach actions, handle every action you register, and set the category identifier on each notification.

```swift ios
import UserNotifications

func registerNotificationCategories() {
    let reorder = UNNotificationAction(identifier: "REORDER", title: "Reorder", options: [.authenticationRequired])
    let snooze = UNNotificationAction(identifier: "SNOOZE", title: "Remind Me Tomorrow", options: [])
    let restock = UNNotificationCategory(
        identifier: "RESTOCK",
        actions: [reorder, snooze],
        intentIdentifiers: [],
        options: [.customDismissAction]
    )
    let delivery = UNNotificationCategory(identifier: "DELIVERY", actions: [], intentIdentifiers: [], options: [])
    UNUserNotificationCenter.current().setNotificationCategories([restock, delivery])
}
```

- **Action identifiers must be unique** across all categories: "the identifier is the only way to distinguish one action from another."
- **`.authenticationRequired`** on Reorder: placing an order spends money, so the system asks the person to unlock first. `.foreground` opens the app (Apple: don't use it "simply to bring your app to the foreground"); `.destructive` highlights actions that delete data.
- **`.customDismissAction`** makes explicit dismissals reach the delegate. Apple: "Ignoring a notification or flicking away a notification banner doesn't trigger this action."
- The system shows "up to 10 actions" with unlimited space and "at most two actions" with limited space, so put the most useful one first. `UNTextInputNotificationAction` adds a text field (a "message the courier" reply, for example).

### Routing responses

When someone taps an action, "the system launches your app in the background" and calls the delegate's `userNotificationCenter(_:didReceive:)`. The response carries the action identifier and the original content. Tapping the notification itself reports `UNNotificationDefaultActionIdentifier`; an explicit dismissal reports `UNNotificationDismissActionIdentifier`. Pantry first turns the response into a value:

```swift
enum Route: Equatable {
    case openOrder(String)
    case reorder(String)
    case snoozeRestock(product: String, minutes: Int)
    case markHandled
    case ignore
}

let defaultAction = "default"      // stands in for UNNotificationDefaultActionIdentifier
let dismissAction = "dismiss"      // stands in for UNNotificationDismissActionIdentifier

func route(category: String, action: String, userInfo: [String: String]) -> Route {
    switch (category, action) {
    case ("DELIVERY", defaultAction):
        guard let order = userInfo["orderID"] else { return .ignore }
        return .openOrder(order)
    case ("RESTOCK", "REORDER"):
        guard let product = userInfo["productID"] else { return .ignore }
        return .reorder(product)
    case ("RESTOCK", "SNOOZE"):
        guard let product = userInfo["productID"] else { return .ignore }
        return .snoozeRestock(product: product, minutes: 24 * 60)
    case ("RESTOCK", dismissAction):
        return .markHandled
    default:
        return .ignore
    }
}

print(route(category: "DELIVERY", action: defaultAction, userInfo: ["orderID": "1042"]))
print(route(category: "RESTOCK", action: "REORDER", userInfo: ["productID": "milk-1l"]))
print(route(category: "RESTOCK", action: "SNOOZE", userInfo: ["productID": "milk-1l"]))
print(route(category: "RESTOCK", action: dismissAction, userInfo: [:]))
print(route(category: "DELIVERY", action: defaultAction, userInfo: [:]))
print(route(category: "PROMO", action: "REORDER", userInfo: ["productID": "x"]))
```

```output
openOrder("1042")
reorder("milk-1l")
snoozeRestock(product: "milk-1l", minutes: 1440)
markHandled
ignore
ignore
```

- **A missing id is ignored, not force-unwrapped.** Apple's sample uses `as! String`, which crashes the background launch the day a server sends a malformed push.
- **Unknown categories are ignored**: an old notification from a removed feature shouldn't crash or do something surprising.
- **Snooze becomes a new request** with the same identifier, 24 hours later, adjusted for quiet hours.

The delegate does the framework part and hands Sendable values to the main actor:

```swift ios
import UIKit
import UserNotifications

@MainActor
final class NotificationRouter {
    func openOrder(_ id: String) {}
    func reorder(_ productID: String) async {}
    func snooze(_ productID: String) async {}
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let router: NotificationRouter

    init(router: NotificationRouter) {
        self.router = router
    }

    /// The person tapped the notification or one of its actions.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let content = response.notification.request.content
        let orderID = content.userInfo["orderID"] as? String
        let productID = content.userInfo["productID"] as? String

        switch (content.categoryIdentifier, response.actionIdentifier) {
        case ("DELIVERY", UNNotificationDefaultActionIdentifier):
            if let orderID { await router.openOrder(orderID) }
        case ("RESTOCK", "REORDER"):
            if let productID { await router.reorder(productID) }
        case ("RESTOCK", "SNOOZE"):
            if let productID { await router.snooze(productID) }
        default:
            break
        }
    }

    /// A notification arrived while Pantry is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        notification.request.content.categoryIdentifier == "DELIVERY" ? [.banner, .sound] : []
    }
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    private var notificationDelegate: NotificationDelegate?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let delegate = NotificationDelegate(router: NotificationRouter())
        notificationDelegate = delegate                     // the center holds its delegate weakly
        UNUserNotificationCenter.current().delegate = delegate
        registerNotificationCategories()
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("send to server:", token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        // Try again on the next launch.
    }
}

func registerNotificationCategories() {
    let reorder = UNNotificationAction(identifier: "REORDER", title: "Reorder", options: [.authenticationRequired])
    let restock = UNNotificationCategory(identifier: "RESTOCK", actions: [reorder], intentIdentifiers: [], options: [])
    UNUserNotificationCenter.current().setNotificationCategories([restock])
}
```

- **The delegate is set in `didFinishLaunching`.** Apple: "You must assign your delegate object to the `UNUserNotificationCenter` object before your app finishes launching," or you "might miss incoming notifications," including the tap that launched the app. A SwiftUI app does this through `@UIApplicationDelegateAdaptor` (Module 40).
- **The async delegate methods** replace the completion-handler versions: returning from `didReceive` is the "call the completion handler" Apple insists on, so don't return before the work is done.
- **Only strings cross to the main actor.** `UNNotificationResponse` isn't `Sendable`, so the delegate reads what it needs first.
- **`willPresent`** decides what happens in the foreground. Without it, notifications for an app that's open aren't shown. Pantry shows delivery updates and hides restock reminders while you're shopping.
- If the action touches files, Apple warns that "users can respond to actions while the device is locked," so files protected with `complete` data protection may be unreadable (Module 42's data protection classes).

## Remote notifications, at a high level

A remote notification travels from your server to APNs to the device. The pieces, from "Registering your app with APNs" and "Generating a remote notification":

1. **Capability.** Enable Push Notifications in Xcode, which adds the `aps-environment` entitlement, and enable push for the App ID.
2. **Device token.** Call `registerForRemoteNotifications()` "each time your app launches" and send the token from `didRegisterForRemoteNotificationsWithDeviceToken` to your server (the `AppDelegate` above). "Never cache device tokens in local storage": APNs issues a new one after a restore, a reinstall or on a new device. Registration can fail offline or without the entitlement; try again later. Registering doesn't prompt the person: whether alerts show still depends on the authorization from the first section.
3. **Payload.** JSON with an `aps` dictionary plus your own keys. "For all other remote notifications, the maximum payload size is 4 KB (4096 bytes)"; VoIP is 5 KB.

```json
{
  "aps": {
    "alert": { "title": "On the way", "body": "Your courier is 3 stops away." },
    "sound": "default",
    "category": "DELIVERY",
    "thread-id": "order-1042",
    "mutable-content": 1
  },
  "orderID": "1042"
}
```

`category` selects the registered actions, `thread-id` groups, and custom keys like `orderID` arrive in `userInfo`. Your server also chooses the identifier: the `apns-collapse-id` header becomes the request's identifier, so a newer "3 stops away" replaces "5 stops away" instead of stacking.

**Background pushes** (`content-available: 1`, no alert, sound or badge) wake the app to fetch data. They need the "Remote notifications" background mode, and Apple is blunt about them: the system "doesn't guarantee their delivery," may throttle them, and "don't try to send more than two or three per hour." The app gets "30 seconds to perform any tasks." They're a hint to refresh, not a messaging channel.

## Notification Service Extension

A service extension receives remote notifications before they're shown and can change them. Apple's uses: decrypt content, download media too large for the 4 KB payload, or add data from the device. It runs only when the payload has `"mutable-content": 1` and an alert with a title, subtitle or body; Apple: "If alerts are disabled for your app, or if the payload specifies only the playing of a sound or the badging of an icon, the extension isn't employed."

Add it with File > New > Target > Notification Service Extension (quoted, not performed). The template's class:

```swift ios
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttempt: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }
        bestAttempt = content
        if let courier = content.userInfo["courierName"] as? String {
            content.body = "\(courier) is 3 stops away with your groceries."
        }
        contentHandler(content)
    }

    /// Called if didReceive runs out of time. Deliver whatever is ready.
    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttempt {
            contentHandler(bestAttempt)
        }
    }
}
```

The time limit, from Apple: "Your `didReceive(_:withContentHandler:)` method has only about 30 seconds to modify the payload and call the provided completion handler." After that the system calls `serviceExtensionTimeWillExpire()`, "at which point you must return whatever you can to the system immediately. If you fail to call the completion handler from either method, the system displays the original contents." So the server's original text must be acceptable on its own: if the decryption fails, the person still sees something sensible.

## Common mistakes

> [!error] Asking at first launch
> The prompt appears before the person knows what Pantry sends, and a "Don't Allow" is permanent until they dig into Settings. Ask provisionally at launch if you want, and fully when the value is clear.

> [!error] Random identifiers for requests that represent data
> Rescheduling a delivery with `UUID().uuidString` leaves the old reminder pending, and the person gets both. Derive identifiers from the data (`slot-1042`) so adding replaces.

> [!error] Setting the delegate late
> A delegate assigned in the first view's `onAppear` misses the response that launched the app from a notification tap.

> [!error] Force-casting userInfo
> `userInfo["orderID"] as! String` crashes a background launch when a payload is malformed. Treat payloads like any other external input.

> [!error] Using background pushes as a schedule
> Sending `content-available` every 5 minutes to keep data fresh gets throttled; Apple says two or three per hour at most and doesn't guarantee delivery. Use visible pushes for what matters and background tasks (lesson 5) for freshness.

> [!error] A service extension that can't fail gracefully
> If the original payload says "(Encrypted)" and the extension times out, that's what the person sees. Write the original text so it's acceptable unmodified.

## Exercises

````exercise
id: m44-l03-e1
type: prediction
prompt: "A shorter quiet-hours check that only works within one day: anything inside the window moves to its end. What does it print?"
code: |
  func shifted(_ minuteOfDay: Int, quietStart: Int, quietEnd: Int) -> Int {
      let inQuiet = quietStart <= quietEnd
          ? (minuteOfDay >= quietStart && minuteOfDay < quietEnd)
          : (minuteOfDay >= quietStart || minuteOfDay < quietEnd)
      return inQuiet ? quietEnd : minuteOfDay
  }

  print(shifted(1_380, quietStart: 1_320, quietEnd: 420))
  print(shifted(1_319, quietStart: 1_320, quietEnd: 420))
  print(shifted(420, quietStart: 1_320, quietEnd: 420))
  print(shifted(0, quietStart: 1_320, quietEnd: 420))
  print(shifted(0, quietStart: 60, quietEnd: 300))
output: |
  420
  1319
  420
  420
  0
hints:
  - "1,320 is 22:00 and 420 is 07:00, so the first window wraps midnight."
  - "The end is exclusive."
solution: |
  ```output
  420
  1319
  420
  420
  0
  ```

  - **1,380 (23:00)** is in the wrapping window, so it moves to 420 (07:00). This version returns a minute of day, so it loses the fact that 07:00 is *tomorrow*: that's why the lesson's version works with absolute minutes.
  - **1,319 (21:59)** is one minute before quiet hours.
  - **420 (07:00)** is the exclusive end: not quiet, returned as is. It happens to equal the end, which is why the third line also prints 420.
  - **0 (midnight)** is inside the wrapping window, so 07:00.
  - With a 01:00 to 05:00 window, midnight is outside.
````

````exercise
id: m44-l03-e2
type: comprehension
prompt: "Pantry calls `requestAuthorization(options: [.alert, .sound, .badge, .provisional])` at first launch. A week later, the person has never tapped Keep or Turn Off. Which statement is true?"
choices:
  - text: "The status is .provisional, and Pantry's notifications appear only in Notification Center's history, without sound or banner."
    correct: true
    why: "Until the person keeps or turns off notifications, the status stays provisional and delivery stays quiet."
  - text: "The person saw a prompt at first launch and allowed provisional notifications."
    correct: false
    why: "Provisional authorization doesn't prompt."
  - text: "The status is .notDetermined until the person taps Keep."
    correct: false
    why: "Apple: the first call automatically grants authorization; the status is .provisional."
  - text: "Pantry's notifications show banners because .alert was in the options."
    correct: false
    why: "Provisional delivery is quiet regardless of the options; alerts need the person to choose full delivery."
solution: |
  Provisional authorization is granted immediately without a prompt; the status is `.provisional` until the person decides from a delivered notification. Delivery is quiet: Notification Center history only. If Pantry needs interrupting notifications (restock reminders the person turned on), it calls `requestAuthorization` without `.provisional`, which shows the system prompt because the person hasn't answered one yet.
````

````exercise
id: m44-l03-e3
type: fill-in
prompt: "Complete the restock category and the request that uses it."
code: |
  let reorder = UNNotificationAction(identifier: "REORDER", title: "Reorder", options: [.[[1]]])
  let category = UNNotificationCategory(identifier: "RESTOCK", actions: [reorder],
                                        intentIdentifiers: [], options: [])
  UNUserNotificationCenter.current().[[2]]([category])

  let content = UNMutableNotificationContent()
  content.title = "Running low on milk?"
  content.[[3]] = "RESTOCK"
  let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 7 * 24 * 60 * 60, repeats: true)
  let request = UNNotificationRequest(identifier: [[4]], content: content, trigger: trigger)
blanks:
  - id: "1"
    answers: ["authenticationRequired"]
  - id: "2"
    answers: ["setNotificationCategories"]
  - id: "3"
    answers: ["categoryIdentifier"]
  - id: "4"
    answers: ["\"restock-milk\"", "\"restock-milk-1l\""]
solution: |
  - `.authenticationRequired`: reordering spends money, so the device must be unlocked.
  - `setNotificationCategories(_:)` registers categories, at launch.
  - `categoryIdentifier` links the notification to the category's actions.
  - A stable identifier such as `"restock-milk"`, so turning the reminder off or changing it replaces or removes this request instead of piling up duplicates. (The interval is well above the 60-second minimum for repeating triggers.)
````

````exercise
id: m44-l03-e4
type: find-errors
prompt: "Pantry's first notification code. Mark every real problem."
code: |
  // In the first view's onAppear:
  UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
  UNUserNotificationCenter.current().delegate = NotificationDelegate()

  func remind(order: Order) {
      let content = UNMutableNotificationContent()
      content.title = "Delivery soon"
      content.badge = 1
      let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: true)
      let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
      UNUserNotificationCenter.current().add(request)
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
      let orderID = response.notification.request.content.userInfo["orderID"] as! String
      openOrder(orderID)
  }
choices:
  - text: "Asking for full authorization in the first view's onAppear, before the person has context."
    correct: true
  - text: "Setting the delegate in onAppear, after launch, can miss the response that launched the app."
    correct: true
  - text: "A repeating time-interval trigger must be at least 60 seconds."
    correct: true
  - text: "A random identifier means rescheduling creates duplicates instead of replacing."
    correct: true
  - text: "The badge won't appear because .badge wasn't requested, and the content has no userInfo, so the as! crashes."
    correct: true
  - text: "Local notifications need a device token."
    correct: false
    why: "Device tokens are for remote notifications through APNs."
rubric:
  - I flagged the timing of the request and of the delegate.
  - I flagged the 30-second repeating trigger.
  - I flagged the random identifier.
  - I flagged the missing .badge option and the missing userInfo with the force cast.
solution: |
  - **Timing:** request in context (after the first order) or provisionally at launch; set the delegate in `didFinishLaunching`.
  - **Trigger:** Apple requires 60 seconds or more for a repeating interval trigger, and a reminder every minute isn't what anyone wants anyway. A one-time calendar trigger an hour before the slot fits.
  - **Identifier:** `"slot-\(order.id)"`.
  - **Options and payload:** request every interaction type you use (`.badge`), put `orderID` in `userInfo`, and read it with `as? String`.
````

````exercise
id: m44-l03-e5
type: solve
prompt: |
  Write `reconcile(pending:desired:)`. Given the requests that are pending and the reminders the app's data says should exist, return the identifiers to remove (pending, not desired) and the identifiers to add (desired, and either not pending or pending with different content). Sort both lists. Remember that adding an existing identifier replaces it, so a changed reminder doesn't need removing first.

  Expected output:

  ```output
  remove: ["restock-eggs"]
  add: ["restock-coffee", "slot-1042"]
  second run: [] []
  ```
starter: |
  struct Reminder: Equatable {
      let id: String
      let minute: Int
      let text: String
  }

  func reconcile(pending: [Reminder], desired: [Reminder]) -> (remove: [String], add: [String]) {
      // your code
      return ([], [])
  }

  let pending = [
      Reminder(id: "restock-milk", minute: 600, text: "Running low on milk?"),
      Reminder(id: "restock-eggs", minute: 600, text: "Running low on eggs?"),
      Reminder(id: "slot-1042", minute: 1_020, text: "Your delivery slot starts in an hour"),
  ]
  let desired = [
      Reminder(id: "restock-milk", minute: 600, text: "Running low on milk?"),
      Reminder(id: "slot-1042", minute: 1_080, text: "Your delivery slot starts in an hour"),
      Reminder(id: "restock-coffee", minute: 600, text: "Running low on coffee?"),
  ]
  let plan = reconcile(pending: pending, desired: desired)
  print("remove:", plan.remove)
  print("add:", plan.add)
  let again = reconcile(pending: desired, desired: desired)
  print("second run:", again.remove, again.add)
hints:
  - "Removal compares identifiers only; adding compares whole values, because a changed time needs a new request."
  - "Running it twice with the result applied should do nothing."
rubric:
  - Removes only identifiers that are no longer desired.
  - Adds new reminders and changed ones, but not unchanged ones.
  - "Is idempotent: a second run with nothing changed returns two empty lists."
solution: |
  ```swift
  struct Reminder: Equatable {
      let id: String
      let minute: Int
      let text: String
  }

  func reconcile(pending: [Reminder], desired: [Reminder]) -> (remove: [String], add: [String]) {
      var remove: [String] = []
      var add: [String] = []
      for old in pending where !desired.contains(where: { $0.id == old.id }) {
          remove.append(old.id)
      }
      for new in desired where !pending.contains(new) {
          add.append(new.id)
      }
      return (remove.sorted(), add.sorted())
  }

  let pending = [
      Reminder(id: "restock-milk", minute: 600, text: "Running low on milk?"),
      Reminder(id: "restock-eggs", minute: 600, text: "Running low on eggs?"),
      Reminder(id: "slot-1042", minute: 1_020, text: "Your delivery slot starts in an hour"),
  ]
  let desired = [
      Reminder(id: "restock-milk", minute: 600, text: "Running low on milk?"),
      Reminder(id: "slot-1042", minute: 1_080, text: "Your delivery slot starts in an hour"),
      Reminder(id: "restock-coffee", minute: 600, text: "Running low on coffee?"),
  ]
  let plan = reconcile(pending: pending, desired: desired)
  print("remove:", plan.remove)
  print("add:", plan.add)
  let again = reconcile(pending: desired, desired: desired)
  print("second run:", again.remove, again.add)
  ```

  ```output
  remove: ["restock-eggs"]
  add: ["restock-coffee", "slot-1042"]
  second run: [] []
  ```

  Eggs left the restock list, so its request goes. The slot moved from 17:00 to 18:00, so it's added again and the system replaces the pending one. Milk didn't change and isn't touched. In the app, `remove` feeds `removePendingNotificationRequests(withIdentifiers:)` and each `add` becomes an `add(_:)` call; the pending side comes from the center's pending requests, mapped back to `Reminder` values. Because the result is idempotent, Pantry can run it on every launch and after every data change.
````

````exercise
id: m44-l03-e6
type: design
prompt: "Pantry's marketing team wants a push to every user at 09:00 every day with the day's deals, sent as soon as the app is installed, with a \"Buy now\" button that places the order directly from the notification. Respond with a design that respects the person and Apple's guidance, and say what you'd push back on."
rubric:
  - Pushes back on daily marketing without consent and on asking at first launch; proposes provisional or an explicit opt-in for deals.
  - Uses a category with an action that requires authentication, and doesn't place orders without confirmation.
  - Uses a quiet interruption level or Scheduled Summary for promotional content, and respects quiet hours.
  - Mentions App Review's rules on promotional push notifications and keeps payload and identifiers sensible.
solution: |
  - **Consent:** deals are marketing. App Review Guideline 4.5.4: push notifications "should not be used for promotions or direct marketing purposes unless customers have explicitly opted in to receive them via consent language displayed in your app's UI," with a way to opt out in the app. Offer "Daily deals" as a toggle in settings, off by default; turning it on is the in-context moment for the full permission request. At install, only provisional delivery for order updates.
  - **Delivery:** not 09:00 for everyone: use the person's time zone and quiet hours, and `.passive` interruption level so deals don't light up the screen. People who chose Scheduled Summary get them there.
  - **Action:** "Buy now" placing an order from a notification is risky. Make it "Add to Cart" with `.authenticationRequired`, and let checkout happen in the app. If an order action exists at all, it needs authentication and an undo path.
  - **Payload:** a `DEALS` category, a `thread-id` of `deals` so they group, `apns-collapse-id` with the date so a corrected push replaces the first. Under 4 KB; images through a service extension if needed, with acceptable text if the download fails.
  - **Measure:** opt-out and disable rates. If people turn notifications off because of deals, they also lose delivery updates, which is the expensive outcome.
````

## Summary

- Ask for notification permission in context, after an action that shows the value; the system prompts only once. Provisional authorization grants quiet, Notification Center-only delivery without a prompt and can be requested at launch. Check settings before every scheduling pass.
- A local notification is content, a trigger and an identifier. Same identifier replaces; `removePendingNotificationRequests` cancels. Repeating interval triggers need 60 seconds or more. Use `threadIdentifier`, `userInfo` ids and an `interruptionLevel` that fits.
- Keep the app's own reminders out of quiet hours (watch windows that wrap midnight), and reconcile pending requests with app data idempotently.
- Register categories and actions at launch, set the delegate before launch finishes, and route responses from `didReceive` by category and action identifier, without force casts. `willPresent` controls foreground display.
- Remote notifications: Push Notifications capability, a device token requested on every launch and never cached, a 4 KB payload with `aps` keys like `category`, `thread-id` and `mutable-content`. Background pushes aren't guaranteed, two or three per hour at most, with 30 seconds of runtime.
- A Notification Service Extension edits alert pushes with `mutable-content: 1` in about 30 seconds and must hand back its best attempt when time expires.

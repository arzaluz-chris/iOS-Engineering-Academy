---
id: m45-l02
title: Core Location
description: "Location is sensitive and expensive, so Core Location makes you ask twice: once in the Info.plist and once at the moment the feature needs it. You choose between When In Use and Always, add the right usage keys, pick between CLLocationUpdate.liveUpdates, a one-shot CLLocationManager request and CLMonitor conditions, set accuracy and distance filters for battery, live within the 20-condition limit, and test with fixed coordinates and simulated locations."
module: m45
order: 2
level: advanced
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m45-l01, m21-l04]
objectives:
  - Choose between When In Use and Always authorization, and list the Info.plist keys each needs.
  - Explain full versus reduced accuracy and when approximate location is enough.
  - Stream positions with CLLocationUpdate.liveUpdates (iOS 17) and get a single fix with CLLocationManager.requestLocation().
  - Configure desiredAccuracy and distanceFilter for the least battery use that still meets the need.
  - Monitor store arrivals with CLMonitor (iOS 17) within the 20-condition limit.
  - Test location logic with constructed coordinates, and the app with simulated locations and GPX files.
terms:
  - term: When In Use authorization
    definition: "Location is available while the app is in use: on iOS, in the foreground and briefly after moving to the background. Apple calls it the preferred choice for privacy and battery."
  - term: Always authorization
    definition: "Location at any time, and the system may launch the app quietly for some updates, such as region events. You can ask to upgrade from When In Use only once."
  - term: Reduced accuracy
    definition: "Approximate location (iOS 14): usually within 1 to 20 kilometers, updated a few times per hour. The person can choose it in the prompt or in Settings; kCLLocationAccuracyReduced or NSLocationDefaultAccuracyReduced asks for it on purpose."
  - term: CLLocationUpdate.liveUpdates
    definition: "An async sequence of location updates (iOS 17). Iterating it starts location delivery and, if needed, the authorization prompt. Each update has an optional location and isStationary."
  - term: CLMonitor
    definition: "An actor (iOS 17) that monitors conditions, such as a CircularGeographicCondition, and delivers events with a state of satisfied or unsatisfied through an async sequence. An app can monitor at most 20 conditions."
  - term: distanceFilter
    definition: "CLLocationManager's minimum horizontal movement, in meters, from the last delivered location before the standard service delivers another update. The default, kCLDistanceFilterNone, reports every movement."
mastery:
  - Write the Info.plist entries for When In Use, Always and temporary full accuracy, with specific purpose strings.
  - Pick the API, accuracy and authorization for a location feature, and justify each choice in terms of battery and privacy.
  - Stream locations with liveUpdates and stop cleanly, and wrap requestLocation() in an async function.
  - Predict which positions a distance filter delivers along a path.
  - Choose which stores to register as conditions when there are more than 20.
  - Write tests for location logic that never touch CLLocationManager.
resources: [requesting-protected-resources, information-property-list, app-review-guidelines, swift-checkedcontinuation, xcode-reducing-battery-use]
cards:
  - id: m45-l02-c1
    front: Which Info.plist keys does location authorization need on iOS?
    back: "NSLocationWhenInUseUsageDescription, always. NSLocationAlwaysAndWhenInUseUsageDescription as well if the app asks for Always. Optional: NSLocationDefaultAccuracyReduced and NSLocationTemporaryUsageDescriptionDictionary. Without the required keys, authorization requests fail immediately."
  - id: m45-l02-c2
    front: When In Use or Always?
    back: "When In Use unless the app must react while it isn't running, such as region events or a location push extension. With When In Use, the system doesn't launch a terminated app for updates; with Always it does for some. The upgrade to Always can be requested only once."
  - id: m45-l02-c3
    front: How do you save battery with CLLocationManager?
    back: "Stop services as soon as you have what you need; set desiredAccuracy to the lowest value that works and distanceFilter to the largest; set activityType and pausesLocationUpdatesAutomatically; keep allowsBackgroundLocationUpdates false unless needed; consider NSLocationDefaultAccuracyReduced."
  - id: m45-l02-c4
    front: What's the limit on CLMonitor conditions, and what happens after a reboot?
    back: "One app can monitor at most 20 conditions of any type at the same time. Monitoring resumes only after the person unlocks the device after a reboot. If the app isn't running when a condition changes, iOS tries to launch it, and the app must recreate the monitor with the same name."
  - id: m45-l02-c5
    front: How do you test location logic without a device moving around?
    back: "Pass constructed coordinates (CLLocationCoordinate2D or your own type) to the logic under test. For app-level tests, set a Simulated Location or a GPX file in the test plan, and set XCUIDevice.shared.location in UI tests."
---

## The idea in one sentence

Location is **personal data that costs battery to produce**, so every Core Location decision is a trade between how precise, how often and how long, and the right answer is always the least the feature can live with.

> [!note] Sources and what was checked
> From Apple's documentation, read in November 2026: Core Location's overview, "Configuring your app to use location services", "Requesting authorization to use location services", "Getting the current location of a device", "Handling location updates in the background", "Monitoring the user's proximity to geographic regions", "Simulating location in tests", `CLLocationUpdate` and `liveUpdates(_:)`, `CLMonitor`, `CLServiceSession`, `CLBackgroundActivitySession`, `CLLocationManager`'s `desiredAccuracy`, `distanceFilter` and `requestLocation()`, `kCLLocationAccuracyReduced`, and the location Info.plist keys; plus App Review Guidelines 2.5.4, 5.1.1 and 5.1.5. Availability was read from each symbol's page: `liveUpdates` and `CLMonitor` are iOS 17, and `CLServiceSession` and the diagnostic properties such as `authorizationDenied` are iOS 18. The Core Location code is type-checked against the iOS SDK, not run, and nothing was tested on a device. The planning, distance and filter models are plain Swift, compiled and run with Swift 6.3.

## Two levels of authorization

Module 21 introduced purpose strings and the one-time prompt. Location adds a choice of level. From "Requesting authorization to use location services":

- **When In Use** "makes location updates available only when someone uses your app. This authorization is the preferred choice, because it has better privacy and battery life implications." On iOS, in use means "in the foreground and for a short time when it transitions from the foreground to the background."
- **Always** "makes location updates available at any time, and lets the system launch your app quietly to handle some updates." Request it "only when necessary," for example for "time-sensitive responses to location changes."

The difference that matters is what happens when the app isn't running: "the system doesn't launch an app with When in Use authorization to deliver new updates; it does launch an app with Always authorization for some types of location updates." And the upgrade is a one-shot: "If your app already has When in Use authorization, you can make a separate request for Always authorization later. However, you can make the request only once."

The Info.plist keys, from their reference pages:

| Key | When |
| --- | --- |
| `NSLocationWhenInUseUsageDescription` | Required for any location use while the app is in use |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | Also required if the app asks for Always |
| `NSLocationDefaultAccuracyReduced` | Optional, `true` to ask for approximate location by default |
| `NSLocationTemporaryUsageDescriptionDictionary` | Optional, purpose strings for one-time full-accuracy requests |

Apple: "Add all usage description keys to your app's Information Property List before you make any authorization requests. Authorization requests fail immediately if the required keys aren't present."

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Pantry uses your location to show stores near you and how far they are.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Pantry tells the store you've arrived so your pickup order is brought out, even if the app is closed.</string>
```

### Precise or approximate

Since iOS 14 the person can also turn off **Precise Location** for your app. Then you get reduced accuracy: `kCLLocationAccuracyReduced`'s page says the location is reduced "in both space and time," "typically preserves the city, and is usually within 1–20 kilometers of the actual location," updated "at most a few times per hour." `CLLocationManager.accuracyAuthorization` tells you which you have (`.fullAccuracy` or `.reducedAccuracy`), and while it's reduced, `desiredAccuracy` "changes have no effect."

For a feature that truly needs precision once, `requestTemporaryFullAccuracyAuthorization(withPurposeKey:)` asks for it with a purpose string chosen from `NSLocationTemporaryUsageDescriptionDictionary`. For features that never need it, asking for reduced accuracy on purpose (with `NSLocationDefaultAccuracyReduced`) is a privacy feature people can see: the prompt shows an approximate map.

## Picking the API and the accuracy

Pantry has four location features, and each needs something different. Apple's power advice from "Getting the current location of a device": start services only when someone uses the feature, stop them "as soon as you have the location data you need," set `desiredAccuracy` "to the lowest possible value that gives you the information you need," and set `distanceFilter` "to the largest possible value." That advice turns into a small decision function Pantry's team keeps next to the feature list:

```swift
struct LocationNeed {
    let feature: String
    let precisionMeters: Int      // how far off the answer may be and still be useful
    let whileMoving: Bool         // needs a stream of positions, not one
    let whenAppIsNotRunning: Bool // must react with the app suspended or terminated
}

/// Names a desiredAccuracy constant (kCLLocationAccuracy... without the prefix):
/// the least precise one that still meets the need.
func accuracyConstant(forPrecision meters: Int) -> String {
    switch meters {
    case ..<10: return "Best"
    case ..<100: return "NearestTenMeters"
    case ..<1_000: return "HundredMeters"
    case ..<3_000: return "Kilometer"
    default: return "ThreeKilometers"
    }
}

func plan(for need: LocationNeed) -> String {
    let api: String
    if need.whenAppIsNotRunning {
        api = "CLMonitor condition, Always"
    } else if need.whileMoving {
        api = "liveUpdates, When In Use"
    } else {
        api = "requestLocation at \(accuracyConstant(forPrecision: need.precisionMeters)), When In Use"
    }
    let reduced = need.precisionMeters >= 20_000 ? "; approximate location is enough" : ""
    return api + reduced
}

let needs = [
    LocationNeed(feature: "Stores near me", precisionMeters: 500, whileMoving: false, whenAppIsNotRunning: false),
    LocationNeed(feature: "Walk to the store", precisionMeters: 20, whileMoving: true, whenAppIsNotRunning: false),
    LocationNeed(feature: "Order ready on arrival", precisionMeters: 150, whileMoving: true, whenAppIsNotRunning: true),
    LocationNeed(feature: "Regional prices", precisionMeters: 50_000, whileMoving: false, whenAppIsNotRunning: false),
]

for need in needs {
    print("\(need.feature): \(plan(for: need))")
}
```

```output
Stores near me: requestLocation at HundredMeters, When In Use
Walk to the store: liveUpdates, When In Use
Order ready on arrival: CLMonitor condition, Always
Regional prices: requestLocation at ThreeKilometers, When In Use; approximate location is enough
```

- **"Stores near me"** needs one answer good to a few hundred meters. A single fix at `kCLLocationAccuracyHundredMeters` lets Core Location skip GPS when Wi-Fi and cell data suffice. Apple: "Lower accuracy values let the system use more power-efficient hardware."
- **"Walk to the store"** follows the person on a map while the screen is open: a stream, stopped when the screen goes away.
- **"Order ready on arrival"** has to work with Pantry closed, so it's a monitored condition, and only Always authorization lets the system launch the app for it.
- **"Regional prices"** only needs the region. Reduced accuracy "typically preserves the city," so Pantry doesn't need precise location at all, and shouldn't ask for it.

The thresholds are Pantry's own choices, not Apple's; what's Apple's is the principle of picking the least precise constant that works. The 20 km cut-off comes from the "1–20 kilometers" in the reduced-accuracy description.

## A stream: liveUpdates

In iOS 17 Core Location gained an async API. Apple's overview now starts with it: "call `liveUpdates(_:)` to obtain an update stream, then asynchronously iterate over that stream." Iterating triggers authorization when needed: "If the system hasn't requested authorization for your app, it does so when your code starts iterating over the asynchronous stream of updates."

```swift ios
import CoreLocation
import Observation

@MainActor
@Observable
final class WalkToStoreModel {
    private(set) var lastLocation: CLLocation?
    private(set) var isStationary = false
    private(set) var message = ""
    private var updatesTask: Task<Void, Never>?

    /// Call when the map screen appears.
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            let updates = CLLocationUpdate.liveUpdates()
            do {
                try await Self.consume(updates) { [weak self] (update: CLLocationUpdate) in
                    await self?.handle(update)
                }
            } catch {
                self?.message = "Location isn't available right now."
            }
        }
    }

    /// Call when the map screen disappears.
    func stop() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    /// Iterates off the main actor until the task is cancelled; each update hops back.
    private nonisolated static func consume(
        _ updates: CLLocationUpdate.Updates,
        handler: @Sendable (CLLocationUpdate) async -> Void
    ) async throws {
        for try await update in updates {
            if Task.isCancelled { break }
            await handler(update)
        }
    }

    private func handle(_ update: CLLocationUpdate) {
        if let location = update.location {
            lastLocation = location
            isStationary = update.isStationary
            message = ""
            return
        }
        if #available(iOS 18.0, *), update.authorizationDenied {
            message = "Turn on location for Pantry in Settings, or search by address."
        }
    }
}
```

- **The loop is the subscription.** Apple: "The loop doesn't terminate unless you explicitly use `return`, `break`, or throw an exception." Apple's SwiftUI sample stops by breaking out of the loop on the next update; `stop()` here does the same through `Task.isCancelled`, so the last update after leaving the screen is ignored.
- **Iteration happens off the main actor.** `consume` is `nonisolated`, the same shape as the StoreKit listener in lesson 1, and each update hops to the main actor through `handler`. The `[weak self]` captures keep the endless loop from keeping the model alive.
- **An update doesn't always carry a location.** Apple's pattern checks `update.location` first and then the state properties. On iOS 18 those properties (`authorizationDenied`, `locationUnavailable`, `accuracyLimited` and others) say why no location came; on iOS 17 you only know none did. That's why the check is behind `#available`.
- **`isStationary`** lets the UI stop animating, and the system saves power on its own when the person stands still.
- **Fallback.** Guideline 5.1.1(iv): "if a user declines to share Location, offer the ability to manually enter an address." The denied message points to both.

`liveUpdates` takes a `LiveConfiguration` (`.default`, `.fitness`, `.automotiveNavigation`, `.otherNavigation` and others) instead of an accuracy and a distance filter. In iOS 18, `CLServiceSession` lets you declare the authorization a feature needs ("Create the session while your app is in the foreground"), and continuing a stream in the background takes a `CLBackgroundActivitySession`, the Location updates background mode, and the work Apple describes in "Handling location updates in the background". Pantry's walking map doesn't need either.

## One fix: CLLocationManager and a continuation

Lots of existing code, and features like "Stores near me", use `CLLocationManager` directly. `requestLocation()` "starts location services long enough to return a result or report an error and then stops them again," at the `desiredAccuracy` you set. Its results arrive through a delegate, which is exactly the callback-to-async situation Module 29's continuation lesson covered:

```swift ios
import CoreLocation

enum LocatorError: Error {
    case denied
    case busy
}

@MainActor
final class StoreFinderLocator: NSObject {
    private let manager = CLLocationManager()
    private var pending: CheckedContinuation<CLLocation, any Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// One fix good to about 100 m. Location services stop again afterwards.
    func currentLocation() async throws -> CLLocation {
        guard pending == nil else { throw LocatorError.busy }
        let status = manager.authorizationStatus
        if status == .denied || status == .restricted {
            throw LocatorError.denied
        }
        return try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            if status == .notDetermined {
                manager.requestWhenInUseAuthorization()   // the delegate requests the fix once allowed
            } else {
                manager.requestLocation()
            }
        }
    }

    private func finish(with result: Result<CLLocation, any Error>) {
        pending?.resume(with: result)
        pending = nil
    }
}

extension StoreFinderLocator: @preconcurrency CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            finish(with: .success(location))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        finish(with: .failure(error))
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard pending != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            finish(with: .failure(LocatorError.denied))
        default:
            break
        }
    }
}
```

- **Exactly once.** Every path ends in `finish(with:)`, which resumes the continuation and clears it, so a late second callback finds `pending == nil` and does nothing. A second caller while one fix is pending gets `.busy` instead of overwriting the continuation (which would leak the first caller).
- **Authorization follows Apple's sample**: `locationManagerDidChangeAuthorization(_:)` is "a central place to process any authorization-related changes," and a new manager reports the current status to it automatically. Requesting the fix only after the status becomes authorized avoids racing the prompt. The person can also dismiss the prompt without deciding; a production version would add a timeout, which this one leaves out.
- **`@preconcurrency` conformance.** The delegate protocol predates Swift concurrency. Core Location calls the delegate on the thread of the run loop where the manager was created, here the main thread, so the main-actor methods are safe; `@preconcurrency` tells the compiler to trust that and check it at run time, as Module 29 described.
- **Errors are real.** `requestLocation()`: "If a location fix cannot be determined in a timely manner, the location manager calls the delegate's `locationManager(_:didFailWithError:)`." And the delegate must implement both methods: "Failure to do so is a programmer error."

### Distance filters

For a continuous `CLLocationManager` stream (`startUpdatingLocation()`), `distanceFilter` is "the minimum distance in meters the device must move horizontally before an update event is generated," measured "relative to the previously delivered location." That last part matters, as this model with positions in whole meters shows:

```swift
/// A position on a local grid, in whole meters east and north of a fixed point.
struct GridPoint {
    let east: Int
    let north: Int
}

/// What CLLocationManager.distanceFilter does: an update is delivered only after the device
/// moves at least `filter` meters from the previously delivered location.
func deliveredUpdates(_ path: [GridPoint], filter: Int) -> [Int] {
    var delivered: [Int] = []
    var last: GridPoint?
    for (index, point) in path.enumerated() {
        if let previous = last {
            let dx = point.east - previous.east
            let dy = point.north - previous.north
            guard dx * dx + dy * dy >= filter * filter else { continue }
        }
        delivered.append(index)
        last = point
    }
    return delivered
}

let walk = [
    GridPoint(east: 0, north: 0), GridPoint(east: 20, north: 0), GridPoint(east: 40, north: 10),
    GridPoint(east: 60, north: 20), GridPoint(east: 60, north: 60), GridPoint(east: 62, north: 61),
    GridPoint(east: 100, north: 90), GridPoint(east: 130, north: 130),
]

for filter in [0, 50, 100] {
    print("filter \(filter) m:", deliveredUpdates(walk, filter: filter))
}
```

```output
filter 0 m: [0, 1, 2, 3, 4, 5, 6, 7]
filter 50 m: [0, 3, 6, 7]
filter 100 m: [0, 6]
```

- **Compared with the last delivered point, not the last measured one.** With 50 m, points 4 and 5 are each within 50 m of point 3, so neither is delivered, and point 6 is measured from point 3 as well.
- **Squared distances** avoid a square root and keep the arithmetic exact; the real filter works on coordinates in meters, but the rule is the same.
- **Fewer updates is the point.** "Higher values let the system turn off radio hardware more frequently." A map following a walk is fine with 10 to 20 m; a "nearest store changed" check is fine with a few hundred.

## Store arrivals with CLMonitor

Region monitoring ("geofencing") watches for entering or leaving an area, and in iOS "the system monitors regions and wakes up your app as needed when conditions change between satisfied and unsatisfied states." Since iOS 17 the API is `CLMonitor`, an actor with an async sequence of events:

```swift ios
import CoreLocation

struct StoreLocation: Sendable {
    let id: String
    let center: CLLocationCoordinate2D
}

/// Registers up to 20 stores and reports arrivals. Recreate the monitor with the same
/// name when the app launches, because the system may relaunch Pantry for an event.
func watchStoreArrivals(_ stores: [StoreLocation], onArrival: @Sendable (String) -> Void) async {
    let monitor = await CLMonitor("pantry-stores")
    for identifier in await monitor.identifiers where !stores.contains(where: { $0.id == identifier }) {
        await monitor.remove(identifier)
    }
    for store in stores.prefix(20) {
        let condition = CLMonitor.CircularGeographicCondition(center: store.center, radius: 150)
        await monitor.add(condition, identifier: store.id, assuming: .unsatisfied)
    }
    do {
        for try await event in await monitor.events {
            if event.state == .satisfied {
                onArrival(event.identifier)
            }
        }
    } catch {
        print("Store monitoring stopped: \(error)")
    }
}
```

- **The 20-condition limit.** "Core Location prevents any single app from monitoring more than 20 conditions of any type simultaneously. Prioritize what you want to monitor." On iOS 18 an event's `conditionLimitExceeded` tells you when you've hit it. Conditions persist with the monitor's name, so the code first removes stores Pantry no longer wants; otherwise old ones would quietly use up slots.
- **`assuming: .unsatisfied`** says the person isn't at the store now, so the first entry produces a satisfied event.
- **Relaunch.** "If an iOS app isn't running when a condition is satisfied, the system tries to launch it. When the app relaunches, recreate the monitor with the same identifier." So `watchStoreArrivals` runs early at launch, not from a view. "Monitoring can only occur after the user unlocks the device after a reboot."
- **Always authorization** is what lets that relaunch happen, so the arrival feature asks for the upgrade at the moment the person turns it on, with the Always purpose string above.

Which 20? Pantry picks the stores nearest to the person (or the ones with an open pickup order) and refreshes the set when the person moves far. The solve exercise writes that selection. To compute real distances, `CLLocation.distance(from:)` returns meters along "a line between the two points that follows the curvature of the Earth." Here is the same idea in plain Swift, for testing:

```swift
import Foundation

struct Coordinate {
    let latitude: Double
    let longitude: Double
}

/// Great-circle distance in meters (haversine, mean Earth radius). CLLocation.distance(from:)
/// does this for you in the app; here it runs anywhere.
func distance(_ a: Coordinate, _ b: Coordinate) -> Double {
    let earthRadius = 6_371_000.0
    let dLat = (b.latitude - a.latitude) * .pi / 180
    let dLon = (b.longitude - a.longitude) * .pi / 180
    let lat1 = a.latitude * .pi / 180
    let lat2 = b.latitude * .pi / 180
    let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
    return 2 * earthRadius * asin(min(1, sqrt(h)))
}

/// "1.4 km", rounded to 100 m, formatted with integers so it prints the same everywhere.
func kilometers(_ meters: Double) -> String {
    let tenths = Int((meters / 100).rounded())
    return "\(tenths / 10).\(tenths % 10) km"
}

let home = Coordinate(latitude: 40.4168, longitude: -3.7038)
let stores = [
    ("Pantry Sol", Coordinate(latitude: 40.4170, longitude: -3.7020)),
    ("Pantry Retiro", Coordinate(latitude: 40.4150, longitude: -3.6840)),
    ("Pantry Chamberí", Coordinate(latitude: 40.4340, longitude: -3.7040)),
    ("Pantry Airport", Coordinate(latitude: 40.4900, longitude: -3.5900)),
]

let radius = 2_500.0
var nearby: [(name: String, meters: Double)] = []
for (name, location) in stores {
    let meters = distance(home, location)
    if meters <= radius {
        nearby.append((name, meters))
    }
}
nearby.sort { $0.meters < $1.meters }
for store in nearby {
    print(store.name, kilometers(store.meters))
}
print("\(stores.count - nearby.count) farther than \(kilometers(radius))")
```

```output
Pantry Sol 0.2 km
Pantry Retiro 1.7 km
Pantry Chamberí 1.9 km
1 farther than 2.5 km
```

- **Formatting with integers** avoids printing a `Double` directly; the digits a `Double` prints can vary, and a test comparing text would break. In the UI, use a `MeasurementFormatter` or `Measurement.formatted()`, which also localizes units.
- **Fixed coordinates make this a unit test.** Apple's "Simulating location in tests": "When testing your app's location-handling logic, you don't need to use `CLLocationManager` or get the device's location. You can construct instances of `CLLocationCoordinate2D` with known values."

## Testing with simulated locations

For the parts that do touch Core Location, Apple documents these steps (quoted, not performed for this lesson):

- **Test plans.** Product > Test Plan > Edit Test Plan > Configuration, then under Localization pick a **Simulated Location**. It "changes only for code running in the test bundle."
- **Journeys.** In the same menu, Add GPX File to Workspace; "Xcode uses the GPX file to replay a journey while your tests are running, updating the simulated location, elevation, and velocity." Record the walk from the Sol store to the Retiro store once and replay it for the walking map.
- **UI tests** run the app in another process, so set `XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude:longitude:))` instead.

Also test denial, approximate location, and a reboot-then-unlock for monitoring on a real device. Those are the paths that break in production.

## App Review

- **5.1.5 Location Services**: "Use Location Services in your app only when it is directly relevant to the features and services provided by the app," and "notify and obtain consent before collecting, transmitting, or using location data."
- **5.1.1(iv) Access**: if a person declines location, "offer the ability to manually enter an address."
- **5.1.2(i)**: your app "may not require users to enable system functionalities (such as push notifications, location services, tracking) in order to access functionality." No "allow location to continue" gate.
- **2.5.4**: background services only "for their intended purposes," location among them. A Location updates background mode without a background location feature is a rejection risk.

## Common mistakes

> [!error] Requesting location at launch
> Apple: "Don't make requests at launch time or from a part of your app that isn't connected to location." The person can't tell why you want it, and a denial is permanent until they find the switch in Settings.

> [!error] Asking for Always "just in case"
> It's worse for privacy and battery, the upgrade request works only once, and a feature without a reason for it invites rejection under 5.1.5. Ask for When In Use; ask for Always when the person turns on a feature that needs it.

> [!error] kCLLocationAccuracyBest for a store list
> GPS-level accuracy costs battery and time ("More accurate location data also takes more time to become available") for a list sorted by kilometers.

> [!error] Leaving updates running
> A stream started on a screen must stop when the screen goes away. Tie it to the view's lifetime (`.task`, or `start` and `stop` on appear and disappear).

> [!error] More than 20 conditions
> The extras are never monitored. Choose the nearest or most relevant 20 and rotate them as the person moves.

> [!error] No fallback after denial
> A blank screen after "Don't Allow" breaks 5.1.1(iv). Offer address or postal code entry.

## Exercises

````exercise
id: m45-l02-e1
type: prediction
prompt: "A distance filter of 30 meters, applied by hand. What does it print?"
code: |
  struct GridPoint {
      let east: Int
      let north: Int
  }

  let filter = 30
  var last = GridPoint(east: 0, north: 0)
  print("deliver 0,0")
  for point in [GridPoint(east: 10, north: 10), GridPoint(east: 25, north: 20),
                GridPoint(east: 30, north: 40), GridPoint(east: 50, north: 40)] {
      let dx = point.east - last.east
      let dy = point.north - last.north
      if dx * dx + dy * dy >= filter * filter {
          print("deliver \(point.east),\(point.north)")
          last = point
      } else {
          print("skip \(point.east),\(point.north)")
      }
  }
output: |
  deliver 0,0
  skip 10,10
  deliver 25,20
  skip 30,40
  deliver 50,40
hints:
  - "Compare squared distances with 30 × 30 = 900."
  - "After a delivery, `last` moves; after a skip, it doesn't."
solution: |
  ```output
  deliver 0,0
  skip 10,10
  deliver 25,20
  skip 30,40
  deliver 50,40
  ```

  - (10,10): 100 + 100 = 200 < 900, skip. `last` stays at (0,0).
  - (25,20): 625 + 400 = 1025 ≥ 900, measured from (0,0), deliver.
  - (30,40): from (25,20), 25 + 400 = 425, skip, even though it's 50 m from the start.
  - (50,40): from (25,20), 625 + 400 = 1025, deliver.

  The filter is relative to the last delivered location, which is why (30,40) is skipped.
````

````exercise
id: m45-l02-e2
type: comprehension
prompt: "Pantry's 'order ready on arrival' feature must notice when the person reaches the store, even if Pantry was closed hours ago. What does it need?"
choices:
  - text: "A CLMonitor circular condition per store, Always authorization with NSLocationAlwaysAndWhenInUseUsageDescription, and recreating the monitor with the same name at launch."
    correct: true
    why: "iOS launches a terminated app for condition events only with Always authorization, and the relaunched app must recreate the monitor to receive them."
  - text: "liveUpdates in a Task started from the order screen."
    correct: false
    why: "The task doesn't exist once the app is closed. Streams are for while the feature is in use."
  - text: "requestLocation() every 15 minutes from a background refresh task."
    correct: false
    why: "Background refresh isn't periodic or timely (lesson 5 of Module 44), and repeated fixes waste battery."
  - text: "When In Use authorization is enough, because region events are handled by the system."
    correct: false
    why: "Apple: with When In Use, the system doesn't launch a terminated app to deliver updates."
solution: |
  Condition monitoring is the power-efficient way to react to arrival: the system watches the region and wakes the app. Waking a terminated app needs Always ("it does launch an app with Always authorization for some types of location updates"), and "when the app relaunches, recreate the monitor with the same identifier." Ask for the upgrade when the person turns the feature on, and keep the total at 20 conditions or fewer.
````

````exercise
id: m45-l02-e3
type: find-errors
prompt: "Mark every real problem in this location setup."
code: |
  // Info.plist: NSLocationWhenInUseUsageDescription = "Location needed."

  @main
  struct PantryApp: App {
      let manager = CLLocationManager()

      init() {
          manager.desiredAccuracy = kCLLocationAccuracyBest
          manager.requestAlwaysAuthorization()
          manager.startUpdatingLocation()
      }

      var body: some Scene {
          WindowGroup { StoreListView() }
      }
  }
choices:
  - text: "It asks for authorization at launch instead of when a location feature is used."
    correct: true
  - text: "It asks for Always without NSLocationAlwaysAndWhenInUseUsageDescription, and without a feature that needs it."
    correct: true
  - text: "kCLLocationAccuracyBest and continuous updates are far more than a store list needs, and nothing ever stops them."
    correct: true
  - text: "The purpose string says nothing specific about why Pantry uses location."
    correct: true
  - text: "CLLocationManager can't be stored in a SwiftUI App struct."
    correct: false
    why: "It compiles; the problems are when it asks, what it asks for, and what it runs."
rubric:
  - I flagged the launch-time request.
  - I flagged Always without its key or a reason.
  - I flagged the accuracy and the never-stopped updates.
  - I flagged the vague purpose string.
solution: |
  - Request When In Use from the store list's "Use my location" action, not at launch.
  - Always needs `NSLocationAlwaysAndWhenInUseUsageDescription`, and only the arrival feature justifies it. Without the key, "authorization requests fail immediately."
  - Use a single fix at `kCLLocationAccuracyHundredMeters` (`requestLocation()` or the first `liveUpdates` value), then stop.
  - Rewrite the purpose string as what the person gets: "Pantry uses your location to show stores near you and how far they are."
````

````exercise
id: m45-l02-e4
type: fill-in
prompt: "Complete the store-arrival monitor."
code: |
  let monitor = await CLMonitor("pantry-stores")
  let condition = CLMonitor.[[1]](center: store.center, radius: 150)
  await monitor.add(condition, identifier: store.id, assuming: .[[2]])
  for try await event in await monitor.[[3]] {
      if event.state == .[[4]] {
          onArrival(event.identifier)
      }
  }
blanks:
  - id: "1"
    answers: ["CircularGeographicCondition"]
  - id: "2"
    answers: ["unsatisfied"]
  - id: "3"
    answers: ["events"]
  - id: "4"
    answers: ["satisfied"]
solution: |
  - `CLMonitor.CircularGeographicCondition(center:radius:)` defines the area.
  - Assuming `.unsatisfied` means "not at the store now", so entering produces an event.
  - `events` is the monitor's async sequence.
  - `.satisfied` is the state when the person is inside the circle.
````

````exercise
id: m45-l02-e5
type: solve
prompt: |
  Write `storesToMonitor(_:from:limit:)`: return the names of at most `limit` stores, nearest to `person` first. Break ties in distance by name, in alphabetical order. Positions are whole meters on a local grid; compare squared distances so everything stays in integers. A negative limit returns nothing.

  Expected output:

  ```output
  ["Sol", "Atocha", "Opera"]
  ["Airport", "Chamberi"]
  6
  []
  ```
starter: |
  struct GridPoint {
      let east: Int
      let north: Int
  }

  struct Store {
      let name: String
      let position: GridPoint
  }

  func storesToMonitor(_ stores: [Store], from person: GridPoint, limit: Int) -> [String] {
      // your code
      return []
  }

  let stores = [
      Store(name: "Sol", position: GridPoint(east: 100, north: 0)),
      Store(name: "Retiro", position: GridPoint(east: 1_500, north: -200)),
      Store(name: "Chamberi", position: GridPoint(east: 0, north: 1_900)),
      Store(name: "Atocha", position: GridPoint(east: 600, north: -800)),
      Store(name: "Opera", position: GridPoint(east: -600, north: 800)),
      Store(name: "Airport", position: GridPoint(east: 9_700, north: 8_100)),
  ]

  print(storesToMonitor(stores, from: GridPoint(east: 0, north: 0), limit: 3))
  print(storesToMonitor(stores, from: GridPoint(east: 9_000, north: 8_000), limit: 2))
  print(storesToMonitor(stores, from: GridPoint(east: 0, north: 0), limit: 20).count)
  print(storesToMonitor([], from: GridPoint(east: 0, north: 0), limit: 20))
hints:
  - "Sort with a closure that compares squared distances and falls back to names."
  - "`prefix(_:)` never goes past the end of the array, but it traps on a negative count."
rubric:
  - Sorts by distance with a deterministic tie-break.
  - Never returns more than the limit, and handles fewer stores than the limit and a negative limit.
  - Uses integer arithmetic only.
solution: |
  ```swift
  struct GridPoint {
      let east: Int
      let north: Int
  }

  struct Store {
      let name: String
      let position: GridPoint
  }

  /// The stores to register as conditions, nearest first, at most `limit` of them.
  func storesToMonitor(_ stores: [Store], from person: GridPoint, limit: Int) -> [String] {
      func squaredDistance(_ store: Store) -> Int {
          let dx = store.position.east - person.east
          let dy = store.position.north - person.north
          return dx * dx + dy * dy
      }
      let sorted = stores.sorted { a, b in
          let da = squaredDistance(a)
          let db = squaredDistance(b)
          return da != db ? da < db : a.name < b.name
      }
      return sorted.prefix(max(0, limit)).map(\.name)
  }

  let stores = [
      Store(name: "Sol", position: GridPoint(east: 100, north: 0)),
      Store(name: "Retiro", position: GridPoint(east: 1_500, north: -200)),
      Store(name: "Chamberi", position: GridPoint(east: 0, north: 1_900)),
      Store(name: "Atocha", position: GridPoint(east: 600, north: -800)),
      Store(name: "Opera", position: GridPoint(east: -600, north: 800)),
      Store(name: "Airport", position: GridPoint(east: 9_700, north: 8_100)),
  ]

  print(storesToMonitor(stores, from: GridPoint(east: 0, north: 0), limit: 3))
  print(storesToMonitor(stores, from: GridPoint(east: 9_000, north: 8_000), limit: 2))
  print(storesToMonitor(stores, from: GridPoint(east: 0, north: 0), limit: 20).count)
  print(storesToMonitor([], from: GridPoint(east: 0, north: 0), limit: 20))
  ```

  ```output
  ["Sol", "Atocha", "Opera"]
  ["Airport", "Chamberi"]
  6
  []
  ```

  - Atocha and Opera are both exactly 1,000 m away (600² + 800²), so the name decides: Atocha first. Without a tie-break, the order of equal elements would be up to the sort, and a test couldn't depend on it.
  - From near the airport, Chamberi is the second nearest, not Sol: the whole set changes as the person moves, which is why Pantry recomputes it after large moves.
  - With 6 stores and a limit of 20, all 6 come back. In the app, `limit` is 20 minus any conditions other features use.
````

````exercise
id: m45-l02-e6
type: design
prompt: "Design location for a new Pantry feature: 'Deals nearby' shows a banner when the person walks past a store with a deal, and the in-app map shows nearby stores. Specify authorization and when you ask, Info.plist keys, APIs, accuracy and distance settings, the 20-condition limit, battery behavior, denial and approximate-location fallbacks, and tests."
rubric:
  - Asks for When In Use from the map and for Always only when the person turns on deal alerts, with both purpose strings.
  - Uses a stream or one-shot request for the map, stopped with the screen, and CLMonitor conditions for alerts, chosen and rotated under the 20 limit.
  - Chooses accuracy and filters per feature and explains the battery reasoning.
  - Handles denial (manual address), reduced accuracy (city-level list, no alerts) and the reboot-unlock rule.
  - Tests the selection and distance logic with fixed coordinates and the app with simulated locations or GPX journeys.
solution: |
  - **Authorization:** the map asks for When In Use when opened ("Use my location" button). Deal alerts are off by default; turning them on explains the feature and then requests Always. Keys: `NSLocationWhenInUseUsageDescription` and `NSLocationAlwaysAndWhenInUseUsageDescription` with specific strings.
  - **Map:** `liveUpdates()` while the map is visible, stopped on disappear. If precision isn't needed, a single `requestLocation()` at hundred-meter accuracy on open and on pull-to-refresh is cheaper.
  - **Alerts:** `CLMonitor` with circular conditions of about 150 m around the 20 nearest stores that have deals (the solve exercise), recomputed when the person has moved a few kilometers or deals change, and stale ones removed. The monitor is recreated with the same name at launch.
  - **Battery:** nothing runs without a visible feature or a registered condition; no background location mode is needed because the system handles monitoring.
  - **Fallbacks:** denied: postal code entry for the map, alerts unavailable with an explanation. Reduced accuracy: the map lists stores in the city; alerts explain that they need precise location, optionally via a temporary full-accuracy request. After a reboot, alerts resume once the device is unlocked.
  - **Tests:** distance, selection and banner-throttling logic with fixed coordinates; the map with a GPX walk in the test plan; UI tests with `XCUIDevice.shared.location`; denial and approximate location on a device.
````

## Summary

- Ask for **When In Use** when a feature needs location; ask for **Always** only for features that must work while the app isn't running, and only once. `NSLocationWhenInUseUsageDescription` is required, plus `NSLocationAlwaysAndWhenInUseUsageDescription` for Always; missing keys make requests fail immediately.
- People can share approximate location (usually 1 to 20 km). Design features that work with it, and ask for it on purpose when that's all you need.
- `CLLocationUpdate.liveUpdates()` (iOS 17) streams locations; iterating starts authorization; stop by breaking the loop. iOS 18 adds diagnostics such as `authorizationDenied` and `CLServiceSession`.
- `CLLocationManager.requestLocation()` gives one fix at the `desiredAccuracy` you set; wrap its delegate in a checked continuation that resumes exactly once.
- Save battery with the lowest accuracy, the largest distance filter (measured from the last delivered location), and stopping as soon as you're done.
- `CLMonitor` (iOS 17) watches conditions such as `CircularGeographicCondition`; at most 20 per app; the system relaunches the app for events, and you recreate the monitor by name.
- Test logic with constructed coordinates; test the app with a Simulated Location or GPX file in the test plan and `XCUIDevice.shared.location` in UI tests. Guidelines 5.1.5, 5.1.1(iv), 5.1.2(i) and 2.5.4 apply.

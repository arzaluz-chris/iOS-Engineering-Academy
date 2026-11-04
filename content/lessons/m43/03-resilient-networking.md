---
id: m43-l03
title: Resilient networking on real devices
description: "Module 30 built a client that retries and cancels correctly against a test server. Real phones add conditions that never happen at your desk: no connection, Low Data Mode, cellular and hotspots the system calls expensive, connections lost mid-request, and networks so slow that a request trickles for minutes. You split work into interactive and discretionary sessions with the configuration Apple recommends, show a waiting state instead of an error, adapt to constrained and expensive paths, cap slow transfers with the resource timeout, and decide per failure and per HTTP method whether to retry now, wait for connectivity, back off or stop."
module: m43
order: 3
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m43-l02, m30-l04, m37-l06]
objectives:
  - Describe the network conditions a device reports (unavailable, constrained, expensive) and what Low Data Mode means for an app.
  - Configure separate URLSessions for interactive and discretionary work, following Apple's guidance for waitsForConnectivity and constrained and expensive access.
  - Show a waiting state with urlSession(_:taskIsWaitingForConnectivity:) and handle networkUnavailableReason.
  - Explain how the request (idle) and resource timeouts behave on a slow network, and choose values for each kind of work.
  - Decide, per failure and per request, whether to retry immediately, wait for connectivity, back off or stop, including Apple's guidance for lost connections.
terms:
  - term: Low Data Mode
    definition: "A setting (iOS 13) that asks apps to reduce network data use. Paths in Low Data Mode are constrained: NWPath.isConstrained is true, and sessions with allowsConstrainedNetworkAccess = false don't use them."
  - term: Expensive network
    definition: "An interface the system considers costly; Apple: \"iOS 13 considers most cellular networks and personal hotspots expensive.\" NWPath.isExpensive reports it."
  - term: waitsForConnectivity
    definition: "A URLSessionConfiguration flag. When true and connectivity is unavailable, the task waits (calling the delegate's taskIsWaitingForConnectivity once) instead of failing; it applies only while establishing the connection. Background sessions always wait."
  - term: networkUnavailableReason
    definition: "A URLError property (iOS 13) set when a task failed because of the session's constraints: .constrained, .expensive or .cellular (and .ultraConstrained from iOS 26.1). nil for other failures."
  - term: Idempotent request
    definition: "A request that has the same effect whether it's sent once or several times: GET, HEAD, PUT and DELETE by HTTP's definition, or a POST carrying an idempotency key the server honors."
mastery:
  - Write the configuration for an interactive and a discretionary session and justify each property.
  - Map a failed request to a UI state using its URLError code and networkUnavailableReason.
  - Predict whether a trickling transfer finishes, hits the idle timeout or hits the resource timeout.
  - Trace a retry policy over a scripted sequence of failures and connectivity changes.
  - Choose image quality and prefetching from the path's constrained and expensive flags.
resources: [foundation-allows-constrained-network, network-nwpath-isconstrained, foundation-urlsessionconfiguration, foundation-urlsession, foundation-urlerror, network-nwpathmonitor, rfc-9110]
cards:
  - id: m43-l03-c1
    front: How does Apple suggest configuring discretionary network work?
    back: "Set allowsConstrainedNetworkAccess and allowsExpensiveNetworkAccess to false and waitsForConnectivity to true, so tasks wait for a suitable (Wi-Fi, non-Low-Data-Mode) interface. Keep constrained access for user-initiated tasks."
  - id: m43-l03-c2
    front: When is waitsForConnectivity consulted, and what tells the UI?
    back: "Only while establishing a connection: if it's unavailable, the task waits and the delegate's urlSession(_:taskIsWaitingForConnectivity:) is called at most once. A connection that drops mid-transfer still fails (for example with .networkConnectionLost). Background sessions ignore the flag and always wait."
  - id: m43-l03-c3
    front: Request timeout vs resource timeout on a slow network?
    back: "timeoutIntervalForRequest is an idle timeout reset whenever data arrives, so a slow trickle can keep a request alive indefinitely. timeoutIntervalForResource caps the whole transfer (default 7 days). Set a resource timeout for anything a person is waiting for."
  - id: m43-l03-c4
    front: Apple's guidance for NSURLErrorNetworkConnectionLost?
    back: "QA1941: idempotent requests can simply be retried, perhaps immediately once and then with your normal backoff. Non-idempotent requests need request-specific logic, such as a unique ID the app can use to ask the server whether the operation happened."
  - id: m43-l03-c5
    front: Is a POST that failed with notConnectedToInternet safe to resend?
    back: "Yes: no connection was made, so nothing reached the server. Wait for connectivity and send it. A POST that failed with a lost connection or a timeout may have reached the server; resend only with an idempotency key."
---

## The idea in one sentence

**A request on a phone doesn't succeed or fail; it waits, gets constrained, trickles, or drops halfway**, and a resilient app decides for each kind of work what to do in each of those cases, then tests it under those conditions instead of on office Wi-Fi.

> [!note] Sources and what was checked
> Behavior is quoted from Apple's reference pages for `URLSessionConfiguration` (`waitsForConnectivity`, `allowsConstrainedNetworkAccess`, `allowsExpensiveNetworkAccess`, `timeoutIntervalForResource`, `isDiscretionary`), `urlSession(_:taskIsWaitingForConnectivity:)`, `URLError.networkUnavailableReason` and `NWPath`, the articles "Reducing networking and Bluetooth power usage" and "Addressing watchdog terminations", and Technical Q&A QA1941 ("Handling 'The network connection was lost' Errors", an archived 2017 document still linked from the current `waitsForConnectivity` page), all read in November 2026. The Foundation and Network blocks are type-checked against the iOS SDK, not run, and nothing in this lesson was run on a device under real network conditions. The timeout and retry models are plain Swift, compiled and run with Swift 6.3, with a virtual clock and scripted failures.

## What Module 30 didn't have to face

Module 30's client maps errors into one type, retries GET requests with backoff and jitter, honors `Retry-After`, and stops when cancelled. Every test ran against canned responses. Pantry's support inbox shows what that misses:

- "The app says 'Something went wrong' on the train." The phone was between towers: **no connectivity** for 40 seconds.
- "My data plan is gone." Pantry prefetched every product image in the catalog on cellular, ignoring **Low Data Mode**.
- "I was charged twice." A POST to `/orders` lost its connection after the server received it, and the app sent it again.
- "Checkout spins forever." On a weak signal, the response trickled in a few bytes at a time, and the **idle timeout** kept resetting.

None of these appear on a developer's desk, which is why Apple's watchdog article warns: "If you always test your app in your office, where network connectivity is good, you'll never see this type of issue."

## The conditions a device reports

The Network framework describes the current route as an `NWPath`:

- **`status`**: whether "a path can be used by connections." `.satisfied` means there's a route; it doesn't mean your server answers (a hotel login page, or a server that's down, both look satisfied).
- **`isExpensive`**: "an interface that is considered expensive, such as Cellular or a Personal Hotspot."
- **`isConstrained`**: whether "the path uses an interface in Low Data Mode." People turn Low Data Mode on per cellular plan or per Wi-Fi network to ask apps to use less data.

`URLSession` uses the same information through configuration flags rather than through checks you write:

| Property | Apple's description |
| --- | --- |
| `waitsForConnectivity` | Whether the session "should wait for connectivity to become available, or fail immediately." Ignored by background sessions, "which always wait." |
| `allowsConstrainedNetworkAccess` | Whether connections "may use the network when the user has specified Low Data Mode." |
| `allowsExpensiveNetworkAccess` | Whether connections "may use a network interface that the system considers expensive." |
| `allowsCellularAccess` | Whether cellular may be used at all. |

When a constraint makes a task fail, the `URLError` says which: its `networkUnavailableReason` is `.constrained`, `.expensive` or `.cellular` (and, from iOS 26.1, `.ultraConstrained`). For any other failure it's `nil`.

Apple's advice on which flag to build policy on: "Prefer basing your app's policy logic around the `allowsConstrainedNetworkAccess` property rather than this one [expensive]. People using your app can use the 'Low Data Mode' setting to set the constrained status, and thereby choose to use a potentially expensive network." In other words, respect what the person chose, rather than guessing what their plan costs.

## Two kinds of work, two sessions

Apple's guidance on both constraint properties is the same: "Limit your app's use of constrained network access to user-initiated tasks, and put off discretionary tasks until a nonconstrained interface becomes available. To do this, set `allowsConstrainedNetworkAccess` (and `allowsExpensiveNetworkAccess`) to `false` and `waitsForConnectivity` to `true`."

Pantry sorts every request into one of two kinds:

- **Interactive:** the person tapped something and is looking at a spinner. Loading the cart, placing an order, searching.
- **Discretionary:** nobody is waiting. Prefetching catalog pages and images, uploading analytics, refreshing recommendations.

```swift ios
import Foundation
import Observation

@MainActor
@Observable
final class ConnectionStatus {
    static let shared = ConnectionStatus()
    private(set) var isWaitingForNetwork = false

    func waiting() { isWaitingForNetwork = true }
    func connected() { isWaitingForNetwork = false }
}

final class WaitingDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        Task { @MainActor in ConnectionStatus.shared.waiting() }
    }
}

enum PantrySessions {
    /// Someone is waiting: any network, wait briefly for one, never longer than 30 s in total.
    static let interactive: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration, delegate: WaitingDelegate(), delegateQueue: nil)
    }()

    /// Nobody is waiting: only unconstrained, inexpensive paths, and take as long as it needs.
    static let discretionary: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.allowsConstrainedNetworkAccess = false
        configuration.allowsExpensiveNetworkAccess = false
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForResource = 6 * 60 * 60
        return URLSession(configuration: configuration)
    }()
}
```

- **Interactive waits, but not for long.** With `waitsForConnectivity = true`, a request started in a tunnel doesn't fail with `.notConnectedToInternet`; it waits, and the delegate is told so the screen can say "Waiting for network…" instead of showing an error. Apple: the delegate "can use this opportunity to update the user interface; for example, by presenting an offline mode." The 30-second resource timeout bounds the wait, because the resource timer "starts when the request is initiated." Module 30 noted that waiting is often wrong for a screen; the difference here is that the screen shows the wait and the cap is short.
- **The waiting callback** is called "at most, once per task, and only if connectivity is initially unavailable." Clear the banner when the request completes (in the client, after `data(for:)` returns or throws).
- **Discretionary never uses Low Data Mode or cellular**, and waits up to six hours for Wi-Fi. A prefetch that never happens is fine; one that spends someone's data plan isn't.
- **Each session is created once**, as in Module 30: Apple's energy article also recommends "a single `URLSession` instance (rather than multiple instances) so you can re-use connections." Two long-lived sessions with different policies keep that benefit within each kind of work.
- Large downloads that may outlive the app go to a **background session** with `isDiscretionary = true`, which lets the system wait for "the device is plugged in and connected to the network via Wi-Fi" (Module 44).

### Waiting applies only before connecting

Apple is precise about the limit: "This property is relevant only during the establishment of a connection. If a connection is established and then drops, the completion handler or delegate receives an error, such as `NSURLErrorNetworkConnectionLost`." So `waitsForConnectivity` handles the tunnel at the start of a request, and the retry policy later in this lesson handles the tunnel in the middle of one.

### Overriding a constraint when the person asks

The constraint flags exist on `URLRequest` too. When a discretionary request fails because of Low Data Mode and the person then explicitly asks for that content, it becomes interactive:

```swift ios
import Foundation

enum ImageLoadError: Error {
    case blockedByLowDataMode
    case blockedByExpensiveNetwork
    case offline
    case other(URLError)
}

func classify(_ error: URLError) -> ImageLoadError {
    switch error.networkUnavailableReason {
    case .constrained?: return .blockedByLowDataMode
    case .expensive?: return .blockedByExpensiveNetwork
    default: break
    }
    if error.code == .notConnectedToInternet { return .offline }
    return .other(error)
}

/// Called when the person taps "Load full-size photo" on a product.
func loadFullSizePhoto(from url: URL) async throws -> Data {
    var request = URLRequest(url: url)
    request.allowsConstrainedNetworkAccess = true    // they asked for it
    request.allowsExpensiveNetworkAccess = true
    let (data, _) = try await URLSession.shared.data(for: request)
    return data
}
```

The `switch` on an optional enum uses `?` patterns, and falls through to the other checks for `nil`. A real client would also use the interactive session rather than `URLSession.shared`; it's shortened here.

## Adapting what you ask for

Waiting is one answer to a constrained path. The other is asking for less. Pantry's product images come in three sizes from its CDN, and the catalog chooses with a rule it can test:

```swift
enum ImageVariant: String {
    case thumbnail, standard, full
}

struct PathInfo {
    let isConstrained: Bool
    let isExpensive: Bool
}

/// Chooses the image size for a product detail screen.
func variant(for path: PathInfo, userAskedForFullSize: Bool) -> ImageVariant {
    if userAskedForFullSize { return .full }
    if path.isConstrained { return .thumbnail }
    return path.isExpensive ? .standard : .full
}

/// Prefetching is discretionary: only on paths that are neither constrained nor expensive.
func shouldPrefetch(on path: PathInfo) -> Bool {
    !path.isConstrained && !path.isExpensive
}

let paths: [(String, PathInfo)] = [
    ("home Wi-Fi", PathInfo(isConstrained: false, isExpensive: false)),
    ("cellular", PathInfo(isConstrained: false, isExpensive: true)),
    ("cellular, Low Data Mode", PathInfo(isConstrained: true, isExpensive: true)),
    ("hotel Wi-Fi, Low Data Mode", PathInfo(isConstrained: true, isExpensive: false)),
]
for (name, path) in paths {
    let image = variant(for: path, userAskedForFullSize: false)
    print("\(name): \(image.rawValue) images, prefetch \(shouldPrefetch(on: path) ? "on" : "off")")
}
print("tapped full size on cellular, Low Data Mode:", variant(for: paths[2].1, userAskedForFullSize: true).rawValue)
```

```output
home Wi-Fi: full images, prefetch on
cellular: standard images, prefetch off
cellular, Low Data Mode: thumbnail images, prefetch off
hotel Wi-Fi, Low Data Mode: thumbnail images, prefetch off
tapped full size on cellular, Low Data Mode: full
```

- **Low Data Mode wins over the interface type.** Someone who turned it on for a metered hotel Wi-Fi gets thumbnails even though Wi-Fi isn't expensive. That follows Apple's advice to build policy on the constrained flag.
- **An explicit request always wins.** That's the `URLRequest` override from the previous section.
- The path information comes from `NWPathMonitor`, which is also what Apple recommends instead of the synchronous `SCNetworkReachability` calls found in older code. It delivers updates on the queue you pass to `start(queue:)`:

```swift ios
import Foundation
import Network

final class PathWatcher: Sendable {
    private let monitor = NWPathMonitor()

    func start(on queue: DispatchQueue, onChange: @escaping @Sendable (_ online: Bool, _ constrained: Bool, _ expensive: Bool) -> Void) {
        monitor.pathUpdateHandler = { path in
            onChange(path.status == .satisfied, path.isConstrained, path.isExpensive)
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}

@MainActor
final class CatalogNetworkPolicy {
    private(set) var isOnline = true
    private(set) var isConstrained = false
    private(set) var isExpensive = false
    private let watcher = PathWatcher()

    func start() {
        // Updates are tiny, so deliver them on the main queue and apply them directly.
        watcher.start(on: .main) { [weak self] online, constrained, expensive in
            MainActor.assumeIsolated {
                self?.isOnline = online
                self?.isConstrained = constrained
                self?.isExpensive = expensive
            }
        }
    }
}
```

The handler runs on the queue passed to `start(queue:)`, here the main queue, which is what makes `MainActor.assumeIsolated` correct. `[weak self]` matters: the policy owns the watcher, the watcher's monitor owns the handler, and a strong `self` in the handler would close the loop.

Use the path to **adapt** (image sizes, prefetching, an "Offline" label), not to **gate** requests. Checking `isOnline` before every request races with the network changing and duplicates what `waitsForConnectivity` already does correctly.

## Timeouts on slow networks

Module 30 introduced the two timeouts: `timeoutIntervalForRequest` (and `URLRequest.timeoutInterval`) is an idle timeout, reset whenever data arrives; `timeoutIntervalForResource` "controls how long (in seconds) to wait for an entire resource to transfer before giving up," starting "when the request is initiated," with a default of 7 days. On a fast network the difference doesn't show. On a bad one it decides whether checkout spins for 30 seconds or for 20 minutes:

```swift
struct Transfer {
    let name: String
    let firstByteAfter: Int     // seconds after the request starts
    let chunkEvery: Int         // seconds between later chunks
    let chunks: Int
}

/// When data arrives: the first byte, then each chunk.
func arrivals(_ transfer: Transfer) -> [Int] {
    [transfer.firstByteAfter] + (0..<transfer.chunks).map { transfer.firstByteAfter + ($0 + 1) * transfer.chunkEvery }
}

func outcome(_ transfer: Transfer, idleTimeout: Int, resourceTimeout: Int) -> String {
    var lastActivity = 0
    for time in arrivals(transfer) {
        let idleDeadline = lastActivity + idleTimeout
        if time > idleDeadline || time > resourceTimeout {
            return idleDeadline < resourceTimeout
                ? "idle timeout at \(idleDeadline) s"
                : "resource timeout at \(resourceTimeout) s"
        }
        lastActivity = time
    }
    return "finished at \(lastActivity) s"
}

let transfers = [
    Transfer(name: "good signal", firstByteAfter: 1, chunkEvery: 1, chunks: 3),
    Transfer(name: "trickle", firstByteAfter: 2, chunkEvery: 20, chunks: 40),
    Transfer(name: "server stalls", firstByteAfter: 90, chunkEvery: 1, chunks: 3),
]
for transfer in transfers {
    print(transfer.name)
    print("  default (60 s idle, 7 days total):", outcome(transfer, idleTimeout: 60, resourceTimeout: 7 * 24 * 3_600))
    print("  interactive (15 s idle, 30 s total):", outcome(transfer, idleTimeout: 15, resourceTimeout: 30))
}
```

```output
good signal
  default (60 s idle, 7 days total): finished at 4 s
  interactive (15 s idle, 30 s total): finished at 4 s
trickle
  default (60 s idle, 7 days total): finished at 802 s
  interactive (15 s idle, 30 s total): idle timeout at 17 s
server stalls
  default (60 s idle, 7 days total): idle timeout at 60 s
  interactive (15 s idle, 30 s total): idle timeout at 15 s
```

- **The trickle is the dangerous case.** With the defaults, a chunk every 20 seconds keeps resetting the 60-second idle timer, and checkout "succeeds" after more than 13 minutes. Nobody waits that long; they force-quit and try again, which for a POST without an idempotency key is how double orders happen.
- **With the interactive values**, the 20-second gap exceeds the 15-second idle timeout. If chunks arrived every 10 seconds instead, the idle timer would never fire and the 30-second resource cap would end it.
- **A stalled server** is caught by either configuration's idle timeout; the interactive one just gives up sooner.
- The numbers are Pantry's choices. Apple documents the defaults (60 seconds idle, 7 days total), not what to pick. For interactive work, choose the total from how long a person will look at a spinner; for discretionary work, from how stale the data may get.

## Retrying under real conditions

Module 30's retry loop answers "should this response be retried?" Real devices add two more questions: **did the request reach the server?** and **is there a network to retry on?** Apple's QA1941 is direct about lost connections: "Requests that are idempotent can simply be retried. You might attempt an immediate retry, just in case there was a transient failure, and then back off." For non-idempotent ones, "you'll need request-specific retry logic," for example "a unique ID with each bank transfer" that the app can use to ask the server whether it already exists.

Pantry's policy, as a function, run against scripted failures with a virtual clock:

```swift
enum Failure {
    case notConnected        // no connection was made: nothing reached the server
    case connectionLost      // dropped mid-request: the server may have received it
    case timedOut            // same uncertainty as a lost connection
    case server(Int)         // a complete HTTP response
}

struct Request {
    let method: String
    let path: String
    let idempotencyKey: String?

    var isSafeToRepeat: Bool {
        ["GET", "HEAD", "PUT", "DELETE"].contains(method) || idempotencyKey != nil
    }
}

enum Decision {
    case retry(afterSeconds: Int)
    case waitForConnectivity
    case stop(String)
}

func decide(_ failure: Failure, for request: Request, attempt: Int, maxAttempts: Int = 4) -> Decision {
    if case .notConnected = failure { return .waitForConnectivity }   // safe even for POST
    guard request.isSafeToRepeat else {
        return .stop("may have reached the server; check the order's status")
    }
    guard attempt < maxAttempts else { return .stop("gave up after \(attempt) attempts") }
    switch failure {
    case .connectionLost where attempt == 1:
        return .retry(afterSeconds: 0)                                // QA1941: one immediate retry
    case .connectionLost, .timedOut, .server(502), .server(503), .server(504):
        return .retry(afterSeconds: min(2 << (attempt - 1), 30))      // 2, 4, 8… capped at 30
    case .server(let status):
        return .stop("HTTP \(status) won't change on retry")
    case .notConnected:
        return .waitForConnectivity
    }
}

/// Plays a request against scripted results. nil means success; connectivity returns at `onlineAt`.
func simulate(_ request: Request, results: [Failure?], onlineAt: Int = 0) {
    print("\(request.method) \(request.path)\(request.idempotencyKey.map { " (key \($0))" } ?? "")")
    var clock = 0
    for (index, result) in results.enumerated() {
        guard let failure = result else {
            print("  t=\(clock)s success")
            return
        }
        switch decide(failure, for: request, attempt: index + 1) {
        case .retry(let seconds):
            print("  t=\(clock)s \(failure) → retry in \(seconds)s")
            clock += seconds
        case .waitForConnectivity:
            clock = max(clock, onlineAt)
            print("  t=\(clock)s \(failure) → waited for connectivity")
        case .stop(let reason):
            print("  t=\(clock)s \(failure) → stop: \(reason)")
            return
        }
    }
}

simulate(Request(method: "GET", path: "/catalog", idempotencyKey: nil),
         results: [.connectionLost, .connectionLost, .timedOut, nil])
simulate(Request(method: "POST", path: "/orders", idempotencyKey: "7F3A"),
         results: [.notConnected, .timedOut, nil], onlineAt: 42)
simulate(Request(method: "POST", path: "/orders", idempotencyKey: nil),
         results: [.notConnected, .connectionLost], onlineAt: 42)
simulate(Request(method: "GET", path: "/cart", idempotencyKey: nil),
         results: [.server(503), .server(404)])
```

```output
GET /catalog
  t=0s connectionLost → retry in 0s
  t=0s connectionLost → retry in 4s
  t=4s timedOut → retry in 8s
  t=12s success
POST /orders (key 7F3A)
  t=42s notConnected → waited for connectivity
  t=42s timedOut → retry in 4s
  t=46s success
POST /orders
  t=42s notConnected → waited for connectivity
  t=42s connectionLost → stop: may have reached the server; check the order's status
GET /cart
  t=0s server(503) → retry in 2s
  t=2s server(404) → stop: HTTP 404 won't change on retry
```

- **`notConnected` is safe for every method.** No connection means no bytes reached the server, so even a POST without a key can be sent when the network returns. That's what `waitsForConnectivity` does for you at the start of a request; the model shows it explicitly.
- **A lost connection on GET** gets one immediate retry (QA1941), then backoff. The backoff here has no jitter so the output is reproducible; Module 30's full jitter belongs in the real client.
- **The POST without a key stops after a lost connection.** Retrying could charge twice; giving up silently could lose the order. QA1941's answer is to ask: Pantry generates the order's ID on the device and, after an uncertain failure, asks `GET /orders/{id}` whether it exists. The better fix is server-side support for an idempotency key, which turns the second POST case into the first.
- **`attempt` counts from 1**, so `2 << (attempt - 1)` gives 2 s after the first failure and doubles; `min(_, 30)` caps it. `server(404)` stops at once.
- **Retry while offline is pointless**: the policy never schedules a timed retry for `notConnected`. Combined with lesson 2's energy guidance, an app that's offline should be quiet until the path changes.

QA1941 also warns about the reverse mistake: "If you use an idempotent HTTP method for a non-idempotent request, that's very bad. NSURLSession might retry the request even though doing so is unsafe." In other words, `URLSession` itself may retry idempotent requests after a lost connection, so a `PUT` that isn't really idempotent can run twice without your code doing anything. The fix is on the server's API, not in the client.

## Offline as a normal state

Module 37 built the offline-first pieces: a local store, an outbox of pending writes, a sync engine with idempotent pushes. On top of that, a resilient screen:

- **Shows what it has.** The cached cart and catalog, with "Updated 2 hours ago" rather than a blank screen and an error.
- **Says what's happening, calmly.** "Waiting for network…" from the waiting delegate; "Offline. Your changes will sync" from the outbox. Not an alert.
- **Disables only what can't work.** Placing an order needs the server; editing the cart doesn't.
- **Retries without being asked** when the path becomes satisfied, through the sync engine's trigger (Module 37) or `waitsForConnectivity`, and **lets people ask** with pull to refresh.

## Testing under bad conditions

- **On a device:** Apple's `allowsExpensiveNetworkAccess` page says you can "override the device's current values for cellular and Wi-Fi cost in Settings > Developer > Network Override." Low Data Mode is in the Wi-Fi network's settings and in Cellular Data Options.
- **Degraded networks:** Apple's watchdog article says that "in Xcode, you can simulate adverse network conditions," pointing to the Xcode Help page "Test under adverse device conditions." That workflow wasn't checked for this lesson; follow the help page for your Xcode version.
- **In unit tests:** a transport fake (Module 30) or a `URLProtocol` subclass replays scripted results like the simulation above, including `URLError(.networkConnectionLost)` and slow responses, without a network.
- **On a train.** Someone on the team should use the app on a real commute before each major release.

## Common mistakes

> [!error] Treating every failure as "Something went wrong"
> Offline, constrained, lost connection and a 503 need different responses: wait, ask for less, retry, back off. Classify by `URLError.code` and `networkUnavailableReason` before deciding what to show.

> [!error] Prefetching over Low Data Mode
> A session with default settings uses constrained and expensive paths. Discretionary work belongs in a session with `allowsConstrainedNetworkAccess` and `allowsExpensiveNetworkAccess` set to `false` and `waitsForConnectivity` set to `true`.

> [!error] Checking reachability before each request
> The answer can change before the request starts, and the synchronous reachability APIs can hang the main thread. Issue the request with `waitsForConnectivity` and observe the path only to adapt the UI.

> [!error] No resource timeout on interactive requests
> The idle timeout resets with every chunk, and the default total is 7 days. Set `timeoutIntervalForResource` to how long a person will actually wait.

> [!error] Retrying a POST after a lost connection
> The server may already have processed it. Retry only with an idempotency key, or ask the server about the operation's ID first.

> [!error] Retrying on a timer while offline
> Nothing can succeed until the path changes, and each attempt costs energy. Wait for connectivity instead.

## Exercises

````exercise
id: m43-l03-e1
type: prediction
prompt: "The timeout model with an interactive configuration of 10 s idle and 45 s total. What does it print?"
code: |
  func outcome(arrivals: [Int], idleTimeout: Int, resourceTimeout: Int) -> String {
      var lastActivity = 0
      for time in arrivals {
          let idleDeadline = lastActivity + idleTimeout
          if time > idleDeadline || time > resourceTimeout {
              return idleDeadline < resourceTimeout
                  ? "idle timeout at \(idleDeadline) s"
                  : "resource timeout at \(resourceTimeout) s"
          }
          lastActivity = time
      }
      return "finished at \(lastActivity) s"
  }

  print(outcome(arrivals: [3, 6, 9], idleTimeout: 10, resourceTimeout: 45))
  print(outcome(arrivals: [2, 10, 18, 26, 34, 42, 50], idleTimeout: 10, resourceTimeout: 45))
  print(outcome(arrivals: [2, 14], idleTimeout: 10, resourceTimeout: 45))
  print(outcome(arrivals: [40, 50], idleTimeout: 60, resourceTimeout: 45))
output: |
  finished at 9 s
  resource timeout at 45 s
  idle timeout at 12 s
  resource timeout at 45 s
hints:
  - "In the second case, every gap is 8 s, under the idle timeout. Which arrival comes after 45 s?"
  - "In the last case, the idle timeout is longer than the resource timeout."
solution: |
  ```output
  finished at 9 s
  resource timeout at 45 s
  idle timeout at 12 s
  resource timeout at 45 s
  ```

  - **3, 6, 9:** every gap is under 10 s, and it ends well before 45 s.
  - **Every 8 s:** the idle timer never fires, but the arrival at 50 s is past the 45 s total. That's the trickle the resource timeout exists for.
  - **2, then 14:** 12 s of silence after the arrival at 2 s; the idle deadline is 12 s.
  - **Idle 60, total 45:** the arrival at 40 s is fine; the one at 50 s is past the 45 s total. Its idle deadline (40 + 60 = 100 s) is later than the resource timeout, so the resource timeout is the one that fires. An idle timeout longer than the total is legal, just pointless.
````

````exercise
id: m43-l03-e2
type: comprehension
prompt: "Pantry's discretionary session has allowsConstrainedNetworkAccess = false and waitsForConnectivity = false. The person is on cellular with Low Data Mode on. What happens to a prefetch request?"
choices:
  - text: "It fails, and the URLError's networkUnavailableReason is .constrained."
    correct: true
    why: "Apple: with no nonconstrained interface and the property false, \"any task created from the session fails,\" with networkUnavailableReason set to constrained."
  - text: "It waits until Wi-Fi without Low Data Mode is available."
    correct: false
    why: "That's what happens with waitsForConnectivity = true. Here it's false."
  - text: "It runs over cellular, because only expensive access is restricted by default."
    correct: false
    why: "The session explicitly disallows constrained paths, and this path is constrained."
  - text: "It runs, but URLSession automatically downloads a smaller version."
    correct: false
    why: "URLSession never changes what you asked for; choosing a smaller variant is the app's job."
solution: |
  Without `waitsForConnectivity`, a disallowed path makes the task fail immediately, with `networkUnavailableReason == .constrained`. That's not wrong for a prefetch (the app can just skip it), but Apple's recommended combination adds `waitsForConnectivity = true` so the task waits for a suitable interface instead of failing. Whichever you choose, don't show the person an error for work they didn't ask for.
````

````exercise
id: m43-l03-e3
type: fill-in
prompt: "Complete the discretionary session Apple's documentation recommends."
code: |
  static let discretionary: URLSession = {
      let configuration = URLSessionConfiguration.default
      configuration.[[1]] = false
      configuration.[[2]] = false
      configuration.[[3]] = true
      configuration.timeoutIntervalFor[[4]] = 6 * 60 * 60
      return URLSession(configuration: configuration)
  }()
blanks:
  - id: "1"
    answers: ["allowsConstrainedNetworkAccess", "allowsExpensiveNetworkAccess"]
  - id: "2"
    answers: ["allowsExpensiveNetworkAccess", "allowsConstrainedNetworkAccess"]
  - id: "3"
    answers: ["waitsForConnectivity"]
  - id: "4"
    answers: ["Resource"]
solution: |
  ```swift ios
  import Foundation

  enum Sessions {
      static let discretionary: URLSession = {
          let configuration = URLSessionConfiguration.default
          configuration.allowsConstrainedNetworkAccess = false
          configuration.allowsExpensiveNetworkAccess = false
          configuration.waitsForConnectivity = true
          configuration.timeoutIntervalForResource = 6 * 60 * 60
          return URLSession(configuration: configuration)
      }()
  }
  ```

  The first two keep discretionary work off Low Data Mode and off cellular and hotspots; `waitsForConnectivity` makes tasks wait for a suitable interface rather than fail; the resource timeout bounds the whole wait and transfer. Either order of the first two blanks is correct.
````

````exercise
id: m43-l03-e4
type: find-errors
prompt: "Pantry's old checkout code. Mark every real problem."
code: |
  func placeOrder(_ cart: Cart) async throws -> Order {
      guard NetworkReachability.isReachable() else {     // synchronous SCNetworkReachability check
          throw CheckoutError.offline
      }
      var request = URLRequest(url: ordersURL)
      request.httpMethod = "POST"
      request.httpBody = try JSONEncoder().encode(cart)
      for attempt in 1...3 {
          do {
              let (data, _) = try await URLSession.shared.data(for: request)
              return try JSONDecoder().decode(Order.self, from: data)
          } catch let error as URLError where error.code == .networkConnectionLost || error.code == .timedOut {
              if attempt == 3 { throw error }
          }
      }
      fatalError("unreachable")
  }
choices:
  - text: "The synchronous reachability check can block the calling thread and races with the network changing."
    correct: true
  - text: "The POST is retried after a lost connection or timeout with no idempotency key, which can create duplicate orders."
    correct: true
  - text: "URLSession.shared has a 7-day resource timeout, so a trickling response can keep checkout spinning for minutes."
    correct: true
  - text: "Retries happen immediately in a loop with no delay."
    correct: true
  - text: "JSONEncoder can't encode a cart for an HTTP body."
    correct: false
    why: "Encoding a Codable cart into the body is fine."
rubric:
  - I flagged the synchronous reachability preflight.
  - I flagged retrying a non-idempotent POST.
  - I flagged the missing resource timeout.
  - I flagged retrying without backoff.
solution: |
  - **Reachability preflight.** Apple names the synchronous reachability calls as a watchdog risk, and the answer can be stale by the time the request starts. Use a session with `waitsForConnectivity` and a short resource timeout, and show the waiting state.
  - **Duplicate orders.** A lost connection or timeout on a POST may mean the order exists. Send an idempotency key (generated once per checkout, reused on every attempt) or ask the server for the order's status before retrying.
  - **No total cap.** `URLSession.shared` uses the defaults; set `timeoutIntervalForResource` for a screen someone is watching.
  - **No backoff.** Three immediate attempts in a dead zone fail together. QA1941 suggests at most one immediate retry, then backoff.
````

````exercise
id: m43-l03-e5
type: solve
prompt: |
  Write `decide(_:method:hasKey:attempt:)` returning a short string, following the lesson's policy with a maximum of 3 attempts:

  - `"offline"` failures → `"wait"` for every request.
  - Requests that aren't safe to repeat (not GET/HEAD/PUT/DELETE and no key) → `"stop"`.
  - At the maximum attempt → `"stop"`.
  - `"lost"` on the first attempt → `"retry 0"`.
  - `"lost"`, `"timeout"`, `"503"` → `"retry N"` with N = 2, 4, 8… by attempt.
  - Anything else → `"stop"`.

  Expected output:

  ```output
  wait
  retry 0
  retry 4
  stop
  stop
  retry 2
  wait
  stop
  ```
starter: |
  func decide(_ failure: String, method: String, hasKey: Bool, attempt: Int) -> String {
      // your code
      return ""
  }

  print(decide("offline", method: "POST", hasKey: false, attempt: 1))
  print(decide("lost", method: "GET", hasKey: false, attempt: 1))
  print(decide("lost", method: "GET", hasKey: false, attempt: 2))
  print(decide("timeout", method: "GET", hasKey: false, attempt: 3))
  print(decide("lost", method: "POST", hasKey: false, attempt: 1))
  print(decide("timeout", method: "POST", hasKey: true, attempt: 1))
  print(decide("offline", method: "PATCH", hasKey: false, attempt: 3))
  print(decide("404", method: "GET", hasKey: false, attempt: 1))
hints:
  - "Check offline first: it's safe regardless of method or attempt."
  - "2 << (attempt - 1) gives 2, 4, 8."
rubric:
  - Waits for connectivity on offline failures for any request and attempt.
  - Stops unsafe requests after uncertain failures.
  - Stops at the maximum attempt.
  - Retries lost connections immediately once, then backs off; stops on other statuses.
solution: |
  ```swift
  func decide(_ failure: String, method: String, hasKey: Bool, attempt: Int) -> String {
      if failure == "offline" { return "wait" }
      let safe = ["GET", "HEAD", "PUT", "DELETE"].contains(method) || hasKey
      guard safe else { return "stop" }
      guard attempt < 3 else { return "stop" }
      if failure == "lost" && attempt == 1 { return "retry 0" }
      if ["lost", "timeout", "503"].contains(failure) { return "retry \(2 << (attempt - 1))" }
      return "stop"
  }

  print(decide("offline", method: "POST", hasKey: false, attempt: 1))
  print(decide("lost", method: "GET", hasKey: false, attempt: 1))
  print(decide("lost", method: "GET", hasKey: false, attempt: 2))
  print(decide("timeout", method: "GET", hasKey: false, attempt: 3))
  print(decide("lost", method: "POST", hasKey: false, attempt: 1))
  print(decide("timeout", method: "POST", hasKey: true, attempt: 1))
  print(decide("offline", method: "PATCH", hasKey: false, attempt: 3))
  print(decide("404", method: "GET", hasKey: false, attempt: 1))
  ```

  ```output
  wait
  retry 0
  retry 4
  stop
  stop
  retry 2
  wait
  stop
  ```

  The order of the checks is the policy. Offline comes first because nothing was sent, so even a PATCH at its last attempt can wait and go out later. Safety comes before the attempt count, because an unsafe request should stop on its first uncertain failure. In the app, these strings are the `Decision` enum from the lesson.
````

````exercise
id: m43-l03-e6
type: design
prompt: "Pantry is adding photo reviews: a person takes up to five photos (about 4 MB each) and writes a review in the store, often in the basement with poor signal. Design the networking: sessions, constraints, timeouts, what happens offline, after a lost connection, and under Low Data Mode, and how you'd test it."
rubric:
  - Separates the review text (small, user-initiated) from photo uploads (large, may take a long time).
  - Uses a background session or a persisted queue for photos, with idempotency for the review creation.
  - Respects Low Data Mode with a clear choice offered to the person, not silently.
  - Shows a calm pending state offline and syncs when connectivity returns; includes a test plan with scripted failures and on-device conditions.
solution: |
  - **Create the review with an ID generated on the device** and an idempotency key; the text is small and goes through the interactive session with `waitsForConnectivity` and a short resource timeout. A lost connection becomes a status check or a safe retry.
  - **Photos upload separately**, keyed by review ID and photo index, from files written to disk first. Use a background `URLSession` (it always waits for connectivity and continues if the app is suspended); `PUT /reviews/{id}/photos/{index}` is idempotent, so retries are safe.
  - **Low Data Mode:** the review text goes immediately; photos are queued with "Photos will upload on Wi-Fi" and a "Upload now" button that sets `allowsConstrainedNetworkAccess = true` on those requests. That's the person's choice, not the app's guess.
  - **Offline:** the review appears in "My reviews" as "Pending" from the outbox (Module 37), never as an error. Uploads start when the path is satisfied.
  - **Timeouts:** the photo session's resource timeout is long (hours); the text request's is about 30 s.
  - **Tests:** unit tests with a scripted transport for `notConnected`, `connectionLost` mid-upload, `timedOut` and 503; device tests with Network Override and Low Data Mode; a basement walk-through before release.
````

## Summary

- Devices report whether a path is satisfied, expensive (most cellular and hotspots) and constrained (Low Data Mode). Build policy on the constrained flag, as Apple recommends.
- Use one session for interactive work (waits for connectivity, shows a waiting state, short resource timeout) and one for discretionary work (no constrained or expensive access, waits, long resource timeout). Override constraints per request when the person explicitly asks.
- `waitsForConnectivity` only applies before connecting; a connection that drops mid-request fails with `.networkConnectionLost`. `networkUnavailableReason` tells you which constraint blocked a task.
- The request timeout is idle time and resets with each chunk; on a trickling network only `timeoutIntervalForResource` (default 7 days) ends the request. Set it for anything a person waits for.
- Retry by what you know: `notConnected` reached nobody (wait, then send); a lost connection or timeout may have reached the server (retry only idempotent requests, one immediate retry then backoff, per QA1941); HTTP errors other than 502–504 don't change on retry.
- Treat offline as a normal state, adapt image size and prefetching to the path, and test with Network Override, Low Data Mode, adverse-condition simulation and scripted failures.

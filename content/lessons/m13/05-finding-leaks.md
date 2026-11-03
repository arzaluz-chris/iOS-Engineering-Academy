---
id: m13-l05
title: Finding leaks
description: You learn what a leak looks like from the outside, make objects report their own death with deinit logging, write a leak check that creates an object, drops it and asserts that a weak reference became nil, and follow a step-by-step workflow with Xcode's memory report, the Memory Graph Debugger and the Leaks and Allocations instruments.
module: m13
order: 5
level: beginner
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m13-l04]
objectives:
  - Recognize the symptoms of a leak in a running app.
  - Use deinit logging to confirm that objects are freed when you expect.
  - Write a leak check with a weak reference and a scope, and explain why each part is there.
  - Describe how the memory report, the Memory Graph Debugger, and the Leaks and Allocations instruments each help, and in what order to use them.
  - Tell a leak apart from abandoned memory that leak tools don't report.
terms:
  - term: Memory leak
    definition: "Memory that's allocated but can no longer be reached or freed. In Swift apps the usual cause is a reference cycle."
  - term: Abandoned memory
    definition: "Memory the app can still reach but will never use again, such as a cache that only grows. Leak detectors don't report it, because it isn't unreachable."
  - term: Leak check
    definition: "A small test: create an object in a scope, keep only a weak reference to it, leave the scope, and check that the weak reference is nil."
  - term: Memory graph
    definition: "A snapshot Xcode captures of a running app's objects and allocations, drawn as nodes connected by arrows that show which object refers to which."
  - term: Instruments
    definition: "Apple's profiling app, opened from Xcode with Product > Profile. Its Leaks instrument reports unreachable memory; its Allocations instrument tracks the number and size of allocations over time."
mastery:
  - List three symptoms that suggest a leak and say how you'd confirm each.
  - Write a generic function that reports whether an object built by a closure is freed.
  - Explain why a leak check that assigns a new object straight to a weak variable always passes.
  - Describe, step by step, how to find which reference keeps a screen alive using the Memory Graph Debugger.
  - Choose between the Leaks and Allocations instruments for a given symptom.
resources: [xcode-memory-use, xcode-reduce-memory, swift-book-arc, swift-book-closures]
cards:
  - id: m13-l05-c1
    front: What's the shape of a leak check?
    back: "Declare weak var probe. In a do block, create the object, use it, set probe = object. After the block, probe must be nil; if it isn't, something still owns the object."
  - id: m13-l05-c2
    front: Why doesn't the Leaks instrument catch an ever-growing cache?
    back: "The cache is still reachable from the app, so it isn't a leak by definition. That's abandoned memory. Use the Allocations instrument's generations to find it."
  - id: m13-l05-c3
    front: What does the Debug Memory Graph button give you?
    back: "A snapshot of the app's objects and allocations at that moment, with arrows showing which object refers to which. You can find a leaked object and see who still points at it."
  - id: m13-l05-c4
    front: Does wrapping code in autoreleasepool fix a reference cycle?
    back: "No. autoreleasepool controls when Objective-C autoreleased objects are released. A cycle's strong references stay in place until you break one."
---

## The idea in one sentence

Leaks are silent, so you make objects announce when they're freed and then check that they are, first with `deinit` prints and a small test, then with Xcode's memory tools when you don't know where to look.

## What a leak looks like from outside

A leaked object doesn't crash anything. You notice its side effects:

- **Memory goes up and doesn't come back.** You open and close the same screen ten times, and memory use climbs a little each time.
- **`deinit` never runs.** If you've added a log line to `deinit`, it's missing when you close the screen.
- **Old objects still react.** You open a screen twice, and an event that should update one screen is handled twice: the first, closed screen is still alive and still listening.
- **Work happens for nobody.** A closed screen keeps refreshing, downloading or printing.

The first symptom tells you something is wrong. The others tell you **what** is still alive.

### Leaks and abandoned memory

Apple's documentation separates two problems. A **leak** is memory that the app can no longer reach and can't free, such as a reference cycle that nothing points into. **Abandoned memory** is memory the app can still reach but will never use again: a dictionary cache that only grows, an array of every message the user ever scrolled past. Leak detectors only find the first kind. The second kind looks the same on a memory graph (it climbs) and needs a different tool, covered below.

## deinit logging

The cheapest diagnostic is a print in `deinit`. Here's a screen that subscribes to a shared event center and leaks, which you can see by opening it twice:

```swift
final class EventCenter {
    private var handlers: [(String) -> Void] = []

    func subscribe(_ handler: @escaping (String) -> Void) {
        handlers.append(handler)
    }

    func post(_ event: String) {
        for handler in handlers {
            handler(event)
        }
    }
}

final class InboxScreen {
    let id: Int

    init(id: Int, center: EventCenter) {
        self.id = id
        center.subscribe { event in
            self.show(event)
        }
    }

    func show(_ event: String) {
        print("Inbox \(id) shows \(event)")
    }

    deinit {
        print("Inbox \(id) freed")
    }
}

let center = EventCenter()
var inbox: InboxScreen? = InboxScreen(id: 1, center: center)
inbox = nil
inbox = InboxScreen(id: 2, center: center)
center.post("new mail")
```

```output
Inbox 1 shows new mail
Inbox 2 shows new mail
```

Two symptoms at once: "Inbox 1 freed" never prints, and the first inbox still handles events after it was closed. This isn't even a cycle. The center lives for the whole program and stores a closure that captures the screen strongly, so the screen lives for the whole program too.

With `[weak self]`, the first screen is freed when it's replaced, and only the live screen reacts:

```swift
final class EventCenter {
    private var handlers: [(String) -> Void] = []

    func subscribe(_ handler: @escaping (String) -> Void) {
        handlers.append(handler)
    }

    func post(_ event: String) {
        for handler in handlers {
            handler(event)
        }
    }
}

final class InboxScreen {
    let id: Int

    init(id: Int, center: EventCenter) {
        self.id = id
        center.subscribe { [weak self] event in
            self?.show(event)
        }
    }

    func show(_ event: String) {
        print("Inbox \(id) shows \(event)")
    }

    deinit {
        print("Inbox \(id) freed")
    }
}

let center = EventCenter()
var inbox: InboxScreen? = InboxScreen(id: 1, center: center)
inbox = nil
inbox = InboxScreen(id: 2, center: center)
center.post("new mail")
```

```output
Inbox 1 freed
Inbox 2 shows new mail
```

The center still holds the first screen's closure, which now does nothing when called. That's a small, real cost: a list of dead handlers that grows each time the screen opens. The next lesson fixes it properly with an unsubscribe step.

A practical habit: while you build a feature, give every screen, view model and service a `deinit` print, and watch the console as you close screens. Remove the prints, or route them through a debug-only logger, before you ship.

## A leak check you can run

Prints need a human to read them. A **leak check** turns "this object should be freed" into something code can verify:

```swift
final class TimerScreen {
    var onTick: (() -> Void)?
    var seconds = 0

    func start() {
        onTick = { [weak self] in
            self?.seconds += 1
        }
    }
}

weak var probe: TimerScreen?
do {
    let screen = TimerScreen()
    screen.start()
    screen.onTick?()
    probe = screen
}
print(probe == nil ? "freed" : "LEAK")
```

```output
freed
```

Each part has a job:

1. `weak var probe` lets you look at the object later without keeping it alive. A strong variable here would itself be the leak.
2. The `do { }` block is a scope. `screen` is the only strong reference, and it ends with the block.
3. Inside the block, you **use** the object the way the app does: here, `start()` and one tick. A leak usually comes from a method that sets something up; checking a freshly created object proves little.
4. After the block, the object should have no owners. If `probe` is still not `nil`, something holds on to it.

Remove `[weak self]` from `start()` and the same check prints `LEAK`.

You can wrap the pattern in a generic function (Module 11) and reuse it for any class. `T: AnyObject` restricts `T` to classes, which `weak` requires:

```swift
func checkFreed<T: AnyObject>(_ label: String, _ make: () -> T) {
    weak var probe: T?
    do {
        let object = make()
        probe = object
    }
    print(probe == nil ? "\(label): freed" : "\(label): LEAK")
}

final class Cart {
    var items: [String] = []
    var onChange: (() -> Void)?

    func watch() {
        onChange = {
            print(self.items.count)
        }
    }
}

final class Wishlist {
    var items: [String] = []
    var onChange: (() -> Void)?

    func watch() {
        onChange = { [weak self] in
            print(self?.items.count ?? 0)
        }
    }
}

checkFreed("Cart") {
    let cart = Cart()
    cart.watch()
    return cart
}
checkFreed("Wishlist") {
    let list = Wishlist()
    list.watch()
    return list
}
```

```output
Cart: LEAK
Wishlist: freed
```

The `make` closure builds the object and runs the setup that might leak. It's non-escaping, so it's gone by the time `checkFreed` looks at `probe`.

### The same check in a test

In a real project, this check belongs in your unit tests, so a leak introduced next month fails the build. You'll write tests in Module 33; here's how the pattern looks with Swift Testing. It's marked as not run, because the course's snippet tests compile plain programs, not test targets:

```swift illustrative
import Testing

@Test func timerScreenIsFreed() {
    weak var probe: TimerScreen?
    do {
        let screen = TimerScreen()
        screen.start()
        probe = screen
    }
    #expect(probe == nil)
}
```

With XCTest, a common version registers the check to run after each test: `addTeardownBlock { [weak sut] in XCTAssertNil(sut) }`, where `sut` is the object under test.

> [!warning] Debug builds and leak checks
> The check relies on the object being released at the end of the `do` block. In debug builds, which is how tests normally run, that's what happens. The rule from lesson 1 still holds: Swift only promises an object lives until its last use, so the check can say "freed" earlier, never later. A `LEAK` result is real.

## Xcode's memory tools

The tools in this section are part of Xcode and Instruments on a Mac. The steps below follow Apple's article [Gathering information about memory use](https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use) and [Making changes to reduce memory use](https://developer.apple.com/documentation/xcode/making-changes-to-reduce-memory-use). They weren't run as part of this course's tests, and menu names can shift between Xcode versions, so check the articles if a button isn't where this says.

### 1. Watch the memory report

While your app runs from Xcode, open the **Debug navigator** and select **Memory**. The memory report shows current use and the highest value seen so far. A yellow region on the gauge means use is high enough to trigger a memory warning; red means iOS may terminate the app.

Repeat the suspect action several times: open and close the screen, run the search, log in and out. If memory climbs with every repetition and doesn't drop back, keep going.

In the **Simulator**, the gauge always stays green, because macOS doesn't send memory warnings or terminate the app for memory use. That's handy for investigating, but green in the simulator doesn't mean you're within safe limits on a device.

### 2. Capture a memory graph

With the app still running after a few repetitions, click the **Debug Memory Graph** button in the debug bar at the bottom of the Xcode window. Xcode captures a graph of the app's objects and allocations at that moment.

- Each **node** is an object, a heap allocation or a memory-mapped file.
- Each **arrow** shows that one region refers to another.

Find your type in the list on the left, for example `InboxScreen`. If you closed the screen and there are still instances, select one. The graph shows the references pointing at it. Follow them backwards until you find the one that shouldn't be there: a closure context owned by an event center, a `delegate` that isn't weak, a parent pointer that is strong.

Two options make the graph more useful:

- To see **where** each object was allocated, turn on **Malloc Stack** in the Diagnostics section of your scheme's Run settings. The inspector then shows the call stack recorded when the node was allocated.
- **File > Export Memory Graph** saves the graph so you can share it or inspect it with the `leaks` and `vmmap` command-line tools.

### 3. Profile with Instruments

Choose **Product > Profile** to build the app and open Instruments, then pick a template:

- **Leaks.** The Leaks instrument periodically scans the app's memory and reports regions that are allocated but unreachable, with their address, size, and a stack trace of the code that allocated them. Reference cycles show up here, because nothing outside the cycle can reach it.
- **Allocations.** Tracks the number and size of heap allocations, grouped by category, on a timeline. Its **Generations** view is the tool for abandoned memory: get the app ready to use the feature, click **Mark Generation**, use the feature, click **Mark Generation** again. Instruments groups allocations by the interval they were made in, so you can see what that one feature allocated and never released. Repeat the cycle a few times; allocations that pile up in every generation are the ones to explain.

### The workflow, in order

1. Notice a symptom (memory climbs, `deinit` missing, events handled twice).
2. Reproduce it with a short, repeatable action.
3. Memory report: confirm memory grows with each repetition.
4. Memory graph: find the instances that should be gone and follow the arrows to the reference that keeps them alive.
5. Fix the reference (weak, unowned, a capture list, an unsubscribe).
6. Write a leak check for that object so it stays fixed.
7. If nothing is leaked but memory still grows, use Allocations with generations to find abandoned memory.

> [!note] autoreleasepool doesn't fix cycles
> You may see `autoreleasepool { … }` around loops in older Apple-platform code. It controls when Objective-C **autoreleased** objects are released, which can lower peak memory inside a loop. It doesn't touch strong references between your objects, so a cycle survives it unchanged.

## Common mistakes

> [!warning] warning: instance will be immediately deallocated because variable 'probe' is 'weak'
> Writing `probe = Screen()` assigns a new object directly to a weak variable. Nothing owns it, so it's freed at once and the check passes no matter how leaky the class is. Create the object in a strong local first, use it, then assign the probe.

```swift warning instance will be immediately deallocated because variable 'probe' is 'weak'
final class Screen {
    var onTap: (() -> Void)?

    func start() {
        onTap = { print(self) }
    }
}

weak var probe: Screen?
probe = Screen()
probe?.start()
print(probe == nil ? "freed" : "LEAK")
```

```output
freed
```

> [!error] Keeping a strong reference outside the scope
> If `let screen` lives outside the `do` block, or you store the object in an array to "check it later", the check always reports `LEAK`. The only strong reference should end with the scope.

> [!error] Checking an object without using it
> Many leaks only appear after a method runs (`start()`, `bind()`, `subscribe()`). A check that only creates the object misses them.

> [!error] Expecting Leaks to find a growing cache
> A cache you still reference isn't unreachable, so it's not a leak by definition. Use Allocations generations, and give the cache a size limit or an eviction rule.

````exercise
id: m13-l05-e1
type: comprehension
prompt: "Users report that the app's memory grows the longer they scroll the feed. Leaks shows nothing, and every screen's deinit runs on schedule. What's the most likely explanation, and which tool do you use next?"
choices:
  - text: "Abandoned memory, such as a cache of loaded posts that only grows. Use the Allocations instrument with Mark Generation while scrolling."
    correct: true
    why: "Reachable-but-unused memory doesn't show up in Leaks. Generations isolate what the scrolling allocates and keeps."
  - text: "A reference cycle that Leaks missed. Run Leaks again for longer."
    correct: false
    why: "Possible but unlikely when every deinit runs. Growth without unreachable memory points to abandoned memory."
  - text: "The simulator always shows growing memory. Test on a device."
    correct: false
    why: "The simulator's gauge stays green, but it still reports real use. The growth is real."
  - text: "Wrap the feed's code in autoreleasepool."
    correct: false
    why: "autoreleasepool doesn't bound a cache that your code keeps referencing."
solution: |
  **Abandoned memory, found with Allocations.** Leaks reports memory that can't be reached. A dictionary of every post the user has seen is still reachable, so it's not a leak, just memory that never gets used again. Mark a generation, scroll, mark again, and look at what that interval allocated and kept. The fix is usually an upper bound or an eviction rule for the cache.
````

````exercise
id: m13-l05-e2
type: prediction
prompt: Predict the exact output.
code: |
  func checkFreed<T: AnyObject>(_ label: String, _ make: () -> T) {
      weak var probe: T?
      do {
          let object = make()
          probe = object
      }
      print(probe == nil ? "\(label): freed" : "\(label): LEAK")
  }

  final class Node {
      var next: Node?
      weak var previous: Node?
  }

  checkFreed("single") {
      Node()
  }
  checkFreed("forward pair") {
      let first = Node()
      let second = Node()
      first.next = second
      second.previous = first
      return first
  }
  checkFreed("loop") {
      let first = Node()
      let second = Node()
      first.next = second
      second.next = first
      return first
  }
output: |
  single: freed
  forward pair: freed
  loop: LEAK
hints:
  - "next is strong, previous is weak."
  - "In the last case, follow next from first and you come back to first."
solution: |
  ```output
  single: freed
  forward pair: freed
  loop: LEAK
  ```

  A single node has one owner, the local constant. In the forward pair, `first` owns `second` through `next`, and `second` points back weakly, so dropping `first` frees both. In the loop, both links are `next`, which is strong: `first` owns `second` and `second` owns `first`. That's a two-object cycle, and the probe is still set after the scope ends.
````

````exercise
id: m13-l05-e3
type: find-errors
prompt: "Two teammates wrote leak checks for `PlayerScreen`, whose `start()` method stores a closure that captures self strongly. Neither check catches the leak correctly. Which statements are true?"
code: |
  // Check A
  weak var probeA: PlayerScreen?
  probeA = PlayerScreen()
  probeA?.start()
  print(probeA == nil ? "A: freed" : "A: LEAK")

  // Check B
  let screen = PlayerScreen()
  weak var probeB: PlayerScreen?
  do {
      screen.start()
      probeB = screen
  }
  print(probeB == nil ? "B: freed" : "B: LEAK")
choices:
  - text: "Check A assigns a new object straight to a weak variable. It's freed immediately, start() never runs, and the check always says freed."
    correct: true
    why: "Nothing owns the object, so probeA is nil before start() is even called."
  - text: "Check B always says LEAK, even for a class with no leak, because screen is declared outside the do block."
    correct: true
    why: "The strong constant outlives the scope, so the object is alive when probeB is checked."
  - text: "Check A would work if probeA were a strong var."
    correct: false
    why: "Then probeA itself would keep the object alive and the check would always say LEAK."
  - text: "Check B is correct; the do block makes everything inside it temporary."
    correct: false
    why: "Only names declared inside the block end with it. screen is declared outside."
rubric:
  - I explained why check A is always "freed".
  - I explained why check B is always "LEAK".
  - My fixed check creates the object in a strong local inside the scope, uses it, then assigns the weak probe.
solution: |
  A correct check creates the object **inside** the scope, in a strong local, uses it, and only then points the weak probe at it:

  ```swift
  final class PlayerScreen {
      var onFinish: (() -> Void)?

      func start() {
          onFinish = { print(self) }
      }
  }

  weak var probe: PlayerScreen?
  do {
      let screen = PlayerScreen()
      screen.start()
      probe = screen
  }
  print(probe == nil ? "freed" : "LEAK")
  ```

  ```output
  LEAK
  ```

  Now the check reports the real leak. Add `[weak self]` to the closure in `start()` and it reports `freed`.
````

````exercise
id: m13-l05-e4
type: solve
prompt: |
  Use `checkFreed` to test `MapScreen` after calling `showRoute()`. It leaks. Find the leak, fix the class, and make the program print exactly:

  ```output
  Route: 3 stops
  MapScreen: freed
  ```
starter: |
  func checkFreed<T: AnyObject>(_ label: String, _ make: () -> T) {
      weak var probe: T?
      do {
          let object = make()
          probe = object
      }
      print(probe == nil ? "\(label): freed" : "\(label): LEAK")
  }

  final class RouteRenderer {
      var onDraw: ((Int) -> Void)?

      func draw(stops: Int) {
          onDraw?(stops)
      }
  }

  final class MapScreen {
      let renderer = RouteRenderer()
      var title = "Route"

      func showRoute() {
          renderer.onDraw = { stops in
              print("\(self.title): \(stops) stops")
          }
          renderer.draw(stops: 3)
      }
  }

  checkFreed("MapScreen") {
      let screen = MapScreen()
      screen.showRoute()
      return screen
  }
hints:
  - "Trace from the closure: who stores it, and who owns that?"
  - "Either [weak self] or capturing only title fixes it."
rubric:
  - I identified the cycle screen → renderer → onDraw → screen.
  - I broke it with [weak self] or a capture of title.
  - The check prints freed.
  - The output matches exactly.
solution: |
  ```swift
  func checkFreed<T: AnyObject>(_ label: String, _ make: () -> T) {
      weak var probe: T?
      do {
          let object = make()
          probe = object
      }
      print(probe == nil ? "\(label): freed" : "\(label): LEAK")
  }

  final class RouteRenderer {
      var onDraw: ((Int) -> Void)?

      func draw(stops: Int) {
          onDraw?(stops)
      }
  }

  final class MapScreen {
      let renderer = RouteRenderer()
      var title = "Route"

      func showRoute() {
          renderer.onDraw = { [weak self] stops in
              guard let self else { return }
              print("\(title): \(stops) stops")
          }
          renderer.draw(stops: 3)
      }
  }

  checkFreed("MapScreen") {
      let screen = MapScreen()
      screen.showRoute()
      return screen
  }
  ```

  ```output
  Route: 3 stops
  MapScreen: freed
  ```

  The screen owns the renderer, the renderer stores `onDraw`, and `onDraw` captured the screen. `[weak self]` breaks the third link. Capturing `[title]` would also work, with one difference: `title` is a `var`, so the closure would keep the value it had when `showRoute()` ran instead of reading the current one.
````

````exercise
id: m13-l05-e5
type: design
prompt: |
  QA reports: "Every time I open and close the Order Details screen, memory goes up by about 2 MB and never comes back." Write the step-by-step plan you'd follow, from reproducing the problem to making sure it never comes back. Name the tool you use at each step and what you expect to see.
rubric:
  - I reproduce with a short repeatable action (open and close the screen N times).
  - I confirm the growth with the memory report in Xcode's Debug navigator.
  - I check for missing deinit logs on the screen and its view model.
  - I capture a memory graph, find leftover OrderDetails instances and follow the arrows to the owning reference.
  - I fix the reference and verify with the memory report again.
  - I add a leak check test for the screen or view model.
  - I mention Allocations generations as the next step if nothing is leaked.
solution: |
  1. **Reproduce.** Open and close Order Details five times in a row from the same starting screen.
  2. **Confirm with the memory report.** In Xcode's Debug navigator, the Memory gauge should step up after each open-and-close and not drop back.
  3. **Check `deinit`.** Add (or look for) `deinit` prints in the screen and its view model. If "OrderDetailsViewModel freed" never appears, the view model is alive.
  4. **Capture a memory graph.** Click Debug Memory Graph after the five repetitions. Filter the list for `OrderDetails`. Five lingering view models confirm the leak. Select one and follow the arrows pointing at it: typically a closure context stored by a long-lived service, or a non-weak delegate. Turn on Malloc Stack in the scheme's Diagnostics if you need to see where an object was created.
  5. **Fix** the reference: `[weak self]` in the closure, `weak var delegate`, or an unsubscribe when the screen closes.
  6. **Verify.** Repeat steps 1–3: memory flat, `deinit` prints.
  7. **Lock it in.** Add a leak check test: create the view model in a `do` block, call the method that subscribes, assign a weak probe, and expect it to be `nil` afterwards.
  8. **If no instances are leaked** but memory still grows, profile with the Allocations instrument, mark a generation before and after each open-and-close, and look for allocations that pile up: that's abandoned memory, such as an image cache with no limit.
````

````exercise
id: m13-l05-e6
type: explain
prompt: Explain the role of each marked part of this leak check, and what would go wrong without it.
code: |
  weak var probe: Screen?        // (1)
  do {                           // (2)
      let screen = Screen()      // (3)
      screen.start()             // (4)
      probe = screen             // (5)
  }
  print(probe == nil ? "freed" : "LEAK")
rubric:
  - (1) weak, so the probe doesn't own the object; a strong probe would always say LEAK.
  - (2) the scope ends the only strong reference; without it, screen would stay alive.
  - (3) a strong local owns the object while it's being used; assigning straight to the weak probe frees it at once.
  - (4) using the object runs the setup that might leak; without it the check proves little.
  - (5) the probe is assigned last, after setup.
solution: |
  1. `weak var probe` lets you check the object afterwards without owning it. If it were strong, it would keep the object alive and the check would always print `LEAK`.
  2. The `do` block is a scope: `screen` ends with it. Without the block, `screen` would be a top-level constant that lives for the whole program, and the check would always print `LEAK`.
  3. `let screen` is a strong owner while you work with the object. Writing `probe = Screen()` instead would free the object immediately (the compiler warns about this), and the check would always print `freed`.
  4. `screen.start()` runs the code that might create a cycle. Most leaks come from setup methods, not from `init` alone.
  5. `probe = screen` records which object to look at. After the block, the only question left is whether anything else still owns it.
````

## Summary

- Symptoms of a leak: memory that climbs with each repetition, missing `deinit` logs, closed screens still reacting, work done for nobody.
- `deinit` prints are the cheapest check. A leak check makes it automatic: strong local in a scope, use it, weak probe, expect `nil`.
- `T: AnyObject` lets you write the check once, generically, for any class.
- Xcode workflow: memory report to confirm growth, Memory Graph Debugger to find who holds the object, then fix and add a check.
- Instruments: **Leaks** finds unreachable memory such as cycles; **Allocations** with generations finds memory that's still reachable but never used again.
- `autoreleasepool` doesn't break cycles.

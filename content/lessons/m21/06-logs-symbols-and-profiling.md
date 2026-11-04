---
id: m21-l06
title: Logs, symbols and a first look at profiling
description: The three tools you use when an app misbehaves where you can't attach a debugger. You write structured logs with Logger and decide what each message may reveal, learn how crash reports turn hexadecimal addresses into function names with dSYM files, symbolicate Apple's own example by hand, and read a Time Profiler call tree to find where the main thread spends its time.
module: m21
order: 6
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m21-l05]
objectives:
  - Write log messages with Logger using a subsystem, a category and the right level.
  - Apply privacy options so personal data is redacted and useful values stay visible.
  - Explain what a dSYM is, how it's matched to a build, and why you keep it.
  - Symbolicate a backtrace address from a load address, an offset and a symbol table.
  - Record a Time Profiler trace from a Release build and read self time, total time and the heaviest stack trace.
terms:
  - term: Unified logging
    definition: "Apple's system-wide log store. Messages are kept in memory and, depending on level, written to disk in a compressed binary format. Read them in Xcode's console, the Console app or the log tool."
  - term: Logger
    definition: "The Swift structure in the os framework for writing to the unified log, created with a subsystem (reverse-DNS) and a category."
  - term: Redaction
    definition: "Replacing an interpolated value with a generic placeholder in the log. By default dynamic strings and objects are redacted; integers, floating-point numbers and Booleans aren't."
  - term: Symbolication
    definition: "Translating the hexadecimal addresses in a backtrace into function names, files and line numbers using the build's debug symbols."
  - term: dSYM
    definition: "A companion file holding a binary's debug symbols (DWARF). It matches exactly one build, identified by a build UUID that both the binary and the dSYM record."
  - term: Load address
    definition: "Where a binary was placed in memory for one run. It changes between runs (ASLR), so crash addresses are converted to offsets from it before looking up symbols."
  - term: Time Profiler
    definition: "An Instruments template that samples the call stacks of your threads at intervals and builds a call tree showing where CPU time goes."
mastery:
  - Create a Logger per feature area and pick debug, info, notice, error or fault for a message.
  - Predict which interpolated values in a log message are redacted by default, and mark them public, private or hashed on purpose.
  - Say where dSYMs come from, which build setting controls them and what goes wrong without the matching one.
  - Compute an offset from a backtrace address and a load address, and find the containing function in a sorted symbol table.
  - Profile a Release build on a device and use self weight, total weight and the heaviest stack trace to pick what to optimize.
resources: [os-logger, xcode-symbolicate-crash-report, xcode-memory-use, lldb-tutorial, owasp-masvs]
cards:
  - id: m21-l06-c1
    front: Which Logger levels are persisted to disk by default?
    back: "Debug: no (memory only). Info: only when collected with the log tool. Notice (default), error and fault: yes, up to a storage limit."
  - id: m21-l06-c2
    front: "logger.info(\"User \\(email) retried \\(count) times\"): what's visible by default?"
    back: "count (an integer) is shown; email (a dynamic string) is redacted. Mark values .public only when they can't identify anyone, and use .private(mask: .hash) to correlate without revealing."
  - id: m21-l06-c3
    front: What ties a dSYM to a specific build?
    back: "A build UUID recorded in both the binary and its dSYM. They only match if they came from the same build; rebuilding the same source gives a different UUID. Keep the Xcode archive of every build you distribute."
  - id: m21-l06-c4
    front: How do you turn a backtrace address into a function name by hand?
    back: "Subtract the binary's load address (from the Binary Images section) to get an offset, then find the function containing that offset in the dSYM's symbols. atos does this: atos -arch arm64 -o <dSYM DWARF file> -l <load address> <address>."
  - id: m21-l06-c5
    front: Self weight vs total weight in a Time Profiler call tree?
    back: "Self weight counts samples where the function itself was running. Total weight also counts samples where it was waiting on functions it called. High self weight is the code to optimize; high total weight shows the path to it."
---

## The idea in one sentence

When an app fails on someone else's phone you can't step through it, so you rely on three things you prepared in advance: **logs** that recorded what happened without leaking personal data, **symbols** that turn a crash's addresses back into your function names, and **profiles** that show where the time went.

> [!note] Sources and what was run
> Logging comes from Apple's `os` documentation ("Generating Log Messages from Your Code", `Logger`, `OSLogPrivacy`, "Viewing Log Messages"); symbols and crash reports from "Building your app to include debugging information", "Adding identifiable symbol names to a crash report" and "Addressing crashes from Swift runtime errors"; profiling from the "Profiling apps using Instruments" tutorials and "Analyzing CPU profiles with call tree views". Read in November 2026. Xcode, Instruments and the `atos` tool weren't run for this lesson. The `Logger` and signpost blocks were type-checked against the iOS SDK, not run; the pure-Swift models were compiled and run with Swift 6.3.

## Logging with Logger

`print` writes to standard output. In an app that means Xcode's console while you're attached, and effectively nowhere once the app is on a user's phone. Apple's **unified logging system** is different: messages go into a system-wide store, are kept in memory and (depending on level) on disk, and can be read later with Xcode's console, the Console app on a Mac, or the `log` command-line tool.

In Swift you write to it with `Logger`, from the `os` framework:

```swift ios
import os

let networkLog = Logger(subsystem: "com.example.Weather", category: "network")
let syncLog = Logger(subsystem: "com.example.Weather", category: "sync")

let attempt = 2
let city = "Oslo"
networkLog.info("Fetching forecast, attempt \(attempt)")
networkLog.error("Forecast request failed for \(city)")
syncLog.debug("Merged \(14) changes")
```

- The **subsystem** is a large area, in reverse-DNS form; use your bundle ID. The **category** is a part of it: `network`, `sync`, `ui`. Both exist so you can filter thousands of messages down to the ones that matter.
- Interpolation looks like a normal string, but it isn't one: `Logger` stores the static text and the values separately, which is what makes privacy and fast binary storage possible.

### Levels

The level decides what's kept and how much it costs. From Apple's table, in increasing severity:

| Level | Method | Persisted to disk | Use for |
| --- | --- | --- | --- |
| Debug | `debug(_:)` | No | Verbose detail useful only while developing |
| Info | `info(_:)` | Only when collected with the `log` tool | Helpful but not essential context |
| Notice (default) | `notice(_:)` or `log(_:)` | Yes, up to a storage limit | Information essential for troubleshooting |
| Error | `error(_:)` | Yes, up to a storage limit | Errors your code handled |
| Fault | `fault(_:)` | Yes, up to a storage limit | Bugs: states that should be impossible |

Debug messages are cheap because they stay in memory; faults cost more because the system captures extra information and writes it all to disk. When the on-disk store fills up, old messages are purged.

### Privacy

The log store can be read by people with access to the device, and logs get attached to bug reports. So the system **redacts** values by default. Apple: "By default, the system doesn't redact integer, floating-point and Boolean values, but it does redact the contents of dynamic strings and complex dynamic objects." A redacted value appears as a generic placeholder.

You override the default per value:

```swift ios
import os

let accountLog = Logger(subsystem: "com.example.Bank", category: "accounts")
let accountNumber = "4417-1234-5678"
let screenName = "TransferReview"
let balanceCents = 125_000

accountLog.notice("Showing \(screenName, privacy: .public)")
accountLog.notice("Loaded account \(accountNumber, privacy: .private(mask: .hash))")
accountLog.notice("Balance \(balanceCents, privacy: .private)")
```

- `.public` shows a value that can't identify anyone, such as a screen name or an error code.
- `.private` always hides it, even integers. A balance is an integer, so without this it would be **visible**.
- `.private(mask: .hash)` hides the value but logs a hash that's the same for the same value within the process, so you can follow one account through many messages without knowing which account it is.

Here's the default rule as a model you can run (the real placeholder text is the system's; the model prints `<redacted>`):

```swift
enum LogValue {
    case integer(Int)
    case boolean(Bool)
    case text(String)
}

enum Privacy {
    case auto, `public`, `private`
}

func render(_ value: LogValue, privacy: Privacy = .auto) -> String {
    let shown: String
    let redactedByDefault: Bool
    switch value {
    case .integer(let number):
        shown = String(number)
        redactedByDefault = false
    case .boolean(let flag):
        shown = String(flag)
        redactedByDefault = false
    case .text(let string):
        shown = string
        redactedByDefault = true
    }
    switch privacy {
    case .public: return shown
    case .private: return "<redacted>"
    case .auto: return redactedByDefault ? "<redacted>" : shown
    }
}

print("retry \(render(.integer(3))) for \(render(.text("ana@example.com")))")
print("premium: \(render(.boolean(true))), screen: \(render(.text("Checkout"), privacy: .public))")
print("balance: \(render(.integer(1250), privacy: .private))")
```

```output
retry 3 for <redacted>
premium: true, screen: Checkout
balance: <redacted>
```

`public` and `private` are Swift keywords, so the enum cases are written with backticks; at the use site, `.public` works without them.

> [!warning] Defaults protect strings, not numbers
> An account balance, an age or a user ID stored as `Int` is logged in the clear unless you mark it `.private`. Decide per value; don't rely on the default. Never log passwords, tokens or full card numbers at all, at any privacy level.

## Crash reports and symbols

When an app crashes, the system writes a **crash report**: the exception type, the backtrace of every thread (the crashed one marked), and a list of the **binary images** loaded, with their load addresses and build UUIDs. You get them from devices you connect to your Mac, and from TestFlight and App Store users through Xcode's Crashes organizer.

A Swift runtime error, such as force-unwrapping `nil` or an index out of range, crashes deliberately. On ARM devices Apple says the report shows:

```output
Exception Type:  EXC_BREAKPOINT (SIGTRAP)
...
Termination Signal: Trace/BPT trap: 5
Termination Reason: Namespace SIGNAL, Code 0x5
```

### Why addresses need symbols

The compiled app doesn't need your function names to run. Release builds put debug symbols in a separate **dSYM** file "to reduce the size of the distributed app", so a backtrace from a user's phone may look like this, from Apple's example of a partially symbolicated report:

```output
Thread 0 Crashed:
0   TouchCanvas      0x1045a19b4 0x10459c000 + 22964
1   TouchCanvas      0x1045a16d0 0x10459c000 + 22224
2   TouchCanvas      0x1045a7130 0x10459c000 + 45360
3   TouchCanvas      0x1045a4610 0x10459c000 + 34320
4   UIKitCore        0x1a6cff6ec forwardMethod1 + 108
```

Each frame is: frame number, binary, the address, and then **load address + offset**. `0x10459c000` is where `TouchCanvas` was loaded in that run. It changes every run, because iOS randomizes memory layout (ASLR, described in Apple Platform Security). The offset doesn't change for the same build, so it's what you look up.

**Symbolication** finds, for each offset, the function that contains it. Here's that process as a model, with a symbol table built from Apple's fully symbolicated version of the same crash:

```swift
struct Symbol {
    let start: UInt64   // offset of the function's first instruction
    let name: String
}

// Sorted by start offset.
let symbols = [
    Symbol(start: 21_976, name: "Line.updateRectForExistingPoint(_:)"),
    Symbol(start: 34_200, name: "@objc ViewController.touchesEstimatedPropertiesUpdated(_:)"),
    Symbol(start: 44_528, name: "CanvasView.updateEstimatedPropertiesForTouches(_:)"),
]

func symbolicate(_ offset: UInt64) -> String {
    var low = 0
    var high = symbols.count - 1
    var found: Symbol? = nil
    while low <= high {
        let mid = (low + high) / 2
        if symbols[mid].start <= offset {
            found = symbols[mid]
            low = mid + 1
        } else {
            high = mid - 1
        }
    }
    guard let symbol = found else { return "???" }
    return "\(symbol.name) + \(offset - symbol.start)"
}

let loadAddress: UInt64 = 0x10459c000
let frames: [UInt64] = [0x1045a19b4, 0x1045a16d0, 0x1045a7130, 0x1045a4610]
for (index, address) in frames.enumerated() {
    let offset = address - loadAddress
    print("\(index)  offset \(offset)  \(symbolicate(offset))")
}
```

```output
0  offset 22964  Line.updateRectForExistingPoint(_:) + 988
1  offset 22224  Line.updateRectForExistingPoint(_:) + 248
2  offset 45360  CanvasView.updateEstimatedPropertiesForTouches(_:) + 832
3  offset 34320  @objc ViewController.touchesEstimatedPropertiesUpdated(_:) + 120
```

Those four lines match Apple's fully symbolicated report frame for frame, including the `+ 988`, `+ 248`, `+ 832` and `+ 120` (the distance into each function). The lookup is the binary search from Module 16, in its "last element ≤ target" form: keep the best candidate whose start is at or before the offset. The model leaves out what real tools also do: function end addresses, inlined functions (the `-i` flag) and source file and line numbers from DWARF.

### dSYMs and build UUIDs

Apple's rules:

- Each binary (the app executable, every framework, every extension) has its own dSYM.
- A binary and a dSYM are tied by a **build UUID** recorded in both. "If you build two binaries from the same source code but with different Xcode versions or build settings, the build UUIDs for the two binaries won't match," and a mismatched dSYM is useless.
- The `DEBUG_INFORMATION_FORMAT` build setting must be **DWARF with dSYM File** for builds you distribute.
- When you archive, Xcode stores the binaries and dSYMs in the archive. Apple: "You must retain the Xcode archive for each build of your app you distribute."
- Upload symbols with your build to App Store Connect and crash reports in the Crashes organizer arrive symbolicated.

The command-line tools, from Apple's article: `xcrun crashlog <report>` symbolicates a whole report, and `atos` one address:

```bash
atos -arch arm64 -o TouchCanvas.app.dSYM/Contents/Resources/DWARF/TouchCanvas -l 0x10459c000 -i 0x1045a4610
```

```output
@objc ViewController.touchesEstimatedPropertiesUpdated(_:) (in TouchCanvas) (/<compiler-generated>:0)
```

`-l` is the load address from the crash report's Binary Images section; `-o` points at the DWARF file **inside** the dSYM bundle, not the bundle itself.

## A first look at profiling

Lesson 3 said slow main-thread work causes hangs and hitches. Instruments tells you which code it is. Apple's tutorial uses the **Time Profiler** template as "a good starting point if you don't yet know what you are looking for and something in your app feels sluggish."

The workflow from Apple's tutorials (Xcode and Instruments UI described from the docs, not checked here):

1. **Profile a Release build on a device.** Product › Profile (⌘I) builds in release mode, "as debug builds can have different performance characteristics." Apple recommends a physical device: "the simulator can have different performance characteristics."
2. **Choose Time Profiler** and record while you reproduce the slow interaction.
3. **Select the Main Thread track and the time range** of the problem. The call tree only shows what ran on the selected thread in the selected range.
4. **Read the call tree, the flame graph or Top Functions**, and the **heaviest stack trace** on the right.

### What the call tree counts

Time Profiler samples call stacks; each sample says "at this moment, this thread was running this function, called from these." The call tree adds them up:

- **Total weight**: samples in which a function appears anywhere in the stack, itself running or waiting on a callee.
- **Self weight**: samples in which the function itself was the one running (the top of the stack). Top Functions sorts by this.
- **Heaviest stack trace**: Apple's tutorial describes it as starting at the root, picking the child with the highest weight, and repeating "until reaching a leaf node".

Six samples from a sluggish "Export" button, counted the way the call tree does:

```swift
let samples: [[String]] = [
    ["main", "tapExport", "renderPDF", "drawChart"],
    ["main", "tapExport", "renderPDF", "drawChart"],
    ["main", "tapExport", "renderPDF", "drawTable"],
    ["main", "tapExport", "renderPDF", "drawChart"],
    ["main", "tapExport", "compress"],
    ["main", "scroll", "layoutCells"],
]

let functions = ["main", "tapExport", "renderPDF", "drawChart", "drawTable", "compress", "scroll", "layoutCells"]
for name in functions {
    var total = 0
    var selfWeight = 0
    for stack in samples {
        if stack.contains(name) {
            total += 1
        }
        if stack.last == name {
            selfWeight += 1
        }
    }
    print("\(name): total \(total), self \(selfWeight)")
}
```

```output
main: total 6, self 0
tapExport: total 5, self 0
renderPDF: total 4, self 0
drawChart: total 3, self 3
drawTable: total 1, self 1
compress: total 1, self 1
scroll: total 1, self 0
layoutCells: total 1, self 1
```

`main` and `tapExport` have huge totals and zero self weight: they're the path, not the cost. `drawChart` has the highest self weight: half the samples were spent drawing the chart. That's where to look first. The heaviest stack trace here is `main → tapExport → renderPDF → drawChart`.

> [!tip] Mark the operation you're measuring
> `OSSignposter` adds named intervals to the Instruments timeline, so you can select exactly one export instead of guessing at a time range. The block below follows Apple's call-tree article.

```swift ios
import os

let signposter = OSSignposter(subsystem: "com.example.Weather", category: .pointsOfInterest)
let state = signposter.beginInterval("exportPDF")
// ... the work you want to measure ...
signposter.endInterval("exportPDF", state)
```

Two habits from Apple's performance guidance: measure before and after a change (Instruments can compare two runs), and fix what the data shows rather than what you suspect.

## Common mistakes

> [!error] Logging personal data as .public "to debug it"
> Logs can be read by anyone with access to the device and get attached to bug reports. Use `.private(mask: .hash)` to correlate, and remove the log rather than exposing the value.

> [!error] Assuming numbers are redacted
> Integers, floating-point numbers and Booleans are shown by default. A balance or a user ID needs `.private`.

> [!error] Using print for diagnostics in shipping code
> It has no levels, no categories, no privacy and nowhere useful to go on a user's phone. Use `Logger`.

> [!error] Losing the dSYM for a released build
> Rebuilding the same commit produces a different build UUID, so its dSYM won't match. Keep every distributed archive and upload symbols.

> [!error] Profiling a Debug build in the simulator
> Debug builds are unoptimized and the simulator runs on your Mac's hardware. Profile Release on a device.

> [!error] Optimizing the function with the highest total weight
> High total weight with zero self weight means "on the path". Look for self weight.

## Exercises

````exercise
id: m21-l06-e1
type: prediction
prompt: "A crash report says `MyApp` was loaded at `0x100000000`. Using this symbol table, what does the program print?"
code: |
  let symbols: [(start: UInt64, name: String)] = [
      (4_096, "AppDelegate.application(_:didFinishLaunchingWithOptions:)"),
      (9_216, "CartModel.total()"),
      (12_800, "CartViewController.checkoutTapped(_:)"),
  ]

  func containingFunction(_ offset: UInt64) -> String {
      var best = "???"
      for symbol in symbols where symbol.start <= offset {
          best = "\(symbol.name) + \(offset - symbol.start)"
      }
      return best
  }

  let loadAddress: UInt64 = 0x100000000
  for address: UInt64 in [0x100002450, 0x100003210, 0x100000800] {
      print(containingFunction(address - loadAddress))
  }
output: |
  CartModel.total() + 80
  CartViewController.checkoutTapped(_:) + 16
  ???
hints:
  - "0x2450 is 9296 in decimal; 0x3210 is 12816; 0x800 is 2048."
  - "The loop keeps the last symbol whose start is at or before the offset, because the table is sorted."
solution: |
  ```output
  CartModel.total() + 80
  CartViewController.checkoutTapped(_:) + 16
  ???
  ```

  Subtract the load address to get offsets: `0x2450` = 9296, `0x3210` = 12816, `0x800` = 2048.

  - 9296 is after 9216 and before 12800: `CartModel.total() + 80`.
  - 12816 is after 12800: `checkoutTapped(_:) + 16`.
  - 2048 is before the first function in the table: nothing matches, so `???`. In a real report that address would belong to code this table doesn't cover.

  The linear loop is fine for three symbols; a real symbolicator uses binary search over many thousands, like the lesson's model.
````

````exercise
id: m21-l06-e2
type: comprehension
multiple: true
prompt: "With no privacy options, which values in this message are visible in the log? `logger.notice(\"User \\(email) has \\(points) points, premium: \\(isPremium), last screen \\(screen)\")`, where `email` and `screen` are String variables, `points` is an Int and `isPremium` is a Bool."
choices:
  - text: "`email`"
    correct: false
    why: Dynamic strings are redacted by default.
  - text: "`points`"
    correct: true
    why: Integers aren't redacted by default.
  - text: "`isPremium`"
    correct: true
    why: Booleans aren't redacted by default.
  - text: "`screen`"
    correct: false
    why: "It's a dynamic string, so it's redacted even though it isn't sensitive. Mark it .public if you need it."
solution: |
  **`points` and `isPremium`.** Apple: the system "doesn't redact integer, floating-point and Boolean values, but it does redact the contents of dynamic strings and complex dynamic objects."

  So the default is wrong in both directions here: `screen` is harmless but hidden (add `privacy: .public`), and `points` may be personal but is shown (add `privacy: .private` if it identifies someone's activity). Decide per value.
````

````exercise
id: m21-l06-e3
type: fill-in
prompt: Complete the atos command that symbolicates one address from a crash report.
code: |
  atos -arch arm64 -o MyApp.app.dSYM/Contents/Resources/[[1]]/MyApp -[[2]] 0x104a00000 0x104a05f20
blanks:
  - id: "1"
    answers: ["DWARF"]
  - id: "2"
    answers: ["l"]
solution: |
  ```bash
  atos -arch arm64 -o MyApp.app.dSYM/Contents/Resources/DWARF/MyApp -l 0x104a00000 0x104a05f20
  ```

  `-o` must point at the DWARF file inside the dSYM bundle, not the `.dSYM` folder. `-l` is the load address of `MyApp` from the report's Binary Images section; `atos` subtracts it to get the offset (here `0x5f20`). Add `-i` to show inlined functions.
````

````exercise
id: m21-l06-e4
type: find-errors
prompt: "Logging in a banking app's transfer flow. Mark every real problem."
code: |
  let log = Logger(subsystem: "com.example.Bank", category: "transfers")

  print("Transfer started")
  log.debug("Auth token \(token, privacy: .public)")
  log.notice("Transfer of \(amountCents) cents to \(recipientIBAN)")
  log.fault("Transfer state machine reached an impossible state: \(state, privacy: .public)")
choices:
  - text: "print is used for a diagnostic message; it has no level, category or privacy, and goes nowhere useful on a user's device."
    correct: true
  - text: "The auth token is logged as .public; secrets must never be logged, at any level."
    correct: true
  - text: "amountCents is an integer, so it's visible by default; for a transfer it should be .private."
    correct: true
  - text: "recipientIBAN is shown in the clear because notice messages ignore privacy."
    correct: false
    why: "Privacy applies at every level. A dynamic string is redacted by default."
  - text: "fault is the wrong level for an impossible state."
    correct: false
    why: "Apple describes fault for information about faults and bugs in your code. That's what an impossible state is."
rubric:
  - I flagged print.
  - I flagged the token logged as public and said tokens shouldn't be logged at all.
  - I noticed the integer amount is visible by default.
  - I knew the IBAN string is redacted by default and fault fits an impossible state.
solution: |
  Three problems:

  1. `print("Transfer started")` should be `log.notice("Transfer started")` (or `info`), so it has a category and ends up in the log store.
  2. The token must not be logged. `.public` makes it readable by anyone with the logs; even `.private` would still put a secret in a log. Remove the line.
  3. `amountCents` is an `Int`, so it's **shown** by default. Mark it `privacy: .private` (or `.private(mask: .hash)` if you need to correlate).

  `recipientIBAN` is a dynamic string, so it's redacted by default at every level. `fault` is right for a state that should be impossible; logging the state's name as `.public` is fine if it's an enum case like `awaitingConfirmation`, not user data.
````

````exercise
id: m21-l06-e5
type: solve
prompt: |
  Write `heaviestStack(_:)`, which computes the heaviest stack trace the way Apple's Instruments tutorial describes it: start with the frames at depth 0, pick the one that appears in the most samples, keep only the samples that go through it, and repeat one level deeper until no sample goes further. Break ties by choosing the alphabetically smaller name.

  ```swift
  let samples: [[String]] = [
      ["main", "openDocument", "parseJSON", "decodeDates"],
      ["main", "openDocument", "parseJSON", "decodeDates"],
      ["main", "openDocument", "parseJSON", "buildIndex"],
      ["main", "openDocument", "loadThumbnails"],
      ["main", "openDocument", "loadThumbnails"],
      ["main", "scroll", "layoutCells"],
      ["main", "scroll", "layoutCells"],
  ]
  print(heaviestStack(samples).joined(separator: " → "))
  ```

  Expected output:

  ```output
  main → openDocument → parseJSON → decodeDates
  ```
starter: |
  func heaviestStack(_ samples: [[String]]) -> [String] {
      var path: [String] = []
      var remaining = samples
      // your code
      return path
  }
hints:
  - "At each depth d, count stack[d] for every remaining sample with more than d frames."
  - "If no remaining sample has a frame at that depth, stop."
  - "After choosing a frame, keep only the samples whose frame at depth d is that frame."
rubric:
  - Counts frames at the current depth only among the remaining samples.
  - Picks the highest count, breaking ties alphabetically.
  - Filters the samples to those that go through the chosen frame.
  - Stops when no sample is deeper; prints the expected path.
solution: |
  ```swift
  func heaviestStack(_ samples: [[String]]) -> [String] {
      var path: [String] = []
      var remaining = samples
      while true {
          let depth = path.count
          var counts: [String: Int] = [:]
          for stack in remaining where stack.count > depth {
              counts[stack[depth], default: 0] += 1
          }
          var best: (name: String, count: Int)? = nil
          for (name, count) in counts {
              if let current = best {
                  if count > current.count || (count == current.count && name < current.name) {
                      best = (name, count)
                  }
              } else {
                  best = (name, count)
              }
          }
          guard let chosen = best else { break }
          path.append(chosen.name)
          var next: [[String]] = []
          for stack in remaining where stack.count > depth && stack[depth] == chosen.name {
              next.append(stack)
          }
          remaining = next
      }
      return path
  }

  let samples: [[String]] = [
      ["main", "openDocument", "parseJSON", "decodeDates"],
      ["main", "openDocument", "parseJSON", "decodeDates"],
      ["main", "openDocument", "parseJSON", "buildIndex"],
      ["main", "openDocument", "loadThumbnails"],
      ["main", "openDocument", "loadThumbnails"],
      ["main", "scroll", "layoutCells"],
      ["main", "scroll", "layoutCells"],
  ]
  print(heaviestStack(samples).joined(separator: " → "))
  ```

  ```output
  main → openDocument → parseJSON → decodeDates
  ```

  Depth 0: `main` (7). Depth 1: `openDocument` (5) beats `scroll` (2). Depth 2, among the 5 remaining: `parseJSON` (3) beats `loadThumbnails` (2). Depth 3, among 3: `decodeDates` (2) beats `buildIndex` (1). Then no sample is deeper, so the loop stops.

  Dictionary iteration order isn't fixed, which is why the tie-break compares names explicitly: without it, two runs could pick different frames. Instruments' real view also requires the path to include the frame you've selected in the call tree; this version has no selection.
````

````exercise
id: m21-l06-e6
type: explain
prompt: "Crash reports for version 3.2 (build 418) arrive in the Crashes organizer as hexadecimal addresses for your app's frames, while UIKit's frames show names. A teammate rebuilds the 3.2 tag on their Mac and tries to use that dSYM, and it still doesn't work. Explain what happened and what the team should change."
code: |
  0   MyApp        0x104b8d2f4 0x104b80000 + 54004
  1   MyApp        0x104b8c9a8 0x104b80000 + 51624
  2   UIKitCore    0x1a6cff6ec forwardMethod1 + 108
rubric:
  - I explained that release builds keep debug symbols in separate dSYM files and the report needs the matching one.
  - I explained the build UUID and why a rebuild of the same source doesn't match.
  - I explained that the app's frames are unsymbolicated because symbols weren't uploaded or the archive was lost, while Apple's frameworks have their own symbols.
  - I recommended keeping every distributed archive, using DWARF with dSYM, and uploading symbols with each build (and dSYMs from third-party frameworks).
solution: |
  Release builds don't carry your debug symbols; they're in a **dSYM** next to the binary, and a crash report can only be symbolicated with the dSYM from **that exact build**. Both record a build UUID, and Apple says two builds from the same source with different Xcode versions or settings get different UUIDs. Your teammate's rebuild of the 3.2 tag produced a new UUID, so its dSYM doesn't match build 418, even if the code is identical.

  UIKit's frames have names because Apple's symbols for its own frameworks are available; yours weren't, either because symbols weren't uploaded with the build or because the archive for build 418 wasn't kept.

  What to change: keep `DEBUG_INFORMATION_FORMAT` as DWARF with dSYM File for Release; archive every distributed build and **keep the archive**; upload symbols with each App Store Connect upload so the organizer symbolicates automatically; and collect dSYMs for any third-party binary frameworks. If the original archive still exists somewhere (another Mac, CI artifacts), find the dSYM with the matching UUID and symbolicate with Xcode, `xcrun crashlog` or `atos`.
````

## Summary

- Use `Logger` with a subsystem (your bundle ID) and a category per area. Levels: debug and info stay mostly in memory; notice, error and fault are persisted up to a limit.
- By default dynamic strings and objects are redacted; integers, floating-point numbers and Booleans aren't. Mark values `.public`, `.private` or `.private(mask: .hash)` on purpose, and never log secrets.
- A crash report's frames are load address + offset. The load address changes each run (ASLR); the offset, looked up in the symbols, gives the function and the distance into it.
- Release builds keep symbols in dSYMs, matched to one build by its UUID. Use DWARF with dSYM File, keep every distributed archive and upload symbols.
- Profile Release builds on a device with Time Profiler. Select the main thread and the time range; high self weight is the cost, high total weight is the path, and the heaviest stack trace leads to the hot spot.

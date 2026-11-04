---
id: m33-l06
title: Debugging and Instruments
description: "Find bugs and slow code with tools instead of guesses. You use LLDB's essentials (breakpoints, v, p and po, conditional and symbolic breakpoints, the Swift error breakpoint) on a real sorting bug, review the Memory Graph workflow, read what the Time Profiler and Allocations instruments show, and lock in a performance fix with an XCTest measure test."
module: m33
order: 6
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m33-l05, m13-l05]
objectives:
  - Set file-and-line, conditional and symbolic breakpoints in LLDB, and stop on thrown Swift errors.
  - Choose between v, p and po to inspect values, and read a backtrace.
  - Describe the Memory Graph workflow for finding what keeps an object alive.
  - Describe what the Time Profiler and Allocations instruments record and when to use each.
  - Write an XCTest performance test with measure, and explain baselines and why measurements need a Release build and a quiet machine.
terms:
  - term: Breakpoint
    definition: "A place where the debugger pauses the program: a file and line, a symbol name, or an event such as a thrown error. It can carry a condition that must be true for it to stop."
  - term: Symbolic breakpoint
    definition: "A breakpoint set on a function or method name rather than a line, useful for code you don't have the source for, like a framework function."
  - term: "v, p and po"
    definition: "LLDB commands for inspecting values. v (frame variable) reads variables from memory without running code; p (expression) compiles and evaluates an expression; po evaluates it and prints the object's description."
  - term: Time Profiler
    definition: "An Instruments template that samples the call stacks of the app's threads at regular intervals, so the functions where most time is spent show up with the most samples."
  - term: Allocations instrument
    definition: "An instrument that records heap and virtual memory allocations, grouped by category, over time. Its Generations feature isolates what one action allocated and didn't free."
  - term: Performance test
    definition: "An XCTest method that runs a block several times inside measure { } and records metrics, by default wall-clock time. In Xcode it can be compared with a saved baseline."
mastery:
  - Run a program under LLDB to a breakpoint, inspect locals and arguments, and evaluate an expression in the current frame.
  - Add a condition to a breakpoint so it only stops on the interesting iteration.
  - Stop at the line that throws an error with a Swift error breakpoint, and move up the stack with frame select.
  - Pick the right instrument for "the screen stutters", "memory grows" and "an object never goes away".
  - Write a measure test plus a correctness test for an optimization, and say what makes the numbers trustworthy.
resources: [lldb-gdb-map, xcode-performance-tests, xcode-improving-performance, lldb-tutorial, xcode-breakpoints, xcode-stepping, xcode-memory-use, xcode-reduce-memory, xcode-understanding-hitches, understanding-hangs]
cards:
  - id: m33-l06-c1
    front: v, p or po?
    back: "v (frame variable) reads stored variables without running code: fast and safe. p (expression) compiles and runs an expression, so it handles method calls and computed properties. po does the same and prints the object's description, which you can customize."
  - id: m33-l06-c2
    front: How do you stop only on the interesting call of a busy function?
    back: "Add a condition: breakpoint set --file main.swift --line 9 --condition 'lhs.isRead != rhs.isRead' (or Edit Breakpoint > Condition in Xcode). The debugger evaluates it at each hit and only pauses when it's true."
  - id: m33-l06-c3
    front: How do you find where a Swift error was thrown, not where try! crashed?
    back: "Add a Swift Error Breakpoint in Xcode's breakpoint navigator, or breakpoint set -E swift in LLDB. It stops in swift_willThrow; frame select 1 shows the throwing line."
  - id: m33-l06-c4
    front: Time Profiler or Allocations?
    back: "Time Profiler for slowness and hangs: where is the CPU time going? Allocations for memory growth: what is being allocated, and with Generations, what one action left behind. A leaked object you already suspect: the Memory Graph."
  - id: m33-l06-c5
    front: What makes an XCTest performance test meaningful?
    back: "A Release build without the debugger, sanitizers or coverage (Apple's advice), real-sized input, only the code under study inside measure { }, a separate correctness test, and a baseline in Xcode so a regression fails the test."
---

## The idea in one sentence

When a test fails or the app misbehaves, stop guessing: pause the program at the right moment with a breakpoint and look at the actual values, use Instruments to see where time and memory actually go, and once you've fixed something, add a test so it stays fixed.

> [!note] What was run, and what wasn't
> LLDB ships with the Swift toolchain, so the debugging sessions in this lesson are real: the program was compiled with `swiftc -g -Onone` and run under LLDB from Swift 6.3 on Linux, and the transcripts are its output with memory addresses, disassembly and some status lines trimmed. Commands follow the [LLDB tutorial](https://lldb.llvm.org/use/tutorial.html) and LLDB's built-in `help`. Xcode's debugger console runs the same LLDB. The Xcode and Instruments steps (buttons, menus, panes) come from Apple's documentation, cited in each section, and **weren't checked in Xcode** for this lesson; menu names can shift between versions. The performance tests were run with `swift test` on Linux.

## A bug to find

The reading list shows read books first, and "Next up" suggests a book the user already finished. The code (Module 32's ordering, with a mistake):

```swift
struct Book {
    let id: Int
    let title: String
    var isRead: Bool
}

func ordered(_ books: [Book]) -> [Book] {
    books.sorted { lhs, rhs in
        lhs.isRead != rhs.isRead ? lhs.isRead : lhs.title < rhs.title
    }
}

func nextUp(in books: [Book]) -> Book? {
    let list = ordered(books)
    return list.first
}

let books = [
    Book(id: 1, title: "Kindred", isRead: true),
    Book(id: 2, title: "The Dispossessed", isRead: false),
    Book(id: 3, title: "Piranesi", isRead: false),
]
let next = nextUp(in: books)
print("Next up: \(next?.title ?? "nothing")")
```

```output
Next up: Kindred
```

Kindred is the read book. You could stare at the comparator, or add `print`s and rebuild. A debugger lets you stop inside the running code and ask.

## LLDB essentials

### Stop at a line and look around

```text
(lldb) breakpoint set --file main.swift --line 15
Breakpoint 1: where = bookshelf`nextUp(in:) + 43 at main.swift:15:17
(lldb) run
Process 42 stopped
* thread #1, name = 'bookshelf', stop reason = breakpoint 1.1
    frame #0: bookshelf`nextUp(books=3 values) at main.swift:15:17
   12
   13  	func nextUp(in books: [Book]) -> Book? {
   14  	    let list = ordered(books)
-> 15  	    return list.first
   16  	}
(lldb) frame variable
([bookshelf.Book]) books = 3 values {
  [0] = (id = 1, title = "Kindred", isRead = true)
  [1] = (id = 2, title = "The Dispossessed", isRead = false)
  [2] = (id = 3, title = "Piranesi", isRead = false)
}
([bookshelf.Book]) list = 3 values {
  [0] = (id = 1, title = "Kindred", isRead = true)
  [1] = (id = 3, title = "Piranesi", isRead = false)
  [2] = (id = 2, title = "The Dispossessed", isRead = false)
}
```

- **`breakpoint set --file main.swift --line 15`** (short form `br s -f main.swift -l 15`, or `b main.swift:15`) pauses before line 15 runs. In Xcode, clicking the line number gutter does the same (Apple's [Setting breakpoints to pause your running app](https://developer.apple.com/documentation/xcode/setting-breakpoints-to-pause-your-running-app)).
- **`run`** starts the program; it stops at the breakpoint and shows the source around it. The arrow is the next line to execute.
- **`frame variable`** (alias `v`) prints the current function's arguments and locals. `list` already has Kindred first: the bug is in `ordered`, not in `nextUp`.

### v, p and po

```text
(lldb) p list.count
(Int) 3
(lldb) po list[0]
▿ Book
  - id : 1
  - title : "Kindred"
  - isRead : true

(lldb) v list[0].isRead
(Bool) list[0].isRead = true
```

Apple's [Stepping through code and inspecting variables](https://developer.apple.com/documentation/xcode/stepping-through-code-and-inspecting-variables-to-isolate-bugs) explains the split:

- **`v`** (`frame variable`) reads what's in memory. It doesn't run code, so it can't call a method or evaluate a computed property, but it's fast and can't change anything. It also powers Xcode's variables view.
- **`p`** (`expression`) compiles the expression and runs it in the paused program. Use it for method calls, computed properties and comparisons: `p list.count`, or `p books.filter { !$0.isRead }.count`, which printed `(Int) 2` in the same session.
- **`po`** (`expression --object-description`) runs the expression and prints the object's description: the `Mirror`-based dump above, or your own text if the type implements `CustomDebugStringConvertible`.

Default to `v`. Use `p` when you need code to run, and `po` when a description reads better than the raw fields.

### Read the stack

```text
(lldb) bt
* thread #1, name = 'bookshelf', stop reason = breakpoint 1.1
  * frame #0: bookshelf`nextUp(books=3 values) at main.swift:15:17
    frame #1: bookshelf`main at main.swift:23:12
    frame #2: libc.so.6`___lldb_unnamed_symbol_2a150 + 122
    frame #3: libc.so.6`__libc_start_main + 139
    frame #4: bookshelf`_start + 37
```

**`bt`** (backtrace) lists the calls that led here, innermost first. Frame 1 is the caller. `frame select 1` (or `up`) moves there so `v` shows that function's variables. The frames below `main` are the C runtime starting the program; on iOS you'd see UIKit and the run loop instead.

### Conditional breakpoints

The comparator runs several times per sort. Stopping on every call is noise; the interesting calls compare a read book with an unread one. A **condition** makes the breakpoint stop only then:

```text
(lldb) breakpoint set --file main.swift --line 9 --condition 'lhs.isRead != rhs.isRead'
Breakpoint 1: where = bookshelf`closure #1 in ordered(_:) + 77 at main.swift:9:20
(lldb) run
Process 41 stopped
* thread #1, name = 'bookshelf', stop reason = breakpoint 1.1
    frame #0: bookshelf`closure #1 in ordered(lhs=(id = 2, title = "The Dispossessed", isRead = false), rhs=(id = 1, title = "Kindred", isRead = true)) at main.swift:9:20
   7   	func ordered(_ books: [Book]) -> [Book] {
   8   	    books.sorted { lhs, rhs in
-> 9   	        lhs.isRead != rhs.isRead ? lhs.isRead : lhs.title < rhs.title
   10  	    }
   11  	}
(lldb) v lhs rhs
(bookshelf.Book) lhs = (id = 2, title = "The Dispossessed", isRead = false)
(bookshelf.Book) rhs = (id = 1, title = "Kindred", isRead = true)
(lldb) p lhs.isRead != rhs.isRead ? lhs.isRead : lhs.title < rhs.title
(Bool) false
```

There it is. `sorted(by:)` asks "should `lhs` come before `rhs`?". An unread book should come before a read one, so the answer should be `true`, but the expression returns `lhs.isRead`, which is `false`. The fix is `!lhs.isRead`, which is what Module 32's version has.

The transcript above also had a second breakpoint, on `nextUp` by name, which stopped first; it's left out here. In Xcode, conditions go in the breakpoint's Edit Breakpoint popover. `breakpoint list`, `breakpoint disable 1` and `breakpoint delete 1` manage breakpoints; `continue` (`c`) resumes, `next` (`n`) steps over a line, `step` (`s`) steps into a call, and `finish` runs until the current function returns.

The fix, and the test that keeps it fixed:

```swift
struct Book {
    let id: Int
    let title: String
    var isRead: Bool
}

func ordered(_ books: [Book]) -> [Book] {
    books.sorted { lhs, rhs in
        lhs.isRead != rhs.isRead ? !lhs.isRead : lhs.title < rhs.title
    }
}

func nextUp(in books: [Book]) -> Book? {
    ordered(books).first
}

let books = [
    Book(id: 1, title: "Kindred", isRead: true),
    Book(id: 2, title: "The Dispossessed", isRead: false),
    Book(id: 3, title: "Piranesi", isRead: false),
]
print("Next up: \(nextUp(in: books)?.title ?? "nothing")")
print(ordered(books).map(\.title))
```

```output
Next up: Piranesi
["Piranesi", "The Dispossessed", "Kindred"]
```

The test is lesson 1's `unreadBooksComeFirst`. A debugging session that ends without a test has fixed the bug once; one that ends with a test has fixed it for good.

### Symbolic breakpoints

A **symbolic breakpoint** stops on a function by name, wherever it's called from: `breakpoint set --name nextUp` (`br s -n nextUp`) above resolved to `nextUp(in:)` at line 14. It's most useful for code you don't have the source for. Apple's breakpoint article uses `UIViewAlertForUnsatisfiableConstraints`, the UIKit function that the Auto Layout "Unable to simultaneously satisfy constraints" log message asks you to break on (Module 23). In Xcode: Breakpoint navigator, the + button, Symbolic Breakpoint. Apple warns that some symbols are called very often; add a condition or enable the breakpoint only once you're near the problem.

### Stop where an error is thrown

When an error escapes through `try!` or a `try?` hides it, the place it was **thrown** is what you want. This importer silently skips a line:

```swift
enum ImportError: Error {
    case missingAuthor
}

func parse(_ line: String) throws -> (title: String, author: String) {
    let parts = line.split(separator: ";", maxSplits: 1)
    guard parts.count == 2 else { throw ImportError.missingAuthor }
    return (String(parts[0]), String(parts[1]))
}

let lines = ["Kindred;Octavia E. Butler", "Piranesi", "Beloved;Toni Morrison"]
var imported = 0
for line in lines {
    if let book = try? parse(line) {
        imported += 1
        print(book.title)
    }
}
print("imported \(imported) of \(lines.count)")
```

```output
Kindred
Beloved
imported 2 of 3
```

LLDB's `breakpoint set -E swift` stops whenever Swift code throws (its `help` says: "Set the breakpoint on exceptions thrown by the specified language"). Xcode's equivalent is the **Swift Error Breakpoint** in the Breakpoint navigator's + menu.

```text
(lldb) breakpoint set -E swift
Breakpoint 1: no locations (pending).
(lldb) run
Kindred
* thread #1, name = 'importer', stop reason = breakpoint 1.1
    frame #0: libswiftCore.so`swift_willThrow
(lldb) bt 3
* thread #1, name = 'importer', stop reason = breakpoint 1.1
  * frame #0: libswiftCore.so`swift_willThrow
    frame #1: importer`parse(line="Piranesi") at throws.swift:7:35
    frame #2: importer`main at throws.swift:14:24
(lldb) frame select 1
frame #1: importer`parse(line="Piranesi") at throws.swift:7:35
   5   	func parse(_ line: String) throws -> (title: String, author: String) {
   6   	    let parts = line.split(separator: ";", maxSplits: 1)
-> 7   	    guard parts.count == 2 else { throw ImportError.missingAuthor }
   8   	    return (String(parts[0]), String(parts[1]))
   9   	}
(lldb) v line
(String) line = "Piranesi"
(lldb) expression imported = 10
(lldb) continue
Beloved
imported 11 of 3
```

- The program stops in the runtime function `swift_willThrow`, which every `throw` calls. Frame 1 is your code: `parse` threw `missingAuthor` for the line "Piranesi".
- **`expression imported = 10`** changed a variable in the paused program, and the final line shows it: `imported 11 of 3`. Changing state from the debugger lets you test a theory ("what if this count were right?") without rebuilding. Use it to explore, never as a fix.

## The Memory Graph, revisited

Module 13 introduced the memory tools. As a workflow inside a debugging session, following Apple's [Gathering information about memory use](https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use):

1. Reproduce the suspected leak: open and close the reading list a few times.
2. Click **Debug Memory Graph** in Xcode's debug bar. The app pauses, and Xcode shows its objects as a graph: nodes are objects, heap allocations or memory-mapped files; arrows are references.
3. Search for your type, for example `ReadingListPresenter`. If instances remain after the screens closed, select one and follow the arrows that point **at** it back to the owner that shouldn't be there.
4. Turn on **Malloc Stack** in the scheme's Run settings, Diagnostics section, to see the call stack that allocated each node.
5. Fix the reference, then write the leak check (Module 13, and lesson 5's presenter test) so it can't come back.

Because the app is paused while you inspect the graph, the LLDB console is live at the same time: `po` on an object you found answers "which screen is this?" without leaving the debugger.

## Instruments: Time Profiler and Allocations

Instruments is the profiling app that ships with Xcode. Choose **Product > Profile** (Command-I); Apple's [Instruments tutorial](https://developer.apple.com/tutorials/instruments) notes that "the Profile action builds your target in release mode, as debug builds can have different performance characteristics than release builds", and recommends measuring on a physical device, "as the simulator can have different performance characteristics". Apple's [Improving your app's performance](https://developer.apple.com/documentation/xcode/improving-your-app-s-performance) maps problems to templates: Time Profiler for unresponsiveness and hangs, Allocations and Leaks for memory.

### Time Profiler

The Time Profiler samples what every thread is doing at regular intervals. Functions that appear in many samples are where the time goes. From Apple's tutorial:

- Start with the **Time Profiler** template "if you don't yet know what you are looking for and something in your app feels sluggish". Record while you do the slow action (scroll the list, import a file).
- Select a time range in the track. The **call tree** below shows only functions that ran on the selected thread during that range. The **Weight** column is how much of the time a function and its callees account for.
- The **Heaviest Stack Trace** on the right summarizes the call tree into the single most expensive path, so you don't have to expand thousands of nodes. Option-click a disclosure triangle to expand down to the first branch.

For the reading list: profile the import of a 5,000-book file, select the main thread during the stall, and follow the heaviest stack to your code, for example a deduplication function called from the import. That's the input for the next section. Module 43 covers hangs and scrolling performance in depth.

### Allocations

The Allocations instrument records every heap and anonymous virtual memory allocation, organized by category, on a timeline. Apple's memory article describes the two views you'll use most:

- The **statistics view** lists categories with counts and sizes; expanding one shows individual allocations, when they happened and the code responsible.
- **Generations**: get the app ready to use a feature, click **Mark Generation**, use the feature, click **Mark Generation** again. Instruments groups allocations by interval, so you can see what that one action allocated and didn't free. Repeat it a few times; allocations that pile up in every generation are the ones to explain.

Which tool when:

| Symptom | First tool |
| --- | --- |
| A screen or action feels slow, the UI stutters or hangs | Time Profiler |
| Memory grows every time you repeat an action | Allocations with Generations |
| A specific object should be gone and isn't | Memory Graph (and a leak check test) |
| A wrong value, a wrong branch, a crash | LLDB breakpoints |

## Performance tests with measure

The profile pointed at deduplication during import. Here are two versions, the one in the app and a replacement:

```swift
struct Book: Equatable, Sendable {
    let id: Int
    let title: String
    let author: String
}

enum Deduplication {
    /// Keeps the first book for each title and author, in the original order.
    static func slow(_ books: [Book]) -> [Book] {
        var result: [Book] = []
        for book in books {
            let isDuplicate = result.contains { $0.title == book.title && $0.author == book.author }
            if !isDuplicate {
                result.append(book)
            }
        }
        return result
    }

    private struct Key: Hashable {
        let title: String
        let author: String
    }

    /// The same result in one pass, remembering seen keys in a Set.
    static func fast(_ books: [Book]) -> [Book] {
        var seen: Set<Key> = []
        return books.filter { seen.insert(Key(title: $0.title, author: $0.author)).inserted }
    }

    /// An import file's worth of books: `count` books, each listed twice.
    static func sampleImport(count: Int) -> [Book] {
        (0..<count * 2).map { index in
            let n = index % count
            return Book(id: index, title: "Book \(n)", author: "Author \(n % 97)")
        }
    }
}

let books = Deduplication.sampleImport(count: 2_000)
let slow = Deduplication.slow(books)
let fast = Deduplication.fast(books)
print(books.count, slow.count, fast.count)
print(slow == fast)
print(fast.prefix(2).map(\.title))
```

```output
4000 2000 2000
true
["Book 0", "Book 1"]
```

`slow` checks every new book against everything kept so far, so the work grows with the square of the input: about 4 million comparisons for these 4,000 books. `fast` remembers the keys it has seen in a `Set`, one hash lookup per book. Same output, very different cost. An XCTest **performance test** records that difference and, in Xcode, keeps it from coming back:

```swift illustrative
import XCTest
@testable import Bookshelf

final class DeduplicationPerformanceTests: XCTestCase {
    let books = Deduplication.sampleImport(count: 2_000)

    func testSlowDeduplication() {
        measure {
            _ = Deduplication.slow(books)
        }
    }

    func testFastDeduplication() {
        measure {
            _ = Deduplication.fast(books)
        }
    }

    func testBothKeepTheSameBooks() {
        XCTAssertEqual(Deduplication.fast(books), Deduplication.slow(books))
        XCTAssertEqual(Deduplication.fast(books).count, 2_000)
    }
}
```

`measure { }` runs the block several times and records the time of each run. From `swift test` on Linux (Swift 6.3, debug build; paths trimmed and the values lists cut):

```text
Test Case 'DeduplicationPerformanceTests.testFastDeduplication' measured [Time, seconds] average: 0.001, relative standard deviation: 5.360%, values: [0.001222, 0.001037, ...], performanceMetricID:org.swift.XCTPerformanceMetric_WallClockTime, maxPercentRelativeStandardDeviation: 10.000%, maxStandardDeviation: 0.100
Test Case 'DeduplicationPerformanceTests.testSlowDeduplication' measured [Time, seconds] average: 0.284, relative standard deviation: 6.758%, values: [0.281341, 0.279614, ...], performanceMetricID:org.swift.XCTPerformanceMetric_WallClockTime, maxPercentRelativeStandardDeviation: 10.000%, maxStandardDeviation: 0.100
```

Ten runs each: about 0.284 s for the slow version and 0.001 s for the fast one on this machine. The numbers themselves mean little elsewhere; the ratio is the finding.

What Apple's [Writing and running performance tests](https://developer.apple.com/documentation/xcode/writing-and-running-performance-tests) adds, for Xcode:

- **Baselines.** Click the icon next to `measure` to see recent results, then **Set Baseline**. With a baseline and a maximum standard deviation, "the test fails if the recorded metric is worse than the baseline value by more than the maximum standard deviation". Without a baseline, a performance test only records.
- **Conditions.** Build for testing with the **Release** configuration, turn off "Debug executable", and disable code coverage and runtime sanitizers in the test plan, so you measure what users run.
- **Metrics.** `measure(_:)` records wall-clock time by default; `measure(metrics:block:)` takes other `XCTMetric`s, such as memory or CPU. Those weren't run here.
- **From a failure to Instruments.** Control-click a failing performance test and choose "Profile" to open it in Instruments.

On Linux, the open-source XCTest has no baselines, but it reports a relative standard deviation limit of 10%, and its library contains the failure message "The relative standard deviation of the measurements is … higher than the max allowed". The slow test's deviation was 6.8% in one run and 9.5% in another, close to that limit: a debug build in a shared container is a noisy place to measure. Swift Testing has no `measure` equivalent in Apple's documentation, which is why performance tests stay in XCTest (lesson 2).

Two tests go together: a **correctness** test that the fast version returns the same books (in the solution to exercise 5), and the **performance** test. An optimization without the first is a bug waiting to happen; without the second, someone will "simplify" it back.

## Common mistakes

> [!error] Debugging with print and rebuild cycles
> Ten rounds of adding `print`, rebuilding and reproducing, for a question a breakpoint answers in one stop. Use `print` (or `Logger`) for things you need in logs; use the debugger to investigate.

> [!error] Stopping on every call of a hot function
> A breakpoint inside a comparator or `cellForRowAt` that you `continue` past 50 times. Add a condition for the case you care about.

> [!error] Using po for everything
> `po` runs code in the paused app, which is slower and can have side effects. `v` reads memory and is usually all you need.

> [!error] Profiling a Debug build in the simulator
> Debug builds skip optimizations and the simulator runs on a Mac's CPU. Profile the Release build Product > Profile makes, on a device.

> [!error] Measuring setup inside measure { }
> Building the 4,000-book sample inside the block measures the sample generator too. Prepare inputs outside, measure only the code under study.

> [!error] Performance tests with toy input
> Deduplicating 10 books takes microseconds whichever algorithm you use. Use realistic sizes, or the test can't tell the versions apart.

> [!error] Leaving a debugger-only fix
> `expression imported = 10` proved a theory; it didn't fix anything. Change the code, and add a test.

## Exercises

````exercise
id: m33-l06-e1
type: comprehension
prompt: "You're paused in a view controller and want the value of viewModel.headerText, a computed property. Which command works?"
choices:
  - text: "p viewModel.headerText"
    correct: true
    why: "p compiles and runs the expression, so it can evaluate a computed property."
  - text: "v viewModel.headerText"
    correct: false
    why: "v (frame variable) only reads stored values from memory; it can't run a computed property's getter. Apple's article says it returns an error in that case."
  - text: "bt viewModel.headerText"
    correct: false
    why: "bt prints the backtrace; it doesn't evaluate expressions."
  - text: "breakpoint set --name headerText"
    correct: false
    why: "That sets a breakpoint on the getter. It doesn't print the value now."
solution: |
  `p` (and `po`) run code in the paused process, so they handle computed properties and method calls. `v` is the faster, side-effect-free choice for stored variables, which is why it's the default; switch to `p` when code has to run.
````

````exercise
id: m33-l06-e2
type: prediction
prompt: "The buggy comparator from this lesson, applied to four books. What does the program print?"
code: |
  struct Book {
      let title: String
      var isRead: Bool
  }

  func ordered(_ books: [Book]) -> [Book] {
      books.sorted { lhs, rhs in
          lhs.isRead != rhs.isRead ? lhs.isRead : lhs.title < rhs.title
      }
  }

  let books = [
      Book(title: "Piranesi", isRead: false),
      Book(title: "Kindred", isRead: true),
      Book(title: "Beloved", isRead: false),
      Book(title: "Dune", isRead: true),
  ]
  let list = ordered(books)
  print(list.map(\.title))
  print("Next up: \(list.first?.title ?? "nothing")")
output: |
  ["Dune", "Kindred", "Beloved", "Piranesi"]
  Next up: Dune
solution: |
  The comparator answers "does `lhs` come first?". When the read flags differ, it returns `lhs.isRead`: a read book comes before an unread one. So the order is read books first, each group sorted by title: Dune, Kindred, then Beloved, Piranesi.

  ```output
  ["Dune", "Kindred", "Beloved", "Piranesi"]
  Next up: Dune
  ```

  The fix is `!lhs.isRead`. The conditional breakpoint in the lesson found it by stopping only on comparisons between a read and an unread book.
````

````exercise
id: m33-l06-e3
type: fill-in
prompt: "Complete the LLDB session that stops in the comparator only when a read and an unread book are compared, shows both, evaluates the comparator's result, and moves on."
code: |
  (lldb) breakpoint set --file main.swift --line 9 [[1]] 'lhs.isRead != rhs.isRead'
  (lldb) [[2]]
  (lldb) [[3]] lhs rhs
  (lldb) [[4]] lhs.isRead != rhs.isRead ? lhs.isRead : lhs.title < rhs.title
  (lldb) [[5]]
blanks:
  - id: "1"
    answers: ["--condition", "-c"]
  - id: "2"
    answers: ["run", "r", "process launch"]
  - id: "3"
    answers: ["v", "frame variable", "fr v"]
  - id: "4"
    answers: ["p", "expression", "expr"]
  - id: "5"
    answers: ["continue", "c"]
solution: |
  `--condition` (`-c`) makes the breakpoint stop only when the expression is true. `run` starts the program. `v` reads the two arguments from memory. `p` compiles and evaluates the comparator's expression in the current frame; it returned `false` in the lesson's session, which is the bug. `continue` resumes.
````

````exercise
id: m33-l06-e4
type: find-errors
prompt: "A performance test added after an optimization. Which comments point at real problems?"
code: |
  final class ImportPerformanceTests: XCTestCase {
      func testDeduplicationIsFast() {
          measure {
              let books = Deduplication.sampleImport(count: 10)
              let start = Date()
              _ = Deduplication.fast(books)
              XCTAssertLessThan(Date().timeIntervalSince(start), 0.01)
          }
      }
  }
  // Run from the Debug scheme on the simulator, with Address Sanitizer and code coverage on.
choices:
  - text: "Building the sample inside measure { } includes the generator in the timing."
    correct: true
    why: "Create the input before measure and only call the code under study inside it."
  - text: "Ten books is too small to show the difference between the algorithms."
    correct: true
    why: "Use an import-sized input, like the lesson's 4,000 books."
  - text: "The hand-rolled Date check duplicates measure and fails on noisy machines; a baseline in Xcode is the right threshold."
    correct: true
    why: "Set a baseline and max standard deviation instead of a hard-coded limit."
  - text: "There's no test that fast returns the same books as slow."
    correct: true
    why: "Pair every optimization with a correctness test."
  - text: "Debug configuration, sanitizers and coverage distort the numbers; Apple recommends Release with them off."
    correct: true
    why: "From Apple's Writing and running performance tests."
  - text: "measure can only be used in async tests."
    correct: false
    why: "measure(_:) takes a synchronous block in a normal test method."
rubric:
  - Moves input creation out of the measured block and uses realistic size.
  - Replaces the hard-coded time assertion with an Xcode baseline.
  - Adds a correctness test.
  - Mentions Apple's recommended configuration for performance tests.
solution: |
  A better version: `let books = Deduplication.sampleImport(count: 2_000)` as a property, `measure { _ = Deduplication.fast(books) }`, a baseline set in Xcode, a separate test comparing `fast` with `slow` (or with expected output), and a test plan for performance tests that builds Release without the debugger, sanitizers or coverage.
````

````exercise
id: m33-l06-e5
type: solve
prompt: "The importer's deduplication is quadratic. Write a version that keeps the first book for each title and author, in the original order, in one pass. Then write the tests that should go with the change: a parameterized Swift Testing test that the fast and slow versions agree on several input sizes, a test of the order and which copy is kept, and an XCTest performance test for each version on an import-sized input."
starter: |
  struct Book: Equatable, Sendable {
      let id: Int
      let title: String
      let author: String
  }

  enum Deduplication {
      static func slow(_ books: [Book]) -> [Book] { /* from the lesson */ }

      static func fast(_ books: [Book]) -> [Book] {
          // Your code
      }
  }
rubric:
  - Uses a Set of a Hashable key (title and author) and keeps the first occurrence, preserving order.
  - The equivalence test is parameterized over sizes, including a small one and an import-sized one.
  - A hand-written test checks the exact ids kept for a list with a duplicate.
  - The performance test builds the input outside measure and measures only the deduplication.
solution: |
  The implementation is the lesson's `Deduplication.fast`: a private `Key` struct with the title and author is `Hashable` by synthesis, and `seen.insert(key).inserted` is `true` only the first time a key appears, so `filter` keeps first occurrences in order.

  ```swift
  struct Book: Equatable, Sendable {
      let id: Int
      let title: String
      let author: String
  }

  enum Deduplication {
      /// Keeps the first book for each title and author, in the original order.
      static func slow(_ books: [Book]) -> [Book] {
          var result: [Book] = []
          for book in books {
              let isDuplicate = result.contains { $0.title == book.title && $0.author == book.author }
              if !isDuplicate {
                  result.append(book)
              }
          }
          return result
      }

      private struct Key: Hashable {
          let title: String
          let author: String
      }

      /// The same result in one pass, remembering seen keys in a Set.
      static func fast(_ books: [Book]) -> [Book] {
          var seen: Set<Key> = []
          return books.filter { seen.insert(Key(title: $0.title, author: $0.author)).inserted }
      }

      /// An import file's worth of books: `count` books, each listed twice.
      static func sampleImport(count: Int) -> [Book] {
          (0..<count * 2).map { index in
              let n = index % count
              return Book(id: index, title: "Book \(n)", author: "Author \(n % 97)")
          }
      }
  }

  let books = [
      Book(id: 1, title: "Kindred", author: "Octavia E. Butler"),
      Book(id: 2, title: "Piranesi", author: "Susanna Clarke"),
      Book(id: 3, title: "Kindred", author: "Octavia E. Butler"),
      Book(id: 4, title: "Kindred", author: "Someone Else"),
  ]
  print(Deduplication.fast(books).map(\.id))
  print(Deduplication.slow(books).map(\.id))
  ```

  ```output
  [1, 2, 4]
  [1, 2, 4]
  ```

  The correctness tests in Swift Testing:

  ```swift illustrative
  import Testing
  @testable import Bookshelf

  @Test(arguments: [10, 500, 2_000])
  func fastMatchesSlow(count: Int) {
      let books = Deduplication.sampleImport(count: count)
      #expect(Deduplication.fast(books) == Deduplication.slow(books))
  }

  @Test func keepsTheFirstCopyInOrder() {
      let books = [
          Book(id: 1, title: "Kindred", author: "Octavia E. Butler"),
          Book(id: 2, title: "Piranesi", author: "Susanna Clarke"),
          Book(id: 3, title: "Kindred", author: "Octavia E. Butler"),
      ]
      #expect(Deduplication.fast(books).map(\.id) == [1, 2])
  }
  ```

  And the performance tests in XCTest, as in the lesson:

  ```swift illustrative
  import XCTest
  @testable import Bookshelf

  final class DeduplicationPerformanceTests: XCTestCase {
      let books = Deduplication.sampleImport(count: 2_000)

      func testSlowDeduplication() {
          measure {
              _ = Deduplication.slow(books)
          }
      }

      func testFastDeduplication() {
          measure {
              _ = Deduplication.fast(books)
          }
      }

      func testBothKeepTheSameBooks() {
          XCTAssertEqual(Deduplication.fast(books), Deduplication.slow(books))
          XCTAssertEqual(Deduplication.fast(books).count, 2_000)
      }
  }
  ```

  Both suites were built and run together with `swift test` (Swift 6.3, Linux), and all tests passed. Book 4 has the same title as book 1 but a different author, so it's kept: the key is the pair, which the hand-written list checks along with the order. Keeping `slow` around in the codebase is optional; it's useful as the reference implementation the equivalence test compares against, as long as nothing else calls it.
````

````exercise
id: m33-l06-e6
type: design
prompt: "Users report that after importing a large library (5,000 books) the reading list scrolls with stutters, and the app's memory keeps growing each time they open and close the list. Describe your investigation, step by step, naming the tool for each question and what you'd add to the test suite when you're done."
rubric:
  - Reproduces on a device with a Release (Profile) build.
  - Uses Time Profiler on the main thread during scrolling and reads the heaviest stack trace.
  - Uses Allocations with Generations around opening and closing the list, and the Memory Graph to find what retains the screen.
  - Uses LLDB (conditional breakpoints, p/po) to confirm a theory in the code.
  - "Ends with tests: a leak check, a performance test with a baseline, and unit tests for any logic changed."
solution: |
  1. **Reproduce** with a 5,000-book import on a device, using Product > Profile so it's a Release build.
  2. **Stutter:** Time Profiler while scrolling. Select a stall on the main thread and follow the Heaviest Stack Trace. Typical culprits: sorting or formatting rows in `cellForRowAt`, synchronous image decoding, recomputing the header for every cell.
  3. **Memory growth:** Allocations, marking a generation before opening the list and after closing it, several times. If the same allocations pile up every generation, open the Memory Graph after a few cycles, find instances of the list's view controller or presenter that should be gone, and follow the references to the owner (a strong `view`, a closure capturing `self`, an observer never removed).
  4. **Confirm in code** with LLDB: a conditional breakpoint in `cellForRowAt` for a large index, `p` on the work being redone, `po` on the object the memory graph pointed at.
  5. **Fix and protect:** a leak check test for the presenter or view model (lesson 5), an XCTest performance test with a baseline for the expensive function on 5,000 books, and unit tests for any logic moved out of the cell (for example, precomputed rows in the view model).
````

## Summary

- **Breakpoints** pause the running program: by file and line, by symbol name (`--name`), with a **condition**, or on every thrown Swift error (`breakpoint set -E swift`, Xcode's Swift Error Breakpoint). `bt` shows how you got there; `frame select` moves up the stack.
- **`v`** reads variables without running code; **`p`** evaluates expressions; **`po`** evaluates and prints a description. Default to `v`. `expression` can change state to test a theory, never as the fix.
- The **Memory Graph** answers "who keeps this object alive?"; turn on Malloc Stack to see where things were allocated.
- **Time Profiler** shows where CPU time goes (call tree, Heaviest Stack Trace); **Allocations** shows what's allocated, and Generations isolates one action. Profile Release builds on a device.
- **`measure { }`** in XCTest records timings; Xcode baselines turn them into a regression check. Measure only the code under study, on realistic input, with Apple's recommended configuration, and pair every optimization with a correctness test.

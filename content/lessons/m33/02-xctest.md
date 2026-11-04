---
id: m33-l02
title: XCTest and migrating between frameworks
description: "Read and write XCTest: XCTestCase subclasses, setUp and tearDown, the XCTAssert family, and expectations for callback-based code. Then run XCTest and Swift Testing side by side in one target, and decide what to migrate, what to leave in XCTest, and what breaks silently when you mix them."
module: m33
order: 2
level: advanced
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m33-l01]
objectives:
  - Write an XCTestCase subclass with test methods, per-test setUp and tearDown, and XCTAssert checks.
  - Describe the XCTest lifecycle, including the class-level setUp, the new instance per test method, and teardown blocks.
  - Test a completion-handler API with an XCTestExpectation, using wait(for:timeout:) in synchronous tests and fulfillment(of:timeout:) in async ones.
  - Run XCTest and Swift Testing in the same target and read the output of both.
  - Translate XCTest assertions to #expect and #require, and decide which tests to migrate and which to keep in XCTest.
terms:
  - term: XCTestCase
    definition: "The XCTest base class for a group of tests. Each method whose name starts with test, takes no parameters and returns nothing is a test method."
  - term: setUp and tearDown
    definition: "Instance methods XCTest calls before and after every test method. The class methods with the same names run once, before the first test and after the last one in the class."
  - term: XCTestExpectation
    definition: "An object a test creates for an asynchronous event, fulfills when the event happens, and waits on with a timeout. Unfulfilled at the timeout, it fails the test."
  - term: Teardown block
    definition: "A closure registered with addTeardownBlock(_:) during a test. XCTest runs registered blocks after the test, last in first out, before tearDown()."
mastery:
  - Read an existing XCTest file and say what each method does and in what order it runs.
  - Write XCTest checks with XCTAssertEqual, XCTAssertNil, XCTUnwrap and XCTAssertThrowsError.
  - Test a callback API with an expectation, and say why an async test must use fulfillment(of:timeout:) instead of wait(for:timeout:).
  - Convert an XCTestCase into a Swift Testing suite, mapping setUp to init and each assertion to #expect or #require.
  - List the kinds of tests that stay in XCTest and explain the risk of calling XCTest assertions from Swift Testing tests.
resources: [swift-testing-docs, swift-checkedcontinuation, swift-book-inheritance, swift-book-closures]
cards:
  - id: m33-l02-c1
    front: How does XCTest find and run test methods?
    back: "Instance methods of an XCTestCase subclass whose names start with test, with no parameters and no return value. It creates a new instance of the class for each test method, calls setUp(), the test, any teardown blocks, then tearDown()."
  - id: m33-l02-c2
    front: wait(for:timeout:) or fulfillment(of:timeout:)?
    back: "wait(for:timeout:) in synchronous test methods; await fulfillment(of:timeout:) in async ones. Swift 6.3's XCTest rejects wait in an async context: \"instance method 'wait' is unavailable from asynchronous contexts\"."
  - id: m33-l02-c3
    front: "XCTAssertEqual(x, y), XCTUnwrap(x), XCTFail(\"…\") in Swift Testing?"
    back: "#expect(x == y), try #require(x), Issue.record(\"…\")."
  - id: m33-l02-c4
    front: Which tests stay in XCTest?
    back: "UI tests (XCUIAutomation is driven from XCTest), performance tests with measure and metrics (Swift Testing documents no equivalent), and tests written in Objective-C."
  - id: m33-l02-c5
    front: What happens to a failing XCTAssert inside a Swift Testing test?
    back: "With Swift 6.3 nothing: the test passes, and a failing #expect inside an XCTest method passes too. Apple documents interoperability modes that report these failures with 6.4 and later toolchains. Until then, keep each framework's assertions in its own tests."
---

## The idea in one sentence

XCTest is the older test framework: tests are methods named `test…` on an `XCTestCase` subclass, checks are `XCTAssert…` functions, and asynchronous callbacks are awaited with expectations; it runs side by side with Swift Testing, so you migrate gradually and leave UI and performance tests where they are.

XCTest has shipped with Xcode for over a decade, so most existing iOS code bases have thousands of XCTest tests. You'll read them long before you write new ones. The suites in this lesson were built and run with `swift test` (Swift 6.3, Linux, which uses the open-source XCTest); output is trimmed of timestamps and paths. Where Linux behaved differently from Apple's [XCTest documentation](https://developer.apple.com/documentation/xctest), the lesson says so.

## An XCTestCase

The reading-list tests from lesson 1, in XCTest:

```swift illustrative
import XCTest
@testable import Bookshelf

final class ReadingListXCTests: XCTestCase {
    var books: [Book] = []

    override func setUp() {
        super.setUp()
        books = [
            Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
            Book(id: 2, title: "Piranesi", author: "Susanna Clarke", isRead: false),
            Book(id: 3, title: "Beloved", author: "Toni Morrison", isRead: false),
        ]
    }

    override func tearDown() {
        books = []
        super.tearDown()
    }

    func testUnreadBooksComeFirst() {
        let titles = ReadingList.ordered(books).map(\.title)
        XCTAssertEqual(titles, ["Beloved", "Piranesi", "Kindred"])
    }

    func testSummaryCountsReadBooks() {
        let readCount = books.filter(\.isRead).count
        XCTAssertEqual(ReadingList.summary(read: readCount, total: books.count), "1 of 3 read")
    }

    func testNextUpIsTheFirstUnreadTitle() throws {
        let next = try XCTUnwrap(ReadingList.nextUp(in: books))
        XCTAssertEqual(next.title, "Beloved")
        XCTAssertFalse(next.isRead)
    }

    func testNothingIsNextWhenEverythingIsRead() {
        for index in books.indices {
            books[index].isRead = true
        }
        XCTAssertNil(ReadingList.nextUp(in: books))
    }

    func testLineWithoutAuthorIsRejected() {
        XCTAssertThrowsError(try BookImporter.parse("Kindred", id: 7)) { error in
            XCTAssertEqual(error as? ImportError, .missingAuthor)
        }
    }
}
```

How it works:

- **`final class ReadingListXCTests: XCTestCase`.** Tests are grouped in a class that inherits from `XCTestCase`. There are no free-function tests in XCTest.
- **`func testUnreadBooksComeFirst()`.** A test method must be an instance method whose name starts with `test`, with no parameters and no return value. That naming rule is how XCTest finds tests. A method called `unreadBooksComeFirst()` is silently ignored.
- **`override func setUp()`** runs before every test method and **`tearDown()`** after it. Here `setUp` builds the sample books. Call `super` in both. When setup can fail, override `setUpWithError() throws` instead; XCTest marks the test failed if it throws.
- **`XCTAssertEqual(titles, [...])`**, **`XCTAssertFalse`**, **`XCTAssertNil`**: one function per kind of check, about 40 in all. Each takes an optional message as a last argument.
- **`try XCTUnwrap(...)`** returns the unwrapped value or throws, ending the test. It's the XCTest equivalent of `try #require(optional)`; the test method is `throws` so the error can leave it.
- **`XCTAssertThrowsError(try ...) { error in ... }`** passes if the expression throws, and hands you the error for further checks. `error as? ImportError` is needed because the error arrives as `any Error`.

The XCTest output for that class (timestamps trimmed):

```text
Test Suite 'ReadingListXCTests' started
Test Case 'ReadingListXCTests.testLineWithoutAuthorIsRejected' passed (0.0 seconds)
Test Case 'ReadingListXCTests.testNextUpIsTheFirstUnreadTitle' passed (0.0 seconds)
Test Case 'ReadingListXCTests.testNothingIsNextWhenEverythingIsRead' passed (0.0 seconds)
Test Case 'ReadingListXCTests.testSummaryCountsReadBooks' passed (0.0 seconds)
Test Case 'ReadingListXCTests.testUnreadBooksComeFirst' passed (0.0 seconds)
Test Suite 'ReadingListXCTests' passed
	 Executed 5 tests, with 0 failures (0 unexpected) in 0.001 (0.001) seconds
```

In this run the methods ran one after another, in alphabetical order rather than the order in the file. Don't rely on either: a test that only passes after another one has run is broken.

### Failure messages

A failing `XCTAssertEqual` prints both values. The plain `XCTAssert(a == b)` can't, because it receives only a `Bool`:

```swift illustrative
import XCTest
@testable import Bookshelf

final class FailingXCTests: XCTestCase {
    func testSummaryAfterReadingTwo() {
        XCTAssertEqual(ReadingList.summary(read: 2, total: 3), "3 of 3 read")
    }

    func testCoverThatNeverArrives() {
        let loader = CoverLoader(covers: [:])
        let loaded = expectation(description: "cover loaded")

        loader.loadCover(for: 9) { result in
            if case .success = result {
                loaded.fulfill()
            }
        }

        wait(for: [loaded], timeout: 0.5)
    }
}
```

```text
FailingXCTests.swift:6: error: FailingXCTests.testSummaryAfterReadingTwo : XCTAssertEqual failed: ("2 of 3 read") is not equal to ("3 of 3 read") -
FailingXCTests.swift:19: error: FailingXCTests.testCoverThatNeverArrives : Asynchronous wait failed - Exceeded timeout of 0.5 seconds, with unfulfilled expectations: cover loaded
```

The same check written as `XCTAssert(ReadingList.summary(read: 2, total: 3) == "3 of 3 read")` printed only `XCTAssertTrue failed -`. That's why XCTest has a function per kind of comparison, and why Swift Testing's `#expect`, which reads the expression itself, needs only one. The second failure is an expectation timing out; expectations are below.

## The lifecycle

XCTest's order of calls matters when tests share setup. This class prints each step:

```swift illustrative
import XCTest

final class LifecycleTests: XCTestCase {
    var log: [String] = []

    override class func setUp() {
        super.setUp()
        print("class setUp: once, before the first test")
    }

    override func setUp() {
        super.setUp()
        log.append("setUp")
        print("setUp for \(name), log has \(log.count) entry")
        addTeardownBlock {
            print("teardown block")
        }
    }

    override func tearDown() {
        print("tearDown")
        super.tearDown()
    }

    func testFirst() {
        print("testFirst")
    }

    func testSecond() {
        print("testSecond")
    }
}
```

```text
Test Suite 'LifecycleTests' started
class setUp: once, before the first test
Test Case 'LifecycleTests.testFirst' started
setUp for LifecycleTests.testFirst, log has 1 entry
testFirst
teardown block
tearDown
Test Case 'LifecycleTests.testFirst' passed (0.0 seconds)
Test Case 'LifecycleTests.testSecond' started
setUp for LifecycleTests.testSecond, log has 1 entry
testSecond
teardown block
tearDown
Test Case 'LifecycleTests.testSecond' passed (0.0 seconds)
```

Three things to read from it:

1. **`class func setUp()` runs once** for the whole class, before the first test. (There's a matching `class func tearDown()` after the last.) Use it rarely: anything it creates is shared by every test.
2. **Every test method gets a new instance.** `log` has one entry in both tests: `testSecond`'s instance never saw `testFirst`'s `setUp`. Swift Testing does the same thing with suite instances (lesson 1), so the habit transfers: keep per-test state in instance properties and build it in `setUp` or `init`.
3. **Teardown blocks run before `tearDown()`.** `addTeardownBlock { … }` registers cleanup next to the setup it undoes, which reads better than a long `tearDown`. Apple's documentation says registered blocks run last in, first out.

## Testing callback-based code with expectations

Many APIs still report results through a completion handler that's called later, on another queue. This loader is one; it also offers an `async` version built with a continuation (Module 29):

```swift
import Foundation

struct Cover: Equatable, Sendable {
    let bookID: Int
    let byteCount: Int
}

enum CoverError: Error, Equatable {
    case notFound
}

/// An older, callback-based API: it calls `completion` later, on its own queue.
final class CoverLoader: Sendable {
    private let covers: [Int: Int]
    private let queue = DispatchQueue(label: "CoverLoader")

    init(covers: [Int: Int]) {
        self.covers = covers
    }

    func loadCover(for bookID: Int, completion: @escaping @Sendable (Result<Cover, CoverError>) -> Void) {
        queue.async {
            if let size = self.covers[bookID] {
                completion(.success(Cover(bookID: bookID, byteCount: size)))
            } else {
                completion(.failure(.notFound))
            }
        }
    }

    /// The same operation as an async function, through a continuation.
    func cover(for bookID: Int) async throws -> Cover {
        try await withCheckedThrowingContinuation { continuation in
            loadCover(for: bookID) { result in
                continuation.resume(with: result)
            }
        }
    }
}

let loader = CoverLoader(covers: [3: 2_048])
print(try await loader.cover(for: 3))
do {
    _ = try await loader.cover(for: 9)
} catch {
    print(error)
}
```

```output
Cover(bookID: 3, byteCount: 2048)
notFound
```

A test can't just call `loadCover` and check a variable afterward: the completion runs later, after the test function has returned. In Swift 6 it doesn't even compile, because the completion is `@Sendable` and may run concurrently with the code that reads the variable:

```swift no-compile mutation of captured var 'loaded' in concurrently-executing code
import Foundation

struct Cover: Equatable, Sendable {
    let bookID: Int
    let byteCount: Int
}

enum CoverError: Error, Equatable {
    case notFound
}

/// An older, callback-based API: it calls `completion` later, on its own queue.
final class CoverLoader: Sendable {
    private let covers: [Int: Int]
    private let queue = DispatchQueue(label: "CoverLoader")

    init(covers: [Int: Int]) {
        self.covers = covers
    }

    func loadCover(for bookID: Int, completion: @escaping @Sendable (Result<Cover, CoverError>) -> Void) {
        queue.async {
            if let size = self.covers[bookID] {
                completion(.success(Cover(bookID: bookID, byteCount: size)))
            } else {
                completion(.failure(.notFound))
            }
        }
    }

    /// The same operation as an async function, through a continuation.
    func cover(for bookID: Int) async throws -> Cover {
        try await withCheckedThrowingContinuation { continuation in
            loadCover(for: bookID) { result in
                continuation.resume(with: result)
            }
        }
    }
}

func checkCoverLoads() {
    let loader = CoverLoader(covers: [3: 2_048])
    var loaded: Cover?
    loader.loadCover(for: 3) { result in
        loaded = try? result.get()
    }
    print(loaded?.byteCount ?? 0)
}

checkCoverLoads()
```

Swift 6.3 says `error: mutation of captured var 'loaded' in concurrently-executing code`. The test has to **wait** for the callback. That's what an `XCTestExpectation` is for:

```swift illustrative
import XCTest
@testable import Bookshelf

final class CoverLoaderTests: XCTestCase {
    func testLoadsACoverWithAnExpectation() {
        let loader = CoverLoader(covers: [3: 2_048])
        let loaded = expectation(description: "cover loaded")

        loader.loadCover(for: 3) { result in
            XCTAssertEqual(try? result.get(), Cover(bookID: 3, byteCount: 2_048))
            loaded.fulfill()
        }

        wait(for: [loaded], timeout: 1)
    }

    func testMissingCoverInAnAsyncTest() async {
        let loader = CoverLoader(covers: [:])
        let failed = expectation(description: "load failed")

        loader.loadCover(for: 9) { result in
            if case .failure(let error) = result {
                XCTAssertEqual(error, .notFound)
                failed.fulfill()
            }
        }

        await fulfillment(of: [failed], timeout: 1)
    }

    func testLoadsACoverWithAwait() async throws {
        let loader = CoverLoader(covers: [3: 2_048])
        let cover = try await loader.cover(for: 3)
        XCTAssertEqual(cover.byteCount, 2_048)
    }
}
```

- **`expectation(description:)`** creates an expectation. The description appears in the failure message if it times out.
- **`fulfill()`** in the callback marks it done. Put the assertions before it, inside the callback.
- **`wait(for: [loaded], timeout: 1)`** blocks a **synchronous** test until every expectation is fulfilled or the timeout passes. In the failing example above, the callback never fulfilled, and the test failed after 0.5 seconds with `Exceeded timeout of 0.5 seconds, with unfulfilled expectations: cover loaded`.
- **`await fulfillment(of: [failed], timeout: 1)`** is the version for **async** test methods. Blocking inside an async function would tie up a thread the concurrency runtime needs, so Swift 6.3's XCTest refuses `wait` there: `error: instance method 'wait' is unavailable from asynchronous contexts; Use await fulfillment(of:timeout:enforceOrder:) instead.`
- **The best version needs no expectation.** `testLoadsACoverWithAwait` calls the `async` wrapper and checks the result directly. Apple's documentation for `wait(for:timeout:)` makes the same suggestion: wrap completion handlers with `withCheckedContinuation` and use `await`.

By default an expectation must be fulfilled exactly once; Apple documents `expectedFulfillmentCount` for events that happen several times and `isInverted` for "this must not happen". Keep timeouts short but not tight. A fake that calls back immediately needs milliseconds, and a long timeout only matters when the test is already failing.

## Both frameworks in one target

You don't migrate a test target in one go. XCTest and Swift Testing coexist in the same target, and even in the same file:

```swift illustrative
import Testing
import XCTest
@testable import Bookshelf

// The old test stays as it was...
final class SummaryXCTests: XCTestCase {
    func testAllRead() {
        XCTAssertEqual(ReadingList.summary(read: 3, total: 3), "All 3 read")
    }
}

// ...and new tests use Swift Testing, in the same target and even the same file.
@Test(arguments: [(0, "No books yet"), (3, "All 3 read")])
func summaryEdges(total: Int, expected: String) {
    #expect(ReadingList.summary(read: total, total: total) == expected)
}
```

`swift test` runs XCTest first, then Swift Testing, each with its own output format (trimmed):

```text
Test Case 'SummaryXCTests.testAllRead' passed (0.0 seconds)
Test Suite 'All tests' passed
◇ Test run started.
✔ Test summaryEdges(total:expected:) with 2 test cases passed after 0.001 seconds.
```

## Migrating

Apple's article [Migrating a test from XCTest](https://developer.apple.com/documentation/testing/migratingfromxctest) maps the pieces:

| XCTest | Swift Testing |
| --- | --- |
| `class FooTests: XCTestCase` | `struct FooTests` (a suite; `@Suite` optional) |
| `func testSomething()` | `@Test func something()` |
| `setUp()` / `setUpWithError()` | `init()` (may be `async throws`) |
| `tearDown()` | `deinit`, in a class or actor suite |
| `XCTAssert(x)`, `XCTAssertTrue(x)` | `#expect(x)` |
| `XCTAssertEqual(x, y)` | `#expect(x == y)` |
| `XCTAssertNil(x)` | `#expect(x == nil)` |
| `XCTAssertThrowsError(try f())` | `#expect(throws: (any Error).self) { try f() }` |
| `try XCTUnwrap(x)` | `try #require(x)` |
| `XCTFail("…")` | `Issue.record("…")` |
| `XCTestExpectation` + `wait` | `await` the async API, or `confirmation()` (lesson 4) |
| `XCTSkip` | `.enabled(if:)` / `.disabled` traits |
| `XCTExpectFailure` | `withKnownIssue { }` |

Two differences that change behavior, not just syntax:

- **Parallelism.** XCTest runs a class's tests one after another; Swift Testing runs tests in parallel by default. A test that quietly relied on order or on shared state starts failing after migration. That's a bug the migration exposed, not one it caused; `.serialized` is the stopgap.
- **Isolation.** Apple's guide says XCTest runs synchronous test methods on the main actor by default, while Swift Testing runs every test on an arbitrary task. Tests of `@MainActor` code need `@MainActor` on the test or suite (lesson 5 does this). On Linux, Swift 6.3's XCTest doesn't isolate test methods to the main actor either, so the explicit annotation is the portable choice.

### What to migrate, and what not

- **Write new unit tests in Swift Testing.** Parameterized tests, better failure messages and suites as structs are reasons enough.
- **Migrate old tests when you touch them**, not in a dedicated rewrite. A test that passes and nobody edits is doing its job in XCTest.
- **Keep UI tests in XCTest.** XCUIAutomation, the UI testing framework (lesson 5), is driven from `XCTestCase` subclasses.
- **Keep performance tests in XCTest.** `measure { }` and its metrics (lesson 6) have no counterpart in Swift Testing's documentation.
- **Keep Objective-C tests in XCTest.** Swift Testing is Swift only.
- **Floating-point comparisons with accuracy**, `XCTAssertEqual(x, y, accuracy:)`, have no Swift Testing equivalent; Apple points to `isApproximatelyEqual` in the swift-numerics package.

### Don't call XCTest assertions from Swift Testing

Old test targets have helper functions built on `XCTAssert…`. It's tempting to call them from new `@Test` functions. With Swift 6.3, the failures disappear:

```swift illustrative
import Testing
import XCTest
@testable import Bookshelf

/// An old helper written for XCTest.
func assertSummary(read: Int, total: Int, is expected: String) {
    XCTAssertEqual(ReadingList.summary(read: read, total: total), expected)
}

@Test func summaryThroughAnXCTestHelper() {
    assertSummary(read: 2, total: 3, is: "3 of 3 read")   // wrong on purpose
}
```

The helper's comparison fails (`"2 of 3 read"` isn't `"3 of 3 read"`), yet the run reports:

```text
✔ Test summaryThroughAnXCTestHelper() passed after 0.001 seconds.
```

The reverse fails silently too. In the same package, this XCTest method with a wrong `#expect` passed:

```swift illustrative
import Testing
import XCTest
@testable import Bookshelf

final class ExpectInXCTestTests: XCTestCase {
    func testSummaryWithExpect() {
        #expect(ReadingList.summary(read: 2, total: 3) == "3 of 3 read")   // wrong on purpose
    }
}
```

```text
Test Case 'ExpectInXCTestTests.testSummaryWithExpect' passed (0.001 seconds)
```

Apple's migration guide describes **interoperability modes** that make an XCTest assertion inside a Swift Testing test record an issue, and a Swift Testing expectation inside an XCTest method do the same. It says the default depends on the toolchain: `none` before 6.4, and `limited` or `complete` with a 6.4 toolchain, depending on the package's tools version. Both runs above used 6.3, so they show the `none` behavior. Until everyone on the team builds with a toolchain that reports these cross-framework failures (and you've checked that it does), keep each framework's checks inside its own tests: convert a shared helper to `#expect` only when every caller is a `@Test` function.

## Common mistakes

> [!error] error: instance method 'wait' is unavailable from asynchronous contexts
> `wait(for:timeout:)` inside an `async` test method. Use `await fulfillment(of: [expectation], timeout: 1)`, or better, `await` an async version of the API. (Swift 6.3, Linux XCTest.)

> [!error] error: mutation of captured var 'loaded' in concurrently-executing code
> Collecting a callback's result in a local `var` and checking it right after the call. The callback hasn't run yet, and Swift 6 rejects the capture. Fulfill an expectation in the callback, or wrap the API in a continuation and `await` it.

> [!error] A test method without the test prefix
> `func loadsCover()` in an `XCTestCase` compiles and never runs. The test count in the output is the only clue. Swift Testing's `@Test` doesn't have this problem.

> [!error] An expectation that's only fulfilled on success
> `if case .success = result { loaded.fulfill() }`: on failure, the test waits out the whole timeout and reports "unfulfilled expectations" instead of the actual error. Assert inside the callback and fulfill on every path.

> [!error] XCTAssert(a == b) for comparisons
> The failure says only `XCTAssertTrue failed`. Use `XCTAssertEqual(a, b)` so the message shows both values.

> [!error] Assertion helpers shared across frameworks
> With Swift 6.3, an XCTest helper called from a `@Test` function, or an `#expect` helper called from an XCTest method, drops its failures and the test passes. Keep a helper per framework until the migration is done.

## Exercises

````exercise
id: m33-l02-e1
type: comprehension
prompt: "An XCTestCase has a class func setUp(), an instance setUp(), two test methods, a teardown block registered in setUp, and tearDown(). Which order is correct for one run of the class?"
choices:
  - text: "class setUp, then for each test: setUp, test, teardown block, tearDown."
    correct: true
    why: "The class method runs once; every test gets its own instance and its own setUp/teardown, with teardown blocks before tearDown()."
  - text: "class setUp, setUp, test 1, test 2, teardown block, tearDown."
    correct: false
    why: "Instance setUp and tearDown run around every test, not once around all of them."
  - text: "setUp, class setUp, test, tearDown, teardown block, for each test."
    correct: false
    why: "The class setUp runs once before everything, and teardown blocks run before tearDown()."
  - text: "class setUp, then for each test: setUp, test, tearDown, teardown block."
    correct: false
    why: "Apple's documentation and the run in this lesson both put teardown blocks before tearDown()."
solution: |
  `class func setUp()` once; then per test method, on a new instance: `setUp()`, the test, registered teardown blocks (last in, first out), `tearDown()`. The lesson's `LifecycleTests` output shows exactly this order.
````

````exercise
id: m33-l02-e2
type: prediction
prompt: "This program imitates two test runners: one that does what XCTest and Swift Testing do (a new instance and setUp for each test), and a naive one that reuses one instance and never calls setUp. What does it print?"
code: |
  final class ShelfTests {
      var shelf: [String] = []

      func setUp() {
          shelf = ["Kindred"]
      }

      func testAdd() {
          shelf.append("Piranesi")
          print("  testAdd: \(shelf.count)")
      }

      func testClear() {
          shelf.removeAll()
          print("  testClear: \(shelf.count)")
      }
  }

  let tests: [(ShelfTests) -> () -> Void] = [
      ShelfTests.testAdd,
      ShelfTests.testClear,
      ShelfTests.testAdd,
  ]

  print("new instance per test:")
  for test in tests {
      let instance = ShelfTests()
      instance.setUp()
      test(instance)()
  }

  print("one shared instance:")
  let shared = ShelfTests()
  for test in tests {
      test(shared)()
  }
output: |
  new instance per test:
    testAdd: 2
    testClear: 0
    testAdd: 2
  one shared instance:
    testAdd: 1
    testClear: 0
    testAdd: 1
solution: |
  `ShelfTests.testAdd` is an unapplied method reference: give it an instance and you get a function that runs the method on that instance.

  - With a new instance per test, every test starts from `setUp`'s `["Kindred"]`. Adding gives 2, clearing gives 0, and the second `testAdd` gives 2 again: it can't see what `testClear` did.
  - With a shared instance and no `setUp`, the shelf starts empty. The first add gives 1, clear gives 0, and the second add gives 1. Each result depends on what ran before.

  ```output
  new instance per test:
    testAdd: 2
    testClear: 0
    testAdd: 2
  one shared instance:
    testAdd: 1
    testClear: 0
    testAdd: 1
  ```

  Both real frameworks behave like the first runner, which is what makes test order irrelevant. The second runner is what you get by accident with `static` properties, singletons or `class func setUp()`.
````

````exercise
id: m33-l02-e3
type: fill-in
prompt: "Migrate these XCTest checks to Swift Testing. The test function has already been made throws."
code: |
  // XCTest
  XCTAssertEqual(ReadingList.summary(read: 1, total: 3), "1 of 3 read")
  let next = try XCTUnwrap(ReadingList.nextUp(in: books))
  XCTAssertNil(ReadingList.nextUp(in: []))
  XCTFail("Unreachable")

  // Swift Testing
  [[1]](ReadingList.summary(read: 1, total: 3) == "1 of 3 read")
  let next = try [[2]](ReadingList.nextUp(in: books))
  #expect(ReadingList.nextUp(in: []) [[3]] nil)
  [[4]].record("Unreachable")
blanks:
  - id: "1"
    answers: ["#expect"]
  - id: "2"
    answers: ["#require"]
  - id: "3"
    answers: ["=="]
  - id: "4"
    answers: ["Issue"]
solution: |
  `XCTAssertEqual(a, b)` becomes `#expect(a == b)`; `try XCTUnwrap(x)` becomes `try #require(x)`; `XCTAssertNil(x)` becomes `#expect(x == nil)`; `XCTFail` becomes `Issue.record`. These are the rows of Apple's migration table.
````

````exercise
id: m33-l02-e4
type: find-errors
prompt: "An XCTest class under review. Which comments point at real problems?"
code: |
  final class CoverLoaderTests: XCTestCase {
      let loader = CoverLoader(covers: [3: 2_048])

      func loadsKnownCover() {
          let loaded = expectation(description: "loaded")
          loader.loadCover(for: 3) { _ in loaded.fulfill() }
          wait(for: [loaded], timeout: 1)
      }

      func testMissingCover() {
          let failed = expectation(description: "failed")
          loader.loadCover(for: 9) { result in
              if case .failure(let error) = result {
                  XCTAssertEqual(error, .notFound)
              }
              failed.fulfill()
          }
          wait(for: [failed], timeout: 60)
      }

      func testCoverSize() async throws {
          let loaded = expectation(description: "loaded")
          var size = 0
          loader.loadCover(for: 3) { result in
              size = (try? result.get().byteCount) ?? 0
              loaded.fulfill()
          }
          wait(for: [loaded], timeout: 1)
          XCTAssert(size == 2_048)
      }
  }
choices:
  - text: "loadsKnownCover never runs: its name doesn't start with test."
    correct: true
    why: "XCTest only runs methods whose names begin with test."
  - text: "A 60-second timeout makes a failing run very slow; a fake that answers immediately needs about a second at most."
    correct: true
    why: "Timeouts only matter when the test is failing, and then they're dead time."
  - text: "testCoverSize uses wait(for:) in an async method, which XCTest rejects."
    correct: true
    why: "Use await fulfillment(of:timeout:), or call the async cover(for:) directly."
  - text: "testCoverSize mutates a captured var from a @Sendable callback, which Swift 6 rejects."
    correct: true
    why: "And it isn't needed: await loader.cover(for: 3) returns the value."
  - text: "XCTAssert(size == 2_048) hides both values when it fails."
    correct: true
    why: "XCTAssertEqual(size, 2_048) prints them."
  - text: "testMissingCover fails when the load succeeds, because fulfill() is called on both paths."
    correct: false
    why: "Fulfilling on every path is correct; it avoids waiting out the timeout. But note the success path has no assertion, so a successful load would pass silently. Add XCTFail in an else branch."
  - text: "The loader property should be created in setUp instead of as a let."
    correct: false
    why: "A stored let is initialized for each new instance, which is once per test. setUp is equivalent here."
rubric:
  - Finds the method that never runs.
  - Flags the long timeout.
  - Finds both compile errors in testCoverSize and proposes awaiting the async API.
  - Flags XCTAssert with a comparison.
  - Notices that testMissingCover passes silently if the load succeeds.
solution: |
  Five real problems, plus one subtle gap. A cleaned-up version:

  - Rename `loadsKnownCover` to `testLoadsKnownCover`.
  - In `testMissingCover`, add `else { XCTFail("Expected notFound, got \(result)") }` and lower the timeout to 1 second.
  - Replace `testCoverSize` with `let cover = try await loader.cover(for: 3)` and `XCTAssertEqual(cover.byteCount, 2_048)`. No expectation, no captured variable.

  The `let loader` property is fine: each test method gets a new instance, so each gets a new loader.
````

````exercise
id: m33-l02-e5
type: solve
prompt: "Migrate `ReadingListXCTests` from this lesson to a Swift Testing suite. Keep every check, move the setup to the right place, and take the chance to improve the tests where Swift Testing allows it."
starter: |
  import Testing
  @testable import Bookshelf

  struct ReadingListTests {
      // Your code
  }
rubric:
  - Replaces setUp with a stored property initialized per instance (or an init), and drops tearDown, which only reset state.
  - Uses #expect for comparisons and try #require instead of XCTUnwrap.
  - "Translates XCTAssertThrowsError plus the cast to #expect(throws: ImportError.missingAuthor)."
  - "Changes the all-read test so it doesn't mutate shared fixtures in a loop, or explains why the mutation is safe in a fresh instance."
  - Keeps test names descriptive without the test prefix.
solution: |
  ```swift illustrative
  import Testing
  @testable import Bookshelf

  struct ReadingListTests {
      let books = [
          Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
          Book(id: 2, title: "Piranesi", author: "Susanna Clarke", isRead: false),
          Book(id: 3, title: "Beloved", author: "Toni Morrison", isRead: false),
      ]

      @Test func unreadBooksComeFirst() {
          #expect(ReadingList.ordered(books).map(\.title) == ["Beloved", "Piranesi", "Kindred"])
      }

      @Test func summaryCountsReadBooks() {
          let readCount = books.filter(\.isRead).count
          #expect(ReadingList.summary(read: readCount, total: books.count) == "1 of 3 read")
      }

      @Test func nextUpIsTheFirstUnreadTitle() throws {
          let next = try #require(ReadingList.nextUp(in: books))
          #expect(next.title == "Beloved")
          #expect(!next.isRead)
      }

      @Test func nothingIsNextWhenEverythingIsRead() {
          let allRead = books.map { book in
              var book = book
              book.isRead = true
              return book
          }
          #expect(ReadingList.nextUp(in: allRead) == nil)
      }

      @Test func lineWithoutAuthorIsRejected() {
          #expect(throws: ImportError.missingAuthor) {
              try BookImporter.parse("Kindred", id: 7)
          }
      }
  }
  ```

  It was built and run with `swift test` (Swift 6.3, Linux) against the same `Bookshelf` module as the XCTest version, and both pass. What changed:

  - `setUp` became a stored property with a default value: each test gets a fresh suite instance, so the books are rebuilt for every test. `tearDown` only emptied the array, so it has no replacement; the instance is thrown away.
  - `try XCTUnwrap` became `try #require`; `XCTAssertEqual`, `XCTAssertFalse` and `XCTAssertNil` became `#expect` with ordinary operators.
  - The throws check got shorter, since `#expect(throws:)` compares the error value directly instead of casting.
  - The all-read test builds its own list with `map` instead of mutating the shared one in a loop. Mutating would also have been safe (the instance is fresh), but `books` is now a `let`, which states that tests don't modify the fixture.
````

````exercise
id: m33-l02-e6
type: design
prompt: "Your team has 1,800 XCTest unit tests, 60 UI tests, 12 performance tests and a set of XCTest helper functions like assertSameBooks(_:_:) used everywhere. The team builds with a Swift 6.3 toolchain today. Plan the move to Swift Testing."
rubric:
  - New tests in Swift Testing from now on; old ones migrated when touched, not in a big rewrite.
  - UI and performance tests stay in XCTest, with the reasons.
  - Addresses the helper functions, recognizing that on 6.3 assertions from one framework are silently ignored inside the other's tests.
  - Mentions parallel execution exposing order-dependent tests and the .serialized stopgap.
  - Mentions main-actor isolation for tests of @MainActor code.
solution: |
  1. **Start with the helpers.** On a 6.3 toolchain an `XCTAssert` inside a helper called from a `@Test` function records nothing, and an `#expect` inside an XCTest method records nothing either, so a helper written for one framework silently checks nothing in the other. Keep two versions of each helper while both frameworks are in use (`assertSameBooks` with `XCTAssertEqual`, `expectSameBooks` with `#expect`), and delete the XCTest one when its last caller migrates. Once the team's toolchain reports cross-framework issues (Apple documents this from 6.4), verify it with a deliberately failing test and simplify.
  2. **New tests in Swift Testing**, in the same targets. No new target is needed; both frameworks run together.
  3. **Migrate when touching.** When someone edits an XCTest class, they convert it: `setUp` to stored properties or `init`, assertions to `#expect`/`#require`, loops to `arguments:`.
  4. **Expect failures from parallelism.** Some converted tests will fail because they relied on running one at a time. Fix the shared state; use `.serialized` only as a temporary marker with a bug link.
  5. **Annotate main-actor tests.** XCTest ran synchronous methods on the main actor; Swift Testing doesn't, so tests of `@MainActor` view models need `@MainActor`.
  6. **Leave UI and performance tests in XCTest.** UI tests use XCUIAutomation through `XCTestCase`, and `measure` has no Swift Testing counterpart. They're a small set and don't block anything.
````

## Summary

- XCTest tests are `test…` methods on an `XCTestCase` subclass. Each test method runs on a **new instance**, between `setUp()` and `tearDown()`; teardown blocks run before `tearDown()`; `class func setUp()` runs once.
- Checks are the `XCTAssert…` family; `XCTAssertEqual` and friends print both values, `XCTAssert(a == b)` doesn't. `try XCTUnwrap` unwraps or ends the test.
- For completion handlers, fulfill an `XCTestExpectation` in the callback and wait with `wait(for:timeout:)` (sync tests) or `await fulfillment(of:timeout:)` (async tests). Better: wrap the API in a continuation and `await` it.
- XCTest and Swift Testing run side by side in one target. Write new tests in Swift Testing, migrate old ones when you touch them, and keep UI, performance and Objective-C tests in XCTest.
- With Swift 6.3, an `XCTAssert` inside a Swift Testing test is silently ignored, and so is an `#expect` inside an XCTest method. Keep each framework's assertions, including shared helpers, inside its own tests.
- Swift Testing runs tests in parallel and off the main actor; migration can expose order-dependent tests and needs `@MainActor` on tests of main-actor code.

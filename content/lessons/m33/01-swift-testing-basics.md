---
id: m33-l01
title: Swift Testing basics
description: "Write unit tests with Swift Testing: @Test functions, #expect and #require, error expectations, suites whose init runs before every test, parameterized tests with arguments, and the traits that disable, tag, link and time-limit tests. Every suite in the lesson was built and run with swift test."
module: m33
order: 1
level: advanced
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m32-l06]
objectives:
  - Set up a test target that imports Testing and the module under test with @testable import.
  - Write @Test functions that check results with #expect and stop early with #require.
  - Check that code throws a specific error with #expect(throws:).
  - Group tests in a @Suite type and use its init for per-test setup.
  - Turn repeated tests into one parameterized test, and predict how many cases two argument collections produce.
  - Apply the .disabled, .bug, .tags, .timeLimit and .enabled(if:) traits and read what they do in the test output.
terms:
  - term: Test function
    definition: "A function marked @Test. Swift Testing finds it at build time; it can be global or a member of a type, and it can be async, throws, or isolated to an actor."
  - term: "#expect"
    definition: "A macro that checks a Boolean condition. When it fails it records an issue with the values of the subexpressions, and the test keeps running."
  - term: "#require"
    definition: "Like #expect, but it throws when the condition is false or the optional is nil, so the test stops there. With an optional it returns the unwrapped value."
  - term: Suite
    definition: "A type that contains test functions, optionally marked @Suite to give it a name or traits. Swift Testing creates a new instance for every instance test it runs."
  - term: Parameterized test
    definition: "A @Test with arguments:. Swift Testing calls it once per element (a test case); with two collections it uses every combination, unless you zip them."
  - term: Trait
    definition: "A value passed to @Test or @Suite that changes how a test runs or is described: .disabled, .enabled(if:), .bug, .tags, .timeLimit, .serialized."
mastery:
  - Write a test file that imports Testing and the app module, with tests that pass and fail for the right reasons.
  - Choose between #expect and #require for each check, and unwrap optionals with try #require.
  - Write #expect(throws:) checks for a specific error value and for any error of a type.
  - Move shared setup into a suite's init and explain why each test gets its own instance.
  - Replace a for loop inside a test with arguments:, and say how many cases zip and two collections produce.
  - Attach traits to tests and suites, and say how each one shows up when the tests run.
resources: [swift-testing-docs, swiftpm-docs, swift-book-error-handling, swift-book-initialization]
cards:
  - id: m33-l01-c1
    front: "#expect or #require?"
    back: "#expect records a failure and the test continues, so you see every broken check. #require throws and ends the test; use it when the rest of the test makes no sense without that value, typically to unwrap an optional with try #require(x)."
  - id: m33-l01-c2
    front: How does Swift Testing run instance tests in a suite?
    back: "It creates a fresh instance of the suite type for every test function (and every test case of a parameterized test), so init works as per-test setup and tests can't leak state into each other through stored properties."
  - id: m33-l01-c3
    front: "@Test(arguments: a, b) with 3 and 4 elements: how many test cases?"
    back: "12: every combination of the two collections. @Test(arguments: zip(a, b)) gives 3, pairing elements by position."
  - id: m33-l01-c4
    front: How do you check that a call throws a specific error?
    back: "#expect(throws: ImportError.missingAuthor) { try parse(line) }. The error type must be Equatable for that form; #expect(throws: ImportError.self) accepts any error of the type."
  - id: m33-l01-c5
    front: "What do .disabled, .bug, .tags and .timeLimit do?"
    back: ".disabled(\"why\") skips the test and prints the reason. .bug(url, title) links the test to a bug report. .tags(.x) labels tests for grouping and filtering. .timeLimit(.minutes(n)) fails a test that runs longer than n minutes."
---

## The idea in one sentence

A Swift Testing test is a function marked `@Test` that runs the code under test and checks the results with `#expect` and `#require`; suites group tests and give each one fresh state, arguments turn one test into many cases, and traits change how tests run.

> [!note] How the code in this module was checked
> The course's snippet tests compile each code block as a standalone program, and a program can't run a test suite. So the code under test appears in ordinary blocks that exercise it with `print`, and those run as usual. The test suites themselves were built into small Swift packages and run with `swift test` (Swift 6.3, Linux), each with the exact code shown. The test output quoted below is from those runs, with timings and file paths trimmed. API details come from Apple's [Swift Testing documentation](https://developer.apple.com/documentation/testing), read in November 2026; Xcode's test navigator wasn't checked.

## Where tests live

Tests live in a **test target**, a separate module that depends on the module under test. In Xcode you add a Unit Testing Bundle target; in a Swift package you declare a `testTarget`:

```swift illustrative
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Bookshelf",
    targets: [
        .target(name: "Bookshelf"),
        .testTarget(name: "BookshelfTests", dependencies: ["Bookshelf"]),
    ]
)
```

The test target's sources go in `Tests/BookshelfTests/`. Each test file starts with two imports:

```swift illustrative
import Testing
@testable import Bookshelf
```

`Testing` is the framework. It ships with the Swift 6 toolchain (Apple lists Swift 6.0 and Xcode 16), including on Linux, so there's no package dependency to add. `@testable import` lets the tests see the module's `internal` declarations, which is what most app code is; without it, tests only see `public` ones. `@testable` works when the module is built with testing enabled, which debug builds are by default.

## The code under test

This module tests the reading-list feature from Module 32. The first pieces are plain functions: the order of the list, the header text, the book to suggest next, and an importer that reads lines like `Kindred; Octavia E. Butler`:

```swift
import Foundation

struct Book: Equatable, Sendable {
    let id: Int
    let title: String
    let author: String
    var isRead: Bool
}

enum ReadingList {
    /// Unread books first, then read ones; alphabetical by title inside each group.
    static func ordered(_ books: [Book]) -> [Book] {
        books.sorted { lhs, rhs in
            lhs.isRead != rhs.isRead ? !lhs.isRead : lhs.title < rhs.title
        }
    }

    /// The header above the list.
    static func summary(read: Int, total: Int) -> String {
        if total == 0 { return "No books yet" }
        if read == total { return "All \(total) read" }
        return "\(read) of \(total) read"
    }

    /// The book at the top of the list if it's unread: the one to suggest next.
    static func nextUp(in books: [Book]) -> Book? {
        ordered(books).first { !$0.isRead }
    }
}

enum ImportError: Error, Equatable {
    case missingTitle
    case missingAuthor
}

enum BookImporter {
    /// Parses one line of an import file: "Title; Author".
    static func parse(_ line: String, id: Int) throws -> Book {
        let parts = line.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard let title = parts.first, !title.isEmpty else { throw ImportError.missingTitle }
        guard parts.count == 2, !parts[1].isEmpty else { throw ImportError.missingAuthor }
        return Book(id: id, title: title, author: parts[1], isRead: false)
    }
}

let books = [
    Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
    Book(id: 2, title: "Piranesi", author: "Susanna Clarke", isRead: false),
    Book(id: 3, title: "Beloved", author: "Toni Morrison", isRead: false),
]
print(ReadingList.ordered(books).map(\.title))
print(ReadingList.summary(read: 1, total: 3))
print(ReadingList.nextUp(in: books)?.title ?? "nothing")
print(try BookImporter.parse("Kindred; Octavia E. Butler", id: 7).author)
do {
    _ = try BookImporter.parse("Kindred", id: 8)
} catch {
    print(error)
}
```

```output
["Beloved", "Piranesi", "Kindred"]
1 of 3 read
Beloved
Octavia E. Butler
missingAuthor
```

Those `print` calls are how you'd check it by hand. A test does the same thing, except the computer compares the results.

## A first test

```swift illustrative
import Testing
@testable import Bookshelf

@Test func unreadBooksComeFirst() {
    let books = [
        Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
        Book(id: 2, title: "Piranesi", author: "Susanna Clarke", isRead: false),
        Book(id: 3, title: "Beloved", author: "Toni Morrison", isRead: false),
    ]

    let titles = ReadingList.ordered(books).map(\.title)

    #expect(titles == ["Beloved", "Piranesi", "Kindred"])
}

@Test("The header counts read books")
func headerCountsReadBooks() {
    #expect(ReadingList.summary(read: 1, total: 3) == "1 of 3 read")
}
```

Line by line:

- `@Test` marks the function as a test. The name can be anything; there's no `test` prefix rule. Swift Testing finds tests through the macro at build time, so a function without `@Test` is just a helper and never runs.
- The body follows **arrange, act, assert**: build the input, call the code once, check the result. Keeping those three steps visible makes a failing test easy to read.
- `#expect(titles == ["Beloved", "Piranesi", "Kindred"])` is the check. It takes an ordinary Boolean expression; there's no `assertEqual` family to learn.
- `@Test("The header counts read books")` gives the test a display name, shown instead of the function name in the output and in Xcode.

Running `swift test` in the package builds the targets and runs every test. The relevant lines (trimmed):

```text
✔ Test unreadBooksComeFirst() passed after 0.001 seconds.
✔ Test "The header counts read books" passed after 0.001 seconds.
```

### What a failure looks like

The value of `#expect` shows up when it fails. This test has the wrong expected value on purpose:

```swift illustrative
import Testing
@testable import Bookshelf

@Test func headerAfterReadingTwo() {
    let books = [
        Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
        Book(id: 2, title: "Piranesi", author: "Susanna Clarke", isRead: true),
        Book(id: 3, title: "Beloved", author: "Toni Morrison", isRead: false),
    ]
    let readCount = books.filter(\.isRead).count
    #expect(ReadingList.summary(read: readCount, total: books.count) == "3 of 3 read")
}

@Test func nextUpWhenEverythingIsRead() throws {
    let books = [Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true)]
    let next = try #require(ReadingList.nextUp(in: books))
    #expect(next.title == "Kindred")
}
```

The output from `swift test`:

```text
✘ Test headerAfterReadingTwo() recorded an issue at FailureTests.swift:11:5: Expectation failed: (ReadingList.summary(read: readCount, total: books.count) → "2 of 3 read") == "3 of 3 read"
✘ Test headerAfterReadingTwo() failed after 0.001 seconds with 1 issue.
✘ Test nextUpWhenEverythingIsRead() recorded an issue at FailureTests.swift:16:20: Expectation failed: ReadingList.nextUp(in: books → [Bookshelf.Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true)]) → nil
✘ Test nextUpWhenEverythingIsRead() failed after 0.001 seconds with 1 issue.
✘ Test run with 2 tests in 0 suites failed after 0.002 seconds with 2 issues.
```

Because `#expect` is a macro, it sees the expression's parts, not only the final `false`. The message shows the source and the value of each side: the function returned `"2 of 3 read"`, the test expected `"3 of 3 read"`. You usually don't need a custom message, because the expression already says what was checked.

## #require: stop when there's no point going on

The second failing test above used `try #require(...)`. `#require` checks the same way as `#expect`, but on failure it **throws**, which ends the test. With an optional, it returns the unwrapped value:

```swift illustrative
import Testing
@testable import Bookshelf

@Test func nextUpIsTheFirstUnreadTitle() throws {
    let books = [
        Book(id: 1, title: "Piranesi", author: "Susanna Clarke", isRead: false),
        Book(id: 2, title: "Beloved", author: "Toni Morrison", isRead: false),
    ]

    let next = try #require(ReadingList.nextUp(in: books))

    #expect(next.title == "Beloved")
    #expect(next.isRead == false)
}

@Test func nothingIsNextWhenEverythingIsRead() {
    let books = [Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true)]
    #expect(ReadingList.nextUp(in: books) == nil)
}
```

- `try #require(ReadingList.nextUp(in: books))` unwraps the `Book?`. If it's `nil`, the test records an issue and stops; the later lines would only produce confusing follow-on failures.
- The test function is `throws` so the error from `#require` can leave it. A thrown error that escapes a test also counts as a failure, which is why tests can call throwing code with plain `try`.
- `#expect(ReadingList.nextUp(in: books) == nil)` checks for `nil` without unwrapping.

Use `#expect` by default, so one run reports every broken check. Reach for `#require` when the remaining checks depend on the value: unwrapping, or a precondition like "the array has three elements" before indexing into it. Never force-unwrap in a test: `!` on `nil` crashes the whole test process, not just the one test.

## Expecting errors

`#expect(throws:)` runs a closure and checks what it throws:

```swift illustrative
import Testing
@testable import Bookshelf

@Test func parsesTitleAndAuthor() throws {
    let book = try BookImporter.parse("Kindred; Octavia E. Butler", id: 7)
    #expect(book == Book(id: 7, title: "Kindred", author: "Octavia E. Butler", isRead: false))
}

@Test func aLineWithoutAuthorIsRejected() {
    #expect(throws: ImportError.missingAuthor) {
        try BookImporter.parse("Kindred", id: 7)
    }
}

@Test func anyImportErrorWillDo() {
    #expect(throws: ImportError.self) {
        try BookImporter.parse("   ", id: 7)
    }
}
```

- `#expect(throws: ImportError.missingAuthor)` passes only if the closure throws that exact value. This form needs the error to be `Equatable`; a simple enum like `ImportError` is, because it declares the conformance.
- `#expect(throws: ImportError.self)` passes for any `ImportError`.
- If the closure doesn't throw, or throws something else, the expectation fails. Apple's [migration guide](https://developer.apple.com/documentation/testing/migratingfromxctest) also lists `#expect(throws: Never.self) { … }` for "doesn't throw", though a plain `try` in a throwing test does the same job.
- `parsesTitleAndAuthor` compares the whole `Book` with `==`. Comparing whole values is shorter than four separate checks, and the failure message prints both values.

## Suites

Any type that contains `@Test` functions is a **suite**. `@Suite` is optional; it lets you give the suite a display name and traits. Suites can nest:

```swift illustrative
import Testing
@testable import Bookshelf

@Suite("Book importer")
struct BookImporterSuite {
    let lines: [String]

    init() {
        lines = ["Kindred; Octavia E. Butler", "Piranesi ;Susanna Clarke"]
    }

    @Test func importsEveryLine() throws {
        let books = try lines.enumerated().map { index, line in
            try BookImporter.parse(line, id: index + 1)
        }
        #expect(books.map(\.title) == ["Kindred", "Piranesi"])
        #expect(books.map(\.author) == ["Octavia E. Butler", "Susanna Clarke"])
    }

    @Suite struct Rejections {
        @Test func blankLine() {
            #expect(throws: ImportError.missingTitle) {
                try BookImporter.parse("   ", id: 1)
            }
        }

        @Test func authorWithoutTitle() {
            #expect(throws: ImportError.missingTitle) {
                try BookImporter.parse("; Octavia E. Butler", id: 1)
            }
        }
    }
}
```

The important rule is in Apple's article [Organizing test functions with suite types](https://developer.apple.com/documentation/testing/organizingtests): for every instance test, Swift Testing **creates a new instance of the suite**. So `init` is per-test setup (XCTest's `setUp`, which lesson 2 covers), and a test can't see what another test did to the stored properties.

You can watch it happen with a class suite that prints from `init` and `deinit`:

```swift illustrative
import Testing
@testable import Bookshelf

final class FreshInstanceTests {
    var books = [Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: false)]

    init() {
        print("init")
    }

    deinit {
        print("deinit")
    }

    @Test func addingABook() {
        books.append(Book(id: 2, title: "Piranesi", author: "Susanna Clarke", isRead: false))
        #expect(books.count == 2)
    }

    @Test func removingABook() {
        books.removeAll()
        #expect(books.isEmpty)
    }
}
```

Both tests pass, even though one adds a book and the other removes all of them. The output contains `init` and `deinit` twice, once per test. A class's `deinit` serves as teardown. Apple's migration guide generally recommends a struct or an actor over a class, because the compiler can check their concurrency safety better; when you need teardown, use a class or an actor and implement `deinit`.

Two constraints come with the instance-per-test rule:

- The suite needs an initializer with **no arguments** (it can be `async` and `throws`). With only `init(fileName:)`, the build fails inside the macro expansion with `error: missing argument for parameter 'fileName' in call` (Swift 6.3).
- Tests **run in parallel** by default, including tests in the same suite. That's safe when each test owns its state, which the fresh instances give you. It isn't safe with shared `static` or global state; the `.serialized` trait (below) runs a suite's tests one at a time when you can't avoid sharing.

## Parameterized tests

When several tests differ only in their inputs, write one test and pass the inputs with `arguments:`:

```swift illustrative
import Testing
@testable import Bookshelf

@Test(arguments: [
    (read: 0, total: 0, expected: "No books yet"),
    (read: 0, total: 3, expected: "0 of 3 read"),
    (read: 2, total: 3, expected: "2 of 3 read"),
    (read: 3, total: 3, expected: "All 3 read"),
])
func summary(read: Int, total: Int, expected: String) {
    #expect(ReadingList.summary(read: read, total: total) == expected)
}

@Test(arguments: ["Kindred", "  Kindred  ", "Kindred;"])
func linesWithoutAnAuthorAreRejected(line: String) {
    #expect(throws: ImportError.missingAuthor) {
        try BookImporter.parse(line, id: 1)
    }
}

@Test(arguments: [false, true], [false, true])
func unreadNeverFollowsRead(firstIsRead: Bool, secondIsRead: Bool) {
    let books = [
        Book(id: 1, title: "Beloved", author: "Toni Morrison", isRead: firstIsRead),
        Book(id: 2, title: "Kindred", author: "Octavia E. Butler", isRead: secondIsRead),
    ]
    let flags = ReadingList.ordered(books).map(\.isRead)
    #expect(flags == flags.sorted { !$0 && $1 })
}
```

- **One collection.** Swift Testing calls the function once per element; each call is a **test case**. A collection of tuples is passed as separate parameters, so `(read: 0, total: 0, expected: "No books yet")` fills `read`, `total` and `expected`.
- **Two collections** make every combination (Apple calls it the Cartesian product). `[false, true], [false, true]` gives four cases: both unread, both read, and each mix. That fits `unreadNeverFollowsRead`, which should hold for every combination.
- **`zip(a, b)`** pairs elements by position instead, for when the second collection holds the expected result for each input. Apple's [parameterized testing article](https://developer.apple.com/documentation/testing/parameterizedtesting) recommends it to avoid the combinatorial count.

The output reports each case with its arguments. That's the advantage over a `for` loop inside one test: in a loop, all inputs share one test, so a thrown error skips the remaining inputs and you can't rerun only the input that failed. Each case passes or fails by itself.

```text
◇ Test case passing 3 arguments read → 0, total → 0, expected → "No books yet" to summary(read:total:expected:) started.
◇ Test case passing 3 arguments read → 3, total → 3, expected → "All 3 read" to summary(read:total:expected:) started.
✔ Test summary(read:total:expected:) with 4 test cases passed after 0.001 seconds.
◇ Test case passing 1 argument line → "Kindred;" to linesWithoutAnAuthorAreRejected(line:) started.
✔ Test unreadNeverFollowsRead(firstIsRead:secondIsRead:) with 4 test cases passed after 0.001 seconds.
```

Test cases run in parallel with each other, like tests do.

## Traits

Traits go in the `@Test` or `@Suite` attribute, after the display name if there is one. A trait on a suite applies to every test in it.

```swift illustrative
import Testing
@testable import Bookshelf

extension Tag {
    @Tag static var importing: Self
    @Tag static var slow: Self
}

@Suite(.tags(.importing))
struct ImportTraitTests {
    @Test(.disabled("Waiting on the CSV format decision"))
    func importsCSV() throws {
        _ = try BookImporter.parse("Kindred,Octavia E. Butler", id: 1)
    }

    @Test(.bug("https://example.com/bookshelf/issues/42", "Semicolons in titles split the title"))
    func semicolonInTitle() {
        withKnownIssue("The importer splits on the first semicolon") {
            let book = try BookImporter.parse("Love; Death; Robots; Various Authors", id: 1)
            #expect(book.title == "Love; Death; Robots")
        }
    }

    @Test(.tags(.slow), .timeLimit(.minutes(1)))
    func importsTenThousandLines() throws {
        let lines = (1...10_000).map { "Book \($0); Author \($0)" }
        let books = try lines.enumerated().map { try BookImporter.parse($1, id: $0) }
        #expect(books.count == 10_000)
    }
}
```

From that run:

```text
➜ Test importsCSV() skipped: "Waiting on the CSV format decision"
━ Test semicolonInTitle() recorded a known issue at TraitTests.swift:20:13: Expectation failed: (book.title → "Love") == "Love; Death; Robots"
↳ The importer splits on the first semicolon
━ Test semicolonInTitle() passed after 0.001 seconds with 1 known issue.
✔ Test importsTenThousandLines() passed after 0.032 seconds.
━ Suite ImportTraitTests passed after 0.034 seconds with 1 known issue.
```

What each trait does, per Apple's [Traits](https://developer.apple.com/documentation/testing/traits) reference:

- **`.disabled("reason")`** skips the test unconditionally and prints the reason. Prefer it to commenting a test out: the test still has to compile, and the skip is visible in every run. `.enabled(if: condition)` and `.disabled(if: condition)` skip based on a runtime condition; if a test has several conditions, all must pass for it to run.
- **`.bug(url, title)`** links the test to a bug report; there's also `.bug(id:)` for trackers that use numbers. On its own it doesn't change whether the test passes. Here it pairs with `withKnownIssue { … }`, which records failures inside the closure as **known issues**: the test passes and the output says why. Once someone fixes the importer, the expectation passes and the test fails with `Known issue was not recorded` (seen in a separate run with a line that parses correctly), which reminds you to remove the wrapper.
- **`.tags(.importing)`** labels tests. You declare a tag as a static member in an extension of `Tag` with the `@Tag` macro; tags declared anywhere else aren't recognized. Apple describes tags as semantic information for organization, filtering and how tests appear; they don't change how tests run. `swift test` in Swift 6.3 filters by name with `--filter` and `--skip` (regular expressions); its help output lists no tag option.
- **`.timeLimit(.minutes(1))`** fails the test if it runs longer than the limit. The duration is in minutes with a minimum of one, because test environments vary too much for short limits; on Apple platforms it requires iOS 16 or macOS 13. It's a safety net for a test that might hang, not a performance check.
- **`.serialized`** on a suite runs its tests one at a time; on a parameterized test it runs the cases one at a time. It has no effect on a test without arguments.

> [!tip] Running a subset
> `swift test --filter BookImporter` runs tests whose names match the regular expression, and `--skip` excludes them. In Xcode you can run one test or suite from the diamond in the editor's gutter (from Apple's documentation, not checked in Xcode for this lesson).

## Common mistakes

> [!error] A helper with parameters marked @Test
> `@Test func summary(read: Int, total: Int)` without `arguments:` doesn't build: `error: Attribute 'Test' must specify arguments when used with function 'summary(read:total:)'` (Swift 6.3). Add `arguments:`, or remove `@Test` if it's a helper that tests call.

> [!error] error: missing argument for parameter 'fileName' in call
> A suite with instance tests whose only initializer takes arguments. Swift Testing has to create the suite itself, with no arguments. Give the properties defaults, or set them in a parameterless `init`. The error appears inside the `@Test` macro expansion, which can make it confusing the first time.

> [!error] A for loop over inputs inside one test
> Works, but the first failure hides which input broke and the cases can't run separately. Pass the inputs with `arguments:`.

> [!error] Force-unwrapping in a test
> `let next = ReadingList.nextUp(in: books)!` crashes the test process when the value is `nil`, taking every other test in the run with it. Use `try #require(...)`.

> [!error] error: static property 'imported' is not concurrency-safe because it is nonisolated global shared mutable state
> A `static var` that several tests append to. In Swift 6 mode the compiler stops you (Swift 6.3's message is the title), and for good reason: tests run in parallel, so they'd overwrite each other and fail at random. Don't silence it with `nonisolated(unsafe)`. Keep state in suite instances, and serialize only the tests that truly share something.

```swift no-compile is not concurrency-safe because it is nonisolated global shared mutable state
struct Book: Equatable, Sendable {
    let id: Int
    let title: String
}

struct ImporterTests {
    static var imported: [Book] = []

    func importsKindred() {
        Self.imported.append(Book(id: 1, title: "Kindred"))
        print(Self.imported.count)
    }
}

ImporterTests().importsKindred()
```

> [!error] A test that can't fail
> `#expect(books.count >= 0)`, or a test that calls the code and checks nothing. Before trusting a new test, break the code (or the expected value) once and watch it fail, as the failing example above does.

## Exercises

````exercise
id: m33-l01-e1
type: comprehension
prompt: "A test needs the first unread book from a list and then checks three of its properties. What's the best way to get the book?"
choices:
  - text: "let book = try #require(ReadingList.nextUp(in: books)), then three #expect checks."
    correct: true
    why: "If there's no book, the test stops with one clear issue; otherwise the three checks all run and report separately."
  - text: "let book = ReadingList.nextUp(in: books)!, then three #expect checks."
    correct: false
    why: "A nil value crashes the whole test process, not just this test."
  - text: "#expect(ReadingList.nextUp(in: books) != nil), then optional chaining in each check: #expect(book?.title == \"Beloved\")."
    correct: false
    why: "It works, but a nil value produces four failures instead of one, and the comparisons against optionals read worse. #require is designed for this."
  - text: "try #require on each of the three property checks."
    correct: false
    why: "Then the first wrong property stops the test and hides the other two. Use #require for the precondition, #expect for the checks."
solution: |
  `try #require(optional)` unwraps or stops the test with one issue. After that, `#expect` lets every check report. The rule: `#require` when the rest of the test depends on the value, `#expect` otherwise.
````

````exercise
id: m33-l01-e2
type: prediction
prompt: "Swift Testing runs @Test(arguments: reads, totals) as every combination, and @Test(arguments: zip(reads, totals)) as pairs. This program prints the cases each one would run, using the summary function. What does it print?"
code: |
  func summary(read: Int, total: Int) -> String {
      if total == 0 { return "No books yet" }
      if read == total { return "All \(total) read" }
      return "\(read) of \(total) read"
  }

  let reads = [0, 3]
  let totals = [3, 4]

  print("two collections:")
  for read in reads {
      for total in totals {
          print("  (\(read), \(total)) -> \(summary(read: read, total: total))")
      }
  }

  print("zip:")
  for (read, total) in zip(reads, totals) {
      print("  (\(read), \(total)) -> \(summary(read: read, total: total))")
  }
output: |
  two collections:
    (0, 3) -> 0 of 3 read
    (0, 4) -> 0 of 4 read
    (3, 3) -> All 3 read
    (3, 4) -> 3 of 4 read
  zip:
    (0, 3) -> 0 of 3 read
    (3, 4) -> 3 of 4 read
solution: |
  Two collections give 2 × 2 = 4 cases, every `read` with every `total`. `zip` pairs by position, so it gives 2: `(0, 3)` and `(3, 4)`.

  ```output
  two collections:
    (0, 3) -> 0 of 3 read
    (0, 4) -> 0 of 4 read
    (3, 3) -> All 3 read
    (3, 4) -> 3 of 4 read
  zip:
    (0, 3) -> 0 of 3 read
    (3, 4) -> 3 of 4 read
  ```

  Which one you want depends on the test. If the second collection is the expected output for each input, you need `zip`; the Cartesian product would pair inputs with the wrong expectations. If the test checks a property that should hold for every combination, two collections are right. Watch the count: three collections of ten elements each are 1,000 cases.
````

````exercise
id: m33-l01-e3
type: fill-in
prompt: "Complete the parameterized test so each title is paired with the author the importer should read from the same line, and a failed parse stops the case."
code: |
  import Testing
  @testable import Bookshelf

  let lines = ["Kindred; Octavia E. Butler", "Piranesi;Susanna Clarke"]
  let authors = ["Octavia E. Butler", "Susanna Clarke"]

  @[[1]](arguments: [[2]](lines, authors))
  func readsTheAuthor(line: String, author: String) [[3]] {
      let book = [[4]] BookImporter.parse(line, id: 1)
      [[5]](book.author == author)
  }
blanks:
  - id: "1"
    answers: ["Test"]
  - id: "2"
    answers: ["zip"]
  - id: "3"
    answers: ["throws"]
  - id: "4"
    answers: ["try"]
  - id: "5"
    answers: ["#expect"]
solution: |
  `@Test(arguments: zip(lines, authors))` makes two cases, each line with its own author; without `zip` it would be four, and two of them would compare a line with the wrong author. The function is `throws` so `try BookImporter.parse` can fail the case by throwing, and `#expect` checks the author.
````

````exercise
id: m33-l01-e4
type: find-errors
prompt: "A test file under review. Which comments point at real problems?"
code: |
  import Testing
  @testable import Bookshelf

  struct ImporterTests {
      nonisolated(unsafe) static var imported: [Book] = []

      @Test func importsKindred() throws {
          Self.imported.append(try BookImporter.parse("Kindred; Octavia E. Butler", id: 1))
          #expect(Self.imported.count == 1)
      }

      @Test func importsPiranesi() throws {
          Self.imported.append(try BookImporter.parse("Piranesi; Susanna Clarke", id: 2))
          #expect(Self.imported.count == 1)
      }

      @Test func rejectsBadLines() {
          for line in ["", "Kindred", ";"] {
              #expect(throws: ImportError.self) { try BookImporter.parse(line, id: 3) }
          }
      }

      @Test func nextUp() {
          let next = ReadingList.nextUp(in: Self.imported)!
          #expect(next.title == "Kindred")
      }

      func testSummary() {
          #expect(ReadingList.summary(read: 0, total: 0) == "No books yet")
      }
  }
choices:
  - text: "The static array is shared by tests that run in parallel, so the count checks pass or fail depending on timing."
    correct: true
    why: "nonisolated(unsafe) silenced the Swift 6 compiler's error about shared mutable state; it didn't remove the race. Each test should own its data, in a stored property or a local."
  - text: "rejectsBadLines loops over inputs; a parameterized test would report each line separately."
    correct: true
    why: "@Test(arguments: [\"\", \"Kindred\", \";\"]) gives three independent cases."
  - text: "nextUp force-unwraps and depends on what other tests imported first."
    correct: true
    why: "It should build its own books and use try #require."
  - text: "testSummary never runs: it has no @Test attribute."
    correct: true
    why: "Swift Testing doesn't use the test prefix; without @Test it's a plain method."
  - text: "The suite needs @Suite to be discovered."
    correct: false
    why: "Any type containing @Test functions is a suite; @Suite is optional."
  - text: "#expect(throws:) can't be used inside a loop."
    correct: false
    why: "It can; the problem is reporting, not legality."
rubric:
  - Finds the shared static state and the order dependence.
  - Finds the loop that should be a parameterized test.
  - Finds the force unwrap and the dependency on another test.
  - Finds the method that never runs.
solution: |
  Four real problems. A fixed version gives each test its own books, makes `rejectsBadLines` a parameterized test over the three lines, builds the list in `nextUp` and unwraps with `try #require`, and adds `@Test` to the summary check (the name can stay or lose its prefix).

  The shared `static var` is the worst one: tests run in parallel by default, so `importsKindred` and `importsPiranesi` race on the array, and `nextUp` passes or crashes depending on which ran first.
````

````exercise
id: m33-l01-e5
type: solve
prompt: "Write `BookSearch.results(for:in:)`, which returns the books whose title or author contains the query, ignoring case and surrounding spaces; an empty or blank query returns every book. Then write a Swift Testing suite for it: a parameterized test pairing queries with the ids they should match (including a query that matches by author and one that matches nothing), a parameterized test for blank queries, and a test that unwraps the first result with #require."
starter: |
  import Foundation

  struct Book: Equatable, Sendable {
      let id: Int
      let title: String
      let author: String
      var isRead: Bool
  }

  enum BookSearch {
      static func results(for query: String, in books: [Book]) -> [Book] {
          // Your code
      }
  }
rubric:
  - Trims and lowercases the query once, and compares against lowercased title and author.
  - Returns the input unchanged for an empty or all-space query.
  - The suite stores the sample books in a property, so every test gets a fresh copy.
  - Uses one parameterized test with query/expected-ids pairs instead of a loop, and covers author matches and no matches.
  - Unwraps with try #require instead of force-unwrapping.
solution: |
  The function, with a few checks by hand:

  ```swift
  import Foundation

  enum BookSearch {
      /// Books whose title or author contains the query, ignoring case and
      /// surrounding spaces. An empty query matches everything.
      static func results(for query: String, in books: [Book]) -> [Book] {
          let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
          guard !needle.isEmpty else { return books }
          return books.filter {
              $0.title.lowercased().contains(needle) || $0.author.lowercased().contains(needle)
          }
      }
  }

  struct Book: Equatable, Sendable {
      let id: Int
      let title: String
      let author: String
      var isRead: Bool
  }

  let books = [
      Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
      Book(id: 2, title: "Parable of the Sower", author: "Octavia E. Butler", isRead: false),
      Book(id: 3, title: "Piranesi", author: "Susanna Clarke", isRead: false),
  ]
  print(BookSearch.results(for: "OCTAVIA", in: books).map(\.id))
  print(BookSearch.results(for: "  clarke ", in: books).map(\.id))
  print(BookSearch.results(for: "   ", in: books).count)
  ```

  ```output
  [1, 2]
  [3]
  3
  ```

  The suite. It was built and run with `swift test` (Swift 6.3, Linux) against the function above:

  ```swift illustrative
  import Testing
  @testable import Bookshelf

  @Suite struct BookSearchTests {
      let books = [
          Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: true),
          Book(id: 2, title: "Parable of the Sower", author: "Octavia E. Butler", isRead: false),
          Book(id: 3, title: "Piranesi", author: "Susanna Clarke", isRead: false),
      ]

      @Test(arguments: [
          (query: "kindred", ids: [1]),
          (query: "OCTAVIA", ids: [1, 2]),
          (query: "  clarke ", ids: [3]),
          (query: "dune", ids: []),
      ])
      func matchesTitleOrAuthor(query: String, ids: [Int]) {
          #expect(BookSearch.results(for: query, in: books).map(\.id) == ids)
      }

      @Test(arguments: ["", "   "])
      func blankQueryReturnsEverything(query: String) {
          #expect(BookSearch.results(for: query, in: books) == books)
      }

      @Test func firstResultForAnAuthor() throws {
          let first = try #require(BookSearch.results(for: "butler", in: books).first)
          #expect(first.title == "Kindred")
      }
  }
  ```

  `ids: []` needs no type annotation because the tuple array's other elements fix it as `[Int]`. The query/ids pairs live in one collection, so there's no `zip` to get wrong. Each test reads `books` from its own suite instance. Blank queries get their own test because the expected result (every book) isn't a list of ids you'd want to repeat.
````

````exercise
id: m33-l01-e6
type: explain
prompt: "Swift Testing creates a new suite instance for each test, while a naive design would create one instance and call every test on it. Using this suite, explain what the per-test instance gives you, how it relates to running tests in parallel, and what it doesn't protect you from."
code: |
  final class ReadingListTests {
      var books = [Book(id: 1, title: "Kindred", author: "Octavia E. Butler", isRead: false)]
      nonisolated(unsafe) static var importLog: [String] = []

      @Test func addingABook() {
          books.append(Book(id: 2, title: "Piranesi", author: "Susanna Clarke", isRead: false))
          Self.importLog.append("added")
          #expect(books.count == 2)
      }

      @Test func removingABook() {
          books.removeAll()
          Self.importLog.append("removed")
          #expect(books.isEmpty)
          #expect(Self.importLog.count == 1)
      }
  }
rubric:
  - Says init acts as per-test setup and every test starts from the same state.
  - Connects fresh instances to safe parallel execution, since tests don't share stored properties.
  - Points out that static properties, globals, singletons, files and other external state are still shared.
  - Mentions .serialized as the tool for tests that must share something.
solution: |
  Each test gets a value built by `init` and nothing else. In this suite, `books` starts with one element in both tests, whichever runs first, so both `books` checks are reliable. No test can see another's changes to stored properties, and the order tests run in doesn't matter. That's also what makes the default parallel execution safe: two tests running at the same moment work on two different instances.

  The guarantee stops at the instance. `importLog` is static, so both tests append to the same array, possibly at the same moment: `#expect(Self.importLog.count == 1)` passes or fails depending on scheduling, and the unsynchronized mutation is a data race. Without `nonisolated(unsafe)`, Swift 6 mode rejects the `static var` as shared mutable state; the attribute tells the compiler you've made it safe yourself, which here isn't true. More generally, a `static var`, a global, a singleton like `UserDefaults.standard`, a file on disk or a `URLProtocol` stub registered in static storage is shared by every test in the process. For those, inject a fresh dependency per test (an in-memory store, an ephemeral session), and if two tests really must share something, put them in a `.serialized` suite.
````

## Summary

- Tests live in a test target that imports `Testing` and `@testable import`s the module under test. Swift Testing ships with Swift 6 toolchains, on Linux too.
- `@Test` marks a test function; the name is free. `#expect(condition)` records a failure with the values of the expression's parts and continues. `try #require(...)` stops the test, and unwraps optionals.
- `#expect(throws: SomeError.value)` checks for a specific `Equatable` error; `#expect(throws: SomeError.self)` for any error of the type.
- Any type with `@Test` members is a suite. Each instance test gets a **new instance**, so `init` is setup and `deinit` (in a class or actor) is teardown. Suites need a parameterless initializer.
- `arguments:` turns one test into a case per element. Two collections make every combination; `zip` pairs them. Cases report and run independently.
- Traits: `.disabled` and `.enabled(if:)` skip, `.bug` links a report (with `withKnownIssue` for known failures), `.tags` labels, `.timeLimit` caps run time in minutes, `.serialized` turns off parallelism for a suite or a parameterized test.

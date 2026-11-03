---
id: m12-l03
title: "try?, try! and defer"
description: You turn errors into optionals with try?, recognize the few places where try! is acceptable and watch it crash where it isn't, and use defer to run cleanup on every way out of a scope, with its execution order checked by running it.
module: m12
order: 3
level: beginner
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m12-l02]
objectives:
  - Use try? to turn a throwing call into an optional, and state the resulting type.
  - Decide when discarding the error with try? is acceptable and when it hides a problem.
  - Explain what try! does when the call throws, and judge whether a given try! is defensible.
  - Use defer to run cleanup when a scope exits, by return, by throw or by reaching its end.
  - Predict the order in which several defer blocks run, and when a defer runs relative to a return.
terms:
  - term: "try?"
    definition: "Calls a throwing function and gives back an optional: the result if it succeeded, nil if it threw. The error itself is discarded."
  - term: "try!"
    definition: "Calls a throwing function and gives back the plain result, promising it won't throw. If it does, the program stops with a fatal error."
  - term: defer
    definition: "A block of code that runs when the current scope exits, however it exits: return, throw, break or reaching the closing brace."
  - term: Cleanup
    definition: "Work that must happen after an operation no matter how it ended: closing a connection, releasing a lock, hiding a spinner."
mastery:
  - "Replace a do-catch whose catch only returns a default with (try? …) ?? default."
  - "Say the type of try? applied to a function returning Int, and to one returning Int?."
  - Point at a try? that hides a failure the user or the developer needs to know about.
  - "Say whether a given try! is defensible, using the Module 8 rule for !."
  - Predict the output of a function with two defer blocks that throws halfway through.
resources: [swift-book-error-handling, swift-optional, swift-fatalerror, swift-book-control-flow]
cards:
  - id: m12-l03-c1
    front: "What's the type of `try? parseQuantity(text)` if parseQuantity returns Int?"
    back: "Int?. It's nil if the call threw. If the function itself returns Int?, try? still gives Int?, not Int??: the optionals are flattened."
  - id: m12-l03-c2
    front: "When is try? the right choice?"
    back: "When you'd do the same thing for every failure and the reason doesn't matter, like using a default for an optional setting. If the user or a developer needs to know what went wrong, catch it."
  - id: m12-l03-c3
    front: "What happens when a try! call throws?"
    back: "The program stops: \"Fatal error: 'try!' expression unexpectedly raised an error:\" followed by the error. It's ! for errors."
  - id: m12-l03-c4
    front: In what order do several defer blocks in one scope run?
    back: "In reverse: the last defer written runs first. They run when the scope exits, after a return value has been computed."
  - id: m12-l03-c5
    front: Does defer run if the function throws?
    back: "Yes. A defer runs on every exit from its scope: return, throw, break, continue or the end of the block. That's what makes it right for cleanup."
---

## The idea in one sentence

`try?` turns an error into `nil` when you don't need the reason, `try!` crashes if an error happens where you promised none could, and `defer` runs cleanup code on every way out of a scope.

## try?: an error becomes nil

Sometimes you don't care **why** something failed, only **whether**. `try?` calls a throwing function and wraps the result in an optional: the value if it worked, `nil` if it threw.

```swift
enum QuantityError: Error {
    case notANumber(String)
    case outOfRange(Int)
}

func parseQuantity(_ text: String) throws -> Int {
    guard let number = Int(text) else {
        throw QuantityError.notANumber(text)
    }
    guard number >= 1 && number <= 99 else {
        throw QuantityError.outOfRange(number)
    }
    return number
}

let good = try? parseQuantity("12")
let bad = try? parseQuantity("abc")
print(good as Any, bad as Any)
print(type(of: good))

let quantity = (try? parseQuantity("500")) ?? 1
print("Using \(quantity)")

if let parsed = try? parseQuantity("7") {
    print("Parsed \(parsed)")
}
```

```output
Optional(12) nil
Optional<Int>
Using 1
Parsed 7
```

1. `try? parseQuantity("12")` has type `Int?`. The call succeeded, so it's `Optional(12)`.
2. `"abc"` throws `notANumber`. `try?` catches it, throws it away, and gives `nil`.
3. `as Any` only silences the warning about printing an optional (Module 8), so you can see the box.
4. Everything from Module 8 now applies: `??` for a default, `if let` and `guard let` to unwrap. The parentheses around `(try? …)` make it clear the `??` applies to the whole result.
5. `"500"` fails with `outOfRange`, `??` supplies 1. Notice that the program can't tell the user the quantity was too high. That information is gone.

That last point is the whole decision. `try?` is the Module 8 rule from the other side: use it when "it didn't work" is all the caller needs.

### Optionals don't nest

If the function already returns an optional, `try?` doesn't add a second layer:

```swift
enum StoreError: Error {
    case offline
}

func cachedName(for id: Int) throws -> String? {
    guard id != 0 else {
        throw StoreError.offline
    }
    return id == 1 ? "Ana" : nil
}

let found = try? cachedName(for: 1)
let missing = try? cachedName(for: 2)
let failed = try? cachedName(for: 0)
print(found as Any, missing as Any, failed as Any)
print(type(of: found))
```

```output
Optional("Ana") nil nil
Optional<String>
```

The type is `String?`, not `String??`. Swift flattens the two optionals into one. The flip side: "not in the cache" and "the store is offline" both come back as `nil`, and you can't tell them apart. If that difference matters, use `do`/`catch`.

### try? on a function that returns nothing

A function that returns `Void` and throws, like `save()`, can be called with `try?` as a statement. That compiles **silently**, and the error disappears:

```swift
enum SaveError: Error {
    case diskFull
}

func save(_ note: String) throws {
    throw SaveError.diskFull
}

try? save("Buy milk")
print("Saved!")
```

```output
Saved!
```

The program says "Saved!" and nothing was saved. This is the most common way `try?` hides bugs. If you really don't care whether it worked, at least say so in a comment. Usually you do care, and you want `do`/`catch` with a log line.

## try!: when an error is impossible

`try!` calls a throwing function and gives you the **plain** result, no optional. You're promising it won't throw. If it does, the program stops:

```swift runtime-error 'try!' expression unexpectedly raised an error
enum QuantityError: Error {
    case notANumber(String)
}

func parseQuantity(_ text: String) throws -> Int {
    guard let number = Int(text) else {
        throw QuantityError.notANumber(text)
    }
    return number
}

let fromCode = try! parseQuantity("3")
print("From code: \(fromCode)")

let userTyped = "three"
let fromUser = try! parseQuantity(userTyped)
print("From user: \(fromUser)")
```

```output
From code: 3
```

Swift 6.3 prints `Fatal error: 'try!' expression unexpectedly raised an error:` followed by the error (with the module name in front of its type) and the program crashes. "From user" never prints.

`try!` is `!` for errors, and the rule from Module 8's lesson on force unwrapping carries over unchanged: **use it only when an error can only mean the code itself is wrong**, and you can see why from the surrounding lines.

- `try! parseQuantity("3")` with a literal you wrote: defensible. If it ever throws, the bug is in `parseQuantity`, and you want to find out loudly.
- A configuration value compiled into the app, like a list of built-in email addresses parsed at startup: defensible, for the same reason.
- Anything the user typed, anything from the network, a file or a database: **never**. Those fail for reasons outside your code, and a crash is the worst possible response.

When in doubt, use `do`/`catch` or `try?`. The cost is a few lines; the cost of being wrong with `try!` is a crash in someone's hand.

## defer: cleanup on every way out

Some work must happen when an operation ends, however it ends. A spinner has to stop, a connection has to close, a "busy" flag has to be reset. With errors, a function can exit from any `try`, so writing the cleanup before every exit is error-prone. **`defer`** fixes that: the block runs when the current scope exits, no matter how.

```swift
enum ImportError: Error {
    case badRow(Int)
}

func importRows(_ rows: [String]) throws -> Int {
    print("Open file")
    defer {
        print("Close file")
    }

    var imported = 0
    for (index, row) in rows.enumerated() {
        guard !row.isEmpty else {
            throw ImportError.badRow(index)
        }
        imported += 1
    }
    return imported
}

do {
    print("Imported \(try importRows(["a", "b"]))")
    print("Imported \(try importRows(["a", "", "c"]))")
} catch {
    print("Failed: \(error)")
}
```

```output
Open file
Close file
Imported 2
Open file
Close file
Failed: badRow(1)
```

1. `defer { … }` doesn't run where it's written. It's registered, and it runs when `importRows` exits.
2. The first call returns normally: "Close file" prints just before the value gets back to the caller.
3. The second call throws from inside the loop. The `defer` still runs, before the error reaches the `catch`. Without `defer`, you'd need a "Close file" line before the `throw` and another before the `return`, and the next person to add an exit would forget one.

Write the `defer` right after the thing it cleans up. "Open, then immediately say how it gets closed" keeps the pair together, and a reader sees both at once.

### The order

Several `defer`s in one scope run in **reverse** order, last written first. And a `defer` runs **after** the return value has been computed:

```swift
func process() -> Int {
    var steps = 0
    defer {
        print("defer 1, steps = \(steps)")
    }
    defer {
        steps = 99
        print("defer 2 changed steps to 99")
    }
    steps = 3
    print("returning steps")
    return steps
}

let result = process()
print("Result: \(result)")
```

```output
returning steps
defer 2 changed steps to 99
defer 1, steps = 99
Result: 3
```

- The second `defer` runs first, then the first. Think of a stack: what you set up last, you tear down first. That's what you want when the second resource depends on the first.
- `return steps` captured the value 3 **before** the defers ran. The second `defer` changed `steps` to 99, which the first `defer` sees, but the caller still gets 3. Don't use `defer` to change what a function returns.

`defer` works in any scope, not just functions. In a loop, it runs at the end of **each** iteration; in a `do` block, when the `do` block ends:

```swift
for attempt in 1...2 {
    defer {
        print("end of attempt \(attempt)")
    }
    print("attempt \(attempt)")
}

do {
    defer {
        print("leaving do")
    }
    print("inside do")
}
print("after")
```

```output
attempt 1
end of attempt 1
attempt 2
end of attempt 2
inside do
leaving do
after
```

### What a defer can't do

A `defer` block can't leave its scope early. It can't `return` (Swift 6.3: `'return' cannot transfer control out of a defer statement`) and it can't throw:

```swift no-compile errors cannot be thrown out of a defer body
enum DiskError: Error {
    case full
}

func flush() throws {
    throw DiskError.full
}

func write() throws {
    defer {
        try flush()
    }
    print("writing")
}

try write()
```

Swift 6.3: `error: call can throw, but errors cannot be thrown out of a defer body`. Cleanup must not fail in a way the caller has to handle. If it can, handle it inside the defer, with `do`/`catch` and a log line, or `try?` when failure truly doesn't matter.

## A practical example: a loading flag

A screen shows a spinner while it loads. Whatever happens, the spinner must stop:

```swift
enum FeedError: Error {
    case offline
    case decoding(line: Int)
}

final class FeedScreen {
    private(set) var isLoading = false
    private(set) var posts: [String] = []
    private(set) var errorMessage: String?

    func reload(from lines: [String], online: Bool) {
        isLoading = true
        defer {
            isLoading = false
        }
        errorMessage = nil

        do {
            posts = try fetchPosts(lines, online: online)
        } catch FeedError.offline {
            errorMessage = "You're offline. Showing saved posts."
        } catch {
            print("[log] feed failed: \(error)")
            errorMessage = "Couldn't load the feed."
        }
    }

    private func fetchPosts(_ lines: [String], online: Bool) throws -> [String] {
        guard online else {
            throw FeedError.offline
        }
        var result: [String] = []
        for (index, line) in lines.enumerated() {
            guard !line.isEmpty else {
                throw FeedError.decoding(line: index)
            }
            result.append(line)
        }
        return result
    }

    func describe() -> String {
        "loading: \(isLoading), posts: \(posts.count), error: \(errorMessage ?? "none")"
    }
}

let screen = FeedScreen()
screen.reload(from: ["Hello", "Swift 6"], online: true)
print(screen.describe())
screen.reload(from: ["Hi"], online: false)
print(screen.describe())
screen.reload(from: ["Hi", ""], online: true)
print(screen.describe())
```

```output
loading: false, posts: 2, error: none
loading: false, posts: 2, error: You're offline. Showing saved posts.
[log] feed failed: decoding(line: 1)
loading: false, posts: 2, error: Couldn't load the feed.
```

Three ways through `reload`, and `isLoading` is `false` after every one. Notice that a failed reload keeps the old posts, because `posts` is only assigned when `fetchPosts` succeeds. That's deliberate: showing yesterday's posts with a banner is better than an empty screen.

## Common mistakes

> [!error] try? on a call whose failure matters
> `try? save(note)` compiles without a warning and loses the error. If the user thinks their note is saved and it isn't, that's data loss. Use `do`/`catch`, and at least log.

> [!error] try! on input from outside
> `try! parseQuantity(textField.text)` crashes the moment someone types "three". Input, files and network data fail for reasons outside your code. Handle them.

> [!error] warning: result of 'try?' is unused
> `try? load()` as a statement, on a function that returns a value, throws away both the result and the error. Swift 6.3 warns. Either use the result or ask yourself why you're calling it.

> [!error] error: call can throw, but errors cannot be thrown out of a defer body
> Cleanup can't throw to the caller. Handle the error inside the `defer`.

> [!error] Expecting defer to run where it's written
> `defer` runs at the end of the scope, not on its line. A `defer` placed as the very last statement of a scope runs immediately, and Swift 6.3 warns: "'defer' statement at end of scope always executes immediately". Put it right after the setup it undoes.

````exercise
id: m12-l03-e1
type: comprehension
prompt: "`func loadAvatar(for id: Int) throws -> Image?` returns nil when the user has no avatar, and throws when the network fails. What's the type of `try? loadAvatar(for: 7)`, and what does nil mean?"
choices:
  - text: "Image??. The outer nil means it threw, the inner nil means no avatar."
    correct: false
    why: "try? flattens optionals since Swift 5. It's a single Image?."
  - text: "Image?. nil means either no avatar or a network failure, and you can't tell which."
    correct: true
    why: "The optionals are flattened, so both kinds of nothing look the same."
  - text: "Image. try? unwraps the inner optional."
    correct: false
    why: "try? adds optionality; it never removes it."
  - text: "It doesn't compile: try? can't be used on a function that returns an optional."
    correct: false
    why: "It compiles. The result is flattened to Image?."
solution: |
  **`Image?`, and `nil` is ambiguous.** `try?` would give `Image??`, but Swift flattens nested optionals from `try?`, so you get one level. Both "no avatar" and "the network failed" become `nil`. For an avatar that's often acceptable (show the placeholder either way). If the screen should show a retry button on network failures, use `do`/`catch` instead.
````

````exercise
id: m12-l03-e2
type: prediction
prompt: Predict the exact output.
code: |
  enum StepError: Error {
      case failed(String)
  }

  func run(_ name: String, fails: Bool) throws {
      print("start \(name)")
      defer {
          print("end \(name)")
      }
      if fails {
          throw StepError.failed(name)
      }
      print("work \(name)")
  }

  func pipeline() throws {
      defer {
          print("pipeline cleanup")
      }
      try run("A", fails: false)
      try run("B", fails: true)
      try run("C", fails: false)
  }

  do {
      try pipeline()
  } catch {
      print("caught \(error)")
  }
output: |
  start A
  work A
  end A
  start B
  end B
  pipeline cleanup
  caught failed("B")
hints:
  - "Each run's defer prints when that run exits, whether it returns or throws."
  - "When B throws, pipeline exits too. Its defer runs before the error reaches the catch."
solution: |
  ```output
  start A
  work A
  end A
  start B
  end B
  pipeline cleanup
  caught failed("B")
  ```

  A runs completely, and its `defer` prints "end A" on the way out. B prints "start B", throws, and its `defer` prints "end B" as it exits. The error propagates out of `pipeline`, so C never starts, and `pipeline`'s own `defer` runs before the error reaches the `catch`. Defers unwind from the innermost scope outward.
````

````exercise
id: m12-l03-e3
type: refactor
prompt: |
  This code reads three optional settings. Each `do`/`catch` only supplies a default. Rewrite it with `try?` and `??` so it's three short lines, with the same output.
code: |
  enum SettingError: Error {
      case missing(String)
      case notANumber(String)
  }

  let stored = ["fontSize": "16", "columns": "x"]

  func intSetting(_ key: String) throws -> Int {
      guard let text = stored[key] else {
          throw SettingError.missing(key)
      }
      guard let value = Int(text) else {
          throw SettingError.notANumber(text)
      }
      return value
  }

  var fontSize = 14
  do {
      fontSize = try intSetting("fontSize")
  } catch {
      fontSize = 14
  }
  var columns = 2
  do {
      columns = try intSetting("columns")
  } catch {
      columns = 2
  }
  var margin = 8
  do {
      margin = try intSetting("margin")
  } catch {
      margin = 8
  }
  print(fontSize, columns, margin)
rubric:
  - Uses (try? intSetting(...)) ?? default for each setting.
  - The variables become let constants.
  - The output is unchanged.
  - Notes why discarding the error is acceptable here.
solution: |
  ```swift
  enum SettingError: Error {
      case missing(String)
      case notANumber(String)
  }

  let stored = ["fontSize": "16", "columns": "x"]

  func intSetting(_ key: String) throws -> Int {
      guard let text = stored[key] else {
          throw SettingError.missing(key)
      }
      guard let value = Int(text) else {
          throw SettingError.notANumber(text)
      }
      return value
  }

  let fontSize = (try? intSetting("fontSize")) ?? 14
  let columns = (try? intSetting("columns")) ?? 2
  let margin = (try? intSetting("margin")) ?? 8
  print(fontSize, columns, margin)
  ```

  ```output
  16 2 8
  ```

  The original catches did the same thing for every error, so they were `try?` written longhand. The constants can be `let` now. Discarding the reason is fine here because the reaction (use the default) is the same for "missing" and "not a number". If you wanted to warn about the corrupt `columns` value, you'd keep a `catch` that logs it.
````

````exercise
id: m12-l03-e4
type: find-errors
prompt: "Which of these uses of try! and try? are problems in a shipping app?"
code: |
  // 1
  let defaultPort = try! parsePort("8080")
  // 2
  let port = try! parsePort(userInput)
  // 3
  try? deleteAccount(id: currentUser.id)
  showMessage("Your account was deleted")
  // 4
  let thumbnail = (try? loadThumbnail(id)) ?? placeholderImage
choices:
  - text: "1 is a problem: try! should never appear in production code."
    correct: false
    why: "The input is a literal in the code. If it throws, parsePort itself is broken, and crashing loudly is a reasonable way to find out."
  - text: "2 is a problem: user input can be anything, and try! will crash on it."
    correct: true
    why: "Input from outside your code fails for reasons you don't control."
  - text: "3 is a problem: if deleting fails, the user is told it succeeded."
    correct: true
    why: "try? throws the error away, and the next line runs either way."
  - text: "4 is a problem: try? can't be combined with ??."
    correct: false
    why: "It can, and here a placeholder is a reasonable reaction to any thumbnail failure."
rubric:
  - I flagged 2 and 3.
  - I explained why 1 is defensible.
  - I explained why 4 is acceptable.
solution: |
  **2 and 3.** Line 2 crashes the app the first time a user types something that isn't a port. Line 3 is worse in a way: it tells the user their account is gone when it might not be. Use `do`/`catch` there and only show the message on success.

  Line 1 is defensible: the string is written in the code, so a failure means `parsePort` has a bug. Line 4 is a fine use of `try?`: whatever went wrong, the reaction is the same, show the placeholder. Logging the failure would still be a good idea if thumbnails fail often.
````

````exercise
id: m12-l03-e5
type: solve
prompt: |
  Write a small connection pool check-out with guaranteed cleanup.

  - `final class Connection` with `let id: Int`, `private(set) var isOpen = false`, `func open()` that sets `isOpen = true` and prints `"open \(id)"`, and `func close()` that sets it to `false` and prints `"close \(id)"`.
  - `enum QueryError: Error { case syntax(String) }`.
  - `func runQuery(_ sql: String, on connection: Connection) throws -> Int` that opens the connection, guarantees it's closed when the function exits, throws `QueryError.syntax(sql)` if `sql` doesn't start with `"SELECT"`, and otherwise prints `"run \(sql)"` and returns `sql.count`.

  This must print:

  ```output
  open 1
  run SELECT 1
  close 1
  rows: 8
  open 1
  close 1
  error: syntax("DROP")
  still open: false
  ```

  from:

  ```swift
  let connection = Connection(id: 1)
  for sql in ["SELECT 1", "DROP"] {
      do {
          print("rows: \(try runQuery(sql, on: connection))")
      } catch {
          print("error: \(error)")
      }
  }
  print("still open: \(connection.isOpen)")
  ```
starter: |
  final class Connection {
      // your code
  }
hints:
  - "Write the class with an init(id:)."
  - "In runQuery: connection.open(), then immediately defer { connection.close() }."
  - "Use guard sql.hasPrefix(\"SELECT\") else { throw … }."
rubric:
  - runQuery opens the connection and closes it with defer right after.
  - The connection is closed on both the success path and the throwing path.
  - No close() call is duplicated before return or throw.
  - The output matches exactly.
solution: |
  ```swift
  final class Connection {
      let id: Int
      private(set) var isOpen = false

      init(id: Int) {
          self.id = id
      }

      func open() {
          isOpen = true
          print("open \(id)")
      }

      func close() {
          isOpen = false
          print("close \(id)")
      }
  }

  enum QueryError: Error {
      case syntax(String)
  }

  func runQuery(_ sql: String, on connection: Connection) throws -> Int {
      connection.open()
      defer {
          connection.close()
      }
      guard sql.hasPrefix("SELECT") else {
          throw QueryError.syntax(sql)
      }
      print("run \(sql)")
      return sql.count
  }

  let connection = Connection(id: 1)
  for sql in ["SELECT 1", "DROP"] {
      do {
          print("rows: \(try runQuery(sql, on: connection))")
      } catch {
          print("error: \(error)")
      }
  }
  print("still open: \(connection.isOpen)")
  ```

  ```output
  open 1
  run SELECT 1
  close 1
  rows: 8
  open 1
  close 1
  error: syntax("DROP")
  still open: false
  ```

  "close 1" prints before "rows: 8" because the `defer` runs as `runQuery` exits, before the caller's `print` gets the value. On the `DROP` path, the `guard` throws and the `defer` still closes the connection. `Connection` is a class so the caller and `runQuery` share one instance and the last line sees its real state.
````

````exercise
id: m12-l03-e6
type: explain
prompt: |
  Explain the difference between these two lines, what each one does when `load()` throws, and give one situation where each is the right choice.
code: |
  let a = try? load()
  let b = try! load()
rubric:
  - I said a is an optional that becomes nil on error, and b is a plain value.
  - I said b crashes the program if load() throws.
  - I gave a fitting situation for try? (the reason doesn't matter, a fallback exists).
  - I gave a fitting situation for try! (failure can only mean a bug in the code, such as a literal input).
solution: |
  `a` is an optional. If `load()` throws, the error is discarded and `a` is `nil`; the program continues. `b` is the plain value. If `load()` throws, the program stops with "Fatal error: 'try!' expression unexpectedly raised an error".

  `try?` fits when every failure leads to the same reaction and nobody needs the reason: an optional thumbnail that falls back to a placeholder, a cached value you'll fetch again anyway.

  `try!` fits only when a failure would mean the code itself is wrong: parsing a constant you wrote in the source, or loading a resource that is bundled with the app and checked by its tests. If anything outside your code can make it fail, `try!` is a crash waiting for a user.
````

## Summary

- `try?` turns a throwing call into an optional and discards the error. Use it when every failure gets the same reaction; combine it with `??`, `if let` or `guard let`.
- `try?` on a function that returns an optional gives one optional, not two, so "no value" and "failed" look the same.
- `try?` on a `Void` function compiles silently and loses the error. Be suspicious of it.
- `try!` returns the plain value and crashes with "'try!' expression unexpectedly raised an error" if the call throws. Same rule as `!`: only when failure means a bug in your code.
- `defer` runs when its scope exits: on `return`, on `throw`, at the end of the block, at the end of each loop iteration. Several defers run in reverse order, after the return value is computed.
- A `defer` can't `return` or throw. Put it right after the setup it undoes.

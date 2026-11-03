---
id: m08-l06
title: "Designing functions that return optionals"
description: You decide when a function should return nil, a default value or (later) an error, write failable lookup and parsing functions, document what nil means, fix the second-largest problem and the Module 6 sentinels with Int?, and close Stage 2 with a small config-file parser.
module: m08
order: 6
level: beginner
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m08-l05]
objectives:
  - Choose between returning an optional, returning a default and throwing an error (Module 12) for a given function.
  - Write failable lookup and parsing functions that return nil for exactly one well-defined reason.
  - Document what nil means with a /// doc comment.
  - Replace sentinels and Bool flags from earlier modules with optional return types.
  - Combine everything from Stage 2 in a program that parses and validates a small config file.
terms:
  - term: Failable function
    definition: "A function whose return type is optional because, for some inputs, there's no meaningful result. Int(_:) with a String is the standard example."
  - term: Doc comment
    definition: "A comment that starts with ///, written right above a declaration. Xcode shows it in Quick Help and in autocompletion."
  - term: Optional tuple
    definition: "A tuple type wrapped in an optional, like (key: String, value: String)?. Either the whole tuple exists or nothing does."
  - term: Default value
    definition: "A real value of the return type that is the correct answer when there's nothing to report, like 0 for a count or [] for a list of results."
mastery:
  - For a list of function descriptions, say which should return an optional, which a plain value and which an error, and why.
  - Write a /// comment that states exactly when a function returns nil.
  - Rewrite a function that returns -1 or a (isValid, value) tuple so it returns an optional.
  - Explain why a search should return an empty array instead of nil when nothing matches.
  - Write a parser that returns an optional tuple and use it with guard let in a loop.
resources: [swift-book-functions, swift-book-basics, swift-book-collection-types, swift-book-control-flow]
cards:
  - id: m08-l06-c1
    front: When should a function return an optional?
    back: "When having no result is a normal outcome with one obvious reason (a lookup with no match, text that isn't a number) and the caller doesn't need to know more."
  - id: m08-l06-c2
    front: When should a function return a default instead of nil?
    back: "When there's a value that's genuinely correct for the empty case: 0 for a count, [] for search results. Not when the default is just convenient, like 0 for an unknown price."
  - id: m08-l06-c3
    front: When is an optional not enough, so that you'd throw an error instead?
    back: "When the caller needs to know why it failed, because there are several reasons that need different handling: wrong password vs. no network. Errors are Module 12."
  - id: m08-l06-c4
    front: What should a failable function's doc comment say?
    back: "Exactly when it returns nil, so the caller knows what nil means without reading the body. For example: \"Returns nil if the item isn't on the menu.\""
  - id: m08-l06-c5
    front: "Why is `func search(_ query: String) -> [String]?` usually a poor signature?"
    back: "An empty array already means \"no matches\". The optional adds a second kind of nothing that every caller has to unwrap and that rarely means anything different."
---

## The idea in one sentence

Return an optional when "no result" is a normal answer with one clear meaning, say in the doc comment what that meaning is, and reach for something else when it isn't.

## nil, a default, or an error?

Every function that can come up empty needs a decision. There are three options, and the choice is part of the function's design, not an implementation detail.

**Return an optional** when having no result is an ordinary outcome with **one** obvious reason, and the caller doesn't need more detail:

- `Int("abc")`: the text isn't a whole number.
- `prices["tea"]`: the key isn't there.
- `scores.first`, `scores.max()`: the array is empty.
- `names.firstIndex(of: "Zoe")`: the value isn't in the array.

**Return a plain value** when there's an answer that is genuinely **correct**, not just convenient, for the empty case:

- How many orders match a filter? 0 is the right answer, not `nil`.
- Which products match a search? `[]` is the right answer. An empty array already means "none".
- Total of an empty cart? 0.

The trap is a default that's merely convenient. The price of an item that isn't on the menu is not 0. Returning 0 is the sentinel problem from Module 6 all over again.

**Throw an error** when the caller needs to know **why** it failed, because different reasons need different handling. Logging in can fail because of a wrong password, a locked account or no network, and the app should react differently to each. An optional can only say "it didn't work". Swift's error handling, `throws` and `try`, is Module 12; for now, recognize the situations where `nil` says too little.

A quick test: write the sentence "returns nil if…". If you can finish it with one short reason, an optional fits. If you need "or" twice, think about an error, or about splitting the function.

## Failable lookups and parsing

A function that looks something up or parses text is the most common place to return an optional. Here's a lookup:

```swift
/// Returns the price of `item` in cents, or `nil` if the item isn't on the menu.
func price(of item: String, in menu: [String: Int]) -> Int? {
    return menu[item.lowercased()]
}

let menu = ["coffee": 450, "bread": 280]

if let cents = price(of: "Coffee", in: menu) {
    print("Coffee costs \(cents) cents")
}
let teaPrice = price(of: "tea", in: menu)
print(teaPrice == nil ? "Tea isn't on the menu" : "Tea is on the menu")
```

```output
Coffee costs 450 cents
Tea isn't on the menu
```

Three things make it a good optional API:

1. **The name expects absence.** `price(of:in:)` reads naturally with "might not have one". `firstIndex(of:)`, `min()` and `Int(_:)` in the standard library work the same way.
2. **The doc comment says what `nil` means.** A comment starting with `///` above a declaration is a **doc comment**: Xcode shows it when you Option-click the function and in autocompletion. One sentence that finishes "returns nil if…" saves every caller from reading the body.
3. **`nil` means one thing.** Here it means "not on the menu", nothing else. (`lowercased()` returns the text in lowercase letters, so `"Coffee"` finds `"coffee"`.)

Parsing works the same way. A function can return an optional **tuple** when it produces several values that only make sense together:

```swift
/// Parses a time written as "HH:MM", like "09:30".
/// Returns `nil` unless the text has exactly one ":" with an hour from 0 to 23
/// before it and a minute from 0 to 59 after it.
func parseTime(_ text: String) -> (hour: Int, minute: Int)? {
    let parts = text.split(separator: ":")
    guard parts.count == 2,
          let hour = Int(parts[0]), hour >= 0 && hour <= 23,
          let minute = Int(parts[1]), minute >= 0 && minute <= 59 else {
        return nil
    }
    return (hour, minute)
}

for text in ["09:30", "23:59", "24:00", "9.30", "12:5:0"] {
    if let time = parseTime(text) {
        print("\(text) -> \(time.hour) h \(time.minute) min")
    } else {
        print("\(text) -> not a time")
    }
}
```

```output
09:30 -> 9 h 30 min
23:59 -> 23 h 59 min
24:00 -> not a time
9.30 -> not a time
12:5:0 -> not a time
```

`text.split(separator: ":")` cuts the text at every `:` and gives back the pieces, so `"09:30"` becomes `["09", "30"]`. (It's a `String` method you haven't used yet. The pieces have type `Substring`, a view into the original text; `Int(…)` accepts them directly, and `String(…)` turns one into a `String` when you need to keep it.) The whole validation is one `guard` with a condition list, and the return type `(hour: Int, minute: Int)?` means the caller gets both numbers or neither. There's no way to end up with a valid hour and a garbage minute.

## Fixing the sentinels

In Module 6, `positionOfFirstVowel` returned -1 for "no vowel", and `parseAge` returned an `(isValid: Bool, age: Int)` flag. Both left the caller free to ignore the bad case. With an optional return type, they can't:

```swift
/// Returns the position of the first vowel in `word`, or `nil` if it has none.
func positionOfFirstVowel(in word: String) -> Int? {
    var position = 0
    for letter in word {
        if letter == "a" || letter == "e" || letter == "i" || letter == "o" || letter == "u" {
            return position
        }
        position += 1
    }
    return nil
}

/// Returns the age in `text`, or `nil` unless it's a whole number from 0 to 130.
func parseAge(_ text: String) -> Int? {
    guard let age = Int(text), age >= 0 && age <= 130 else {
        return nil
    }
    return age
}

for word in ["swift", "rhythm"] {
    if let position = positionOfFirstVowel(in: word) {
        print("\(word): first vowel at \(position)")
    } else {
        print("\(word): no vowels")
    }
}

for input in ["34", "abc", "200", "0"] {
    print(input, "->", parseAge(input).map { age in "age \(age)" } ?? "not a valid age")
}
```

```output
swift: first vowel at 2
rhythm: no vowels
34 -> age 34
abc -> not a valid age
200 -> not a valid age
0 -> age 0
```

`return nil` replaces `return -1`. `parseAge` shrinks from a tuple with a flag to a single `guard let`, and 0 is still a perfectly good age, because "invalid" is now `nil`, not a number. The caller of `positionOfFirstVowel` can no longer write `position + 1` by accident: the compiler stops them until they've handled `nil`.

## Second largest, for real

In Module 2 you designed an algorithm for "the second highest distinct value, or *doesn't exist*", with a variable `second` that started as **none**. Swift has none now:

```swift
/// Returns the second highest distinct value in `values`,
/// or `nil` if there are fewer than two distinct values.
func secondLargest(_ values: [Int]) -> Int? {
    guard let largest = values.max() else {
        return nil
    }
    var second: Int? = nil
    for value in values {
        guard value != largest else { continue }
        if let current = second, current >= value { continue }
        second = value
    }
    return second
}

let testCases: [[Int]] = [[5, 9, 4], [9, 9, 4], [7, 7, 7], [7], [], [-3, -8], [4, 9]]
for values in testCases {
    if let second = secondLargest(values) {
        print("\(values) -> \(second)")
    } else {
        print("\(values) -> doesn't exist")
    }
}
```

```output
[5, 9, 4] -> 5
[9, 9, 4] -> 4
[7, 7, 7] -> doesn't exist
[7] -> doesn't exist
[] -> doesn't exist
[-3, -8] -> -8
[4, 9] -> 4
```

This is the Module 2 pseudocode, line for line:

1. `guard let largest = values.max()` covers "if the list is empty, return doesn't exist". `max()` returns `nil` for an empty array, and the guard turns that into the function's `nil`.
2. `var second: Int? = nil` is "second ← none". It's an `Int?` because "no second value yet" is a real state, distinct from every number, including 0 and negatives.
3. `guard value != largest else { continue }` skips copies of the largest.
4. `if let current = second, current >= value { continue }` is "if second is none or p > second, then second ← p", turned around: if there's already a second value at least as big, skip; otherwise take this one.
5. `return second` returns the optional as it is: `nil` if nothing was ever found.

Every row of the Module 2 edge-case table comes out as designed, including `[-3, -8]`, which a version starting at 0 would get wrong.

## Optional parameters, briefly

Optionals work as parameters too. Use one when "not provided" is a legitimate input, often with a default of `nil`:

```swift
func greeting(for name: String?, punctuation: String = "!") -> String {
    guard let name, !name.isEmpty else {
        return "Hello there" + punctuation
    }
    return "Hello, \(name)" + punctuation
}

print(greeting(for: "Christian"))
print(greeting(for: nil))
print(greeting(for: "", punctuation: "."))
```

```output
Hello, Christian!
Hello there!
Hello there.
```

Don't make a parameter optional just in case. Every optional parameter is a branch inside the function and a question for every caller.

## Optionals that make an API worse

Some optional types add a `nil` that doesn't mean anything useful:

- **Optional collections.** `func search(_ query: String) -> [String]?` gives callers two kinds of "nothing", `nil` and `[]`. Unless they truly mean different things (for example, "the search didn't run" versus "it ran and found nothing"), return `[String]` and use `[]`.
- **`Bool?`.** Three states hidden in a type that looks like two. `if isEnabled == true` and `if isEnabled != false` behave differently for `nil`, and readers get them wrong. If there are three states, Module 9's enums can name them.
- **Optionals that are never `nil`.** If a function always returns a value, `Int?` forces callers to handle a case that can't happen. They'll write `!` to get rid of it, and now there's a force unwrap in their code because of your signature.

## A complete program: reading a config file

To close Stage 2, here's a program that uses most of what you've learned since Module 4: functions, loops, `guard`, collections, dictionaries and optionals. It reads settings from lines like you'd find in a simple config file, skips comments and blank lines, reports malformed lines, and validates each setting with a sensible fallback.

```swift
/// Splits a line like "volume=7" into its key and value.
/// Returns `nil` unless the line has exactly one "=" with text on both sides.
func parseSetting(_ line: String) -> (key: String, value: String)? {
    let parts = line.split(separator: "=")
    guard parts.count == 2 else {
        return nil
    }
    return (key: String(parts[0]), value: String(parts[1]))
}

/// Returns the setting for `key` as a whole number from `low` to `high`,
/// or `nil` if it's missing, isn't a whole number, or is out of range.
func intSetting(_ key: String, in settings: [String: String], from low: Int, to high: Int) -> Int? {
    guard let text = settings[key], let value = Int(text), value >= low && value <= high else {
        return nil
    }
    return value
}

let configLines = [
    "# Display",
    "theme=dark",
    "fontSize=18",
    "",
    "# Sound",
    "volume=loud",
    "brightness=140",
    "language",
    "volume=7",
]

var settings: [String: String] = [:]
for line in configLines {
    if line.isEmpty || line.hasPrefix("#") {
        continue
    }
    guard let setting = parseSetting(line) else {
        print("Ignoring malformed line: \"\(line)\"")
        continue
    }
    settings[setting.key] = setting.value
}

let theme = settings["theme"] ?? "light"
let fontSize = intSetting("fontSize", in: settings, from: 8, to: 32) ?? 14
let volume = intSetting("volume", in: settings, from: 0, to: 10) ?? 5
let brightness = intSetting("brightness", in: settings, from: 0, to: 100) ?? 100

if intSetting("brightness", in: settings, from: 0, to: 100) == nil, let raw = settings["brightness"] {
    print("brightness \"\(raw)\" is invalid, using \(brightness)")
}
print("theme: \(theme), font size: \(fontSize), volume: \(volume), brightness: \(brightness)")
```

```output
Ignoring malformed line: "language"
brightness "140" is invalid, using 100
theme: dark, font size: 18, volume: 7, brightness: 100
```

Walk through the decisions:

1. **Blank lines and comments are filtered by the caller**, not by `parseSetting`. If the parser returned `nil` for those too, `nil` would mean "skip this, it's fine" for some lines and "this is broken" for others, and the loop couldn't report only the broken ones. Keeping `nil` to one meaning made the caller simple. (`hasPrefix("#")` checks whether the text starts with `#`.)
2. **`parseSetting` returns an optional tuple.** A line either yields a key and a value, or nothing. `guard let` in the loop unwraps it and reports the failure.
3. **Later lines win.** `volume=loud` is stored first, then `volume=7` replaces it, because assigning to an existing dictionary key overwrites it. That's a decision about the file format; a stricter parser might report duplicates.
4. **`intSetting` merges three failures into one `nil`**: missing, not a number, out of range. That's acceptable here because the caller does the same thing for all three, use the fallback. If the app had to tell the user exactly what was wrong with each setting, that would be the cue for an error type (Module 12).
5. **The fallbacks live at the call site**, next to `??`, where each one is visible. `intSetting` doesn't pick defaults, because a good default depends on the setting.
6. The brightness warning shows the one place the program needed more than `??`: it uses `if` with a condition list to report a value that exists but is invalid.

## Common mistakes

> [!error] Returning a convenient default instead of nil
> `price(of:)` returning 0 for an unknown item lets the caller sell it for free. Return `Int?` and make the caller decide.

> [!error] One nil, several meanings
> If `nil` can mean "skip this" or "this is broken", the caller can't react correctly to either. Handle one case before calling, split the function, or use an error (Module 12).

> [!error] An optional collection where an empty one would do
> `[String]?` makes every caller unwrap something that `[]` already expressed.

> [!error] No word on what nil means
> A failable function without a doc comment forces every caller to read its body. One `///` line that finishes "returns nil if…" fixes that.

> [!error] Wrapping a result in an optional "just in case"
> If the function can't fail, a plain return type is the honest one. An optional that's never `nil` trains callers to use `!`.

````exercise
id: m08-l06-e1
type: comprehension
prompt: Which function is best designed with an optional return type?
choices:
  - text: "`func numberOfUnreadMessages() -> Int?`"
    correct: false
    why: "0 is the correct answer when there are none. An optional adds a meaningless second \"none\"."
  - text: "`func contact(withEmail email: String) -> Contact?`"
    correct: true
    why: "Not finding a contact is a normal outcome with one clear meaning: no contact has that email."
  - text: "`func search(_ query: String) -> [Contact]?`"
    correct: false
    why: An empty array already says "no matches".
  - text: "`func logIn(user: String, password: String) -> Session?`"
    correct: false
    why: "Logging in can fail for several reasons that need different handling (wrong password, locked account, no network). That's a job for errors, in Module 12."
solution: |
  **`contact(withEmail:)`**. A lookup by a key is the classic optional: either there's a match or there isn't, and `nil` has one meaning. The unread count and the search have correct plain answers for the empty case (0 and `[]`). Login can return `nil` too, but then the app can't tell the user whether to retype the password or check their connection.
````

````exercise
id: m08-l06-e2
type: prediction
prompt: Predict the exact output.
code: |
  func discount(forCode code: String) -> Int? {
      if code == "SAVE10" { return 10 }
      if code == "HALF" { return 50 }
      return nil
  }

  func finalPrice(_ price: Int, code: String?) -> Int {
      guard let code, let percent = discount(forCode: code) else {
          return price
      }
      return price - price * percent / 100
  }

  print(finalPrice(200, code: "SAVE10"))
  print(finalPrice(200, code: "HALF"))
  print(finalPrice(200, code: "FREE"))
  print(finalPrice(200, code: nil))
  print(discount(forCode: "half") ?? 0)
output: |
  180
  100
  200
  200
  0
hints:
  - "price * percent / 100 is evaluated left to right."
  - "The guard fails both when there's no code and when the code is unknown."
  - String comparison is case-sensitive.
solution: |
  ```output
  180
  100
  200
  200
  0
  ```

  1. 10%: `200 - 200 * 10 / 100 = 200 - 20 = 180`.
  2. 50%: `200 - 100 = 100`.
  3. `"FREE"` isn't a known code, so `discount` returns `nil`, the guard fails, and the full price comes back.
  4. No code at all: the first binding fails.
  5. `"half"` isn't `"HALF"`, so the lookup is `nil` and `??` gives 0.
````

````exercise
id: m08-l06-e3
type: refactor
prompt: |
  This is Module 6's flag-in-a-tuple version. Rewrite `parseTemperature` so it returns `Int?`, add a doc comment that says when it returns `nil`, and update the caller. The output must stay the same.
code: |
  func parseTemperature(_ text: String) -> (isValid: Bool, value: Int) {
      let number = Int(text) ?? -1000
      if number < -90 || number > 60 {
          return (false, 0)
      }
      return (true, number)
  }

  for text in ["21", "-5", "hot", "75"] {
      let result = parseTemperature(text)
      if result.isValid {
          print("\(text): \(result.value) degrees")
      } else {
          print("\(text): invalid")
      }
  }
rubric:
  - The return type is Int? and there's no flag or made-up value left.
  - A /// comment states exactly when the function returns nil.
  - The caller uses if let (or guard let) instead of checking a flag.
  - The output is the same.
solution: |
  ```swift
  /// Returns the temperature in `text` in degrees Celsius,
  /// or `nil` unless it's a whole number from -90 to 60.
  func parseTemperature(_ text: String) -> Int? {
      guard let value = Int(text), value >= -90 && value <= 60 else {
          return nil
      }
      return value
  }

  for text in ["21", "-5", "hot", "75"] {
      if let value = parseTemperature(text) {
          print("\(text): \(value) degrees")
      } else {
          print("\(text): invalid")
      }
  }
  ```

  ```output
  21: 21 degrees
  -5: -5 degrees
  hot: invalid
  75: invalid
  ```

  The `-1000` fallback and the `(false, 0)` placeholder both disappear. The caller can no longer read `value` for an invalid input, because there's no value to read: it only exists inside the `if let`.
````

````exercise
id: m08-l06-e4
type: solve
prompt: |
  Write `func parseCommand(_ line: String) -> (name: String, amount: Int)?` for a tiny calculator. A valid command is a name and a whole number separated by **one space**, like `"add 5"`. Only the names `add` and `subtract` are valid. Return `nil` for anything else.

  Then run this list through it, starting from a total of 0, applying valid commands and reporting the rest:

  ```swift
  let commands = ["add 5", "add five", "subtract 2", "multiply 3", "add 10", "subtract"]
  ```

  Expected output:

  ```output
  Skipping "add five"
  Skipping "multiply 3"
  Skipping "subtract"
  Total: 13
  ```
starter: |
  func parseCommand(_ line: String) -> (name: String, amount: Int)? {
      // your code
  }

  let commands = ["add 5", "add five", "subtract 2", "multiply 3", "add 10", "subtract"]
hints:
  - "line.split(separator: \" \") splits at spaces."
  - "Check parts.count == 2 before reading parts[0] and parts[1]."
  - "String(parts[0]) gives you a String to compare with \"add\"."
  - In the loop, guard let the parsed command and continue on nil.
rubric:
  - parseCommand returns an optional tuple and nil for every invalid line.
  - It never reads parts[1] without first checking the count.
  - The loop reports each invalid line and applies the valid ones.
  - The output matches exactly.
solution: |
  ```swift
  /// Parses a command like "add 5". Returns `nil` unless the line is
  /// "add" or "subtract", one space, and a whole number.
  func parseCommand(_ line: String) -> (name: String, amount: Int)? {
      let parts = line.split(separator: " ")
      guard parts.count == 2, let amount = Int(parts[1]) else {
          return nil
      }
      let name = String(parts[0])
      guard name == "add" || name == "subtract" else {
          return nil
      }
      return (name, amount)
  }

  let commands = ["add 5", "add five", "subtract 2", "multiply 3", "add 10", "subtract"]

  var total = 0
  for line in commands {
      guard let command = parseCommand(line) else {
          print("Skipping \"\(line)\"")
          continue
      }
      if command.name == "add" {
          total += command.amount
      } else {
          total -= command.amount
      }
  }
  print("Total: \(total)")
  ```

  ```output
  Skipping "add five"
  Skipping "multiply 3"
  Skipping "subtract"
  Total: 13
  ```

  `parts.count == 2` comes first in the condition list, so `parts[1]` is only read when it exists. Reading it without the check would crash on `"subtract"` with "Index out of range". The parser validates the name too, so the loop only ever sees `"add"` or `"subtract"`, and its `else` can safely mean subtract. 0 + 5 − 2 + 10 = 13.
````

````exercise
id: m08-l06-e5
type: design
prompt: |
  You're designing the functions for a small library app. For each one, write the signature, choose the return type (optional, plain value or "error, in Module 12") and write a one-line doc comment:

  1. Find a book by its ISBN.
  2. Count how many books a member has borrowed.
  3. List all books by an author.
  4. Get the due date of a member's loan of a given book. (Represent a date as a `String` for now.)
  5. Borrow a book, which can fail because the book is already lent out, the member has too many loans, or the member owes fees.
rubric:
  - "1 and 4 return optionals, and their doc comments say what nil means."
  - "2 returns Int with 0 for none, and 3 returns an array that's empty when there are none."
  - 5 is identified as needing errors because the failure reasons need different handling.
  - The names read naturally at the call site and suggest when a result can be missing.
solution: |
  One reasonable design (types like `Book` are placeholders; you'll write your own types in Module 9):

  ```swift illustrative
  /// Returns the book with this ISBN, or nil if the catalog has none.
  func book(withISBN isbn: String) -> Book?

  /// Returns how many books the member currently has borrowed (0 if none).
  func loanCount(forMember memberID: Int) -> Int

  /// Returns every book by `author`, or an empty array if there are none.
  func books(by author: String) -> [Book]

  /// Returns the due date of the member's loan of this book,
  /// or nil if the member hasn't borrowed it.
  func dueDate(ofBook isbn: String, forMember memberID: Int) -> String?

  /// Lends the book to the member. Fails if the book is already lent out,
  /// the member has too many loans, or the member owes fees.
  func borrow(isbn: String, memberID: Int) throws  // Module 12
  ```

  1 and 4 are lookups that can find nothing, with one meaning each. 2 and 3 have correct plain answers for "none". 5 has three failure reasons, and the app must tell the member which one applies, which is more than `nil` can say. This block is marked illustrative because it's a set of signatures without bodies, not a runnable program.
````

````exercise
id: m08-l06-e6
type: explain
prompt: |
  A teammate's function returns `[String]?` for "the names of the friends who liked a post", returning `nil` when nobody liked it. Explain what's wrong with this design and what you'd change. Then describe one situation where `[String]?` would be justified.
code: |
  /// Returns the names of the friends who liked the post, or nil if nobody did.
  func friendsWhoLiked(post postID: Int) -> [String]?
rubric:
  - I said that an empty array already means nobody liked it.
  - I said the optional forces every caller to unwrap and handle two kinds of "none".
  - I proposed returning [String] with [] for no likes.
  - "I gave a case where nil and [] mean different things, such as \"not loaded yet\" vs \"loaded, no likes\"."
solution: |
  An empty array already says "nobody liked it". Returning `nil` for that case creates two ways to say the same thing, and every caller now has to write `likes ?? []` or `if let` before doing anything, including just counting. Worse, some callers will check `likes == nil` and others `likes?.isEmpty == true`, and one of them will be wrong. Return `[String]` and use `[]`.

  `[String]?` is justified when `nil` and `[]` mean different things the caller cares about: for example, `nil` for "the likes haven't been loaded from the server yet" (show a spinner) and `[]` for "loaded, and nobody liked it" (show "Be the first to like this"). In that case, document both meanings. Later in the course you'll see an enum with named cases handle a state like that even more clearly.
````

## Summary

- Return an optional when "no result" is normal and has one meaning. Return a plain value when there's a correct answer for the empty case. Use an error (Module 12) when the caller needs to know why.
- Name failable functions so absence sounds expected, and write a `///` comment that finishes "returns nil if…".
- An optional tuple returns several values that only exist together.
- Optional return types replace sentinels like -1 and `(isValid, value)` flags, and the compiler makes callers handle the missing case.
- `secondLargest` with `var second: Int? = nil` is the Module 2 algorithm, with "none" finally a real value.
- Avoid optional collections, `Bool?` and optionals that are never `nil`.
- Keep `nil` meaning one thing: filter the cases you want to skip before calling a parser, and put fallbacks at the call site with `??`.

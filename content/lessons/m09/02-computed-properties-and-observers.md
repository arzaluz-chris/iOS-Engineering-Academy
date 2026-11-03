---
id: m09-l02
title: "Computed properties and property observers"
description: You write properties that are calculated instead of stored, with a getter and optionally a setter, react to changes with willSet and didSet, learn exactly when observers run and when they don't, and delay expensive work with lazy.
module: m09
order: 2
level: beginner
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m09-l01]
objectives:
  - Write read-only computed properties and computed properties with a getter and a setter.
  - Choose between a stored property, a computed property and a method.
  - Use willSet and didSet to react to changes, and predict when they run.
  - Keep a stored property valid by correcting it in didSet.
  - Use a lazy stored property and explain when its value is created.
terms:
  - term: Computed property
    definition: "A property that doesn't store a value. Its getter calculates the value every time you read it, and an optional setter runs when you assign to it."
  - term: Getter and setter
    definition: "The get block computes a computed property's value; the set block runs on assignment and receives the new value as newValue."
  - term: Property observer
    definition: "A willSet or didSet block attached to a stored property. willSet runs just before a new value is stored, didSet right after."
  - term: newValue and oldValue
    definition: "The implicit names for the incoming value in willSet and in a setter, and for the previous value in didSet."
  - term: Lazy stored property
    definition: "A var property marked lazy whose initial value is computed the first time it's read, not when the instance is created."
mastery:
  - Turn a method with no parameters that just derives a value into a read-only computed property.
  - Write a computed property with a setter that updates the stored properties it's derived from.
  - Predict the output of a program with willSet and didSet, including assignments in an initializer.
  - Clamp a value to a valid range in didSet.
  - Say why a lazy property needs a var instance.
resources: [swift-book-properties, swift-book-structures-classes, swift-book-basics]
cards:
  - id: m09-l02-c1
    front: What's the difference between a stored and a computed property?
    back: "A stored property keeps a value in every instance. A computed property keeps nothing: its getter recalculates the value from other properties each time it's read."
  - id: m09-l02-c2
    front: Why must a computed property be declared with var?
    back: "Its value can change whenever the properties it's computed from change, so it isn't a constant. Swift 6.3: 'let' declarations cannot be computed properties."
  - id: m09-l02-c3
    front: Do willSet and didSet run when the initializer sets the property?
    back: "No. Observers only run for assignments after the instance is fully initialized, not for the default value or for assignments in the type's own initializer."
  - id: m09-l02-c4
    front: Does didSet run if you assign the same value the property already has?
    back: "Yes. didSet runs on every assignment, and on every in-place change like append. Compare oldValue with the property yourself if you only care about real changes."
  - id: m09-l02-c5
    front: When is a lazy property's value computed?
    back: "The first time it's read. After that it's stored like any other property. Reading it changes the instance, so the instance must be a var."
---

## The idea in one sentence

Some properties shouldn't be stored at all but calculated from the others, and some stored properties need to react when they change: computed properties do the first, observers the second.

## Computed properties

A rectangle has a width and a height. Its area isn't a third independent fact; it's whatever width times height is right now. If you stored it, you'd have to remember to update it on every change, and one day you'd forget.

A **computed property** stores nothing. It has a **getter**, a block of code that runs every time you read the property:

```swift
struct Rectangle {
    var width: Double
    var height: Double

    var area: Double {
        return width * height
    }

    var isSquare: Bool {
        width == height
    }
}

var rect = Rectangle(width: 4, height: 2.5)
print(rect.area)
print(rect.isSquare)

rect.height = 4
print(rect.area)
print(rect.isSquare)
```

```output
10.0
false
16.0
true
```

1. `var area: Double { … }` declares a computed property: a name, a type, and a body in braces. There's no `=` and no initial value.
2. Reading `rect.area` runs the body. It uses the current `width` and `height`, so after `rect.height = 4` the area is right without any extra work.
3. `isSquare` leaves out `return`. As with functions, a body that's a single expression returns that expression.
4. Callers can't tell a computed property from a stored one. `rect.area` reads exactly like `rect.width`. That's the point: whether a value is stored or computed is the struct's business.

Computed properties aren't part of the memberwise initializer. `Rectangle(width:height:)` asks only for what's stored.

### Getters and setters

A computed property can also have a **setter**, which runs when you assign to it. The setter receives the assigned value as `newValue` and updates the stored properties it's derived from:

```swift
struct Temperature {
    var celsius: Double

    var fahrenheit: Double {
        get {
            celsius * 9 / 5 + 32
        }
        set {
            celsius = (newValue - 32) * 5 / 9
        }
    }
}

var today = Temperature(celsius: 25)
print(today.fahrenheit)

today.fahrenheit = 212
print(today.celsius)
```

```output
77.0
100.0
```

Only `celsius` is stored. `fahrenheit` is a view of it in another unit. Assigning `today.fahrenheit = 212` runs `set` with `newValue` equal to 212, which stores 100 in `celsius`. Reading either property afterward gives consistent answers, because there's only one real value.

With a setter, you have to write `get { … }` explicitly. Without one, the plain `{ … }` form is a **read-only computed property**, and assigning to it fails:

```swift no-compile cannot assign to property: 'area' is a get-only property
struct Rectangle {
    var width: Double
    var height: Double

    var area: Double {
        width * height
    }
}

var rect = Rectangle(width: 4, height: 2.5)
rect.area = 20
```

That's often what you want. What would setting the area of a rectangle even mean: change the width, the height, or both?

### Property or method?

`area` could have been `func area() -> Double` like in lesson 1. Both work. The conventions Swift code follows:

- **Computed property** when the value is a characteristic of the instance, is cheap to compute, takes no arguments and has no side effects: `area`, `isEmpty`, `fahrenheit`, `fullName`.
- **Method** when it takes arguments, does real work (searching a large collection, formatting a long report), or changes something: `hoursToRead(pagesPerHour:)`, `summary(for:)`.

The standard library follows the same split: `count` and `isEmpty` are properties; `sorted()` and `filter(_:)` are methods.

## Property observers

Sometimes a stored property must stay stored, but you want to run code whenever it changes: log it, keep it in range, update something that depends on it. **Property observers** do that:

```swift
struct StepCounter {
    var steps: Int {
        willSet {
            print("About to set steps to \(newValue)")
        }
        didSet {
            print("Added \(steps - oldValue) steps")
        }
    }
}

var counter = StepCounter(steps: 0)
counter.steps = 200
counter.steps = 560
```

```output
About to set steps to 200
Added 200 steps
About to set steps to 560
Added 360 steps
```

- **`willSet`** runs just before the new value is stored. The incoming value is available as `newValue`; the property still holds the old one.
- **`didSet`** runs right after. The property holds the new value, and the previous one is available as `oldValue`.

You can write either one or both. Most real code only needs `didSet`.

### When observers run, and when they don't

Observers are for changes to an instance that already exists. The rules, each one checked by the program below:

1. They run on **every** assignment, even when the new value equals the old one.
2. They run when the property changes **in place**: `+=`, or `append` on an array property.
3. They **don't** run for the property's initial value, either a default value or an assignment in the type's own initializer.

```swift
struct Playlist {
    var songs: [String] = [] {
        didSet {
            print("Playlist now has \(songs.count) songs")
        }
    }
}

var playlist = Playlist(songs: ["Intro"])
print("Created")
playlist.songs.append("Song 2")
playlist.songs = ["Intro", "Song 2"]
playlist.songs[0] = "New intro"
```

```output
Created
Playlist now has 2 songs
Playlist now has 2 songs
Playlist now has 2 songs
```

Creating the playlist printed nothing, even though the memberwise initializer stored `["Intro"]`. The `append` triggered `didSet` (rule 2). Assigning an array equal to the current one triggered it again (rule 1), and so did changing one element, because changing an element changes the array, and the array is the property.

Rule 1 surprises people. If you only care about real changes, compare in `didSet`:

```swift
struct Playlist {
    var songs: [String] = [] {
        didSet {
            if songs != oldValue {
                print("The playlist changed")
            }
        }
    }
}

var playlist = Playlist(songs: ["Intro"])
playlist.songs = ["Intro"]
playlist.songs.append("Song 2")
```

```output
The playlist changed
```

### Keeping a value valid with didSet

An observer may assign to its own property. That assignment does **not** trigger the observer again, which makes `didSet` a natural place to correct a value:

```swift
struct Speaker {
    var volume: Int = 5 {
        didSet {
            if volume > 10 {
                volume = 10
            } else if volume < 0 {
                volume = 0
            }
        }
    }
}

var speaker = Speaker()
speaker.volume += 3
print(speaker.volume)
speaker.volume = 25
print(speaker.volume)
speaker.volume -= 40
print(speaker.volume)
```

```output
8
10
0
```

`volume = 10` inside `didSet` stores the clamped value without starting an endless loop. Remember rule 3, though: `Speaker(volume: 99)` would store 99, because the initializer doesn't trigger observers. Lesson 3 shows how to validate in an initializer.

## lazy stored properties

A **lazy** stored property gets its initial value the first time someone reads it, not when the instance is created. That's useful when the value is expensive to build and might never be needed:

```swift
struct Document {
    var text: String

    lazy var wordCount: Int = {
        print("Counting words...")
        return text.split(separator: " ").count
    }()
}

var document = Document(text: "the quick brown fox")
print("Document created")
print(document.wordCount)
print(document.wordCount)
```

```output
Document created
Counting words...
4
4
```

1. `lazy var wordCount: Int = { … }()` is a stored property whose initial value comes from a closure that's called right away: note the `()` at the end. You've seen closures in Module 6; this one takes no parameters and returns an `Int`.
2. Because it's `lazy`, the closure doesn't run when the document is created. "Counting words..." appears only at the first read.
3. The second read uses the stored result. The closure never runs again.

Two limitations follow from how it works:

- **The instance must be a `var`.** The first read stores a value, which changes the instance. On a `let` instance, Swift 6.3 says `cannot use mutating getter on immutable value: 'document' is a 'let' constant`.
- **The value isn't recalculated.** If `text` changes after the first read, `wordCount` keeps its old value. Here a computed property would be correct and simpler. Use `lazy` only for values that don't depend on anything that changes, or that you'll refresh yourself.

```swift no-compile cannot use mutating getter on immutable value: 'document' is a 'let' constant
struct Document {
    var text: String

    lazy var wordCount: Int = {
        return text.split(separator: " ").count
    }()
}

let document = Document(text: "the quick brown fox")
print(document.wordCount)
```

In practice, a computed property is the right tool much more often than `lazy`. You'll see `lazy` mostly in iOS code that creates expensive objects, such as views, only when they're first shown.

## A practical example: a bank account

Putting both tools together: stored properties for the facts, a computed property for a derived value, and `didSet` to keep a history.

```swift
struct Account {
    let owner: String
    var balanceInCents: Int {
        didSet {
            let change = balanceInCents - oldValue
            history.append(change)
        }
    }
    var history: [Int] = []

    var balanceText: String {
        let dollars = balanceInCents / 100
        let cents = balanceInCents % 100
        return cents < 10 ? "$\(dollars).0\(cents)" : "$\(dollars).\(cents)"
    }

    var isOverdrawn: Bool {
        balanceInCents < 0
    }
}

var account = Account(owner: "Christian", balanceInCents: 10_000)
account.balanceInCents += 2_550
account.balanceInCents -= 4_005
print("\(account.owner): \(account.balanceText)")
print("Changes: \(account.history)")
print("Overdrawn: \(account.isOverdrawn)")
```

```output
Christian: $85.45
Changes: [2550, -4005]
Overdrawn: false
```

The starting balance isn't in `history`, because the initializer doesn't trigger `didSet`. That's correct here: the history records changes, and opening the account isn't one. `balanceText` and `isOverdrawn` can never disagree with the balance, because they're computed from it on every read.

## Common mistakes

> [!error] error: 'let' declarations cannot be computed properties
> A computed property is always declared with `var`, even if it's read-only, because its value can change when the properties it reads change.

```swift no-compile 'let' declarations cannot be computed properties
struct Rectangle {
    var width: Double
    var height: Double

    let area: Double {
        width * height
    }
}
```

> [!error] Storing a value that should be computed
> `var area: Double` as a stored property next to `width` and `height` means every change to the width must remember to update the area. Make it computed and the question disappears.

> [!error] Expecting didSet to run in the initializer
> `Speaker(volume: 99)` stores 99 without calling `didSet`. If a value must be validated from the start, validate it in the initializer too (lesson 3).

> [!warning] Expecting didSet to fire only on real changes
> It runs on every assignment, including assigning the same value. Compare with `oldValue` when that matters.

> [!warning] Using lazy for a value that depends on other properties
> A lazy property is computed once. If its inputs change later, it goes stale silently. That's a job for a computed property.

````exercise
id: m09-l02-e1
type: comprehension
prompt: "A `struct Circle` stores `radius`. Which is the best way to provide its diameter?"
choices:
  - text: "A stored property `var diameter: Double` that you update whenever radius changes."
    correct: false
    why: Two stored values that must always agree will eventually disagree.
  - text: "A computed property `var diameter: Double { radius * 2 }`."
    correct: true
    why: "It's derived from radius, cheap and takes no arguments, so a computed property fits and can never be stale."
  - text: "A lazy property `lazy var diameter: Double = { radius * 2 }()`."
    correct: false
    why: "It's computed once, so it goes stale as soon as radius changes."
  - text: "A didSet on radius that prints the new diameter."
    correct: false
    why: "That shows the diameter but doesn't give callers a way to read it."
solution: |
  **A computed property.** `diameter` is fully determined by `radius`, so it shouldn't be stored separately. You could also give it a setter that sets `radius = newValue / 2`, so callers can assign either one.
````

````exercise
id: m09-l02-e2
type: prediction
prompt: Predict the exact output.
code: |
  struct Thermostat {
      var target: Int {
          willSet {
              print("will: \(target) -> \(newValue)")
          }
          didSet {
              if target > 30 {
                  target = 30
              }
              print("did: \(oldValue) -> \(target)")
          }
      }
  }

  var thermostat = Thermostat(target: 20)
  thermostat.target = 22
  thermostat.target = 22
  thermostat.target = 35
  print(thermostat.target)
output: |
  will: 20 -> 22
  did: 20 -> 22
  will: 22 -> 22
  did: 22 -> 22
  will: 22 -> 35
  did: 22 -> 30
  30
hints:
  - The initializer doesn't trigger observers.
  - Observers run even when the value doesn't change.
  - Assigning to the property inside its own didSet doesn't run the observers again.
solution: |
  ```output
  will: 20 -> 22
  did: 20 -> 22
  will: 22 -> 22
  did: 22 -> 22
  will: 22 -> 35
  did: 22 -> 30
  30
  ```

  1. `Thermostat(target: 20)` prints nothing: observers don't run during initialization.
  2. Setting 22: `willSet` sees the old 20 in `target` and 22 in `newValue`; `didSet` sees `oldValue` 20 and the new 22.
  3. Setting 22 again still runs both observers.
  4. Setting 35: `willSet` sees 35 coming. In `didSet`, the clamp stores 30 without triggering `willSet` or `didSet` again, and then the print shows the corrected value.
````

````exercise
id: m09-l02-e3
type: fill-in
prompt: "Complete `Distance` so it stores meters and offers kilometers as a computed property you can read and assign. The program should print `1.5` and then `2500.0`."
code: |
  struct Distance {
      var meters: Double

      var kilometers: Double {
          [[1]] {
              meters / 1000
          }
          [[2]] {
              meters = [[3]] * 1000
          }
      }
  }

  var run = Distance(meters: 1500)
  print(run.kilometers)
  run.kilometers = 2.5
  print(run.[[4]])
blanks:
  - id: "1"
    answers: [get]
  - id: "2"
    answers: [set]
  - id: "3"
    answers: [newValue]
  - id: "4"
    answers: [meters]
solution: |
  ```swift
  struct Distance {
      var meters: Double

      var kilometers: Double {
          get {
              meters / 1000
          }
          set {
              meters = newValue * 1000
          }
      }
  }

  var run = Distance(meters: 1500)
  print(run.kilometers)
  run.kilometers = 2.5
  print(run.meters)
  ```

  ```output
  1.5
  2500.0
  ```

  The setter receives the assigned 2.5 as `newValue` and stores 2500 in `meters`. Only `meters` is stored, so the two units can never disagree.
````

````exercise
id: m09-l02-e4
type: find-errors
prompt: "A teammate wrote this to track a user's display name and how many times it changed. It should print `Changed 2 times: Chris`. Which statements are true?"
code: |
  struct Profile {
      var changeCount = 0
      var displayName: String {
          didSet {
              changeCount += 1
          }
      }
      let greeting: String {
          "Hi, \(displayName)"
      }
  }

  var profile = Profile(displayName: "Christian")
  profile.displayName = "Christian R."
  profile.displayName = "Chris"
  print("Changed \(profile.changeCount) times: \(profile.displayName)")
choices:
  - text: "greeting doesn't compile because a computed property must be a var."
    correct: true
    why: "Swift 6.3 reports 'let' declarations cannot be computed properties."
  - text: "changeCount ends at 3 because creating the profile also triggers didSet."
    correct: false
    why: Observers don't run during initialization, so only the two later assignments count.
  - text: "didSet can't change another property of the struct."
    correct: false
    why: "An observer can change other stored properties, and even its own."
  - text: "The memberwise initializer call is wrong: it also needs changeCount."
    correct: false
    why: "changeCount has a default value, so its parameter in the memberwise initializer is optional. Lesson 3 covers this."
rubric:
  - I spotted that greeting must be declared with var.
  - I explained that the initializer doesn't count as a change.
solution: |
  Only the `let` on `greeting` is a real problem. With `var greeting: String { "Hi, \(displayName)" }` the program compiles and prints the right thing:

  ```swift
  struct Profile {
      var changeCount = 0
      var displayName: String {
          didSet {
              changeCount += 1
          }
      }
      var greeting: String {
          "Hi, \(displayName)"
      }
  }

  var profile = Profile(displayName: "Christian")
  profile.displayName = "Christian R."
  profile.displayName = "Chris"
  print("Changed \(profile.changeCount) times: \(profile.displayName)")
  print(profile.greeting)
  ```

  ```output
  Changed 2 times: Chris
  Hi, Chris
  ```

  The initial `"Christian"` comes from the initializer, which doesn't trigger `didSet`, so the count is exactly the two renames.
````

````exercise
id: m09-l02-e5
type: solve
prompt: |
  Write a `struct Battery` with a stored `level` (`Int`, a percentage) that:

  - is clamped to 0...100 in `didSet` whenever it's assigned,
  - has a computed `status: String` that is `"empty"` at 0, `"low"` from 1 to 20, `"ok"` from 21 to 99 and `"full"` at 100,
  - has a computed `bars: Int` from 0 to 4, equal to `level / 25` (so 100 gives 4).

  Then run this and match the expected output:

  ```swift illustrative
  var battery = Battery(level: 50)
  for change in [-35, -20, 60, 80] {
      battery.level += change
      print("\(battery.level)% \(battery.status), \(battery.bars) bars")
  }
  ```

  ```output
  15% low, 0 bars
  0% empty, 0 bars
  60% ok, 2 bars
  100% full, 4 bars
  ```
starter: |
  struct Battery {
      var level: Int {
          didSet {
              // clamp
          }
      }

      // status and bars
  }

  var battery = Battery(level: 50)
  for change in [-35, -20, 60, 80] {
      battery.level += change
      print("\(battery.level)% \(battery.status), \(battery.bars) bars")
  }
hints:
  - "min(max(level, 0), 100) clamps in one expression."
  - "A switch over level with ranges (Module 5) fits status well."
rubric:
  - didSet keeps level in 0...100.
  - status and bars are computed properties, not stored ones.
  - status covers every value with a switch or if chain, including 0 and 100.
  - The output matches exactly.
solution: |
  ```swift
  struct Battery {
      var level: Int {
          didSet {
              level = min(max(level, 0), 100)
          }
      }

      var status: String {
          switch level {
          case 0:
              return "empty"
          case 1...20:
              return "low"
          case 100:
              return "full"
          default:
              return "ok"
          }
      }

      var bars: Int {
          level / 25
      }
  }

  var battery = Battery(level: 50)
  for change in [-35, -20, 60, 80] {
      battery.level += change
      print("\(battery.level)% \(battery.status), \(battery.bars) bars")
  }
  ```

  ```output
  15% low, 0 bars
  0% empty, 0 bars
  60% ok, 2 bars
  100% full, 4 bars
  ```

  50 − 35 = 15. 15 − 20 = −5, which `didSet` clamps to 0. 0 + 60 = 60. 60 + 80 = 140, clamped to 100. `min(max(level, 0), 100)` first raises anything below 0 to 0, then lowers anything above 100 to 100. The `default` in `status` is fine here: it's a switch over `Int`, and after the clamp only 21...99 can reach it.
````

````exercise
id: m09-l02-e6
type: explain
prompt: |
  Explain what this program prints and why `wordCount` is wrong at the end. Then say how you'd fix it.
code: |
  struct Note {
      var text: String
      lazy var wordCount: Int = {
          text.split(separator: " ").count
      }()
  }

  var note = Note(text: "buy milk")
  print(note.wordCount)
  note.text = "buy milk and eggs today"
  print(note.wordCount)
rubric:
  - I said it prints 2 twice.
  - I explained that a lazy property is computed once, at the first read, and then stored.
  - I proposed a computed property so the count follows the text.
solution: |
  It prints `2` and then `2` again:

  ```swift
  struct Note {
      var text: String
      lazy var wordCount: Int = {
          text.split(separator: " ").count
      }()
  }

  var note = Note(text: "buy milk")
  print(note.wordCount)
  note.text = "buy milk and eggs today"
  print(note.wordCount)
  ```

  ```output
  2
  2
  ```

  A `lazy` property runs its initializer once, at the first read, and stores the result. Changing `text` afterward doesn't touch the stored 2. The count depends on a property that changes, so it should be computed:

  ```swift
  struct Note {
      var text: String
      var wordCount: Int {
          text.split(separator: " ").count
      }
  }

  var note = Note(text: "buy milk")
  print(note.wordCount)
  note.text = "buy milk and eggs today"
  print(note.wordCount)
  ```

  ```output
  2
  5
  ```

  A bonus: `wordCount` no longer needs a `var` instance to be read.
````

## Summary

- A **computed property** stores nothing: its getter calculates the value on every read. Declare it with `var`, a type and a body.
- Add `get { }` and `set { }` to make it assignable. The setter gets the assigned value as `newValue` and updates the stored properties.
- Use a computed property for cheap characteristics without arguments; use a method for work, arguments or side effects.
- **`willSet`** runs before a stored property changes (`newValue`); **`didSet`** runs after (`oldValue`).
- Observers run on every assignment and every in-place change, even with the same value. They don't run for default values or in the type's own initializer.
- Assigning to a property inside its own `didSet` doesn't trigger the observer again, so `didSet` can clamp a value.
- A **`lazy var`** is computed once, at its first read. The instance must be a `var`, and the value doesn't follow later changes.

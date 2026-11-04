---
id: m47-l01
title: How to answer a technical question
description: "Give technical answers an interviewer can follow and probe: a direct answer first, then the mechanism, a small example, the trade-off and where it breaks. You practice replacing hand-waving with precise, checkable statements, and saying \"I don't know\" in a way that still shows how you'd find out, with a ten-line experiment as the proof."
module: m47
order: 1
level: advanced
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m42-l07, m43-l06]
objectives:
  - Structure an answer as direct answer, mechanism, example, trade-off and limits, and stop when the question is answered.
  - Replace vague claims ("it's faster", "it's thread-safe") with precise statements that name a condition.
  - Answer a question you can't fully answer by separating what you know, what you suspect and how you'd verify it.
  - Write a small experiment that settles a language question in a few lines.
  - Practice with the course's interview bank without memorizing answers.
terms:
  - term: Direct answer
    definition: "The one or two sentences that answer the question as asked, before any background. If the interviewer stopped you there, they'd still have the answer."
  - term: Mechanism
    definition: "Why the direct answer is true: the rule, data structure or runtime behavior that produces it."
  - term: Trade-off
    definition: "What the behavior costs, and when a different choice would be better."
  - term: Hand-waving
    definition: "A statement that sounds technical but can't be checked: no condition, no mechanism, no example (\"Swift handles that for you\")."
  - term: Falsifiable claim
    definition: "A statement precise enough that a small program, a documentation page or a measurement could prove it wrong."
mastery:
  - Answer a new language question in five parts, each one or two sentences, in under two minutes.
  - Point to the vague word in someone else's answer and rewrite the sentence with the condition that makes it true.
  - "Say \"I don't know\" followed by an adjacent fact, a labeled hypothesis and a concrete way to check it."
  - Write an experiment whose output settles a question about Swift behavior.
resources: [swift-book, swift-book-collection-types, swift-book-properties, swift-array, swift-evolution]
cards:
  - id: m47-l01-c1
    front: What are the five parts of a technical answer in this course?
    back: "Direct answer, mechanism, example, trade-off, and when it breaks. Lead with the direct answer; the rest is there for when the interviewer wants more."
  - id: m47-l01-c2
    front: "What happens when you append to an array inside `for item in array`?"
    back: "The loop keeps iterating the array as it was when the loop started: `for-in` iterates over a copy of the value (sharing its buffer until the append makes a copy). The appended element isn't visited."
  - id: m47-l01-c3
    front: How do you turn a hand-wavy claim into a precise one?
    back: "Find the word that hides a condition (always, faster, safe, basically) and name the condition: when, compared with what, under which isolation or input size."
  - id: m47-l01-c4
    front: "What are the three parts of a good \"I don't know\"?"
    back: "What you do know that's adjacent, a hypothesis you label as one, and how you'd check it (a documentation page, a Swift Evolution proposal, a ten-line experiment or a measurement)."
  - id: m47-l01-c5
    front: "Does `didSet` on an array property fire when you change one element?"
    back: "Yes. `songs[0] = \"x\"` modifies the whole `songs` value through its accessors, so `didSet` runs with the full old array in `oldValue`."
---

## The idea in one sentence

A strong technical answer gives the answer first and then earns it: the mechanism, a small example, what it costs and where it stops being true, each part short enough that the interviewer can stop you or push deeper.

> [!note] Where this module fits
> Module 46 was about coding problems. This module is about the spoken questions: "what's the difference between…", "what happens when…", "why would you…". The course already has a bank of 210 interview questions in the **Interviews** section, with model answers, key points and follow-ups, grouped into 14 categories. This module doesn't repeat them. It teaches how to answer, practices on new and deeper questions, and points to bank questions where they're the natural next step. Code in this module was compiled and run with Swift 6.3 on Linux; compiler messages are quoted from that run. Nothing here describes how any particular company interviews.

## Why answers go wrong

Most weak answers aren't wrong. They're shaped badly:

- **Background first.** The candidate starts with history ("so, back in Objective-C…") and the interviewer has to wait a minute to learn whether they know the answer.
- **Everything at once.** Every fact the candidate knows, in the order they remember it, with no point where the interviewer can steer.
- **Unfalsifiable claims.** "It's more efficient", "Swift handles it", "it's thread-safe". None of these can be checked, so none of them shows understanding.
- **Bluffing.** An invented API name or a confident wrong rule. Interviewers ask follow-ups precisely to find these, and one is usually enough to undo the rest of the answer.

A fixed shape fixes the first two, a habit of precision fixes the third, and a good way to say "I don't know" removes the temptation behind the fourth.

## The five-part answer

| Part | What it does | Typical length |
| --- | --- | --- |
| **Direct answer** | Answers the question as asked | One or two sentences |
| **Mechanism** | Says why it's true: the rule, the data structure, the runtime behavior | Two or three sentences |
| **Example** | Makes it concrete: a few lines of code, or a scenario from an app | A short snippet or one scenario |
| **Trade-off** | What it costs, and when you'd choose differently | One or two sentences |
| **When it breaks** | The edge where the rule stops holding, or the bug people write | One or two sentences |

Two habits make the shape work:

1. **Pause after the mechanism.** That's the natural point for the interviewer to say "good, next question" or "show me". Offering the example ("want me to sketch it?") is fine; reciting all five parts without looking up isn't.
2. **The last two parts are where seniority shows.** Anyone who read the documentation can give the direct answer. Knowing what it costs and where it breaks comes from having used it.

### A worked example

Here's a question that isn't in the bank: *"What happens if you append to an array while you're looping over it with `for-in`?"*

A weak answer: "I think that's not allowed, it would crash or loop forever. You should never modify a collection while iterating it."

It sounds careful, and it's wrong for Swift arrays. Here's the five-part version.

**Direct answer.** "The loop doesn't see the new element. It finishes iterating the array as it was when the loop started, and the append still happens to the variable."

**Mechanism.** "`for-in` calls `makeIterator()` on the array value, and the iterator holds its own copy of that value. Because `Array` is a value type with copy-on-write, the copy shares the buffer until the append; at that point the variable gets a new buffer and the iterator keeps the old one."

**Example.**

```swift
var numbers = [1, 2, 3]
for number in numbers {
    if number == 1 {
        numbers.append(4)
    }
    print(number)
}
print(numbers)
```

```output
1
2
3
[1, 2, 3, 4]
```

**Trade-off.** "It's safe, but the append inside the loop copies the whole buffer once, because the iterator still holds a reference to it. For a big array in a hot loop, collect the new elements in a separate array and append them after the loop."

**When it breaks.** "Index-based loops don't get this protection. `for index in array.indices` computes the range once, so removing elements inside the loop runs past the end."

```swift runtime-error Index out of range
var scores = [70, 40, 90, 30]
for index in scores.indices {
    print("checking", index)
    if scores[index] < 50 {
        scores.remove(at: index)
    }
}
print(scores)
```

```output
checking 0
checking 1
checking 2
checking 3
```

Index 1 removes 40, so the array becomes `[70, 90, 30]`; index 2 now holds 30, which is also removed; the array has two elements, and index 3 traps. (It also skipped 90, which slid into index 1 after it was checked.) The fix is `scores.removeAll { $0 < 50 }`, which does the filtering in one pass.

That answer takes about ninety seconds out loud. The direct answer and the mechanism alone take twenty, and if the interviewer moves on after those, you've lost nothing.

> [!tip] The bank question that goes deeper
> Copy-on-write itself is [How does copy-on-write work, and how would you add it to your own struct?](#/interviews/question/q-swift-copy-on-write). Lesson 2 goes further than that answer and counts the copies.

## Precision instead of hand-waving

Precision doesn't mean jargon. It means each sentence names the condition under which it's true, so it could be checked. A few rewrites, all on topics Modules 9 to 43 covered:

| Hand-waving | Precise |
| --- | --- |
| "Structs are copied every time." | "Assigning a struct gives you an independent value. Standard collections inside it share their buffer until one side mutates." |
| "Actors make it thread-safe." | "An actor runs one piece of its isolated code at a time, so its state can't have a data race. It's reentrant at every `await`, so a check before an `await` can be stale after it." |
| "`weak` prevents memory leaks." | "A `weak` reference doesn't keep the object alive and becomes `nil` when it's deallocated. It breaks a retain cycle only if it replaces one of the strong references in that cycle." |
| "`async` code runs in the background." | "`await` marks a point where the function may suspend. Where the code runs depends on its isolation: a `@MainActor` async function runs on the main actor." |
| "SwiftUI redraws the view." | "SwiftUI calls `body` again for views whose dependencies changed: state they read, observable properties they read in `body`, environment values they read, or new inputs from the parent." |
| "UserDefaults isn't secure." | "UserDefaults is a property list in the app's container, meant for preferences. Secrets belong in the Keychain, which is what MASVS-STORAGE-1 expects for sensitive data." |

Some words are signals that a condition is missing:

- **"Always", "never".** Usually true under a condition you didn't state. Say the condition.
- **"Faster", "more efficient".** Than what, for which input size, measured how? "O(1) instead of O(n) for lookups" is precise; "faster" isn't.
- **"Basically", "under the hood it just…".** Often the start of a simplification that's wrong in the detail the interviewer is about to ask.
- **"Thread-safe".** Safe from data races? From race conditions? Under which isolation? Module 28 separated the two, and they're different answers.

> [!error] Using the precise term for the wrong thing
> "A data race" and "a race condition" aren't synonyms, nor are "concurrent" and "parallel", or `weak` and `unowned`. Using the precise word wrongly is worse than using a plain word, because it invites the follow-up you can't answer. If you're not sure of the term, describe the behavior in plain words.

## When you don't know

You'll get questions you can't answer fully. Silence and bluffing both lose. A good "I don't know" has three parts:

1. **What you do know that's adjacent.** "I know `didSet` runs after any assignment to the property."
2. **A hypothesis, labeled.** "My guess is that changing one element counts as an assignment to the whole array, because arrays are values. I'm not certain."
3. **How you'd check.** "I'd write a five-line playground with a `didSet` that prints, or look at the Swift book's section on property observers."

Here's that experiment:

```swift
struct Playlist {
    var songs: [String] = ["Intro", "Theme"] {
        didSet { print("didSet: \(oldValue) -> \(songs)") }
    }
}

var playlist = Playlist()
playlist.songs[0] = "Overture"
playlist.songs.append("Outro")
```

```output
didSet: ["Intro", "Theme"] -> ["Overture", "Theme"]
didSet: ["Overture", "Theme"] -> ["Overture", "Theme", "Outro"]
```

The hypothesis holds: changing one element or calling a mutating method on the property runs `didSet`, with the entire previous array as `oldValue`. The Swift book's "Properties" chapter states the related rule for in-out: passing a property with observers as an in-out argument always calls `willSet` and `didSet`, because of the copy-in copy-out model.

In an interview you won't run code, but saying exactly which experiment would settle it is most of the value. In the job, run it. Five lines beat twenty minutes of guessing.

What not to do:

- **Don't invent names.** If you can't remember the exact API, describe what it does ("there's a modifier that ties a task's lifetime to the view and restarts it when an id changes") instead of guessing a signature.
- **Don't claim a version you're not sure of.** "Recent Swift" is honest; "Swift 5.4" when it was 5.7 is a fact the interviewer can check.
- **Don't apologize repeatedly.** Say it once, then switch to how you'd find out.

## Practicing with the bank

The bank's questions each have a model answer, key points (the rubric) and follow-ups. Use them like this:

1. Read only the question.
2. Answer out loud in the five parts. Time it.
3. Compare with the **key points**, not the wording. Every key point you missed is a gap; anything you added that the key points don't mention is fine if it's correct.
4. Answer the follow-ups before reading theirs.
5. Write the one sentence you'd change next time.

The simulator in the Interviews section runs this with a timer and keeps your results by category. Memorizing the model answers defeats the purpose: interviewers rephrase, and a memorized answer to a different question is easy to spot.

## Common mistakes

> [!error] The answer to a different question
> "What's the difference between `weak` and `unowned`?" answered with a tour of ARC. Repeat the question in your head and check that your first sentence answers it.

> [!error] An example that's bigger than the point
> A whole view controller to show one capture list. Pick the smallest example that shows the behavior, and say what it prints.

> [!error] No trade-off, or a fake one
> "There's no downside" is almost never true and is easy to challenge. If you can't think of a cost, say what you'd measure to find one.

> [!error] Correcting yourself silently
> If you notice a mistake mid-answer, say so: "Actually, I said X; it's Y, because…". Lesson 6 practices recovering from a wrong answer.

## Exercises

````exercise
id: m47-l01-e1
type: prediction
prompt: "A queue is extended inside its own `for-in` loop. What does the program print?"
code: |
  var queue = ["a", "b"]
  for item in queue {
      queue.append(item.uppercased())
      print(item, queue.count)
  }
  print(queue)
output: |
  a 3
  b 4
  ["a", "b", "A", "B"]
solution: |
  The loop iterates the array as it was when the loop started, `["a", "b"]`, so it runs twice. Each pass appends to the variable, so `queue.count` grows to 3 and then 4. The appended elements are never visited, so there's no infinite loop.

  ```output
  a 3
  b 4
  ["a", "b", "A", "B"]
  ```
````

````exercise
id: m47-l01-e2
type: comprehension
prompt: "An interviewer asks: \"What does `@discardableResult` do?\" Which opening is best?"
choices:
  - text: "\"So, Swift used to be closer to Objective-C, where ignoring return values was normal, and then the language changed…\""
    correct: false
    why: "Background first. The interviewer still doesn't know whether you know the answer."
  - text: "\"It silences the compiler's 'result of call is unused' warning for that function, so callers can ignore the return value. You'd put it on something like a method that returns the inserted element, where most callers don't need it.\""
    correct: true
    why: "Direct answer, mechanism (which warning) and an example of when it fits, in two sentences."
  - text: "\"It's an attribute. There are lots of attributes in Swift, like @escaping and @MainActor, and they change how the compiler treats a declaration.\""
    correct: false
    why: "True but it doesn't answer the question. It describes the category, not the attribute."
  - text: "\"It makes the function more efficient because the result doesn't have to be stored.\""
    correct: false
    why: "Wrong mechanism. It only affects a warning; the function computes and returns its result either way."
solution: |
  The second opening answers first, names the mechanism (the unused-result warning) and gives a real use. The others start with background, describe a category instead of the thing, or invent a performance effect. A good trade-off to add if asked: overusing it hides calls whose result really should be checked.
````

````exercise
id: m47-l01-e3
type: find-errors
prompt: "Here's a candidate's answer to \"Is it safe to read a `lazy var` from two threads?\" Which statements are problems?"
code: |
  "Lazy vars are basically thread-safe, because Swift
  handles initialization for you under the hood (1).
  The initializer runs the first time the property is
  read (2). Static stored properties are also
  initialized lazily, and Swift guarantees that
  happens only once even with several threads (3).
  So lazy is always the faster choice (4)."
choices:
  - text: "(1) \"basically thread-safe… Swift handles it\" is wrong: a lazy instance property has no synchronization, so two threads reading it the first time can both run the initializer."
    correct: true
    why: "Hand-waving that's also false. Swift doesn't synchronize lazy instance properties."
  - text: "(2) The initializer runs on first access: that's correct."
    correct: false
    why: "It's true, so it's not a problem."
  - text: "(3) Static stored properties are initialized lazily and only once, even when several threads access them: that's correct, and a useful contrast."
    correct: false
    why: "The Swift book documents this guarantee for stored type properties. It's the right contrast to make."
  - text: "(4) \"Always the faster choice\" is an unconditioned claim: lazy adds a check on every access and only pays off when the value is expensive and often unused."
    correct: true
    why: "No condition, no comparison. Lazy is a trade-off, not a speedup."
rubric:
  - Flags (1) as both hand-waving and false.
  - Flags (4) as an unconditioned performance claim.
  - Accepts (2) and (3) as correct.
solution: |
  (1) and (4) are the problems. The Swift book warns that if a lazy property is accessed by multiple threads at the same time and it hasn't been initialized yet, there's no guarantee it'll be initialized only once. Stored type properties are different: the book guarantees they're initialized only once, even when several threads access them at the same time. "Always faster" ignores that lazy has a per-access check and only helps when the value is costly and often not needed. The bank's question on lazy properties covers the rest.
````

````exercise
id: m47-l01-e4
type: solve
prompt: "You're asked: \"If a struct property has a `didSet`, does it fire when you call a `mutating` method on that struct?\" You suspect yes. Write the smallest experiment that settles it: a `Counter` struct with a `mutating func increment()`, held in a property with a `didSet` that prints the old and new value, and two calls."
starter: |
  struct Counter {
      var value = 0
      // add increment()
  }

  struct Screen {
      // a counter property with didSet
  }
rubric:
  - The experiment is small and self-contained.
  - It calls a mutating method through the observed property, not a plain assignment.
  - The output shows didSet running once per call, with old and new values.
  - The conclusion is stated in one sentence.
solution: |
  ```swift
  struct Counter {
      var value = 0
      mutating func increment() { value += 1 }
  }

  struct Screen {
      var counter = Counter() {
          didSet { print("didSet: \(oldValue.value) -> \(counter.value)") }
      }
  }

  var screen = Screen()
  screen.counter.increment()
  screen.counter.increment()
  ```

  ```output
  didSet: 0 -> 1
  didSet: 1 -> 2
  ```

  Yes: a mutating method on a value-type property modifies the whole property, so its observer runs once per call with the full previous value. The same experiment with a class instead of a struct prints nothing, because mutating the object doesn't change the reference stored in the property.
````

````exercise
id: m47-l01-e5
type: explain
prompt: "Rewrite each sentence so it names the condition that makes it true or false. Keep each to one or two sentences."
code: |
  1. "Dictionaries are fast."
  2. "Closures cause retain cycles."
  3. "@MainActor makes code run on the main thread."
rubric:
  - "1 mentions average O(1) lookup by hashing, and the condition (a good hash, no pathological collisions) or the contrast with a linear search."
  - "2 says a cycle needs the closure to be stored by the object (directly or through something it owns) and to capture that object strongly."
  - "3 says @MainActor isolates the declaration to the main actor, so the compiler requires callers from other isolation domains to await, and the code runs on the main actor's executor (the main thread)."
solution: |
  1. "Looking up a key in a `Dictionary` is O(1) on average, because it hashes the key to find its bucket. That depends on a reasonable `hash(into:)`; a hash that sends everything to one bucket degrades it toward O(n)."
  2. "A closure creates a retain cycle when an object stores it, directly or through something it owns, and the closure captures that object strongly. A closure that isn't stored, like `map`'s, can't."
  3. "`@MainActor` isolates the code to the main actor, whose executor is the main thread. The compiler enforces it: calls from other isolation domains need `await`, and synchronous access from them doesn't compile in Swift 6 mode."
````

````exercise
id: m47-l01-e6
type: design
prompt: "Prepare a five-part answer (direct answer, mechanism, example, trade-off, when it breaks) to: \"What does `String.count` cost, and why?\" Write each part in one or two sentences."
rubric:
  - "Direct answer: O(n) in the length of the string, not O(1)."
  - "Mechanism: count is the number of Characters (extended grapheme clusters), and finding their boundaries requires walking the string's contents."
  - "Example: an emoji with a skin-tone modifier, or a letter with a combining accent, is one Character made of several Unicode scalars."
  - "Trade-off: if you need a length repeatedly, compute it once; if you need byte length for a buffer or protocol, utf8.count is the right measure."
  - "When it breaks: calling count in a loop condition makes the loop O(n²); comparing count with UIKit's NSString-based length (UTF-16 units) gives different numbers."
solution: |
  - **Direct answer:** "`count` is O(n): it walks the string."
  - **Mechanism:** "It counts `Character`s, which are extended grapheme clusters. A cluster can span several Unicode scalars, so the only way to know where clusters end is to look at the contents. `String` isn't a random-access collection, and Apple's documentation lists `count` as O(n) for non-random-access collections."
  - **Example:** "`\"é\"` written as `e` plus a combining accent is one `Character` but two scalars; a family emoji is one `Character` made of several scalars joined by zero-width joiners."
  - **Trade-off:** "Grapheme-correct counting is what users expect from 'characters'. If you need the size for a network protocol or a buffer, use `utf8.count`, which is the encoded length."
  - **When it breaks:** "`while i < text.count` re-walks the string on every iteration, so the loop becomes O(n²). And `NSString.length` counts UTF-16 units, so a text field's limit computed one way and checked the other disagrees for emoji."

  The bank question on Strings and Unicode covers why you can't index with an `Int`; this answer is about the cost.
````

## Summary

- Answer in five parts: direct answer, mechanism, example, trade-off, when it breaks. Lead with the answer, pause after the mechanism, and let the interviewer steer.
- `for-in` over an array iterates a copy of the array as it was when the loop started; index-based loops that remove elements run off the end.
- Precision means naming the condition: compared with what, under which isolation, for which input. Words like "always", "faster", "basically" and "thread-safe" usually hide one.
- A good "I don't know" gives an adjacent fact, a labeled hypothesis and a concrete way to check. Changing one element of an array property runs its `didSet`, and a five-line experiment proves it.
- Practice with the bank by answering before reading, grading yourself against the key points and answering the follow-ups first.

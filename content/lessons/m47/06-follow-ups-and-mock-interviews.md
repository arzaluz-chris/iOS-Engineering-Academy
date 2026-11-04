---
id: m47-l06
title: Follow-ups and mock interviews
description: "Interviewers drill down until they find the edge of what you know. You learn the six kinds of follow-up and follow one chain on inout five levels deep, from copy-in copy-out to a runtime exclusivity trap. Then you practice recovering from a wrong answer, read a full mock technical interview (fictional, with commentary), and grade yourself with a rubric you can reuse with the course's interview simulator."
module: m47
order: 6
level: advanced
minutes: 75
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m47-l05]
objectives:
  - Recognize the six kinds of follow-up and prepare for them from the parts of an answer you left out.
  - Follow a drill-down chain several levels deep and back each level with evidence.
  - Recover from a wrong answer by naming it, correcting it and explaining why the first version was wrong.
  - Hold a correct answer under pushback without becoming defensive.
  - Grade a mock interview with a rubric and pick one thing to improve.
terms:
  - term: Drill-down
    definition: "A sequence of follow-ups on the same topic, each one deeper than the last, until the candidate reaches the limit of what they know."
  - term: Copy-in copy-out
    definition: "The semantics of inout: the argument's value is copied into the function, and the final value is written back when the function returns. The compiler may optimize it into passing an address, but the observable behavior is the write-back."
  - term: Exclusivity
    definition: "Swift's rule that a modification of a variable can't overlap with any other access to the same variable (SE-0176). Violations are compile errors when the compiler can see them and runtime traps otherwise."
  - term: Self-grading rubric
    definition: "A fixed list of criteria with level descriptions, used after a practice interview to score yourself consistently and choose what to work on."
mastery:
  - Predict the follow-ups an answer invites and prepare one level deeper than the answer itself.
  - Explain inout from basic behavior down to static and dynamic exclusivity enforcement, with a program for each level.
  - Recover from a wrong answer in under thirty seconds, in words that keep the interviewer's trust.
  - Score a practice answer on the rubric and write the one change you'll make next time.
resources: [se-0176-exclusivity, swift-book-functions, swift-book-properties, swift-evolution, swift-actor, swift-book-concurrency]
cards:
  - id: m47-l06-c1
    front: Name the six kinds of follow-up.
    back: "Why (the mechanism), what if (a changed constraint), what breaks (the edge), how would you verify it, what's the alternative (the trade-off), and show me (code or a concrete example)."
  - id: m47-l06-c2
    front: "A function does `value += 1` three times on an inout property that has a didSet. How many times does didSet run?"
    back: "Once, after the function returns: inout is copy-in copy-out, so the property is written back a single time with the final value."
  - id: m47-l06-c3
    front: When does Swift catch an exclusivity violation at compile time, and when at run time?
    back: "At compile time when it can see both accesses, such as passing the same local variable to two inout parameters. At run time for class properties, globals and escaping closures, where it inserts dynamic checks and traps with \"Simultaneous accesses…\"."
  - id: m47-l06-c4
    front: What are the steps of recovering from a wrong answer?
    back: "Notice it, say so plainly, give the correct version, explain why the first version was wrong, and continue. Don't hide it or over-apologize."
  - id: m47-l06-c5
    front: "The interviewer asks \"Are you sure?\" and you are. What do you do?"
    back: "Restate the claim with its evidence (the mechanism or the experiment that would show it), ask what they're thinking of, and stay open to a case you missed. Don't flip because of the question alone."
---

## The idea in one sentence

The first answer gets you into the conversation; the follow-ups are where the interviewer learns how deep your understanding goes, so prepare for them as deliberately as for the questions.

> [!note] About this lesson
> The drill-down programs were compiled and run with Swift 6.3 on Linux; diagnostics and runtime messages are quoted from those runs. The mock interview below is **fictional**: the people, the company and the conversation were written for this course to show technique, and nothing in it describes how a real company interviews.

## How interviewers drill down

Most follow-ups fall into six kinds. Each one probes a part of lesson 1's five-part answer:

| Follow-up | Sounds like | Probes |
| --- | --- | --- |
| **Why** | "Why does that happen?" | The mechanism |
| **What if** | "What if there are a million items? Two threads? iOS 16?" | Whether the answer generalizes |
| **What breaks** | "When doesn't that work?" | The limits |
| **Verify** | "How would you know? How would you test it?" | Whether you can produce evidence |
| **Alternative** | "Why not X instead?" | The trade-off |
| **Show me** | "Can you write it?" | Whether the understanding survives contact with code |

The practical consequence: **every part you leave out of an answer is a follow-up you've invited.** That's fine; a two-sentence answer that invites the right follow-up is a good answer. Prepare for it. When you study a topic, write the answer and then the next question for each of the six kinds.

## One chain, five levels deep

Here's a drill-down on a small topic, the way it can go in an interview. At each level, the answer and the evidence.

### Level 1: "What does inout do?"

"It lets a function modify a variable the caller passes with `&`. The change is visible to the caller after the call."

### Level 2: "So it's pass by reference?"

"Not semantically. The Swift book describes it as copy-in copy-out: the value is copied in when the function is called, the function modifies its copy, and the copy is written back when it returns. The compiler is allowed to optimize that into passing an address, but you can observe the write-back with a property observer."

```swift
struct Thermostat {
    var target = 20 {
        didSet { print("didSet: \(oldValue) -> \(target)") }
    }
}

func nudge(_ value: inout Int) {
    value += 1
    value += 1
    value += 1
    print("inside nudge: \(value)")
}

var thermostat = Thermostat()
nudge(&thermostat.target)
print("after: \(thermostat.target)")
```

```output
inside nudge: 23
didSet: 20 -> 23
after: 23
```

Three modifications, one `didSet`, after the function's last line. With pass by reference you'd expect an observer call per write.

### Level 3: "What if you pass the same variable twice?"

"That's an overlapping access, and Swift rejects it. Two `inout` parameters would both have write access to the same memory for the duration of the call."

```swift no-compile overlapping accesses to 'total', but modification requires exclusive access
func addBoth(_ first: inout Int, _ second: inout Int) {
    first += 1
    second += 1
}

var total = 0
addBoth(&total, &total)
```

Swift 6.3 reports two errors here: `inout arguments are not allowed to alias each other`, and `overlapping accesses to 'total', but modification requires exclusive access; consider copying to a local variable`.

### Level 4: "Is it always caught at compile time?"

"No. The compiler enforces it statically when it can see both accesses, like two arguments to one call on a local variable. For class properties, globals and variables captured by escaping closures, it can't always prove what overlaps, so it inserts runtime checks, and a violation traps."

```swift runtime-error but modification requires exclusive access
final class Counter {
    var value = 0
}

func increment(_ number: inout Int, then action: () -> Void) {
    number += 1
    action()
}

let counter = Counter()
print("start")
increment(&counter.value) {
    counter.value += 1
}
print(counter.value)
```

```output
start
```

The closure modifies `counter.value` while `increment` still holds write access to it through `number`. The program stops with `Simultaneous accesses to 0x…, but modification requires exclusive access.` and never reaches the last `print`.

### Level 5: "Why does Swift enforce this at all?"

"Memory safety and optimization. SE-0176, 'Enforce Exclusive Access to Memory', made it a rule so that a modification has the variable to itself: without it, code like level 4 would read a value that's halfway through being changed, and the compiler couldn't safely keep values in registers or avoid copies. It's the same idea the concurrency model extends across threads: one writer at a time."

Notice the shape: each level is short, and each claim has a program or a source behind it. When the chain reaches something you don't know, lesson 1's "I don't know" applies: what you know, a labeled guess, how you'd check.

## Recovering from a wrong answer

You will say something wrong. What matters is what happens next. Five steps:

1. **Notice.** Often the interviewer's follow-up is the hint ("and what does `didSet` print then?").
2. **Say so, plainly.** "Actually, I got that wrong."
3. **Correct it.** Give the right answer in one or two sentences.
4. **Explain why the first version was wrong.** This is what turns a mistake into a demonstration of understanding.
5. **Continue.** Don't keep apologizing, and don't let it shake the rest of the interview.

An example, from level 2 of the chain:

> **Candidate:** "inout passes a reference, so each `+= 1` writes straight to the property and `didSet` runs three times."
>
> **Interviewer:** "Let's say it runs. What does `oldValue` hold on the second call?"
>
> **Candidate:** "It would be 21… actually, wait. I said it's a reference, but that's not the model. It's copy-in copy-out: the function works on a copy and writes back once at the end, so `didSet` runs once, with 20 as the old value and 23 as the new one. I conflated it with what the optimizer is allowed to do."

Twelve seconds, and the interviewer now knows the candidate can find their own mistake, which is most of what debugging is.

### When you're right and they push back

Sometimes "are you sure?" is a test. Don't flip because of the question alone:

> "I'm fairly sure: the Swift book describes inout as copy-in copy-out, and a `didSet` on the property would show a single write-back. Is there a case you're thinking of where it behaves differently?"

That keeps your position, shows the evidence, and leaves room for a case you missed. If they show you one, go back to the recovery steps.

## A mock technical interview

> [!warning] Fictional transcript
> Everything in this section is invented for the course: the company, the interviewer ("Iris") and the candidate ("Sam"). It shows technique, including mistakes and recoveries. It doesn't describe any real company's process, questions or grading.

**Setting:** a 45-minute technical conversation for a mid-level iOS role. No coding environment; code is written in a shared document. The commentary after each part is the course's, not the interviewer's.

### Part 1: value semantics in a real screen

> **Iris:** A list screen has a view model with `var items: [Item]`, where `Item` is a struct. Tapping a row pushes a detail screen that receives the item and lets you edit its title. After editing and going back, the list shows the old title. Why?
>
> **Sam:** Because `Item` is a value type. The detail screen got a copy when it was created, so editing it changes the detail screen's copy and nothing writes it back to the array.
>
> **Iris:** How would you fix it?
>
> **Sam:** A few options. In SwiftUI I'd pass a binding into the array, like `$model.items[index]`, or better, pass the item's id and let the detail screen ask the model to update the item with that id, so the model stays the only owner. In UIKit it's the same idea with a closure or delegate that reports the edited item back, and the view model replaces it by id.
>
> **Iris:** Why "better"?
>
> **Sam:** An index can be stale: if the list changes while the detail is open, say a sync removes an earlier row, the index points at a different item. An id stays correct.
>
> **Iris:** What if `Item` were a class?
>
> **Sam:** Then the detail screen and the array would share the same instance, so the edit would be in the array immediately. But the list might still not update: the array itself didn't change, so anything observing the array doesn't see it. With Observation, `Item` would have to be `@Observable` and the row would have to read `title` in its body.

> [!note] Commentary
> Sam led with a direct answer and the mechanism. The fix came with a trade-off (binding versus id) without being asked, and the "why better" follow-up got a concrete failure case. The class follow-up is a classic "what if"; Sam's answer is correct and adds the observation subtlety from lesson 3, which is the kind of second-order detail that separates levels.

### Part 2: concurrency, with a wrong turn

> **Iris:** Is this safe in Swift 6?
>
> ```
> final class Counter {
>     var value = 0
>     func increment() { value += 1 }
> }
> // 1,000 child tasks in a task group each call counter.increment()
> ```
>
> **Sam:** Yes, it's a class, so all the tasks share one instance and the count ends at 1,000.
>
> **Iris:** Two tasks call `increment()` at the same moment. Walk me through `value += 1`.
>
> **Sam:** It reads `value`, adds one, writes it… right, I answered the wrong question. Sharing the instance is exactly the problem: two tasks can read 41 and both write 42. That's a data race. And in Swift 6 it doesn't compile, because `Counter` isn't `Sendable` and the child tasks would capture it while the parent can still use it.

Sam's claim about the compiler is right:

```swift no-compile closure captures 'counter' which is accessible to code in the current task
final class Counter {
    var value = 0
    func increment() { value += 1 }
}

func run() async -> Int {
    let counter = Counter()
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<1_000 {
            group.addTask { counter.increment() }
        }
    }
    return counter.value
}
```

> **Iris:** Fix it.
>
> **Sam:** Make it an actor. Each increment runs on the actor one at a time, and callers `await` it.

```swift
actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}

func run() async -> Int {
    let counter = Counter()
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<1_000 {
            group.addTask { await counter.increment() }
        }
    }
    return await counter.value
}

print(await run())
```

```output
1000
```

> **Iris:** Is the actor the best fix here?
>
> **Sam:** For a counter, probably not: each increment is an actor hop. If the tasks only need to report something, I'd have each child return its contribution and sum them in the parent, so there's no shared state at all. The actor is right when the state really has to be shared and long-lived.

> [!note] Commentary
> The first answer was wrong, and Sam's recovery followed the steps: noticed it from Iris's hint, said so, corrected it, explained why (read-modify-write from two tasks), and continued without dwelling on it. The answer to "is the actor the best fix?" recovered more ground than the mistake lost, because it showed Sam knows the alternative from lesson 4. A weaker recovery would have been to defend the first answer or to apologize for a minute.

### Part 3: SwiftUI identity

> **Iris:** A list of chores uses `ForEach(Array(chores.enumerated()), id: \.offset)`. Each row has a `@State` "expanded" flag. Expand the second row, delete the first, and now a different chore looks expanded. Why?
>
> **Sam:** Identity. The rows are identified by their position, so after deleting the first, the chore that was second is now at offset 0 and gets the identity, and the state, that belonged to the old first row. The expanded flag stayed with offset 1, which is now a different chore.
>
> **Iris:** Fix?
>
> **Sam:** Identify rows by a stable id from the data: make `Chore` `Identifiable` and use `ForEach(chores)`.

The buggy line, as a fragment:

```swift illustrative
ForEach(Array(chores.enumerated()), id: \.offset) { pair in ChoreRow(chore: pair.element) }
```

The fixed version:

```swift ios
import SwiftUI

struct Chore: Identifiable {
    let id: UUID
    var title: String
}

struct ChoreRow: View {
    let chore: Chore
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading) {
            Button(chore.title) { isExpanded.toggle() }
            if isExpanded {
                Text("Details for \(chore.title)")
            }
        }
    }
}

struct ChoreList: View {
    @State private var chores = [
        Chore(id: UUID(), title: "Dishes"),
        Chore(id: UUID(), title: "Laundry")
    ]

    var body: some View {
        List {
            ForEach(chores) { chore in
                ChoreRow(chore: chore)
            }
            .onDelete { offsets in
                chores.remove(atOffsets: offsets)
            }
        }
    }
}
```

> **Iris:** Where should the `UUID()` come from?
>
> **Sam:** From when the chore is created or loaded, and stored. Not generated in `body`, or every update makes new identities and resets all the state.

> [!note] Commentary
> Short, correct and mechanism-first. Sam could have added the trade-off (keeping expansion state in the model instead of the row, so it survives the row leaving the screen), but the interviewer moved on, which is a sign the answer was enough. The bank's identity question and Module 36, lesson 5 cover the rest.

### Part 4: a security question with a gap

> **Iris:** In debug builds the app prints every network response to the console. Any problem?
>
> **Sam:** If it's only in debug builds, the risk is smaller, but responses can contain tokens and personal data, and debug builds end up on testers' devices. I'd use `Logger` with the dynamic values marked private, which is the default for interpolated strings in the unified logging system, and never log the authorization header or tokens at all. That's MASVS-STORAGE-2, preventing leakage.
>
> **Iris:** How would you make sure nobody adds a log like that later?
>
> **Sam:** I'm not sure there's a lint rule built into Xcode for it. I'd look at whether our linter can flag `print` of response bodies, wrap logging in our own function that redacts known fields, and add a test with a spy logger like the analytics one, checking a token never appears. I'd also check the MASTG tests for sensitive data in logs to see what a reviewer would look for.

> [!note] Commentary
> The answer named the control and a mechanism. On the follow-up Sam didn't know an exact tool and said so, then gave three concrete ways to find out or enforce it, which is lesson 1's "I don't know" done well. One imprecision: "the default for interpolated strings" is true for dynamic strings and objects in `Logger` messages, but integers, floating-point values and Booleans aren't redacted by default, so an account number stored as an `Int` would appear in the log. A stronger answer says "dynamic strings are private by default; mark everything sensitive explicitly, numbers included" (Module 42, lesson 5).

### Debrief

Iris's questions were each followed by one to three follow-ups, and each part reached a "what if" or an "alternative". Sam's strongest moments were the recovery in part 2 and the honest gap in part 4. On the rubric below, this transcript scores well on directness, mechanism and recovery, and loses points on precision in part 4.

## A self-grading rubric

Use this after every practice session, including the simulator in the Interviews section. Score each row 0, 1 or 2.

| Criterion | 0 | 1 | 2 |
| --- | --- | --- | --- |
| **Correctness** | A wrong claim that stood | Minor errors, corrected when probed | Correct, or corrected unprompted |
| **Directness** | The answer came after a minute of background | The answer was in there, but late | First sentence answered the question |
| **Mechanism** | No "why" | A plausible but vague why | The actual rule or runtime behavior |
| **Evidence** | No example | A generic example | A small, specific example or experiment, with its result |
| **Trade-off and limits** | None | One, when asked | Offered at least one cost or edge without being asked |
| **Precision** | Unconditioned words (always, faster, safe) | Mostly precise | Every claim names its condition |
| **Follow-ups** | Stuck after the first answer | Handled one level | Handled two or more levels, or reached "I don't know, here's how I'd check" cleanly |
| **Recovery and honesty** | Bluffed, or hid a mistake | Corrected with a long apology | Named the mistake, fixed it, explained it, moved on |

How to use it:

- **Record yourself** (audio is enough) and score from the recording, not from memory.
- **Total out of 16** is less useful than the lowest row. Pick that row and change one habit for the next session.
- **Track the same rows over time.** The simulator keeps your results by category; add your rubric notes to the course's notes feature so you can see the trend.

## Common mistakes

> [!error] Answering the follow-up you expected
> The interviewer asked "what if two threads?", and you answer "what if a million items?" because you prepared that one. Listen to which of the six kinds you were asked.

> [!error] Flipping under pushback
> Changing a correct answer because the interviewer asked "are you sure?" tells them your answers aren't grounded. Restate the evidence and ask what case they have in mind.

> [!error] A recovery that turns into a lecture
> Correct the mistake in a sentence or two and continue. Re-explaining the whole topic to prove you know it uses time the interviewer wanted for the next question.

> [!error] Practicing only first answers
> If your notes have answers but no follow-ups, you're preparing for the easy half. For each topic, write one follow-up of each kind.

## Exercises

````exercise
id: m47-l06-e1
type: prediction
prompt: "A function adjusts an inout property several times, then the caller changes it with `+= 0`. What does the program print?"
code: |
  struct Volume {
      var level = 5 {
          didSet { print("didSet \(oldValue) -> \(level)") }
      }
  }

  func adjust(_ value: inout Int, by steps: [Int]) {
      for step in steps {
          value += step
      }
      print("adjusted to \(value)")
  }

  var volume = Volume()
  adjust(&volume.level, by: [2, -1, 3])
  volume.level += 0
output: |
  adjusted to 9
  didSet 5 -> 9
  didSet 9 -> 9
solution: |
  Inside `adjust`, the three changes happen to the copied-in value; the `print` runs before the write-back. When the function returns, the final value 9 is written to `volume.level` once, so `didSet` runs once with `oldValue` 5. Then `+= 0` is a write too: property observers run on every assignment, even when the value doesn't change.

  ```output
  adjusted to 9
  didSet 5 -> 9
  didSet 9 -> 9
  ```
````

````exercise
id: m47-l06-e2
type: comprehension
prompt: "You've just said that `Task.detached { }` doesn't inherit the current actor. The interviewer asks, \"Are you sure about that?\" You are. What's the best response?"
choices:
  - text: "\"Sorry, you're right, it probably does inherit it.\""
    correct: false
    why: "Flipping because of the question alone. It tells the interviewer your answers aren't grounded."
  - text: "\"Yes. It's documented.\""
    correct: false
    why: "Correct but unhelpful: no evidence, and it closes the conversation."
  - text: "\"Yes: detached tasks don't inherit the actor, priority or task-local values; that's the difference from Task { }. If I printed #isolation inside one started from the main actor, it would be nil. Is there a case you're thinking of?\""
    correct: true
    why: "Restates the claim with the mechanism and a way to check it, and stays open to a case you missed."
  - text: "\"I read it in a blog post, so I'm pretty sure.\""
    correct: false
    why: "Weak evidence, and not the kind you can check in the room."
solution: |
  Hold a correct position with evidence and an invitation. The third answer does all three: the rule (detached tasks inherit nothing from the current context), a concrete experiment (`#isolation` would be `nil`) and a question that lets the interviewer show a case if they have one.
````

````exercise
id: m47-l06-e3
type: find-errors
prompt: "A candidate recovers from a wrong answer about `weak`. Which parts of the recovery are problems?"
code: |
  Interviewer: "So what happens to a weak reference when the
  object is deallocated?"
  Candidate: "It keeps pointing at the old memory (1)... hmm.
  I'm so sorry, I'm really nervous, I usually know this, I've
  used weak references in every project, sorry (2). Okay. It
  becomes nil automatically when the object is deallocated (3),
  because the runtime zeroes weak references, which is why weak
  must be an optional var (4). So, to recap ARC from the start:
  every object has a reference count, strong references
  increment it, and... (5)"
choices:
  - text: "(1) The initial wrong answer is a problem in itself."
    correct: false
    why: "Mistakes happen. What matters is the recovery that follows."
  - text: "(2) The long apology and self-justification take time and add nothing."
    correct: true
    why: "Say \"I got that wrong\" once and correct it."
  - text: "(3) The correction is right and stated plainly."
    correct: false
    why: "That's the correct behavior."
  - text: "(4) Explaining why weak must be an optional var shows the mechanism behind the correction."
    correct: false
    why: "Good: it explains why the first answer was wrong."
  - text: "(5) Re-explaining ARC from the beginning turns the recovery into a lecture."
    correct: true
    why: "The interviewer didn't ask for it. Continue with the conversation instead."
rubric:
  - Flags the apology (2) and the unprompted lecture (5).
  - Recognizes that (3) and (4) are the right parts of a recovery.
  - Doesn't penalize the original mistake on its own.
solution: |
  (2) and (5) are the problems. A good version: "It keeps pointing… actually no, I got that wrong. A weak reference becomes nil when the object is deallocated; the runtime zeroes it, which is why weak references have to be optional variables." Then stop and let the interviewer continue.
````

````exercise
id: m47-l06-e4
type: solve
prompt: "Level 4's program traps because the closure modifies `counter.value` while `increment` holds write access to it. Change the API of `increment` so the caller can still do a second increment inside the action, without violating exclusivity, and print the final value."
starter: |
  final class Counter {
      var value = 0
  }

  func increment(_ number: inout Int, then action: () -> Void) {
      number += 1
      action()
  }
rubric:
  - The action no longer reaches the same storage through another path while the inout access is active.
  - "One clean approach: pass the inout value to the action (action: (inout Int) -> Void)."
  - The program runs to completion and prints 2.
  - The explanation says why the original trapped and why the new version doesn't.
solution: |
  ```swift
  final class Counter {
      var value = 0
  }

  func increment(_ number: inout Int, then action: (inout Int) -> Void) {
      number += 1
      action(&number)
  }

  let counter = Counter()
  increment(&counter.value) { value in
      value += 1
  }
  print(counter.value)
  ```

  ```output
  2
  ```

  In the original, two accesses overlapped: `increment`'s inout access to `counter.value`, and the closure's own modification of `counter.value` through the class reference. Here the closure modifies the value it's handed, which is the same inout access passed along, so there's only ever one writer. Another fix is to run the action after `increment` returns, if the API allows it.
````

````exercise
id: m47-l06-e5
type: explain
prompt: "An interviewer asks: \"Why did the compiler reject `addBoth(&total, &total)`, but let the class-property version compile and then crash?\" Explain the difference in a few sentences."
code: |
  // Rejected at compile time:
  addBoth(&total, &total)

  // Compiles, traps at run time:
  increment(&counter.value) {
      counter.value += 1
  }
rubric:
  - "Static enforcement: for a local variable passed twice in the same call, the compiler can see both accesses."
  - "Dynamic enforcement: for a class property reached through a reference (and for globals and escaping captures), the compiler can't prove whether two accesses overlap, so it inserts runtime checks."
  - "Names the rule (exclusive access to memory, SE-0176) and what the trap message says."
  - "Notes that the runtime check means the program stops instead of reading a value mid-modification."
solution: |
  Both break the same rule: a modification needs exclusive access to the variable for its whole duration (SE-0176). In `addBoth(&total, &total)` both accesses are to a local variable within one call, so the compiler sees the overlap and refuses to compile. In the class version, the two accesses reach `counter.value` through a reference, one via the `inout` argument and one via the closure, and in general the compiler can't prove whether two references point to the same object. So Swift checks at run time, tracking active accesses, and traps with "Simultaneous accesses to …, but modification requires exclusive access." That's a deliberate crash instead of letting the closure read or write a value that's in the middle of being modified.
````

````exercise
id: m47-l06-e6
type: design
prompt: "Plan and run a 30-minute mock interview for yourself using the course's interview bank. Choose three questions from different categories, write two follow-ups of different kinds for each before reading the bank's, answer out loud while recording, then grade yourself with the rubric. Write down your scores, the lowest row, and the one habit you'll change."
rubric:
  - Three questions from three different categories of the bank.
  - Six follow-ups written in advance, covering at least four of the six kinds.
  - Answers were recorded and graded from the recording, not from memory.
  - All eight rubric rows scored, with one sentence of evidence for each score.
  - The lowest-scoring row is identified, with one specific change for next time.
solution: |
  An example plan:

  - **Questions:** one from swift (copy-on-write), one from concurrency (cancellation), one from security (storing a session token).
  - **Follow-ups, written first:** for copy-on-write, "what if the struct holds a class?" (what if) and "how would you prove when the copy happens?" (verify); for cancellation, "what happens to a `Task { }` started inside?" (what breaks) and "show me a loop that respects it" (show me); for the token, "why not UserDefaults?" (alternative) and "who enforces the expiry?" (why).
  - **Run:** a 10-minute block per question, answered aloud and recorded. Then compare with the bank's key points and follow-ups.
  - **Grade:** each rubric row with a sentence ("Evidence: 1, I described COW but didn't mention a way to observe it").
  - **Change:** for the lowest row, one habit, such as "say what the example prints" or "end with one limit".

  Repeat weekly with new questions, and keep the scores so you can see which rows improve.
````

## Summary

- Follow-ups come in six kinds: why, what if, what breaks, verify, alternative, show me. Each part you leave out of an answer invites one; prepare one level deeper than the answer.
- A drill-down chain should have evidence at every level. For `inout`: copy-in copy-out (one `didSet` after the function returns), aliasing two inout arguments is a compile error, overlapping access through a class property is a runtime trap, and SE-0176 is why.
- Recover from a wrong answer by noticing, saying so, correcting, explaining why the first version was wrong, and continuing. Under pushback when you're right, restate the evidence and ask what case they have in mind.
- The fictional mock interview shows the techniques together: mechanism-first answers, an honest "I don't know" with ways to find out, and a recovery that gained more than the mistake cost.
- Grade every practice session with the eight-row rubric, from a recording, and work on the lowest row.

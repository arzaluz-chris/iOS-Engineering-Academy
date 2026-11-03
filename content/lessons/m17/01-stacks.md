---
id: m17-l01
title: Stacks
description: You build a generic Stack on top of Array, check that push, pop and peek are O(1) because they all happen at the array's end, and use stacks for the jobs they're made for, such as undo and redo, matching opening and closing tags, and evaluating postfix expressions.
module: m17
order: 1
level: intermediate
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m16-l06]
objectives:
  - Define a stack by its rule (last in, first out) and its three operations.
  - Write a generic Stack struct on top of Array and give the cost of each operation.
  - Explain why the top of the stack has to be the end of the array, not the start.
  - Recognize problems where the most recent unfinished item is the one that matters next.
  - Use a stack to match nested tags, implement undo and redo, and evaluate a postfix expression.
terms:
  - term: Stack
    definition: A collection where you only add and remove at one end, the top. The last element pushed is the first one popped (LIFO).
  - term: LIFO
    definition: Last in, first out. The order in which a stack hands elements back.
  - term: Push
    definition: Add an element on top of the stack.
  - term: Pop
    definition: Remove the top element and return it. On an empty stack there's nothing to return, so a safe pop returns an optional.
  - term: Peek
    definition: Read the top element without removing it.
  - term: Postfix notation
    definition: "Writing an operator after its operands: 3 4 + instead of 3 + 4. It needs no parentheses and can be evaluated left to right with one stack."
mastery:
  - Implement Stack<Element> with push, pop, peek, isEmpty and count, and state that each is O(1) (push amortized).
  - Explain why popLast() is O(1) and removeFirst() isn't, and which end is the top.
  - Trace a sequence of pushes and pops and write down what each pop returns.
  - Match nested opening and closing tags with a stack, including the two checks people forget.
  - Design undo and redo with two stacks and explain why a new edit clears the redo stack.
resources: [swift-array, swift-book-generics, swift-book-structures-classes, swift-optional]
cards:
  - id: m17-l01-c1
    front: What does LIFO mean, and which structure follows it?
    back: Last in, first out. A stack. The element you pushed most recently is the first one pop returns.
  - id: m17-l01-c2
    front: Why is the top of an Array-backed stack the end of the array?
    back: "append and popLast() work at the end: append is O(1) on average and popLast() is O(1). Inserting or removing at index 0 shifts every other element, which is O(n)."
  - id: m17-l01-c3
    front: Why should pop() return an optional instead of crashing?
    back: "An empty stack has nothing to pop. Array's removeLast() stops the program on an empty array; popLast() returns nil, so the caller decides what an empty stack means."
  - id: m17-l01-c4
    front: When matching nested opening and closing tags with a stack, what are the two checks besides comparing names?
    back: A closing tag that arrives when the stack is empty is an error, and anything left on the stack at the end is an unclosed tag.
  - id: m17-l01-c5
    front: In undo and redo with two stacks, what happens to the redo stack when the user makes a new edit?
    back: It's cleared. Redo only makes sense for edits that were undone from the current state; a new edit starts a different history.
---

## The idea in one sentence

A stack only lets you touch its **most recent** element, and that restriction is exactly what you want whenever the last unfinished thing is the next thing to handle.

## What a stack is

A **stack** is a collection with one open end, called the **top**. You can do three things:

- **push**: put an element on top.
- **pop**: take the top element off and get it back.
- **peek**: look at the top element without taking it.

The order is **LIFO**, last in, first out. A stack of plates works this way: you put a clean plate on top and you take the top one. Unlike plates, a stack in code never lets you reach under the top, not even to look.

You've already used one without building it. In Module 15, every recursive call got a frame on the **call stack**, and returning popped it. The function that started last finishes first.

## A generic Stack on top of Array

Array already has everything a stack needs at its end: `append(_:)` adds there, `popLast()` removes from there, and `last` reads there. A `Stack` type wraps an array and exposes only those operations:

```swift
struct Stack<Element> {
    private var items: [Element] = []

    var isEmpty: Bool { items.isEmpty }
    var count: Int { items.count }
    var top: Element? { items.last }

    mutating func push(_ element: Element) {
        items.append(element)
    }

    @discardableResult
    mutating func pop() -> Element? {
        items.popLast()
    }
}

var history = Stack<String>()
history.push("Inbox")
history.push("Thread")
history.push("Attachment")
print(history.count, history.top ?? "none")
print(history.pop() ?? "none")
print(history.pop() ?? "none")
print(history.count, history.top ?? "none")
history.pop()
print(history.isEmpty, history.pop() ?? "none")
```

```output
3 Attachment
Attachment
Thread
1 Inbox
true none
```

Line by line:

1. `Stack<Element>` is generic (Module 11), so the same type holds strings, integers or your own structs.
2. `items` is `private`. Code outside the type can't insert in the middle or read the bottom element, so the LIFO rule can't be broken by accident.
3. `top` is the **peek** operation. It returns `items.last`, which is `nil` for an empty stack.
4. `push` appends. `pop` calls `popLast()`, which returns the removed element, or `nil` if the array is empty.
5. `@discardableResult` lets you call `pop()` just to drop the top, as the third-from-last line does, without a warning about an unused result.
6. `mutating` is needed because `Stack` is a struct: pushing and popping change its stored array.

Because `Stack` is a struct holding an Array, it has **value semantics**. Assigning it to another variable gives you an independent stack (copy-on-write makes that copy lazy, as you saw in Module 15).

> [!note] Why not just use an Array?
> You could, and in a short function many people do. The wrapper earns its place when the stack is a property that lives a long time or is shared across a type: the name says what it's for, and `private` stops anyone from calling `insert(_:at:)` or `removeFirst()` on it.

## What each operation costs

| Operation | Implemented with | Cost |
| --- | --- | --- |
| push | `append(_:)` | O(1) on average over many calls (amortized) |
| pop | `popLast()` | O(1) |
| peek | `last` | O(1) |
| isEmpty, count | `isEmpty`, `count` | O(1) |

Apple's documentation lists `popLast()` as O(1) and `append(_:)` as "O(1) on average, over many calls". The "on average" is the amortized cost from Module 15: an occasional append reallocates the array and copies everything, but those copies get rarer as the array grows. Space is O(n) for n elements.

The whole design depends on the top being the **end** of the array. Put the top at index 0 and every push becomes `insert(_:at: 0)` and every pop becomes `removeFirst()`. Both shift every other element, O(n). Same behavior, a much slower stack.

## When to think "stack"

The signal is **nesting** or **going back**: the thing you need next is the most recent one that isn't finished.

- **Undo**: the edit to undo is the most recent one.
- **Matching**: a closing tag must close the most recently opened tag that's still open.
- **Evaluation**: an operator applies to the most recent values computed.
- **Navigation**: the Back button returns to the screen you came from. A navigation stack in UIKit or SwiftUI is named after this.
- **Depth-first exploration**: go as deep as possible, then back up to the most recent branch point. That's what recursion does with the call stack, and you'll replace recursion with an explicit stack in the graph modules.

The [Valid Parentheses](#/challenge/valid-parentheses) challenge is a stack problem too. The examples below are different, so that one is still yours to solve.

## Example: undo and redo

A text editor keeps every edit on an **undo stack**. Undo pops the most recent edit and pushes it onto a **redo stack**. Redo does the reverse. A new edit clears the redo stack, because the edits you undid no longer follow from the current text.

```swift
struct Stack<Element> {
    private var items: [Element] = []
    var isEmpty: Bool { items.isEmpty }
    mutating func push(_ element: Element) { items.append(element) }
    mutating func pop() -> Element? { items.popLast() }
    mutating func removeAll() { items.removeAll() }
}

struct Editor {
    private(set) var text = ""
    private var undoStack = Stack<String>()
    private var redoStack = Stack<String>()

    mutating func type(_ newText: String) {
        undoStack.push(text)
        redoStack.removeAll()
        text += newText
    }

    mutating func undo() {
        guard let previous = undoStack.pop() else { return }
        redoStack.push(text)
        text = previous
    }

    mutating func redo() {
        guard let next = redoStack.pop() else { return }
        undoStack.push(text)
        text = next
    }
}

var editor = Editor()
editor.type("Hello")
editor.type(", world")
editor.type("!")
print(editor.text)
editor.undo()
editor.undo()
print(editor.text)
editor.redo()
print(editor.text)
editor.type("?")
editor.redo()
print(editor.text)
```

```output
Hello, world!
Hello
Hello, world
Hello, world?
```

1. Each stack stores **snapshots** of the text before a change. That's the simplest design; a real editor stores the edit itself (what was inserted where) to save memory.
2. `type` pushes the current text, clears the redo stack, then changes the text.
3. `undo` pops the previous snapshot. If there's none, `guard let` returns early: undo on an empty history does nothing.
4. Before replacing the text, `undo` pushes the current text onto the redo stack, so redo can bring it back.
5. After the new edit `"?"`, the redo stack is empty, so the last `redo()` does nothing.

Every operation is O(1) stack work plus the cost of building the strings. Apple's `UndoManager` keeps its own undo and redo stacks in the same shape.

## Example: matching nested tags

A chat app lets people format messages with simple tags: `<b>bold</b>`, `<i>italic</i>`, nested like `<b><i>both</i></b>`. Before rendering, you check that the tags nest properly. To keep the focus on the stack, the message arrives already split into tokens.

The rule: a closing tag must close the **most recently opened** tag that's still open. That's a stack.

```swift
enum Token {
    case open(String)
    case close(String)
    case text(String)
}

func tagsAreBalanced(_ tokens: [Token]) -> Bool {
    var openTags: [String] = []
    for token in tokens {
        switch token {
        case .open(let name):
            openTags.append(name)
        case .close(let name):
            guard let last = openTags.popLast(), last == name else {
                return false
            }
        case .text:
            continue
        }
    }
    return openTags.isEmpty
}

let nested: [Token] = [.open("b"), .open("i"), .text("both"), .close("i"), .close("b")]
let crossed: [Token] = [.open("b"), .open("i"), .text("oops"), .close("b"), .close("i")]
let unclosed: [Token] = [.open("b"), .text("bold")]
let strayClose: [Token] = [.text("hi"), .close("b")]
print(tagsAreBalanced(nested))
print(tagsAreBalanced(crossed))
print(tagsAreBalanced(unclosed))
print(tagsAreBalanced(strayClose))
print(tagsAreBalanced([]))
```

```output
true
false
false
false
true
```

1. A plain array works as the stack here: inside one short function, `append` and `popLast()` are clear enough.
2. An opening tag is pushed. Text is ignored.
3. A closing tag pops the most recent open tag. `guard let last = openTags.popLast(), last == name` handles **two** failures in one line: the stack was empty (a closing tag with nothing open), or the names differ (crossed tags).
4. After the loop, a non-empty stack means some tag was never closed.

Counting isn't enough: `crossed` has one open and one close of each tag, and it's still wrong. Only the order tells you, and the stack keeps the order. **O(n) time and O(n) space** in the worst case, when every tag is an opening tag.

## Example: evaluating a postfix expression

In **postfix notation**, the operator comes after its operands: `3 4 +` means 3 + 4, and `5 1 2 + 4 * + 3 -` means 5 + (1 + 2) × 4 − 3. There are no parentheses, and one stack is enough to evaluate it: numbers are pushed, and an operator pops two values and pushes the result. HP calculators made it famous as RPN (reverse Polish notation), and expression evaluators often convert ordinary infix expressions to postfix before evaluating them.

```swift
enum EvaluationError: Error {
    case notEnoughOperands
    case unknownToken(String)
    case leftoverValues
}

func evaluatePostfix(_ expression: String) throws -> Int {
    var values: [Int] = []
    for token in expression.split(separator: " ") {
        if let number = Int(token) {
            values.append(number)
            continue
        }
        guard let right = values.popLast(), let left = values.popLast() else {
            throw EvaluationError.notEnoughOperands
        }
        switch token {
        case "+": values.append(left + right)
        case "-": values.append(left - right)
        case "*": values.append(left * right)
        default: throw EvaluationError.unknownToken(String(token))
        }
    }
    guard values.count == 1, let result = values.last else {
        throw EvaluationError.leftoverValues
    }
    return result
}

for expression in ["3 4 +", "5 1 2 + 4 * + 3 -", "2 +", "1 2"] {
    do {
        print(expression, "=", try evaluatePostfix(expression))
    } catch {
        print(expression, "->", error)
    }
}
```

```output
3 4 + = 7
5 1 2 + 4 * + 3 - = 14
2 + -> notEnoughOperands
1 2 -> leftoverValues
```

1. `split(separator: " ")` gives the tokens. `Int(token)` succeeds for numbers.
2. For an operator, the **first** value popped is the right operand. For `-` that matters: `5 3 -` is 5 − 3, so `left` must be the one pushed earlier.
3. The `guard` turns a stack that runs dry into an error instead of a crash.
4. A valid expression leaves exactly one value on the stack.

Trace `5 1 2 + 4 * + 3 -`, writing the stack bottom to top:

| Token | Stack after |
| --- | --- |
| 5, 1, 2 | 5 1 2 |
| + | 5 3 |
| 4 | 5 3 4 |
| * | 5 12 |
| + | 17 |
| 3 | 17 3 |
| - | 14 |

Each token is pushed or causes two pops and one push: **O(n)** for n tokens.

## Common mistakes

> [!error] Fatal error: Can't remove last element from an empty collection
> `removeLast()` stops the program when the array is empty. In a stack, an empty pop usually means bad input (a closing tag with nothing open), not a programming error, so use `popLast()` and handle `nil`.

```swift runtime-error Can't remove last element from an empty collection
var undoStack: [String] = []
print("Undo pressed")
let previous = undoStack.removeLast()
print(previous)
```

```output
Undo pressed
```

> [!error] Using the front of the array as the top
> `insert(_:at: 0)` and `removeFirst()` produce the same LIFO behavior, at O(n) per operation. Over n operations that's O(n²). The top is the end.

> [!error] Forgetting to check the stack at the end
> In a matching problem, a loop that finishes without errors isn't enough: `<b>bold` has no wrong closing tag, only a missing one. Return `stack.isEmpty`, not `true`.

> [!error] Popping operands in the wrong order
> The first pop is the most recent value, which is the **right** operand. Subtraction and division give wrong answers if you swap them; addition and multiplication hide the bug.

> [!error] Using pop when you meant peek
> Calling `pop()` just to look at the top removes it. If you only need to read it, use `top` (or `last`).

> [!warning] warning: result of call to 'popLast()' is unused
> `popLast()` isn't marked `@discardableResult`, so calling it only to drop the top gets a warning in Swift 6.3. Write `_ = stack.popLast()` to say the value is thrown away on purpose. The `Stack` type above marks its own `pop()` with `@discardableResult` for this reason.

```swift warning result of call to 'popLast()' is unused
var breadcrumbs = ["Home", "Settings", "Privacy"]
breadcrumbs.popLast()
print(breadcrumbs)
```

```output
["Home", "Settings"]
```

## Exercises

````exercise
id: m17-l01-e1
type: comprehension
prompt: Which of these features needs a stack (LIFO) rather than some other order?
choices:
  - text: A Back button that returns to the previous screen, then the one before it
    correct: true
    why: The screen to return to is always the most recently visited one that's still in the history. That's LIFO.
  - text: A print queue where documents print in the order they were sent
    correct: false
    why: The first document sent prints first. That's first in, first out, a queue (next lesson).
  - text: A leaderboard that always shows the highest score
    correct: false
    why: The order depends on the score, not on when it arrived. That's a sorted structure or a priority queue.
  - text: A cache that looks up user profiles by ID
    correct: false
    why: Lookup by key is a dictionary's job. Order doesn't matter.
solution: |
  **The Back button.** Navigation history is a stack: visiting a screen pushes it, Back pops it, and the screen you return to is the most recent one still in the history. The print queue is FIFO, the leaderboard is ordered by value, and the profile cache is keyed lookup. The signal for a stack is "the most recent unfinished thing comes next".
````

````exercise
id: m17-l01-e2
type: prediction
prompt: Predict the exact output.
code: |
  var stack: [Int] = []
  for value in [4, 7, 1] {
      stack.append(value)
  }
  print(stack.popLast() ?? -1)
  stack.append(9)
  print(stack.last ?? -1, stack.count)
  while let top = stack.popLast() {
      print(top, terminator: " ")
  }
  print()
  print(stack.popLast() ?? -1)
output: |
  1
  9 3
  9 7 4 
  -1
hints:
  - The end of the array is the top. After the loop, the stack is [4, 7, 1].
  - last reads the top without removing it.
  - while let keeps popping until popLast() returns nil.
solution: |
  ```output
  1
  9 3
  9 7 4 
  -1
  ```

  After the loop the stack is `[4, 7, 1]`, with 1 on top, so the first pop returns 1. Pushing 9 gives `[4, 7, 9]`: `last` peeks at 9 and `count` is 3. The `while let` loop pops 9, 7 and 4, in the reverse of the order they went in, each followed by a space (so there's a trailing space before the newline from `print()`). The stack is now empty, `popLast()` returns `nil`, and `?? -1` prints -1.
````

````exercise
id: m17-l01-e3
type: fill-in
prompt: Complete this generic stack so the program prints `Optional(3) Optional(2) 1`.
code: |
  struct Stack<Element> {
      private var items: [Element] = []
      var count: Int { items.count }
      var top: Element? { items.[[1]] }

      mutating func push(_ element: Element) {
          items.[[2]](element)
      }

      mutating func pop() -> Element? {
          items.[[3]]()
      }
  }

  var stack = Stack<Int>()
  stack.push(1)
  stack.push(2)
  stack.push(3)
  let first = stack.pop()
  print(first as Any, stack.top as Any, stack.count - 1)
blanks:
  - id: "1"
    answers: ["last"]
  - id: "2"
    answers: ["append"]
  - id: "3"
    answers: ["popLast"]
solution: |
  ```swift
  struct Stack<Element> {
      private var items: [Element] = []
      var count: Int { items.count }
      var top: Element? { items.last }

      mutating func push(_ element: Element) {
          items.append(element)
      }

      mutating func pop() -> Element? {
          items.popLast()
      }
  }

  var stack = Stack<Int>()
  stack.push(1)
  stack.push(2)
  stack.push(3)
  let first = stack.pop()
  print(first as Any, stack.top as Any, stack.count - 1)
  ```

  ```output
  Optional(3) Optional(2) 1
  ```

  All three operations work at the end of the array: `last` to peek, `append` to push, `popLast()` to pop. That's what keeps them O(1) (push on average). `first` and `removeFirst()` would compile too, but the top would be index 0 and pop would cost O(n). `as Any` prints the optionals as they are, without a warning.
````

````exercise
id: m17-l01-e4
type: find-errors
prompt: This function checks that formatting tags nest correctly. Which statements about it are true?
code: |
  func tagsAreBalanced(_ tags: [String]) -> Bool {
      var openTags: [String] = []
      for tag in tags {
          if tag.hasPrefix("/") {
              let name = String(tag.dropFirst())
              if openTags.removeLast() != name {
                  return false
              }
          } else {
              openTags.append(tag)
          }
      }
      return true
  }

  print(tagsAreBalanced(["b", "i", "/i", "/b"]))
  print(tagsAreBalanced(["b", "i", "/i"]))
choices:
  - text: "It returns true for [\"b\", \"i\", \"/i\"], even though <b> is never closed."
    correct: true
    why: The function returns true without checking that the stack is empty at the end.
  - text: "A closing tag with nothing open, like [\"/b\"], crashes the program."
    correct: true
    why: "removeLast() on an empty array is a fatal error: Can't remove last element from an empty collection."
  - text: "It returns false for [\"b\", \"i\", \"/i\", \"/b\"] because it compares the tags in the wrong order."
    correct: false
    why: "That input is correct and the function returns true for it: the most recent open tag is compared with each closing tag, which is the right order."
  - text: The function is O(n²) because removeLast() shifts the remaining elements.
    correct: false
    why: removeLast() is O(1). Removing from the front would shift elements; removing from the end doesn't.
rubric:
  - I found that a leftover open tag isn't detected.
  - I found the crash on a closing tag with an empty stack.
  - I fixed both, with popLast() and a final isEmpty check.
  - I kept the O(n) cost.
solution: |
  Two bugs, one at each "edge" of the stack. The loop never asks whether the stack is empty before removing, and the end never asks whether it's empty after the loop:

  ```swift
  func tagsAreBalanced(_ tags: [String]) -> Bool {
      var openTags: [String] = []
      for tag in tags {
          if tag.hasPrefix("/") {
              let name = String(tag.dropFirst())
              guard let last = openTags.popLast(), last == name else {
                  return false
              }
          } else {
              openTags.append(tag)
          }
      }
      return openTags.isEmpty
  }

  print(tagsAreBalanced(["b", "i", "/i", "/b"]))
  print(tagsAreBalanced(["b", "i", "/i"]))
  print(tagsAreBalanced(["/b"]))
  print(tagsAreBalanced(["b", "i", "/b", "/i"]))
  ```

  ```output
  true
  false
  false
  false
  ```

  `popLast()` returns `nil` on an empty stack, and the `guard` treats that as invalid input instead of crashing. `return openTags.isEmpty` catches unclosed tags. Each tag is pushed or popped once: O(n) time, O(n) space.
````

````exercise
id: m17-l01-e5
type: solve
prompt: |
  A file browser shows paths like `/photos/2024/../2025/./trip`. Write `func simplifiedPath(_ path: String) -> String` that returns the canonical path: `.` means the current folder (skip it), `..` means the parent folder (go up one level; at the root, stay at the root), and empty parts from repeated slashes are skipped. The result starts with `/` and has no trailing slash.

  Expected output for the starter's calls:

  ```output
  /photos/2025/trip
  /
  /a/c
  /
  ```
starter: |
  func simplifiedPath(_ path: String) -> String {
      // Use a stack of folder names
      return "/"
  }

  print(simplifiedPath("/photos/2024/../2025/./trip"))
  print(simplifiedPath("/../.."))
  print(simplifiedPath("//a//b/../c/"))
  print(simplifiedPath("/"))
hints:
  - "split(separator: \"/\") drops the empty pieces between repeated slashes for you."
  - A folder name is pushed. ".." pops, if there's anything to pop.
  - "At the end, join the stack from bottom to top with \"/\" and put one \"/\" in front."
rubric:
  - Uses a stack of folder names.
  - Ignores "." and empty parts, and pops on ".." only when the stack isn't empty.
  - Builds the result bottom to top with a leading slash, and returns "/" for an empty stack.
  - The output matches, and the answer states O(n) time and O(n) space.
solution: |
  ```swift
  func simplifiedPath(_ path: String) -> String {
      var folders: [Substring] = []
      for part in path.split(separator: "/") {
          switch part {
          case ".":
              continue
          case "..":
              _ = folders.popLast()
          default:
              folders.append(part)
          }
      }
      return "/" + folders.joined(separator: "/")
  }

  print(simplifiedPath("/photos/2024/../2025/./trip"))
  print(simplifiedPath("/../.."))
  print(simplifiedPath("//a//b/../c/"))
  print(simplifiedPath("/"))
  ```

  ```output
  /photos/2025/trip
  /
  /a/c
  /
  ```

  `..` always refers to the most recently entered folder that's still open, which is why a stack fits. `popLast()` on an empty stack returns `nil` and does nothing, which is exactly "at the root, stay at the root". `_ =` discards the popped name on purpose; without it, Swift 6.3 warns `result of call to 'popLast()' is unused`. The stack is joined from bottom to top, which is the order the folders appear in the path. Each part is pushed or popped at most once: **O(n) time and O(n) space** for a path of n characters. The `Substring` values avoid copying each part into a new `String`; `joined` builds one string at the end.
````

````exercise
id: m17-l01-e6
type: design
prompt: |
  A drawing app wants undo and redo, with two extra rules: the history keeps at most 50 steps (older ones are dropped), and some actions, like "select all", shouldn't be undoable. Describe the data structures and what happens on a new action, an undo and a redo. Say where the 50-step limit is enforced and what it costs.
rubric:
  - Uses an undo stack and a redo stack, and explains what each holds.
  - A new undoable action pushes onto undo and clears redo; non-undoable actions touch neither.
  - Undo moves the top of undo to redo; redo does the reverse; both do nothing on an empty stack.
  - "Explains the limit: when undo exceeds 50, the oldest (bottom) entry is dropped, and notes that removing from the front of an Array is O(n), with a fixed small n making it acceptable or a ring buffer avoiding it."
solution: |
  **Two stacks of actions.** Store each undoable action as a value that knows how to apply and reverse itself (for example, "add stroke 42" and its inverse "remove stroke 42"), rather than a snapshot of the whole canvas, which would be expensive.

  - **New undoable action**: apply it, push it on the undo stack, clear the redo stack. A non-undoable action ("select all") is applied and recorded nowhere, so it doesn't break the history.
  - **Undo**: pop from undo; if it's empty, do nothing. Apply the action's inverse and push the action on redo.
  - **Redo**: pop from redo; if it's empty, do nothing. Apply the action again and push it on undo.

  **The limit** belongs in the push onto undo: after pushing, if the stack holds 51 entries, drop the **bottom** one, the oldest action. That's the one operation a stack doesn't offer, and with an Array it's `removeFirst()`, O(n). With n capped at 50, that's at most 50 element moves per action, which is fine. If the cap were large (say 100,000 steps), you'd use a ring buffer, which the next lesson builds, to drop the oldest in O(1). Redo doesn't need its own limit: it can never hold more entries than undo had.
````

## Summary

- A stack lets you push, pop and peek at **one end**, the top. Order is **LIFO**: last in, first out.
- On an Array, the top is the **end**: `append` (O(1) amortized), `popLast()` (O(1)), `last` (O(1)). Using index 0 makes every operation O(n).
- A `Stack<Element>` struct with a `private` array documents the intent and blocks operations that break LIFO. `pop` returns an optional; `removeLast()` on an empty array crashes.
- Think "stack" when the **most recent unfinished thing** is what you handle next: undo, matching nested pairs, evaluating postfix expressions, back navigation, depth-first exploration.
- Matching needs two extra checks: a closing item with an empty stack, and a non-empty stack at the end.
- Undo and redo use two stacks, and a new action clears the redo stack.

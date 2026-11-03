---
id: m18-l01
title: Thinking recursively
description: You write recursive functions on purpose instead of by accident. A base case that stops, a recursive case that shrinks the problem, and the habit of trusting the smaller call instead of tracing it. You watch frames pile up on the call stack, measure how deep a recursion goes, see why deep recursion crashes an app, turn a recursion into a loop with an explicit stack, and get a first look at memoization.
module: m18
order: 1
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m17-l06]
objectives:
  - Write a recursive function by naming its base case and a recursive case that moves toward it.
  - Reason about a recursive call by trusting what it returns instead of tracing every level.
  - Describe what the call stack holds during a recursion and measure a recursion's depth.
  - Decide when recursion depth is safe and when a loop is the better choice.
  - Rewrite a tree recursion as a loop with an explicit stack.
  - Recognize repeated subproblems and remove them with a memo.
terms:
  - term: Base case
    definition: The input a recursive function answers directly, without calling itself. Every chain of calls has to end at one.
  - term: Recursive case
    definition: The part of a recursive function that calls itself on a smaller input and builds its answer from the result.
  - term: Stack frame
    definition: The block of memory a single call gets on the call stack, holding its parameters, local variables and where to return to. It's freed when the call returns.
  - term: Recursion depth
    definition: The largest number of calls of a recursive function that are in progress at the same time, which is the number of frames it stacks up at its deepest point.
  - term: Stack overflow
    definition: A crash that happens when the call stack runs out of space, usually because a recursion went too deep or never stopped.
  - term: Memoization
    definition: Storing the result of a call the first time it's computed and returning the stored result on later calls with the same input.
mastery:
  - Write a recursive function over an array index or a tree and point at its base case.
  - Explain a recursive function's correctness in two sentences, without tracing it.
  - Predict the order of prints that happen before and after a recursive call.
  - Give the recursion depth of a function in terms of its input, and say whether it's safe for large inputs.
  - Convert a recursive tree walk into a while loop over an array used as a stack.
resources: [swift-book-functions, swift-book-control-flow, swift-book-enumerations, swift-array]
cards:
  - id: m18-l01-c1
    front: What two things does every recursive function need?
    back: A base case it answers without recursing, and a recursive case that calls itself on a smaller input, so that every chain of calls eventually reaches a base case.
  - id: m18-l01-c2
    front: What does "trust the recursive call" mean?
    back: Assume the call on the smaller input already returns the right answer, and only check that your function builds the correct answer from it and that the base case is right. That's induction; tracing every level isn't needed.
  - id: m18-l01-c3
    front: Is a recursion that sums an array of n elements, one index per call, safe for n = 1,000,000?
    back: No. Its depth is n + 1 frames. On the test container it crashed between 100,000 and 120,000 elements in a debug build, and iOS stacks are smaller. Use a loop. Depth of O(log n) or the height of a shallow tree is fine.
  - id: m18-l01-c4
    front: Does Swift turn a tail-recursive function into a loop?
    back: The language doesn't guarantee it. The optimizer may do it in some optimized builds, but you can't rely on it, and debug builds keep every frame.
  - id: m18-l01-c5
    front: How do you turn a recursive tree walk into a loop?
    back: Keep an array as an explicit stack. Push the root; while the stack isn't empty, pop a node, process it and push its children. The array lives on the heap, so depth no longer threatens the call stack.
---

## The idea in one sentence

A recursive function answers a problem by answering **a smaller version of the same problem** and doing a little work on top, and you write it by getting two things right: the smallest case, and how one step builds on the next one down.

Module 15 taught you to count the calls of a recursive function to find its cost. This lesson is about writing one.

## Base case and recursive case

Summing an array, recursively:

```swift
func sum(_ values: [Int], from index: Int) -> Int {
    if index == values.count {
        return 0
    }
    return values[index] + sum(values, from: index + 1)
}

print(sum([4, 8, 15, 16], from: 0))
print(sum([], from: 0))
```

```output
43
0
```

- `if index == values.count { return 0 }` is the **base case**: past the last element there's nothing left to add, so the sum is 0. No recursive call.
- `values[index] + sum(values, from: index + 1)` is the **recursive case**: the sum from `index` on is this element plus the sum of everything after it. The call works on a problem one element smaller.
- Each call moves `index` one step closer to `values.count`, so every chain of calls reaches the base case. That's the second half of the contract: the recursive case must **make progress toward a base case**.

Passing `values` into every call doesn't copy the array. Arrays are copy-on-write (Module 7), and nothing here mutates it, so every call reads the same storage.

## Trust the smaller call

The tempting way to check `sum` is to trace it: `sum(from: 0)` calls `sum(from: 1)`, which calls `sum(from: 2)`… That works for four elements and falls apart for anything with two branches. The way that scales is the way a proof by induction works:

1. **The base case is right.** For an empty tail the answer is 0. Check.
2. **Assume the call on the smaller input is right.** `sum(values, from: index + 1)` returns the sum of everything after `index`. Don't open it. Take it as given.
3. **Check that you build the right answer from it.** This element plus the sum of the rest is the sum from `index` on. Check.

If both checks pass and every call makes progress, the function is correct for every input. This is sometimes called the recursive leap of faith; it isn't faith, it's induction.

It pays off on trees, where tracing is hopeless. A folder holds files and other folders:

```swift
struct Folder {
    let name: String
    let fileSizes: [Int]
    let subfolders: [Folder]
}

func totalSize(of folder: Folder) -> Int {
    var total = 0
    for size in folder.fileSizes {
        total += size
    }
    for subfolder in folder.subfolders {
        total += totalSize(of: subfolder)
    }
    return total
}

let photos = Folder(name: "Photos", fileSizes: [300, 450], subfolders: [
    Folder(name: "2025", fileSizes: [120], subfolders: []),
    Folder(name: "2026", fileSizes: [80, 95], subfolders: [
        Folder(name: "Trip", fileSizes: [500], subfolders: []),
    ]),
])
print(totalSize(of: photos))
```

```output
1545
```

The leap of faith reads: "a folder's size is its own files plus, trusting the call, the total size of each subfolder." You never think about how deep the folders go.

Where's the base case? There's no `if`. A folder with no subfolders runs the second loop zero times and returns just its files. **The empty loop is the base case.** That's common with trees: the recursion stops at the leaves on its own.

A struct can contain an array of itself because the array stores its elements separately. A struct can't contain a plain stored property of its own type; that's what `indirect` is for in enums (Module 9).

### A practical example: printing a hierarchy

The same shape walks anything nested: folders, a view and its subviews, a comment thread and its replies, the menu of a settings screen. Printing a tree with indentation needs one extra parameter, the depth:

```swift
struct Folder {
    let name: String
    let fileSizes: [Int]
    let subfolders: [Folder]
}

func printTree(_ folder: Folder, depth: Int) {
    let indent = String(repeating: "  ", count: depth)
    print("\(indent)\(folder.name) (\(folder.fileSizes.count) files)")
    for subfolder in folder.subfolders {
        printTree(subfolder, depth: depth + 1)
    }
}

let photos = Folder(name: "Photos", fileSizes: [300, 450], subfolders: [
    Folder(name: "2025", fileSizes: [120], subfolders: []),
    Folder(name: "2026", fileSizes: [80, 95], subfolders: [
        Folder(name: "Trip", fileSizes: [500], subfolders: []),
    ]),
])
printTree(photos, depth: 0)
```

```output
Photos (2 files)
  2025 (1 files)
  2026 (2 files)
    Trip (1 files)
```

The parent prints itself **before** its children, so the output reads top-down. Move the `print` after the loop and every folder would print after everything inside it. Exercise 2 is about that order.

## What the call stack holds

Every call that hasn't returned yet has a **frame** on the call stack, the stack you built in Module 17: its own copy of the parameters and local variables, plus where to continue when it returns. A recursive call pushes a new frame; returning pops it. Making that visible:

```swift
func factorial(_ n: Int, depth: Int) -> Int {
    let indent = String(repeating: "  ", count: depth)
    print("\(indent)factorial(\(n)) starts")
    if n <= 1 {
        print("\(indent)factorial(\(n)) returns 1")
        return 1
    }
    let result = n * factorial(n - 1, depth: depth + 1)
    print("\(indent)factorial(\(n)) returns \(result)")
    return result
}

print(factorial(4, depth: 0))
```

```output
factorial(4) starts
  factorial(3) starts
    factorial(2) starts
      factorial(1) starts
      factorial(1) returns 1
    factorial(2) returns 2
  factorial(3) returns 6
factorial(4) returns 24
24
```

When `factorial(1)` runs, four frames are on the stack, each with its own `n` and each stopped at the multiplication, waiting for the call below it. Nothing gets multiplied on the way down; all the work happens on the way back up, as frames pop. The first call to start is the last to finish.

### Recursion depth

The **depth** of a recursion is how many of its frames are on the stack at the deepest point. It's a different number from the total number of calls:

| Function | Total calls | Depth |
| --- | --- | --- |
| `sum(values, from: 0)` on n elements | n + 1 | n + 1 |
| `factorial(n)` | n | n |
| Naive `fib(n)` from Module 15 | exponential | n |
| `totalSize` on a folder tree | one per folder | the tree's height |
| A recursive binary search on n elements | about log₂ n | about log₂ n |

Depth is what costs **stack memory**: O(depth) of it, even when the function allocates nothing else. Module 15 counted that as space; here it's also a limit.

### Stack overflow in practice

The call stack has a fixed size, set when the thread starts, and it's small. Apple's archived *Threading Programming Guide* lists 1 MB for the iOS main thread and 512 KB for secondary threads. Those figures are old, so treat them as orders of magnitude, not as current guarantees. When a recursion needs more frames than fit, the program crashes with a stack overflow. Swift doesn't throw an error you can catch; the process dies.

This is what it looks like on purpose:

```swift illustrative
func sum(_ values: [Int], from index: Int) -> Int {
    if index == values.count {
        return 0
    }
    return values[index] + sum(values, from: index + 1)
}

let manyOnes = Array(repeating: 1, count: 1_000_000)
print(sum(manyOnes, from: 0))   // crashes
```

In the Linux container that tests this course's code, a debug build of this `sum` crashed somewhere between 100,000 and 120,000 elements, with `*** Program crashed: Bad pointer dereference` and a backtrace of thousands of identical `sum(_:from:)` frames. In Xcode you'd see `EXC_BAD_ACCESS` in the debugger and a huge stack in the debug navigator. The exact limit depends on the platform, the thread, the build settings and how big each frame is, which is why the rule is about the shape, not a number:

- **Depth O(log n)**, like binary search or a balanced split: safe. log₂ of a billion is 30.
- **Depth = height of a tree you control**, like a settings menu or a view hierarchy: safe in practice.
- **Depth O(n) over user data**, like one call per element of an array or per node of a long linked list: not safe for large n. Use a loop.

> [!note] Tail calls aren't a way out
> `return sum(values, from: index + 1, runningTotal: total + values[index])`, where the recursive call is the very last thing the function does, is a tail call. Some languages guarantee that tail calls reuse the current frame. Swift doesn't guarantee it. The optimizer may do it in some optimized builds, but debug builds keep every frame, and code that only works when optimized is a bug waiting for a build setting to change.

## Recursion or a loop?

Anything recursive can be written as a loop. For a single chain of calls, like `sum` or `factorial`, the loop is obvious and better: same O(n) time, O(1) space instead of O(n) stack. For a tree, the loop needs the stack the recursion was using for free, so you keep one yourself, in an array:

```swift
struct Folder {
    let name: String
    let fileSizes: [Int]
    let subfolders: [Folder]
}

func totalSizeIterative(of root: Folder) -> Int {
    var total = 0
    var pending = [root]
    while let folder = pending.popLast() {
        for size in folder.fileSizes {
            total += size
        }
        pending.append(contentsOf: folder.subfolders)
    }
    return total
}

let photos = Folder(name: "Photos", fileSizes: [300, 450], subfolders: [
    Folder(name: "2025", fileSizes: [120], subfolders: []),
    Folder(name: "2026", fileSizes: [80, 95], subfolders: [
        Folder(name: "Trip", fileSizes: [500], subfolders: []),
    ]),
])
print(totalSizeIterative(of: photos))
```

```output
1545
```

`pending` holds the folders still to visit, the same job the call stack's frames did. `popLast()` takes the most recently added one, so this visits folders depth first, in a different order from the recursive version; for a total, order doesn't matter. The array grows on the heap, which has far more room than the call stack, so a very deep tree no longer crashes.

How to choose:

- **Recursion** when the data is recursive (trees, nested structures), the depth is bounded and modest, and the recursive version is clearly easier to read. Backtracking (lesson 2) and merge sort (lesson 5) are naturally recursive.
- **A loop** when the recursion is a single chain over the input, when depth grows with the data, or when the order of visits needs control the call stack doesn't give you (a queue instead of a stack gives breadth-first order; you'll use that in the graph modules).

## A preview: repeated subproblems

Some recursions solve the same subproblem many times. Module 15 showed it with Fibonacci. Here's a different one: the number of paths from the top-left corner of a grid to the bottom-right corner, moving only right or down. The number of paths to any cell is the paths to the cell above it plus the paths to the cell on its left:

```swift
func paths(row: Int, column: Int, calls: inout Int) -> Int {
    calls += 1
    if row == 0 || column == 0 {
        return 1
    }
    return paths(row: row - 1, column: column, calls: &calls)
        + paths(row: row, column: column - 1, calls: &calls)
}

func pathsMemo(row: Int, column: Int, memo: inout [[Int?]], calls: inout Int) -> Int {
    calls += 1
    if row == 0 || column == 0 {
        return 1
    }
    if let known = memo[row][column] {
        return known
    }
    let result = pathsMemo(row: row - 1, column: column, memo: &memo, calls: &calls)
        + pathsMemo(row: row, column: column - 1, memo: &memo, calls: &calls)
    memo[row][column] = result
    return result
}

var plainCalls = 0
print(paths(row: 9, column: 9, calls: &plainCalls), plainCalls)

var memo = Array(repeating: Array(repeating: Int?.none, count: 10), count: 10)
var memoCalls = 0
print(pathsMemo(row: 9, column: 9, memo: &memo, calls: &memoCalls), memoCalls)
```

```output
48620 97239
48620 163
```

Same answer, 97,239 calls against 163. The base case is the top row or left column: one path, straight along the edge. The plain version computes `paths(row: 1, column: 1)` 12,870 times, once for every route that passes through it. The memo version computes each of the 81 inner cells once; every later call for that cell is a lookup. The memo turns the cost from "number of paths" into "number of distinct subproblems". Module 20 is built on that idea; for now, recognize the signal: **a recursion with more than one call whose arguments can repeat**.

## Common mistakes

> [!error] No base case, or one the recursion can't reach
> `func countdown(_ n: Int) { if n == 0 { return }; countdown(n - 2) }` works for 4 and never stops for 3: 3, 1, −1, −3… until the stack overflows. Check that **every** input reaches a base case, and prefer `n <= 0` over `n == 0` when the step is bigger than 1 or the input could be negative.

> [!error] error: missing return in global function expected to return 'Int'
> The recursive call is there, but its result isn't returned. Swift 6.3 also warns "result of call to 'sum(_:from:)' is unused" on that line. The value has to be returned, every level up.

```swift no-compile missing return in global function expected to return 'Int'
func sum(_ values: [Int], from index: Int) -> Int {
    if index == values.count {
        return 0
    }
    sum(values, from: index + 1)
}
```

> [!error] Copying the rest of the array on every call
> `max(of: Array(values.dropFirst()))` reads nicely and copies n − 1 elements, then n − 2, and so on: O(n²) time for an O(n) job. Pass an index, as `sum(_:from:)` does. Passing the `ArraySlice` from `dropFirst()` without wrapping it in `Array(…)` avoids the copy, but see the next mistake.

> [!error] Fatal error: Index out of bounds
> An `ArraySlice` keeps the indices of the original array. After `dropFirst()`, the first index is 1, not 0. Use `rest.first`, `rest[rest.startIndex]`, or pass an index into the original array.

```swift runtime-error Index out of bounds
let values = [4, 8, 15]
let rest = values.dropFirst()
print(rest)
print(rest[0])
```

```output
[8, 15]
```

> [!error] Recursion over user data with O(n) depth
> One call per element, per character or per node of a long list works on your test data and crashes on a big import. If the depth grows with the input, write the loop.

## Exercises

````exercise
id: m18-l01-e1
type: comprehension
prompt: |
  `printTree` from the lesson is called on a folder tree with 2,000 folders. The deepest folder is 6 levels below the root. What's the largest number of `printTree` frames on the call stack at any moment?
choices:
  - text: "7"
    correct: true
    why: "The root's frame, plus one frame per level on the way down to the deepest folder: 1 + 6. Frames for siblings are popped before the next sibling's frame is pushed."
  - text: "2,000"
    correct: false
    why: "That's the total number of calls. Calls on different branches are never on the stack at the same time."
  - text: "6"
    correct: false
    why: "Off by one: the root's own call is a frame too."
  - text: "log₂ 2,000, about 11"
    correct: false
    why: "Depth depends on the tree's height, not on the number of folders. A tree isn't balanced just because it's a tree."
solution: |
  **7.** Depth is the longest chain of calls in progress at once, and a call on one subfolder returns before the call on the next subfolder starts. So the stack only ever holds the path from the root to the folder being printed: the root plus 6 levels. The 2,000 is the total number of calls, which decides the time (O(number of folders)), while the 7 decides the stack space.
````

````exercise
id: m18-l01-e2
type: prediction
prompt: Predict the exact output.
code: |
  func echo(_ n: Int) {
      if n == 0 {
          print("base")
          return
      }
      print("down \(n)")
      echo(n - 1)
      print("up \(n)")
  }

  echo(3)
output: |
  down 3
  down 2
  down 1
  base
  up 1
  up 2
  up 3
hints:
  - Each call prints "down" before calling itself and "up" after the call returns.
  - The call that started last finishes first.
solution: |
  ```output
  down 3
  down 2
  down 1
  base
  up 1
  up 2
  up 3
  ```

  The prints before the recursive call run on the way down, as frames are pushed: 3, 2, 1. `echo(0)` prints `base` and returns. Then each waiting frame resumes after its call, in reverse order of when it started: 1, 2, 3. Anything you put after the recursive call runs in reverse. That's how a recursive function can print a list backwards without reversing it.
````

````exercise
id: m18-l01-e3
type: fill-in
prompt: Complete the recursive power function, which computes base raised to a non-negative exponent.
code: |
  func power(_ base: Int, _ exponent: Int) -> Int {
      if exponent == [[1]] {
          return [[2]]
      }
      return [[3]] * power(base, [[4]])
  }
blanks:
  - id: "1"
    answers: ["0"]
  - id: "2"
    answers: ["1"]
  - id: "3"
    answers: ["base"]
  - id: "4"
    answers: ["exponent - 1", "exponent-1"]
solution: |
  ```swift
  func power(_ base: Int, _ exponent: Int) -> Int {
      if exponent == 0 {
          return 1
      }
      return base * power(base, exponent - 1)
  }

  print(power(2, 10), power(3, 0), power(5, 3))
  ```

  ```output
  1024 1 125
  ```

  - **Base case:** anything to the power 0 is 1.
  - **Recursive case:** trust that `power(base, exponent - 1)` is right; multiplying it by `base` once more gives the answer.
  - Each call lowers the exponent by 1, so a non-negative exponent always reaches 0. That's O(exponent) calls and O(exponent) depth. Lesson 6 halves the exponent instead, for O(log exponent).
````

````exercise
id: m18-l01-e4
type: find-errors
prompt: |
  This function should return how many decimal digits an integer has: 3 for 482, 1 for 7, 2 for −45. Which statements are true?
code: |
  func digitCount(_ n: Int) -> Int {
      if n == 0 {
          return 0
      }
      return 1 + digitCount(n / 10)
  }
choices:
  - text: "digitCount(0) returns 0, but 0 has one digit."
    correct: true
    why: "The base case is the answer for the end of the recursion, not for the input 0. The function needs a different base case or a special case for 0."
  - text: "It recurses forever on negative numbers."
    correct: false
    why: "Swift's integer division truncates toward zero: −45 / 10 is −4, and −4 / 10 is 0. It returns 2 for −45, which is right."
  - text: "It's correct for every positive number."
    correct: true
    why: "Each call strips one digit, and the recursion stops when none are left: 482 → 48 → 4 → 0 counts 3."
  - text: "It needs to copy n into a var before dividing."
    correct: false
    why: "It never mutates n. It passes n / 10, a new value, to the next call."
rubric:
  - I found that 0 returns 0.
  - I checked negative numbers instead of assuming they break.
  - I proposed a fix whose base case handles single-digit numbers.
solution: |
  The only bug is 0. The fix is to stop at one digit instead of at zero digits:

  ```swift
  func digitCount(_ n: Int) -> Int {
      if n > -10 && n < 10 {
          return 1
      }
      return 1 + digitCount(n / 10)
  }

  print(digitCount(482), digitCount(7), digitCount(-45), digitCount(0))
  ```

  ```output
  3 1 2 1
  ```

  A base case has to be the right answer **for the input it matches**. "When n is 0 the count is 0" was standing in for "there are no digits left", which is a different question from "how many digits does 0 have". Matching single-digit numbers asks the right question for every input, including 0 and negatives.
````

````exercise
id: m18-l01-e5
type: solve
prompt: |
  Using the lesson's `Folder` struct, write `func path(to name: String, in folder: Folder) -> [String]?` that returns the names from the root down to the first folder called `name`, or `nil` if there's none. Search subfolders in order.

  With the `photos` tree from the lesson, print `path(to: "Trip", in: photos)`, `path(to: "2025", in: photos)`, `path(to: "Photos", in: photos)` and `path(to: "Music", in: photos)`, using `?? []` for the missing one. Expected:

  ```output
  ["Photos", "2026", "Trip"]
  ["Photos", "2025"]
  ["Photos"]
  []
  ```
starter: |
  struct Folder {
      let name: String
      let fileSizes: [Int]
      let subfolders: [Folder]
  }

  func path(to name: String, in folder: Folder) -> [String]? {
      // Base case: is this the folder?
      // Recursive case: try each subfolder
      return nil
  }
hints:
  - "If folder.name == name, the path is just [folder.name]."
  - "Otherwise, trust the call: if path(to: name, in: subfolder) returns a path, put folder.name in front of it."
  - "If no subfolder finds it, return nil."
rubric:
  - The base case returns a one-element path when the current folder matches.
  - The recursive case prepends the current folder's name to a subfolder's non-nil result and returns immediately.
  - It returns nil when nothing matches, and the output matches.
solution: |
  ```swift
  struct Folder {
      let name: String
      let fileSizes: [Int]
      let subfolders: [Folder]
  }

  func path(to name: String, in folder: Folder) -> [String]? {
      if folder.name == name {
          return [folder.name]
      }
      for subfolder in folder.subfolders {
          if let rest = path(to: name, in: subfolder) {
              return [folder.name] + rest
          }
      }
      return nil
  }

  let photos = Folder(name: "Photos", fileSizes: [300, 450], subfolders: [
      Folder(name: "2025", fileSizes: [120], subfolders: []),
      Folder(name: "2026", fileSizes: [80, 95], subfolders: [
          Folder(name: "Trip", fileSizes: [500], subfolders: []),
      ]),
  ])
  print(path(to: "Trip", in: photos) ?? [])
  print(path(to: "2025", in: photos) ?? [])
  print(path(to: "Photos", in: photos) ?? [])
  print(path(to: "Music", in: photos) ?? [])
  ```

  ```output
  ["Photos", "2026", "Trip"]
  ["Photos", "2025"]
  ["Photos"]
  []
  ```

  The leap of faith: "if a subfolder can find a path to `name`, the path from here is my name followed by that path." The first subfolder that finds one wins, which gives "the first match in order". There are two base cases: a match (return a path) and a leaf that doesn't match (the loop does nothing and the function returns `nil`). Cost: O(number of folders) time in the worst case, and depth equal to the tree's height. Building `[folder.name] + rest` at each level copies the path, which adds O(height²) in total; for folder trees that's nothing.
````

````exercise
id: m18-l01-e6
type: refactor
prompt: |
  This finds the largest value in a non-empty array, recursively. It's correct. Rewrite it so it doesn't copy the array on every call, keeping it recursive, then say what the time was before and after and what its recursion depth is.
code: |
  func largest(_ values: [Int]) -> Int {
      if values.count == 1 {
          return values[0]
      }
      return max(values[0], largest(Array(values.dropFirst())))
  }
rubric:
  - The new version passes an index (or a slice used with its own indices) instead of building a new array.
  - I stated O(n²) before because each call copies the rest, and O(n) after.
  - I said the depth is still n, so neither version is safe for very large arrays, and a loop or values.max() is the practical choice.
solution: |
  ```swift
  func largest(_ values: [Int], from index: Int) -> Int {
      if index == values.count - 1 {
          return values[index]
      }
      return max(values[index], largest(values, from: index + 1))
  }

  print(largest([4, 42, 8, 15], from: 0))
  print(largest([7], from: 0))
  ```

  ```output
  42
  7
  ```

  **Before:** each call builds a new array of the remaining elements, copying n − 1, then n − 2, … elements: n(n − 1) / 2 copies, **O(n²)** time, and the copies take O(n²) memory in total over the run. **After:** each call does O(1) work and reads the same array, so **O(n)** time.

  The depth didn't change: n frames either way. That's fine as an exercise and wrong for production data; `values.max()` (Module 7) or a loop does the same in O(n) time with O(1) stack. The point of the refactor is the habit: recursion over an array moves an index, it doesn't rebuild the array.
````

## Summary

- A recursive function has a **base case** it answers directly and a **recursive case** that calls itself on a smaller input. Every input must reach a base case.
- Check a recursion like an induction proof: the base case is right; assuming the smaller call is right, the step builds the right answer. Don't trace every level.
- On trees, the base case is often an empty loop over no children.
- Each call in progress has a **frame** on the call stack. **Depth** is the longest chain of frames at once; it costs O(depth) stack memory, separate from the total number of calls.
- Stacks are small (old Apple figures: 1 MB for the iOS main thread, 512 KB for secondary threads). Depth O(log n) or a shallow tree's height is safe; depth O(n) over user data isn't. Swift doesn't guarantee tail-call elimination.
- Any recursion can become a loop; for trees, keep an explicit stack in an array.
- When a recursion makes several calls whose arguments repeat, a **memo** turns "number of calls" into "number of distinct subproblems". Module 20 builds on it.

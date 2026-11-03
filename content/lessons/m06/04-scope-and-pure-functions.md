---
id: m06-l04
title: Scope, side effects and pure functions
description: You learn where each name is visible, why a parameter can't be reassigned, how inout lets a function change the caller's variable, and why functions with no side effects are the easiest code you'll ever test.
module: m06
order: 4
level: beginner
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m06-l03]
objectives:
  - Say where a name declared in a function, a block or at the top level is visible.
  - Explain shadowing and recognize when it helps and when it hides a bug.
  - Explain why parameters are constants and work around it with a local copy.
  - Use inout and & to let a function modify a variable of the caller.
  - Tell a pure function from one with side effects and explain why pure functions are easy to test.
terms:
  - term: Scope
    definition: The region of the code where a name is visible. A name declared inside a pair of braces is visible from its declaration to the closing brace.
  - term: Local name
    definition: A constant, variable or parameter declared inside a function or block. It exists only while that function or block runs.
  - term: Global name
    definition: A name declared at the top level of a file, outside any function. It's visible everywhere in the program.
  - term: Shadowing
    definition: Declaring a local name with the same name as one from an outer scope. Inside the inner scope, the new name hides the outer one.
  - term: inout parameter
    definition: A parameter that the function can modify, with the change copied back to the caller's variable when the function returns. The call marks the argument with &.
  - term: Side effect
    definition: Anything a function does besides returning a value, like printing, changing a variable outside itself, reading input or writing a file.
  - term: Pure function
    definition: A function whose result depends only on its arguments and that has no side effects. The same arguments always give the same result.
mastery:
  - Point at any name in a program and say where it's visible and where it isn't.
  - Fix "cannot find 'x' in scope" and "cannot assign to value 'x' is a 'let' constant" on a parameter without the compiler's help.
  - Rewrite a function that modifies an inout parameter as a pure function that returns the new value.
  - Classify functions as pure or impure and name the side effect in each impure one.
resources: [swift-book-functions, swift-book-basics]
cards:
  - id: m06-l04-c1
    front: Where is a constant declared inside a function visible?
    back: Only inside that function, from its declaration to the function's closing brace. Outside, Swift reports cannot find 'name' in scope.
  - id: m06-l04-c2
    front: Can a function assign a new value to one of its parameters?
    back: "No. Parameters are constants. To change the value, copy it into a local var (var value = value) or, if the caller's variable must change, use inout."
  - id: m06-l04-c3
    front: How do you call a function with an inout parameter?
    back: "Pass a var and put & before it: addBonus(to: &score). The & warns the reader that the function can change score."
  - id: m06-l04-c4
    front: What makes a function pure?
    back: Its result depends only on its arguments, and it has no side effects (no printing, no changing outside state). Same input, same output, every time.
  - id: m06-l04-c5
    front: Why are pure functions easy to test?
    back: A test is just a call and a comparison with the expected result. No setup, no hidden state, no output to capture.
---

## The idea in one sentence

Every name lives in a **scope**, and a function that only reads its parameters and returns a value, touching nothing else, is the simplest kind of code there is to reason about and to test.

## Scope: where a name is visible

**Plain definition:** a name's scope is the part of the code where you can use it.

**Precise definition:** a name declared inside a pair of braces, in a function body, an `if`, a loop, a `do` block, is visible from its declaration to the matching closing brace. Inner blocks can see names from the blocks around them; outer blocks can't see names declared inside inner ones.

```swift
let taxPercent = 16

func priceWithTax(_ price: Int) -> Int {
    let tax = price * taxPercent / 100
    return price + tax
}

print(priceWithTax(100))
print(taxPercent)
```

```output
116
16
```

- `taxPercent` is declared at the top level, outside any function. It's a **global** constant, visible everywhere, including inside `priceWithTax`.
- `price` (the parameter) and `tax` are **local** to `priceWithTax`. They're created when the call starts and disappear when it ends.

Try to use `tax` outside the function and the program doesn't compile:

```swift no-compile cannot find 'tax' in scope
func priceWithTax(_ price: Int) -> Int {
    let tax = price * 16 / 100
    return price + tax
}

print(priceWithTax(100))
print(tax)
```

Swift 6.3 says `error: cannot find 'tax' in scope`. From where `print(tax)` is, no `tax` is visible.

The same rule applies to every block you met in Module 5. A `let` inside an `if` or a loop body exists only inside it, and the loop variable in `for i in 1...3` exists only inside the loop. If you need a value after the block ends, declare it before the block.

```swift
func sumUpTo(_ n: Int) -> Int {
    var total = 0
    for i in 1...n {
        let doubled = i * 2
        total += doubled / 2
    }
    // i and doubled don't exist here; total does.
    return total
}

print(sumUpTo(4))
```

```output
10
```

## Global variables in Swift 6

A global **constant** like `taxPercent` is safe to read from any function: it never changes. A global **variable** is a different story. Look what happens when a function tries to change one:

```swift no-compile can not be mutated from a nonisolated context
var visits = 0

func registerVisit() {
    visits += 1
}

registerVisit()
print(visits)
```

Swift 6.3, in Swift 6 language mode, rejects it: `error: main actor-isolated var 'visits' can not be mutated from a nonisolated context`. Even reading `visits` from inside a function gets a similar error. If the variable lives in a file other than `main.swift`, the error is different but just as firm: `var 'visits' is not concurrency-safe because it is nonisolated global shared mutable state`.

The wording comes from concurrency, which you'll study much later (Module 29). The short version: a global variable can be changed by any code, from anywhere, at any time, including from code running in parallel, and Swift 6 refuses to let that happen by accident. The design lesson applies right now, though. **Don't reach out to global variables from functions.** Pass values in as parameters and hand results back with `return`:

```swift
func registerVisit(count: Int) -> Int {
    count + 1
}

var visits = 0
visits = registerVisit(count: visits)
visits = registerVisit(count: visits)
print(visits)
```

```output
2
```

Now `registerVisit` depends only on its argument, and the only code that changes `visits` is the code that owns it.

## Shadowing

You can declare a local name with the same name as an outer one. Inside the inner scope, the local name **shadows** (hides) the outer one:

```swift
let taxPercent = 16

func priceWithReducedTax(_ price: Int) -> Int {
    let taxPercent = 8
    return price + price * taxPercent / 100
}

print(priceWithReducedTax(100))
print(taxPercent)
```

```output
108
16
```

Inside the function, `taxPercent` is the local 8. Outside, the global 16 is untouched. It's legal, but here it's a trap: a reader who sees `taxPercent` in the function may assume the global value. Give it a different name, like `reducedTaxPercent`.

There's one shadowing pattern Swift programmers use on purpose, and it's in the next section.

## Parameters are constants

Inside a function, every parameter behaves like a `let`. You can read it, but not reassign it:

```swift no-compile cannot assign to value: 'value' is a 'let' constant
func clamp(_ value: Int) -> Int {
    if value > 100 {
        value = 100
    }
    return value
}
```

Swift 6.3: `error: cannot assign to value: 'value' is a 'let' constant`. It's the same message you saw in Module 4 for `let`.

This protects you: the value of a parameter is always what the caller passed, on every line of the body. If you really need to work with a changing copy, declare a local variable. Shadowing the parameter with the same name is the usual idiom:

```swift
func clamp(_ value: Int) -> Int {
    var value = value
    if value > 100 {
        value = 100
    }
    return value
}

print(clamp(250), clamp(42))
```

```output
100 42
```

`var value = value` creates a local variable named `value`, initialized with the parameter's value. From that line on, `value` means the local variable. The caller's argument is never touched: it was a copy all along.

## inout: changing the caller's variable

Sometimes a function's whole purpose is to modify a variable that belongs to the caller. For that, mark the parameter `inout` and pass the argument with `&`:

```swift
func addBonus(to score: inout Int, points: Int) {
    score += points
}

var playerScore = 50
addBonus(to: &playerScore, points: 10)
addBonus(to: &playerScore, points: 5)
print(playerScore)
```

```output
65
```

1. `inout Int` says the function can change this parameter, and the change goes back to the caller.
2. The argument must be a `var`. A `let` or a literal can't be changed, so it can't be passed.
3. `&playerScore` marks the call. The `&` is mandatory, so anyone reading the call knows `playerScore` may change.

The language reference in the Swift book describes this as **copy-in, copy-out**: the value is copied into the function, the function modifies its copy, and when the function returns the copy is written back to the caller's variable.

Use `inout` sparingly. A function that returns the new value is almost always easier to follow:

```swift
func addingBonus(to score: Int, points: Int) -> Int {
    score + points
}

var playerScore = 50
playerScore = addingBonus(to: playerScore, points: 10)
print(playerScore)
```

```output
60
```

The assignment `playerScore = …` shows exactly where the variable changes. The `-ing` in `addingBonus` follows a Swift naming convention: a name ending in *-ing* or *-ed* returns a new value instead of changing one in place.

## Side effects

A function's **side effects** are everything it does besides returning a value:

- printing to the console,
- changing a variable outside itself (an `inout` parameter, a global),
- reading input from the user, a file or the network,
- writing to a file, a database or the network.

Side effects aren't bad. A program with none would do nothing visible. But they make a function harder to reason about, because to understand a call you have to know what else it touched.

## Pure functions

A function is **pure** when:

1. its result depends **only on its arguments**, and
2. it has **no side effects**.

Call it with the same arguments and you get the same result, every time, no matter what else happened in the program.

```swift
// Pure: depends only on its arguments, does nothing else.
func average(_ a: Int, _ b: Int) -> Int {
    (a + b) / 2
}

// Impure: prints (a side effect) instead of returning.
func printAverage(_ a: Int, _ b: Int) {
    print("Average:", (a + b) / 2)
}

print(average(8, 4))
printAverage(8, 4)
```

```output
6
Average: 6
```

`average` can be used anywhere: in a calculation, in a condition, inside another function. `printAverage` can only do one thing, print, and you can't use its result because it doesn't have one.

### Why pure functions are easy to test

Testing a pure function is a call and a comparison:

```swift
func average(_ a: Int, _ b: Int) -> Int {
    (a + b) / 2
}

print(average(8, 4) == 6)
print(average(0, 0) == 0)
print(average(-4, 4) == 0)
print(average(5, 6) == 5)
```

```output
true
true
true
true
```

No setup and no output to capture. Since nothing else in the program affects the result, a test that passes today passes tomorrow. Real test frameworks, which come in Module 33, do this same comparison with better reporting. Testing `printAverage`, by contrast, means capturing what it prints and comparing text, which is fragile and much more work.

That's why the receipt in lesson 1 kept the calculations (`itemCost`, `discountedTotal`) pure and pushed the printing into a separate function. It's the Module 2 idea of separating calculation from presentation, and it's how the code inside well-built iOS apps is organized: pure logic in the middle, side effects (screens, network, storage) at the edges.

## Common mistakes

> [!error] error: cannot find 'tax' in scope
> You used a name outside the block where it was declared. Move the declaration to the outer scope, or return the value from the function and store it in the caller.

> [!error] error: cannot assign to value: 'value' is a 'let' constant
> You assigned to a parameter. Copy it into a local `var` first, or return the new value instead of modifying it.

> [!error] error: passing value of type 'Int' to an inout parameter requires explicit '&'
> The parameter is `inout` and the call is missing the `&`. Swift 6.3:

```swift no-compile passing value of type 'Int' to an inout parameter requires explicit '&'
func addBonus(to score: inout Int, points: Int) {
    score += points
}

var playerScore = 50
addBonus(to: playerScore, points: 10)
```

> [!error] Shadowing by accident
> A local `let total` inside a loop or function hides an outer `total`, and the outer one never changes. If you meant to update the outer variable, assign to it (`total = …`) instead of declaring a new one (`let total = …`).

> [!warning] Hidden side effects
> A function named `average` that also prints, or a function named `isValid` that also changes a variable, surprises everyone who calls it. If a function has a side effect, its name should say so.

````exercise
id: m06-l04-e1
type: comprehension
prompt: |
  Which of these functions is **pure**?
choices:
  - text: "`func greet(_ name: String) { print(\"Hi, \\(name)\") }`"
    correct: false
    why: It prints, which is a side effect, and it returns nothing.
  - text: "`func greeting(for name: String) -> String { \"Hi, \\(name)\" }`"
    correct: true
    why: The result depends only on name, and it does nothing besides returning.
  - text: "`func addTax(to price: inout Int) { price += price * 16 / 100 }`"
    correct: false
    why: It modifies the caller's variable through inout, which is a side effect.
  - text: "`func readNumber() -> Int { Int(readLine() ?? \"\") ?? 0 }`"
    correct: false
    why: Its result depends on what the user types, not on its arguments. Reading input is a side effect.
solution: |
  **`greeting(for:)`.** It returns a `String` that depends only on `name` and does nothing else, so the same name always gives the same greeting. `greet` prints, `addTax` changes the caller's variable, and `readNumber` depends on outside input; each of those is a side effect.
````

````exercise
id: m06-l04-e2
type: prediction
prompt: Predict the exact output. Keep track of which `count` each line refers to.
code: |
  let count = 10

  func describe(_ count: Int) -> String {
      var count = count
      count *= 2
      return "Inside: \(count)"
  }

  func bump(_ value: inout Int) {
      value += count
  }

  var total = 1
  print(describe(3))
  bump(&total)
  bump(&total)
  print(total)
  print("Outside: \(count)")
output: |
  Inside: 6
  21
  Outside: 10
hints:
  - "Inside describe, the parameter count shadows the global, and var count = count shadows the parameter."
  - "bump doesn't declare its own count, so it sees the global 10."
solution: |
  ```output
  Inside: 6
  21
  Outside: 10
  ```

  1. In `describe(3)`, the parameter `count` is 3. `var count = count` makes a local copy, which becomes 6. The global `count` is never involved.
  2. `bump` has no local `count`, so it reads the global constant, 10. Two calls: `1 + 10 + 10 = 21`, written back to `total` through `inout`.
  3. The global `count` is still 10: a `let` can't change, and the `count` inside `describe` was a different name in a different scope.

  Reading a global **constant** from a function is fine in Swift 6. Reading a global `var` from `bump` wouldn't compile.
````

````exercise
id: m06-l04-e3
type: find-errors
prompt: This program doesn't compile. Pick out the real problems, then write a fixed version.
code: |
  func countVowels(in word: String) -> Int {
      for letter in word {
          var vowels = 0
          if letter == "a" || letter == "e" || letter == "i" || letter == "o" || letter == "u" {
              vowels += 1
          }
      }
      return vowels
  }

  func shout(_ word: String) -> String {
      word = word + "!"
      return word
  }

  print(countVowels(in: "banana"), shout("hey"))
choices:
  - text: "vowels is declared inside the loop, so it doesn't exist at return vowels."
    correct: true
    why: "cannot find 'vowels' in scope. It also restarts at 0 on every pass, so it would never count past 1."
  - text: "shout assigns to its parameter word, which is a constant."
    correct: true
    why: "cannot assign to value: 'word' is a 'let' constant."
  - text: "A function can't loop over a String parameter."
    correct: false
    why: for letter in word works on any String, parameter or not.
  - text: "shout can't return a parameter."
    correct: false
    why: Returning a parameter's value is fine. The problem is assigning to it.
rubric:
  - I moved vowels before the loop, so it exists for the return and isn't reset on every pass.
  - I fixed shout without assigning to the parameter.
  - My version prints 3 hey!
solution: |
  ```swift
  func countVowels(in word: String) -> Int {
      var vowels = 0
      for letter in word {
          if letter == "a" || letter == "e" || letter == "i" || letter == "o" || letter == "u" {
              vowels += 1
          }
      }
      return vowels
  }

  func shout(_ word: String) -> String {
      word + "!"
  }

  print(countVowels(in: "banana"), shout("hey"))
  ```

  ```output
  3 hey!
  ```

  The scope bug in `countVowels` is also a logic bug: even if the `return` could see it, a counter declared inside the loop is created fresh on every pass. Accumulators always go **before** the loop. For `shout`, there's no need for a variable at all: return the new value directly.
````

````exercise
id: m06-l04-e4
type: refactor
prompt: |
  This function uses `inout` and prints. Rewrite it as a **pure** function that returns the new balance, and move the printing to the caller. The program's output must stay the same.
code: |
  func withdraw(_ amount: Int, from balance: inout Int) {
      if amount <= balance {
          balance -= amount
      }
      print("Balance:", balance)
  }

  var account = 100
  withdraw(30, from: &account)
  withdraw(200, from: &account)
rubric:
  - The new function has no inout parameter and doesn't print.
  - It returns the balance after the withdrawal, or the unchanged balance if there isn't enough money.
  - The caller assigns the result and prints it.
  - The output is still Balance 70 twice.
solution: |
  ```swift
  func balance(_ balance: Int, afterWithdrawing amount: Int) -> Int {
      guard amount <= balance else { return balance }
      return balance - amount
  }

  var account = 100
  account = balance(account, afterWithdrawing: 30)
  print("Balance:", account)
  account = balance(account, afterWithdrawing: 200)
  print("Balance:", account)
  ```

  ```output
  Balance: 70
  Balance: 70
  ```

  The new function can be checked with a single comparison, `balance(100, afterWithdrawing: 30) == 70`, without capturing any output. The caller now shows, with an assignment, exactly where `account` changes. The `guard` handles the "not enough money" case first, as in the previous lesson.
````

````exercise
id: m06-l04-e5
type: solve
prompt: |
  Write a **pure** function `clampedPercent(_:)` that takes any `Int` and returns it limited to the range 0 to 100: below 0 becomes 0, above 100 becomes 100, anything else stays. Then "test" it by printing whether each of these comparisons is true:

  ```swift illustrative
  clampedPercent(-20) == 0
  clampedPercent(0) == 0
  clampedPercent(55) == 55
  clampedPercent(100) == 100
  clampedPercent(140) == 100
  ```

  All five lines should print `true`.
starter: |
  func clampedPercent(_ value: Int) -> Int {
      // your code
  }
hints:
  - Two early returns handle the two out-of-range cases.
  - Don't assign to value; return what you need.
rubric:
  - The function doesn't print and doesn't modify anything outside itself.
  - It doesn't assign to its parameter.
  - All five checks print true, including the edge cases 0 and 100.
solution: |
  ```swift
  func clampedPercent(_ value: Int) -> Int {
      if value < 0 {
          return 0
      }
      if value > 100 {
          return 100
      }
      return value
  }

  print(clampedPercent(-20) == 0)
  print(clampedPercent(0) == 0)
  print(clampedPercent(55) == 55)
  print(clampedPercent(100) == 100)
  print(clampedPercent(140) == 100)
  ```

  ```output
  true
  true
  true
  true
  true
  ```

  The checks include both boundaries, 0 and 100, the edge cases from Module 2 where off-by-one errors live. Because the function is pure, each check is one line and none of them depends on the others: you could run them in any order.
````

````exercise
id: m06-l04-e6
type: explain
prompt: Explain, in your own words, what `var value = value` does on the first line of this function, and why Swift needs it.
code: |
  func roundedDown(_ value: Int, toMultipleOf step: Int) -> Int {
      var value = value
      while value % step != 0 {
          value -= 1
      }
      return value
  }
rubric:
  - I said that parameters are constants and can't be reassigned.
  - I explained that the line declares a new local var initialized with the parameter's value.
  - I mentioned shadowing, that from that line on value means the local variable.
  - I noted that the caller's argument is not affected.
solution: |
  Parameters are constants, so `value -= 1` on the parameter itself wouldn't compile ("cannot assign to value: 'value' is a 'let' constant"). `var value = value` declares a **new local variable** named `value`, initialized with the parameter's value. From that line on, the local variable **shadows** the parameter, so the loop modifies the copy.

  The caller's argument is never affected: `roundedDown(17, toMultipleOf: 5)` returns 15, and a variable passed as the first argument keeps its value. The function stays pure. Here's the check:

  ```swift
  func roundedDown(_ value: Int, toMultipleOf step: Int) -> Int {
      var value = value
      while value % step != 0 {
          value -= 1
      }
      return value
  }

  let price = 17
  print(roundedDown(price, toMultipleOf: 5), price)
  ```

  ```output
  15 17
  ```
````

## Summary

- A name is visible from its declaration to the end of the block that contains it. Inner blocks see outer names; outer blocks don't see inner ones.
- Global constants are fine to read anywhere. In Swift 6, functions can't touch global variables; pass values in and return results.
- A local name with the same name as an outer one shadows it. `var value = value` is the one shadowing idiom to use on purpose.
- Parameters are constants. `inout` plus `&` lets a function change the caller's variable, but returning a new value is usually clearer.
- Side effects are everything besides returning a value. Pure functions have none and depend only on their arguments.
- Pure functions are tested with a call and a comparison. Keep calculations pure and side effects at the edges.

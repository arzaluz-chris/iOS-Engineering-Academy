---
id: m06-l05
title: Functions as values
description: You read and write function types like (Int) -> Int, store a function in a constant, pass one function to another, and write your first closures, including trailing closure syntax.
module: m06
order: 5
level: beginner
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m06-l04]
objectives:
  - Read and write function types such as (Int) -> Int, (Int, Int) -> Bool and () -> Void.
  - Store a function in a constant and call it through that constant.
  - Write a function that takes another function as a parameter.
  - Write a closure expression, from its full form to { x in x * 2 }.
  - Call a function with a trailing closure.
terms:
  - term: Function type
    definition: The type of a function, made of its parameter types and its return type, like (Int, Int) -> Int. Labels and parameter names aren't part of it.
  - term: Higher-order function
    definition: A function that takes another function as a parameter or returns one.
  - term: Closure expression
    definition: A function written inline without a name, between braces, like { x in x * 2 }. The parameters come before the keyword in and the body after it.
  - term: Trailing closure
    definition: A closure passed as a function's last argument and written after the call's closing parenthesis, like transform(5) { x in x + 1 }.
mastery:
  - Write the function type of any function you've declared so far.
  - Write a function that applies a function passed as a parameter, and call it with a named function and with a closure.
  - "Shorten a closure from { (x: Int) -> Int in return x * 2 } to { x in x * 2 } and explain what Swift infers at each step."
  - Rewrite a call that passes a closure as its last argument using trailing closure syntax.
resources: [swift-book-closures, swift-book-functions]
cards:
  - id: m06-l05-c1
    front: "What's the type of `func add(_ a: Int, _ b: Int) -> Int`?"
    back: (Int, Int) -> Int. A function type lists the parameter types and the return type; labels and names aren't part of it.
  - id: m06-l05-c2
    front: "How do you pass a function to another function?"
    back: "Declare the parameter with a function type, like _ operation: (Int) -> Int, and pass the function's name without parentheses: apply(double, to: 5)."
  - id: m06-l05-c3
    front: "What does `{ x in x * 2 }` mean?"
    back: A closure that takes one parameter, x, and returns x * 2. Parameters go before in, the body after it. Swift infers the types from context.
  - id: m06-l05-c4
    front: What's a trailing closure?
    back: "A closure written after the call's parentheses when it's the last argument: transform(5) { x in x + 1 } instead of transform(5, using: { x in x + 1 })."
---

## The idea in one sentence

In Swift, a function is a **value**: it has a type, you can store it in a constant, and you can pass it to another function the same way you pass a number.

## Function types

Every value has a type, and functions are no exception. A function's type is its **parameter types** in parentheses, an arrow, and its **return type**:

| Function | Its type |
| --- | --- |
| `func double(_ n: Int) -> Int` | `(Int) -> Int` |
| `func add(_ a: Int, _ b: Int) -> Int` | `(Int, Int) -> Int` |
| `func isEven(_ n: Int) -> Bool` | `(Int) -> Bool` |
| `func greeting(for name: String) -> String` | `(String) -> String` |
| `func sayHello()` | `() -> Void` |

Labels and parameter names **aren't part of the type**. `greeting(for:)` and a function `shout(_ text: String) -> String` have the same type, `(String) -> String`, because both take a `String` and return a `String`.

## Storing a function in a constant

```swift
func double(_ n: Int) -> Int {
    n * 2
}

let operation: (Int) -> Int = double
print(operation(5))

let sameThing = double
print(sameThing(21))
```

```output
10
42
```

1. `double` **without parentheses** is the function itself, as a value. `double(5)` would call it and give you 10.
2. `let operation: (Int) -> Int = double` stores the function in a constant with an explicit function type.
3. `operation(5)` calls whatever function `operation` holds.
4. Without an annotation, Swift infers the type from `double`.

When you call a function through a constant, **you don't write labels**. The constant's type has none, so `operation(5)` is the only way to call it, even if the original function had labels.

Why would you want this? Because the constant can be **chosen at runtime**:

```swift
func regularPrice(_ price: Int) -> Int {
    price
}

func memberPrice(_ price: Int) -> Int {
    price * 80 / 100
}

let isMember = true
let pricing = isMember ? memberPrice : regularPrice
print(pricing(250))
```

```output
200
```

Both functions have type `(Int) -> Int`, so the ternary can pick either one. From then on, the code just calls `pricing` and doesn't care which rule it got.

## Passing a function to another function

A parameter can have a function type. Then the caller decides **what** the function does at one step of its work:

```swift
func applyTwice(_ operation: (Int) -> Int, to value: Int) -> Int {
    operation(operation(value))
}

func double(_ n: Int) -> Int {
    n * 2
}

func addTen(_ n: Int) -> Int {
    n + 10
}

print(applyTwice(double, to: 3))
print(applyTwice(addTen, to: 3))
```

```output
12
23
```

Line by line:

1. `_ operation: (Int) -> Int` is a parameter whose type is a function from `Int` to `Int`.
2. Inside the body, `operation` is called like any function: `operation(value)`, and then again on that result.
3. `applyTwice(double, to: 3)` passes the function `double`, without parentheses: `double(double(3)) = double(6) = 12`.
4. `applyTwice(addTen, to: 3)`: `addTen(addTen(3)) = addTen(13) = 23`.

`applyTwice` is a **higher-order function**: a function that takes a function. It knows *when* to apply the operation; the caller decides *which* operation. Here's a more useful one, which counts how many numbers in a range pass a test:

```swift
func count(from start: Int, to end: Int, where test: (Int) -> Bool) -> Int {
    var matches = 0
    for n in start...end {
        if test(n) {
            matches += 1
        }
    }
    return matches
}

func isEven(_ n: Int) -> Bool {
    n % 2 == 0
}

func isMultipleOfSeven(_ n: Int) -> Bool {
    n % 7 == 0
}

print(count(from: 1, to: 20, where: isEven))
print(count(from: 1, to: 100, where: isMultipleOfSeven))
```

```output
10
14
```

The loop and the counter are written once. The question asked of each number is a parameter. In Module 7 you'll use functions just like this one, already written in the standard library, on arrays: `filter`, `map`, `sorted` and others all take a function that says what to do with each element.

## Closures: functions without a name

Declaring a named function for every little test gets tedious, especially when you only use it once. A **closure expression** writes the function right where you need it:

```swift
func count(from start: Int, to end: Int, where test: (Int) -> Bool) -> Int {
    var matches = 0
    for n in start...end {
        if test(n) {
            matches += 1
        }
    }
    return matches
}

let multiplesOfThree = count(from: 1, to: 30, where: { (n: Int) -> Bool in
    return n % 3 == 0
})
print(multiplesOfThree)
```

```output
10
```

A closure has the same parts as a function, minus `func` and the name:

```swift illustrative
{ (n: Int) -> Bool in
    return n % 3 == 0
}
```

- The braces enclose the whole closure.
- `(n: Int) -> Bool` is the parameter list and the return type, as in a function declaration.
- The keyword **`in`** separates the signature from the body.
- The body follows, as in any function.

Because `count` already says the parameter is `(Int) -> Bool`, Swift can **infer** the types, so you can drop them. And like a function, a closure whose body is a single expression returns it without `return`. Step by step, these are all the same closure:

```swift
func count(from start: Int, to end: Int, where test: (Int) -> Bool) -> Int {
    var matches = 0
    for n in start...end {
        if test(n) {
            matches += 1
        }
    }
    return matches
}

print(count(from: 1, to: 30, where: { (n: Int) -> Bool in return n % 3 == 0 }))
print(count(from: 1, to: 30, where: { n in return n % 3 == 0 }))
print(count(from: 1, to: 30, where: { n in n % 3 == 0 }))
```

```output
10
10
10
```

`{ n in n % 3 == 0 }` reads as: *given n, the result is n % 3 == 0*.

You can also store a closure in a constant. With no surrounding context to infer from, you have to give Swift the types, either in the closure or in an annotation:

```swift
let triple = { (x: Int) -> Int in x * 3 }
let square: (Int) -> Int = { x in x * x }
print(triple(4), square(4))
```

```output
12 16
```

Swift has an even shorter form, `{ $0 % 3 == 0 }`, where `$0` is the first parameter. You'll see it in other people's code. Stick with named parameters until the longer form is second nature.

## Trailing closures

When a closure is the **last argument** of a call, you can write it **after** the closing parenthesis and drop its label:

```swift
func transform(_ value: Int, using operation: (Int) -> Int) -> Int {
    operation(value)
}

print(transform(5, using: { x in x + 1 }))
print(transform(5) { x in x + 1 })

let result = transform(7) { x in
    let squared = x * x
    return squared - 1
}
print(result)
```

```output
6
6
48
```

The first two calls are identical. In the second, the closure moved outside the parentheses and the `using:` label disappeared. Trailing closures help most when the closure has several lines, as in the third call: the call reads like a block of code, the same shape as an `if` or a `for`. You'll see this syntax all over SwiftUI and in the collection methods in Module 7.

> [!note]
> Closures can do something named functions in this module haven't needed: they can **capture** values from the code around them and keep using them later. That has consequences for memory, so it gets its own treatment in Module 11. For now, write closures that only use their own parameters.

## Common mistakes

> [!error] error: cannot convert value of type '(Int, Int) -> Int' to expected argument type '(Int) -> Int'
> You passed a function whose type doesn't match the parameter's: here, a function of two `Int`s where a function of one was expected. The parameter count, the parameter types and the return type all have to match. Swift 6.3:

```swift no-compile cannot convert value of type '(Int, Int) -> Int' to expected argument type '(Int) -> Int'
func applyTwice(_ operation: (Int) -> Int, to value: Int) -> Int {
    operation(operation(value))
}

let add: (Int, Int) -> Int = { a, b in a + b }
print(applyTwice(add, to: 3))
```

> [!error] error: extraneous argument label 'x:' in call
> You called a function through a constant and used the original function's label. Function types have no labels, so the call through the constant has none either.

```swift no-compile extraneous argument label 'x:' in call
func double(x: Int) -> Int {
    x * 2
}

let operation = double
print(operation(x: 3))
```

> [!error] Calling the function instead of passing it
> `applyTwice(double(3), to: 3)` passes the *result* of `double(3)`, which is the `Int` 6, not the function. Pass the name without parentheses: `applyTwice(double, to: 3)`.

> [!error] error: unnamed argument #2 must precede argument 'to'
> A trailing closure always fills the **last** parameter. Here the function parameter comes first, so Swift tries to put the closure after `to:` and complains about the order. Put function parameters last when you declare them. Swift 6.3:

```swift no-compile unnamed argument #2 must precede argument 'to'
func apply(_ operation: (Int) -> Int, to value: Int) -> Int {
    operation(value)
}

print(apply(to: 5) { n in n + 1 })
```

> [!error] Forgetting the in
> `{ n n % 3 == 0 }` doesn't compile. The keyword `in` separates the parameters from the body: `{ n in n % 3 == 0 }`. Swift's messages for this one ("consecutive statements on a line must be separated by ';'" and "cannot find 'n' in scope") don't point at the real cause, so remember the shape.

````exercise
id: m06-l05-e1
type: comprehension
prompt: |
  What's the type of this function?

  ```swift
  func canVote(_ age: Int, in country: String) -> Bool {
      age >= 18
  }
  ```
choices:
  - text: "`(_ age: Int, in country: String) -> Bool`"
    correct: false
    why: Labels and parameter names aren't part of a function type.
  - text: "`(Int, String) -> Bool`"
    correct: true
    why: Two parameters, an Int and a String, and a Bool result.
  - text: "`(Int) -> (String) -> Bool`"
    correct: false
    why: That would be a function that returns another function. canVote takes both values at once.
  - text: "`Bool`"
    correct: false
    why: Bool is the type of the result of calling it, not the type of the function itself.
solution: |
  **`(Int, String) -> Bool`.** A function type lists only the parameter types, in order, and the return type. The labels (`_`, `in`) and the parameter names (`age`, `country`) belong to the declaration, not the type. `Bool` would be the type of `canVote(20, in: "Mexico")`, the result of a call.
````

````exercise
id: m06-l05-e2
type: prediction
prompt: Predict the exact output, line by line.
code: |
  func combine(_ a: Int, _ b: Int, with operation: (Int, Int) -> Int) -> Int {
      operation(a, b)
  }

  func subtract(_ x: Int, _ y: Int) -> Int {
      x - y
  }

  print(combine(10, 4, with: subtract))
  print(combine(10, 4) { x, y in x * y })
  print(combine(3, 4, with: { a, b in a * 10 + b }))

  let pick: (Int, Int) -> Int = { first, second in second }
  print(combine(7, 9, with: pick))
output: |
  6
  40
  34
  9
hints:
  - "combine just calls operation with a and b, in that order."
  - "The closure { first, second in second } returns its second parameter."
solution: |
  ```output
  6
  40
  34
  9
  ```

  1. `subtract(10, 4) = 6`.
  2. A trailing closure that multiplies: `10 * 4 = 40`.
  3. `3 * 10 + 4 = 34`. Inside the closure, `a` and `b` are its own parameters; they just happen to share names with `combine`'s parameters, which is fine because they're in different scopes.
  4. `pick` ignores its first parameter and returns the second: 9.

  A closure with two parameters lists both before `in`, separated by a comma.
````

````exercise
id: m06-l05-e3
type: fill-in
prompt: |
  Complete the code so it prints `25` and then `6`. The first call passes the function `square`; the second uses a trailing closure that adds 1.
code: |
  func apply(to value: Int, _ operation: [[1]]) -> Int {
      operation(value)
  }

  func square(_ n: Int) -> Int {
      n * n
  }

  print(apply(to: 5, [[2]]))
  print(apply(to: 5) { n [[3]] n + 1 })
blanks:
  - id: "1"
    answers: ["(Int) -> Int"]
  - id: "2"
    answers: ["square"]
  - id: "3"
    answers: ["in"]
solution: |
  ```swift
  func apply(to value: Int, _ operation: (Int) -> Int) -> Int {
      operation(value)
  }

  func square(_ n: Int) -> Int {
      n * n
  }

  print(apply(to: 5, square))
  print(apply(to: 5) { n in n + 1 })
  ```

  ```output
  25
  6
  ```

  1. The parameter's type is `(Int) -> Int`: `operation(value)` passes it an `Int` and the function returns its result as an `Int`.
  2. `square` without parentheses passes the function itself. `square(5)` would pass the number 25, which isn't a function.
  3. `in` separates the closure's parameter from its body.

  The function parameter is the **last** one in `apply`, and that's what makes the trailing closure in the second call possible.
````

````exercise
id: m06-l05-e4
type: solve
prompt: |
  Write a higher-order function `printTable(from:to:using:)` that receives a range of numbers and a function `(Int) -> Int`, and prints one line per number with the number and the function's result. Then call it twice to print exactly:

  ```output
  1 -> 1
  2 -> 4
  3 -> 9
  4 -> 16
  10 -> 5
  11 -> 6
  12 -> 6
  ```

  The first call uses a named function `square`. The second uses a **trailing closure** that computes `(n + 1) / 2`.
starter: |
  func printTable(from start: Int, to end: Int, using operation: (Int) -> Int) {
      // your code
  }
hints:
  - "A for-in loop over start...end, and print(\"\\(n) -> \\(operation(n))\") for each number."
  - "The second call ends in ) { n in (n + 1) / 2 }."
rubric:
  - printTable takes a parameter of type (Int) -> Int and calls it for each number.
  - The first call passes square without parentheses.
  - The second call uses trailing closure syntax.
  - The output matches exactly.
solution: |
  ```swift
  func printTable(from start: Int, to end: Int, using operation: (Int) -> Int) {
      for n in start...end {
          print("\(n) -> \(operation(n))")
      }
  }

  func square(_ n: Int) -> Int {
      n * n
  }

  printTable(from: 1, to: 4, using: square)
  printTable(from: 10, to: 12) { n in (n + 1) / 2 }
  ```

  ```output
  1 -> 1
  2 -> 4
  3 -> 9
  4 -> 16
  10 -> 5
  11 -> 6
  12 -> 6
  ```

  `printTable` owns the loop and the formatting; the caller only supplies the calculation. Because the function parameter is last, the second call can use a trailing closure and drop the `using:` label. `(11 + 1) / 2` and `(12 + 1) / 2` are both 6 with integer division.
````

````exercise
id: m06-l05-e5
type: refactor
prompt: |
  These three functions differ in a single line. Rewrite them as one higher-order function that takes the test as a parameter, and show the three original calls rewritten with closures.
code: |
  func countEven(upTo limit: Int) -> Int {
      var total = 0
      for n in 1...limit {
          if n % 2 == 0 { total += 1 }
      }
      return total
  }

  func countOdd(upTo limit: Int) -> Int {
      var total = 0
      for n in 1...limit {
          if n % 2 != 0 { total += 1 }
      }
      return total
  }

  func countMultiplesOfFive(upTo limit: Int) -> Int {
      var total = 0
      for n in 1...limit {
          if n % 5 == 0 { total += 1 }
      }
      return total
  }

  print(countEven(upTo: 20), countOdd(upTo: 20), countMultiplesOfFive(upTo: 20))
rubric:
  - There's one function with a parameter of type (Int) -> Bool.
  - The loop and the counter appear only once.
  - The three calls use closures, at least one as a trailing closure.
  - The output is the same as the original, 10 10 4.
solution: |
  ```swift
  func count(upTo limit: Int, where test: (Int) -> Bool) -> Int {
      var total = 0
      for n in 1...limit {
          if test(n) { total += 1 }
      }
      return total
  }

  let even = count(upTo: 20, where: { n in n % 2 == 0 })
  let odd = count(upTo: 20) { n in n % 2 != 0 }
  let fives = count(upTo: 20) { n in n % 5 == 0 }
  print(even, odd, fives)
  ```

  ```output
  10 10 4
  ```

  The part that varied, the condition, became a parameter. Adding a fourth count (multiples of 3, say) is now one line at the call site instead of a new nine-line function. This is the same reasoning as in lesson 1, applied one level up: there you turned repeated *values* into parameters; here you turned a repeated *piece of logic* into one.
````

## Summary

- A function's type is its parameter types and return type: `(Int, Int) -> Int`, `() -> Void`. Labels aren't part of it.
- A function's name without parentheses is the function as a value. You can store it, choose it with a ternary and call it through a constant, without labels.
- A parameter with a function type lets the caller decide what one step of your function does. Functions that take functions are higher-order functions.
- A closure is an unnamed function: `{ (x: Int) -> Int in return x * 2 }`, shortened to `{ x in x * 2 }` when Swift can infer the types.
- When a closure is the last argument, write it after the parentheses as a trailing closure. Put function parameters last for that reason.
- Closures can capture surrounding values; that's Module 11.

---
id: m06-l01
title: Declaring and calling functions
description: You turn a named procedure from Module 2 into a Swift function with func, parameters and a return type, call it, and learn what happens when a function returns nothing.
module: m06
order: 1
level: beginner
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m05-l06]
objectives:
  - Explain why you'd wrap a piece of code in a function.
  - Declare a function with func, parameters and a return type.
  - Call a function and use its result in an expression.
  - Tell a parameter from an argument.
  - Write functions that return nothing (Void) and functions with an implicit return.
terms:
  - term: Function
    definition: A named block of code that receives zero or more values, does some work and can hand back a result. You declare it once and call it as many times as you need.
  - term: Parameter
    definition: A name in the function's declaration that stands for a value the function receives, like price in func itemCost(price:quantity:). Inside the body it behaves like a constant.
  - term: Argument
    definition: "The actual value you pass when you call the function, like 45 in itemCost(price: 45, quantity: 2)."
  - term: Return type
    definition: The type written after -> in the declaration. It says what kind of value the function hands back.
  - term: return
    definition: The statement that ends the function and hands a value back to the caller.
  - term: Void
    definition: The return type of a function that returns nothing. It's the same as the empty tuple, ().
  - term: Implicit return
    definition: When a function's body is a single expression, Swift returns that expression's value without writing return.
mastery:
  - Translate a pseudocode procedure with Input and Output into a Swift function.
  - Write a function's declaration from a description of what it receives and returns.
  - Trace by hand a program that calls the same function several times and predict its output.
  - Fix the "missing return" and "unexpected non-void return value" errors without the compiler's help.
resources: [swift-book-functions, swift-book-basics]
cards:
  - id: m06-l01-c1
    front: What's the difference between a parameter and an argument?
    back: "The parameter is the name in the declaration (price in func itemCost(price: Int, …)). The argument is the value you pass in a call (45 in itemCost(price: 45, …))."
  - id: m06-l01-c2
    front: "What does `-> Int` mean in `func square(_ n: Int) -> Int`?"
    back: The function returns a value of type Int. Every path through the body has to end in return with an Int.
  - id: m06-l01-c3
    front: What does a function without -> return?
    back: Void, which is the empty tuple (). It does its work (printing, for example) and hands nothing back.
  - id: m06-l01-c4
    front: When can you leave out the word return?
    back: "When the whole body is a single expression, like func square(_ n: Int) -> Int { n * n }. Swift returns that expression's value."
---

## The idea in one sentence

A function is a **named procedure**: you write the steps once, give them a name, and run them whenever you need them by calling that name.

## Why functions

In Module 2 you broke a shopping receipt into subproblems and noticed that "compute one item's cost" was used once per product. You called that a **procedure**: it receives a price and a quantity and returns a cost. In pseudocode:

```pseudo
Input: price, quantity
Output: the cost of that item

Return price × quantity
```

Without functions, the Swift version repeats the same calculation everywhere it's needed:

```swift
let coffeeCost = 45 * 2
let breadCost = 28 * 3
let juiceCost = 39 * 1
print(coffeeCost + breadCost + juiceCost)
```

```output
213
```

Here the calculation is a single multiplication, so the repetition looks harmless. Real procedures are ten or thirty lines long. Copy those three times and a fix to one copy doesn't reach the others. A function keeps the steps in **one place** and gives them a name that says what they do.

## Declaring a function

```swift
func itemCost(price: Int, quantity: Int) -> Int {
    return price * quantity
}

print(itemCost(price: 45, quantity: 2))
```

```output
90
```

Line by line:

1. `func` starts a function declaration.
2. `itemCost` is the function's name. Same conventions as variables: camelCase, starting lowercase. Functions *do* something, so their names often start with a verb or describe what they produce.
3. `(price: Int, quantity: Int)` is the **parameter list**. Each parameter has a name and a type, separated by a colon. These are the pseudocode's `Input:`.
4. `-> Int` is the **return type**: this function hands back an `Int`. It's the pseudocode's `Output:`.
5. The body goes between `{` and `}`. `return price * quantity` computes the value and hands it back. It's the pseudocode's `Return`.
6. `itemCost(price: 45, quantity: 2)` **calls** the function. `45` and `2` are the **arguments**: the actual values for this call. The `price:` and `quantity:` you write in the call are argument labels, which the next lesson covers in detail.

**Parameter or argument?** The parameter is the name in the declaration; the argument is the value in the call. `price` is a parameter. `45` is the argument passed for it. People mix the words up in conversation, but the difference matters when you read documentation and compiler errors.

## What happens during a call

When Swift reaches `itemCost(price: 45, quantity: 2)`:

1. It evaluates the arguments: `45` and `2`.
2. It jumps into the function's body, with `price` bound to 45 and `quantity` bound to 2.
3. It runs the body until it reaches `return`.
4. It jumps back to where the call was, and the call **is replaced by the returned value**, 90.

That last step is why a call can go anywhere an `Int` can go: in a `let`, inside another expression, as an argument to `print`, even as an argument to another call.

```swift
func itemCost(price: Int, quantity: Int) -> Int {
    return price * quantity
}

let coffeeCost = itemCost(price: 45, quantity: 2)
let total = coffeeCost + itemCost(price: 28, quantity: 3) + itemCost(price: 39, quantity: 1)
print("Coffee:", coffeeCost)
print("Total:", total)
print("Double order:", itemCost(price: itemCost(price: 45, quantity: 2), quantity: 2))
```

```output
Coffee: 90
Total: 213
Double order: 180
```

In the last line the inner call runs first and returns 90, which becomes the `price` of the outer call: `90 * 2 = 180`.

The parameters only exist **during** the call. Each call gets fresh values: the `price` in the second call has nothing to do with the `price` in the first.

## Functions that return nothing

Some functions do their work and have nothing to hand back. Printing a receipt line is a good example. You leave out the arrow and the return type:

```swift
func printLine(item: String, cost: Int) {
    print("\(item): \(cost)")
}

printLine(item: "Coffee", cost: 90)
printLine(item: "Bread", cost: 84)
```

```output
Coffee: 90
Bread: 84
```

A function without `->` has the return type **`Void`**. These three declarations mean exactly the same thing:

```swift illustrative
func printLine(item: String, cost: Int) { … }
func printLine(item: String, cost: Int) -> Void { … }
func printLine(item: String, cost: Int) -> () { … }
```

`Void` is another name for `()`, the empty tuple: a value that carries no information. You'll almost always see the first form. You can still write `return` with no value in a `Void` function to leave early, which lesson 3 uses with `guard`.

A function that returns nothing can't be used as a value in an expression. There's nothing to use: `let x = printLine(item: "Tea", cost: 30)` compiles, but `x` is just `()`, and Swift 6.3 warns you: "constant 'x' inferred to have type '()', which may be unexpected".

## Implicit return

When the body is **a single expression**, you can drop `return`:

```swift
func square(_ n: Int) -> Int {
    n * n
}

func isEven(_ n: Int) -> Bool {
    n % 2 == 0
}

print(square(7), isEven(7), isEven(10))
```

```output
49 false true
```

Both functions have a single expression as their body, and Swift returns its value. As soon as the body has two statements, for example a `let` and then a calculation, you need `return` again. The `_` before `n` means you call the function without a label: `square(7)` instead of `square(n: 7)`. The next lesson explains it.

Swift functions can be declared anywhere at the top level of a file, before or after the line that calls them. In the examples, the declaration goes first because it's easier to read.

## A practical example: the receipt, rebuilt

The shopping receipt again, split into calculation and presentation:

```swift
func itemCost(price: Int, quantity: Int) -> Int {
    price * quantity
}

func discountedTotal(subtotal: Int, discountPercent: Int) -> Int {
    let discount = subtotal * discountPercent / 100
    return subtotal - discount
}

func printLine(item: String, cost: Int) {
    print("\(item): \(cost)")
}

let coffee = itemCost(price: 45, quantity: 2)
let bread = itemCost(price: 28, quantity: 3)
let subtotal = coffee + bread

printLine(item: "Coffee x2", cost: coffee)
printLine(item: "Bread x3", cost: bread)
printLine(item: "Total with 10% off", cost: discountedTotal(subtotal: subtotal, discountPercent: 10))
```

```output
Coffee x2: 90
Bread x3: 84
Total with 10% off: 157
```

`174 * 10 / 100` is 17 with integer division, so the total is `174 - 17 = 157`. Notice the split: `itemCost` and `discountedTotal` compute and return numbers; only `printLine` knows that a console exists. If this receipt ever moves into an app screen, the two calculation functions come along unchanged.

`discountedTotal` has two statements, so it needs an explicit `return`. `itemCost` has one expression and doesn't.

## Common mistakes

> [!error] error: missing return in global function expected to return 'Int'
> The function promises an `Int` with `-> Int`, but some path through the body reaches the closing `}` without a `return`. A common cause is an `if` that returns, with nothing after it for the other case. Swift 6.3 reports it like this:

```swift no-compile missing return in global function expected to return 'Int'
func sign(_ n: Int) -> Int {
    if n >= 0 {
        return 1
    }
}
```

The fix is to make every path return: add `return -1` after the `if`, or use an `else`.

> [!error] error: non-void function should return a value
> You wrote `return` with nothing after it in a function that has a return type. Write the value: `return total`.

```swift no-compile non-void function should return a value
func total() -> Int {
    return
}
```

> [!error] error: unexpected non-void return value in void function
> The opposite: the function has no `->`, so it returns `Void`, but the body tries to return a value. Either add the return type or remove the value.

```swift no-compile unexpected non-void return value in void function
func double(_ n: Int) {
    return n * 2
}
```

> [!warning] warning: result of call to 'double' is unused
> You called a function that returns a value and threw the value away. The program compiles and runs, but the call did nothing useful. Usually you meant `let doubled = double(4)` or `print(double(4))`.

```swift warning result of call to 'double' is unused
func double(_ n: Int) -> Int {
    n * 2
}

double(4)
print("The result went nowhere")
```

```output
The result went nowhere
```

> [!error] Printing instead of returning
> A function that `print`s its answer instead of returning it can't be used in a calculation. If a caller might need the value, return it and let the caller decide whether to print it.

````exercise
id: m06-l01-e1
type: comprehension
prompt: |
  In this code, which of these is an **argument**?

  ```swift
  func area(width: Int, height: Int) -> Int {
      width * height
  }
  let room = area(width: 4, height: 3)
  ```
choices:
  - text: "`width`"
    correct: false
    why: width is a parameter, a name in the declaration.
  - text: "`Int` after the arrow"
    correct: false
    why: That's the return type.
  - text: "`4`"
    correct: true
    why: It's the value passed for width in this particular call.
  - text: "`room`"
    correct: false
    why: room is a constant that stores the returned value, 12.
solution: |
  **`4`.** Arguments are the actual values you pass in a call; `4` and `3` are the arguments here. `width` and `height` are parameters: names in the declaration that get those values during the call. `-> Int` is the return type, and `room` is a constant that ends up holding `12`.
````

````exercise
id: m06-l01-e2
type: prediction
prompt: Predict the exact output, line by line. Follow each call into the body before you move on.
code: |
  func triple(_ n: Int) -> Int {
      n * 3
  }

  func announce(_ value: Int) {
      print("Value:", value)
  }

  let a = triple(4)
  announce(a)
  announce(triple(a) - 30)
  print(triple(triple(1)))
  announce(a % 5)
output: |
  Value: 12
  Value: 6
  9
  Value: 2
hints:
  - "a is 12. triple(a) is 36."
  - "triple(triple(1)): the inner call runs first."
solution: |
  ```output
  Value: 12
  Value: 6
  9
  Value: 2
  ```

  1. `a = triple(4) = 12`. `announce(a)` prints `Value: 12`.
  2. `triple(a)` is 36; `36 - 30 = 6` is the argument to `announce`.
  3. `triple(1)` is 3, and `triple(3)` is 9. `print` shows it directly, without the "Value:" prefix.
  4. `12 % 5` is 2.

  Notice that `announce` returns nothing: it's only ever used as a statement on its own line, never inside an expression.
````

````exercise
id: m06-l01-e3
type: fill-in
prompt: |
  Complete the function so the program prints `Perimeter: 14`.
code: |
  [[1]] perimeter(width: Int, height: Int) [[2]] Int {
      [[3]] 2 * (width + height)
  }
  print("Perimeter:", perimeter(width: 4, height: 3))
blanks:
  - id: "1"
    answers: ["func"]
  - id: "2"
    answers: ["->"]
  - id: "3"
    answers: ["return"]
solution: |
  ```swift
  func perimeter(width: Int, height: Int) -> Int {
      return 2 * (width + height)
  }
  print("Perimeter:", perimeter(width: 4, height: 3))
  ```

  ```output
  Perimeter: 14
  ```

  `func` starts the declaration, `->` introduces the return type, and `return` hands back `2 * (4 + 3) = 14`. Since the body is a single expression, `return` is optional here, so leaving the third blank empty would also compile.
````

````exercise
id: m06-l01-e4
type: find-errors
prompt: This program should print the average of three test scores. It doesn't compile. Pick out the real problems, then write the fixed version.
code: |
  func average(a: Int, b: Int, c: Int) {
      let sum = a + b + c
      return sum / 3
  }

  func showScore(score: Int) -> Int {
      print("Average:", score)
  }

  showScore(score: average(a: 80, b: 90, c: 70))
choices:
  - text: "average returns a value but its declaration has no return type."
    correct: true
    why: "Without ->, the function returns Void, so return sum / 3 is rejected with unexpected non-void return value in void function."
  - text: "showScore promises an Int with -> Int but never returns one."
    correct: true
    why: "It only prints. Swift reports missing return in global function expected to return 'Int'. Since it has nothing to hand back, remove -> Int."
  - text: "You can't pass the result of one function call as an argument to another."
    correct: false
    why: A call is replaced by its value, so it can go anywhere a value of that type can.
  - text: "average needs return on both lines of its body."
    correct: false
    why: Only the last line hands back a value. The let just stores an intermediate result.
rubric:
  - I added -> Int to average.
  - I removed -> Int from showScore, because it has nothing to return.
  - My version compiles and prints Average 80.
solution: |
  ```swift
  func average(a: Int, b: Int, c: Int) -> Int {
      let sum = a + b + c
      return sum / 3
  }

  func showScore(score: Int) {
      print("Average:", score)
  }

  showScore(score: average(a: 80, b: 90, c: 70))
  ```

  ```output
  Average: 80
  ```

  The two errors are mirror images. `average` computes something and must declare what it returns. `showScore` only prints, so it returns `Void` and its declaration has no arrow. `240 / 3` is exactly 80, so integer division loses nothing here.
````

````exercise
id: m06-l01-e5
type: solve
prompt: |
  Write a function `secondsIn(hours:)` that receives a number of hours and **returns** how many seconds that is. Then use it to print:

  ```output
  1 hour: 3600 seconds
  A day: 86400 seconds
  A week: 604800 seconds
  ```

  The function must not print anything itself. For the week, call the function rather than multiplying the day by 7 by hand.
starter: |
  func secondsIn(hours: Int) -> Int {
      // your code
  }
hints:
  - "An hour has 60 minutes and a minute has 60 seconds."
  - "A week is 24 * 7 hours."
  - Use interpolation to build each line.
rubric:
  - The function returns an Int and doesn't print.
  - The three lines match exactly.
  - Every number of seconds comes from a call to secondsIn, not from a hand-written result.
  - I used named constants or a clear expression instead of unexplained numbers.
solution: |
  ```swift
  func secondsIn(hours: Int) -> Int {
      let secondsPerMinute = 60
      let minutesPerHour = 60
      return hours * minutesPerHour * secondsPerMinute
  }

  print("1 hour: \(secondsIn(hours: 1)) seconds")
  print("A day: \(secondsIn(hours: 24)) seconds")
  print("A week: \(secondsIn(hours: 24 * 7)) seconds")
  ```

  ```output
  1 hour: 3600 seconds
  A day: 86400 seconds
  A week: 604800 seconds
  ```

  The function has a single job, converting hours to seconds, and returns the result so the caller decides what to do with it. An interpolation can hold a whole call: `\(secondsIn(hours: 24))` is evaluated and its value inserted into the text. The body has three statements, so `return` is required.
````

````exercise
id: m06-l01-e6
type: refactor
prompt: |
  This program converts three temperatures from Celsius to Fahrenheit. The formula is repeated three times. Rewrite it with a function so the formula appears once, and keep the output identical.
code: |
  print("0°C =", 0 * 9 / 5 + 32, "°F")
  print("25°C =", 25 * 9 / 5 + 32, "°F")
  print("100°C =", 100 * 9 / 5 + 32, "°F")
rubric:
  - The formula appears exactly once, inside a function.
  - The function returns the value and doesn't print.
  - The output is the same as the original.
  - The function and parameter names say what they mean.
solution: |
  ```swift
  func fahrenheit(fromCelsius celsius: Int) -> Int {
      celsius * 9 / 5 + 32
  }

  print("0°C =", fahrenheit(fromCelsius: 0), "°F")
  print("25°C =", fahrenheit(fromCelsius: 25), "°F")
  print("100°C =", fahrenheit(fromCelsius: 100), "°F")
  ```

  ```output
  0°C = 32 °F
  25°C = 77 °F
  100°C = 212 °F
  ```

  If you find a mistake in the formula now, you fix it once. Watch the order of operations with integers: `25 * 9 / 5` is `225 / 5 = 45`, which is exact. Writing `9 / 5 * 25` would compute `9 / 5 = 1` first and give a wrong answer. The `fromCelsius celsius` part gives the parameter a label for the caller and a different name inside the body; the next lesson covers that. `fahrenheit(celsius: Int)` is a fine answer too.
````

## Summary

- A function is a named procedure: `func name(parameter: Type) -> ReturnType { body }`.
- Parameters are the names in the declaration; arguments are the values in the call.
- A call jumps into the body, runs it until `return`, and is replaced by the returned value.
- Without `->`, a function returns `Void` (the empty tuple `()`) and is used as a statement on its own.
- A body that's a single expression returns that expression without writing `return`.
- Keep calculation in functions that return values, and printing in separate functions.

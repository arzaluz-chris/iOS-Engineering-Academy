---
id: m04-l06
title: "String interpolation and special characters"
description: You insert values and expressions into text with \( ), write quotes, line breaks and emoji with escape sequences, and build multi-line text. You close the module by writing a complete receipt.
module: m04
order: 6
level: beginner
minutes: 45
prerequisites: [m04-l04, m04-l05]
codeStatus: tested
swiftVersion: "6.4"
objectives:
  - Insert constants, variables and expressions into a String with interpolation.
  - Choose between interpolation, concatenation with + and passing several values to print.
  - Use the escape sequences \", \\, \n, \t and \u{…}.
  - Write multi-line literals with triple quotes and control their indentation.
  - Recognize and avoid interpolating an optional.
terms:
  - term: String
    definition: Swift's type for text. A String literal is written between double quotes.
  - term: Interpolation
    definition: Inserting the value of an expression into a text literal by writing \(expression). It works with values of any type.
  - term: Concatenation
    definition: Joining two pieces of text with the + operator. Both sides have to be String.
  - term: Escape sequence
    definition: A combination starting with \ inside a piece of text that stands for a special character, like \n (line break) or \" (double quote).
  - term: Multi-line literal
    definition: Text delimited by three double quotes at the start and at the end, which can span several lines of code.
  - term: Raw string literal
    definition: Text delimited with # around the quotes, like #"C:\folder"#, in which \ doesn't start escape sequences.
mastery:
  - Rewrite a program that uses String(…) and + so it uses interpolation, with the same output.
  - Predict the output of text containing \(…), \n and \", including arithmetic expressions inside the interpolation.
  - Write a multi-line literal whose inner indentation is controlled by the position of the closing quotes.
  - Explain why "\(Int("30"))" shows Optional(30) and how to avoid it.
resources: [swift-book-strings, swift-book-basics, swift-print]
cards:
  - id: m04-l06-c1
    front: How do you insert the value of `total` into a piece of text?
    back: With interpolation, "Total \(total)". It works with any type and with expressions, like "\(a + b)".
  - id: m04-l06-c2
    front: Which escape sequences write a double quote, a backslash, a line break and a tab?
    back: \" for a double quote, \\ for a backslash, \n for a line break and \t for a tab.
  - id: m04-l06-c3
    front: In a multi-line literal, what decides how much indentation is removed?
    back: The indentation of the closing quotes. That many spaces are removed from each line; anything further to the right is kept.
  - id: m04-l06-c4
    front: Why does `"Age \(Int("30"))"` show `Optional(30)`?
    back: Int("30") is an Int?, and interpolation shows the optional's description. The compiler warns about it. Use Int("30") ?? 0 before interpolating.
---

## The idea in one sentence

Interpolation writes a value **inside** a piece of text: `"Total: \(total)"`. It's the normal way to combine text and data in Swift.

## The problem it solves

Since the first lesson of the module, you've known this doesn't compile:

```swift no-compile binary operator '+' cannot be applied to operands of type 'String' and 'Int'
let total = 73
print("Total: " + total)
```

Until now you had two ways around it: `print` with several values, or converting with `String(…)`:

```swift
let total = 73
print("Total:", total)
print("Total: " + String(total) + " dollars")
```

```output
Total: 73
Total: 73 dollars
```

The first one only works inside `print`. The second works anywhere, but with several values it fills up with `+` and `String(…)`.

## Interpolation

**Plain definition:** writing `\(something)` inside a piece of text so the value of `something` shows up there.

**Precise definition:** inside a `String` literal, the sequence `\(expression)` evaluates the expression, turns its result into text and inserts it at that spot. The expression can be of any type.

```swift
let name = "Ana"
let age = 30
let message = "Hi, \(name). You're \(age) years old."
print(message)
print("Next year you'll be \(age + 1).")
```

```output
Hi, Ana. You're 30 years old.
Next year you'll be 31.
```

Line by line:

1. and 2. Two constants, a `String` and an `Int`.
3. `\(name)` is replaced with `Ana` and `\(age)` with `30`. The result is an ordinary `String`, stored in `message`.
4. It prints like any other text.
5. An **expression** can go inside `\( )`: `age + 1` is calculated first.

No conversion needed: interpolation works the same with `Int`, `Double`, `Bool` or any other type.

```swift
let price = 45.5
let isAvailable = true
print("Price: \(price), available: \(isAvailable), division: \(7 / 2)")
```

```output
Price: 45.5, available: true, division: 3
```

The type rules still apply inside: `7 / 2` between integers is still 3.

### Interpolation, +, or several values in print?

| Form | When to use it |
| --- | --- |
| `"Total: \(total)"` | Almost always. It works anywhere, with any type, and reads like the final text |
| `"Hello " + name` | To join two pieces of text that are already `String`s |
| `print("Total:", total)` | For a quick print while you're trying something out |

## Escape sequences

Some characters can't be typed as-is inside the quotes. You write them with a **backslash** `\`:

| You write | You get |
| --- | --- |
| `\"` | a double quote |
| `\\` | a backslash |
| `\n` | a line break |
| `\t` | a tab |
| `\u{1F600}` | the Unicode character with that hex code, here 😀 |

```swift
print("She said: \"hi\"")
print("Path: C:\\Users")
print("Line 1\nLine 2")
print("\u{00E9} \u{1F600}")
```

```output
She said: "hi"
Path: C:\Users
Line 1
Line 2
é 😀
```

In practice you type `é` and 😀 straight into the code. `\u{…}` is for when a character can't be typed or can't be seen, like a special space.

> [!note]
> Interpolation `\( )` also starts with `\`. So if you want to write a literal `\(` in a piece of text, you need `\\(`.

## Multi-line text

For long text, use three double quotes:

```swift
let receipt = """
    Central Café
      Coffee     45
      Bread      28
    Thanks for coming
    """
print(receipt)
```

```output
Central Café
  Coffee     45
  Bread      28
Thanks for coming
```

The rules:

1. The three opening quotes go at the end of their line; the text starts on the next line.
2. The three closing quotes go on their own line.
3. The **indentation of the closing quotes** is removed from every line. Here it's four spaces. Anything further to the right, like the two extra spaces before Coffee and Bread, is kept.
4. Interpolation and escapes work inside, and you can write `"` without escaping it.

If a line in the code ends with `\`, the line break isn't included in the text. That lets you split a long line in the code without splitting it in the output.

### Raw string literals

With `#` around the quotes, `\` stops being special. Handy for Windows paths or regular expressions:

```swift
print(#"Path: C:\folder and "quotes""#)
```

```output
Path: C:\folder and "quotes"
```

Inside a raw string literal, interpolation is written `\#(value)`.

## Interpolating an optional

```swift warning string interpolation produces a debug description for an optional value
let age = Int("30")
print("Age: \(age)")
```

```output
Age: Optional(30)
```

`Int("30")` is an `Int?` (from the conversions lesson). Interpolation shows its debug description, `Optional(30)`, which a user should never see, and the compiler warns about it. Deal with the `nil` case before you interpolate:

```swift
let age = Int("30") ?? 0
print("Age: \(age)")
```

```output
Age: 30
```

## A practical example: a receipt

This program pulls the whole module together: constants, variables, types, conversions, comparisons and interpolation.

```swift
let customer = "Mariana"
let coffeePrice = 45
let breadPrice = 28
let coffeeCount = 2
let isBirthday = true

var total = coffeePrice * coffeeCount + breadPrice
let discount = isBirthday ? 20 : 0
total -= discount
let totalWithTip = Double(total) * 1.10

let receipt = """
    Customer: \(customer)
    Coffees: \(coffeeCount) × \(coffeePrice) = \(coffeeCount * coffeePrice)
    Bread: \(breadPrice)
    Birthday discount: \(discount)
    Total: \(total)
    Total with 10% tip: \(Int(totalWithTip.rounded()))
    Paid more than 100?: \(total > 100)
    """
print(receipt)
```

```output
Customer: Mariana
Coffees: 2 × 45 = 90
Bread: 28
Birthday discount: 20
Total: 98
Total with 10% tip: 108
Paid more than 100?: false
```

One new piece: `isBirthday ? 20 : 0` is the **ternary conditional operator**: if the condition is true, its value is what comes after `?`; if not, what comes after `:`. You'll study it alongside `if` in the next module.

Look at the tip: 98 × 1.10 in `Double` isn't exactly 107.8, which is why it's rounded before it's shown.

## Common mistakes

> [!error] error: binary operator '+' cannot be applied to operands of type 'String' and 'Int'
> Use interpolation: `"Total: \(total)"`.

> [!error] error: cannot find ')' to match opening '(' in string interpolation
> The parenthesis of `\( )` isn't closed. It usually comes along with `unterminated string literal`.

> [!error] error: multi-line string literal content must begin on a new line
> You wrote text on the same line as the three opening quotes. The content starts on the next line.

> [!error] Seeing Optional(…) in a piece of text
> You interpolated an optional. Deal with it first using `?? defaultValue`.

> [!error] Forgetting the backslash
> `"Total: (total)"` prints `(total)` literally. Interpolation needs `\(`.

````exercise
id: m04-l06-e1
type: comprehension
prompt: |
  What does this program print?

  ```swift
  let a = 4
  let b = 6
  print("\(a) + \(b) = \(a + b)")
  ```
choices:
  - text: "`4 + 6 = 10`"
    correct: true
    why: Each \( ) is replaced by its value; the + outside is just text.
  - text: "`a + b = a + b`"
    correct: false
    why: Without \( ) the names would be printed; with \( ) they're evaluated.
  - text: "`4 + 6 = 4 + 6`"
    correct: false
    why: The third interpolation contains an expression, and it gets calculated.
  - text: It doesn't compile because it mixes text and numbers.
    correct: false
    why: Interpolation accepts values of any type.
solution: |
  It prints **`4 + 6 = 10`**. Outside `\( )`, the `+` and `=` characters are part of the text. Inside, `a + b` is an expression that gets evaluated. Interpolation turns each result into text, so there's no type problem.
````

````exercise
id: m04-l06-e2
type: prediction
prompt: Predict the exact output, line by line.
code: |
  let name = "Ana"
  let points = 7
  let bonus = 3
  print("\(name) has \(points + bonus) points")
  print("Average: \(Double(points) / 2)")
  print("Said: \"done\"")
  print("One\nTwo")
  var greeting = "Hello"
  greeting += ", \(name)!"
  print(greeting)
  print("Won? \(points + bonus >= 10)")
output: |
  Ana has 10 points
  Average: 3.5
  Said: "done"
  One
  Two
  Hello, Ana!
  Won? true
hints:
  - "\\n inside a piece of text produces a line break: one print, two lines."
  - "+= works with String too: it adds text to the end."
solution: |
  ```output
  Ana has 10 points
  Average: 3.5
  Said: "done"
  One
  Two
  Hello, Ana!
  Won? true
  ```

  1. `points + bonus` is evaluated: 10.
  2. `Double(7) / 2` is 3.5.
  3. `\"` produces a double quote inside the text.
  4. `\n` splits the text into two lines.
  5. `greeting += …` appends to the end of the variable.
  6. The comparison `10 >= 10` is `true`, and it's interpolated as text.
````

````exercise
id: m04-l06-e3
type: fill-in
prompt: |
  Complete the program so it prints exactly:

  ```output
  Product: "Headphones"
  Price: 899.5
  ```
code: |
  let product = "Headphones"
  let price = 899.5
  print("Product: [[1]]\(product)[[2]]")
  print("Price: [[3]](price)")
blanks:
  - id: "1"
    answers: ["\\\""]
  - id: "2"
    answers: ["\\\""]
  - id: "3"
    answers: ["\\"]
solution: |
  ```swift
  let product = "Headphones"
  let price = 899.5
  print("Product: \"\(product)\"")
  print("Price: \(price)")
  ```

  ```output
  Product: "Headphones"
  Price: 899.5
  ```

  `\"` writes a double quote inside the text. You need two, in blanks 1 and 2, before and after the name. `\(` starts the interpolation: without the backslash, `(price)` would be printed literally.
````

````exercise
id: m04-l06-e4
type: refactor
prompt: Rewrite this program with interpolation. The output has to be identical, with no `String(…)` and no `+` between pieces of text left over.
code: |
  let city = "Austin"
  let temperature = 23
  let humidity = 0.45
  print("It's " + String(temperature) + " degrees in " + city + ".")
  print("Humidity: " + String(Int(humidity * 100)) + "%")
rubric:
  - The output is identical to the original.
  - There's no + between pieces of text and no String(…) left.
  - The expressions are calculated inside the interpolation or in named constants.
solution: |
  ```swift
  let city = "Austin"
  let temperature = 23
  let humidity = 0.45
  print("It's \(temperature) degrees in \(city).")
  print("Humidity: \(Int(humidity * 100))%")
  ```

  ```output
  It's 23 degrees in Austin.
  Humidity: 45%
  ```

  Interpolation reads like the final text. The `Int(…)` conversion stays because `humidity * 100` is a `Double` (45.0) and you want to show `45`, not `45.0`. If the expression inside `\( )` gets long, pull it out into a named constant, like `let humidityPercent = Int(humidity * 100)`.
````

````exercise
id: m04-l06-e5
type: solve
prompt: |
  Using these constants, write a program that prints the business card exactly as shown, using **a single** multi-line literal with interpolation.

  ```swift
  let name = "Christian"
  let role = "iOS Engineer"
  let yearsOfExperience = 1
  let usesSwiftUI = true
  ```

  ```output
  +--------------------------+
  | Christian
  | iOS Engineer
  | Experience: 1 year(s)
  | SwiftUI?: true
  +--------------------------+
  ```
starter: |
  let name = "Christian"
  let role = "iOS Engineer"
  let yearsOfExperience = 1
  let usesSwiftUI = true
hints:
  - "The closing quotes decide how much indentation is removed. Line them up with the start of the lines."
  - "You can write \"(s)\" as-is; only \\( starts an interpolation."
rubric:
  - I used a single multi-line literal.
  - I interpolated all four constants.
  - The output matches character for character, with no leftover indentation.
solution: |
  ```swift
  let name = "Christian"
  let role = "iOS Engineer"
  let yearsOfExperience = 1
  let usesSwiftUI = true

  let card = """
      +--------------------------+
      | \(name)
      | \(role)
      | Experience: \(yearsOfExperience) year(s)
      | SwiftUI?: \(usesSwiftUI)
      +--------------------------+
      """
  print(card)
  ```

  ```output
  +--------------------------+
  | Christian
  | iOS Engineer
  | Experience: 1 year(s)
  | SwiftUI?: true
  +--------------------------+
  ```

  The closing quotes are indented four spaces, so Swift removes four spaces from every line and the text sits flush against the margin. `year(s)` isn't interpolation because the parenthesis isn't preceded by `\`. Choosing between "year" and "years" based on the number is a decision, an `if`, which you'll see in the next module.
````

## Summary

- `"Text \(expression)"` inserts the value of any expression, of any type. It's the normal way to combine text and data.
- `+` joins pieces of text that are already `String`s; `print` with several values is for quick checks.
- Escapes: `\"`, `\\`, `\n`, `\t`, `\u{…}`.
- `"""` creates multi-line text; the indentation of the closing quotes is removed from every line.
- `#"…"#` creates a raw string where `\` isn't special.
- Don't interpolate optionals: deal with them first using `??`.

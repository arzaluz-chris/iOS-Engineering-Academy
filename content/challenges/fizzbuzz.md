---
id: fizzbuzz
title: FizzBuzz
difficulty: easy
order: 1
patterns: [Linear scan, Conditionals]
prerequisites: [m05, m07]
summary: The classic interview screener. Easy to solve, and just as easy to get wrong if you don't watch the order of your conditions.
solutionFile: FizzBuzz.swift
testFile: FizzBuzzTests.swift
starter: |
  func fizzBuzz(_ n: Int) -> [String] {
      // Your solution
      return []
  }
time: O(n)
space: O(n) for the result list
edgeCases:
  - n equal to 1
  - n equal to 0 or negative
  - Multiples of 15
askInterviewer:
  - Do I return a list or print each line?
  - What should happen if n is 0 or negative?
  - Does the range include n?
hints:
  - A multiple of 15 is a multiple of both 3 and 5. What happens if you check "multiple of 3" first?
  - "`i % 3 == 0` means `i` is a multiple of 3."
followUps:
  - How would you extend it so the rules (3 → Fizz, 5 → Buzz, 7 → Bazz) can be configured without changing the function?
  - What changes if n can be a billion? Think about memory and about producing the values lazily.
  - How would you test it without writing out all 100 expected values?
rubric:
  - Multiples of 15 produce FizzBuzz, not just Fizz.
  - I handled n less than 1 without crashing.
  - I mentioned the O(n) complexity.
codeStatus: tested
---

Write a function that takes an integer `n` and returns a list of strings, one for each number from 1 to `n` inclusive:

- If the number is a multiple of both 3 and 5: `"FizzBuzz"`.
- If it's only a multiple of 3: `"Fizz"`.
- If it's only a multiple of 5: `"Buzz"`.
- Otherwise: the number as text, for example `"7"`.

If `n` is less than 1, return an empty list.

```swift
fizzBuzz(5)  // ["1", "2", "Fizz", "4", "Buzz"]
```

**Constraints:** `-10^4 ≤ n ≤ 10^4`.

<!-- reveal -->

## First approach

Loop from 1 to `n` and decide what to append on each pass. The only real difficulty is the **order of the conditions**: 15 matches two rules at once, so it has to be checked before either rule on its own.

## Naive solution

```swift
func fizzBuzz(_ n: Int) -> [String] {
    var result: [String] = []
    for i in 1...n {
        if i % 3 == 0 {
            result.append("Fizz")
        } else if i % 5 == 0 {
            result.append("Buzz")
        } else if i % 15 == 0 {
            result.append("FizzBuzz")
        } else {
            result.append(String(i))
        }
    }
    return result
}
```

## Problems with the naive solution

- **The FizzBuzz case never happens.** For 15, the first condition (`i % 3 == 0`) is already true, so it appends `"Fizz"`. The `else if` for 15 is dead code.
- **It crashes when n is less than 1.** `1...n` with `n = 0` is an invalid range: Swift stops the program at runtime, because the lower bound can't be greater than the upper bound.

## Optimized solution

Check the combined case first. Better still, evaluate both conditions once and decide with a `switch` on the pair. That way the compiler checks that you covered all four combinations.

## Line by line

- `guard n >= 1 else { return [] }`: protects the `1...n` range, which can't handle `n < 1`.
- `reserveCapacity(n)`: allocates memory once. It doesn't change the complexity, but it avoids reallocations. It's a detail worth saying out loud.
- `let divisibleBy3 = i % 3 == 0`: computes each condition once and gives it a name.
- `switch (divisibleBy3, divisibleBy5)`: a `switch` on a tuple of two `Bool`s. All four combinations are written out, and Swift requires the `switch` to be exhaustive, so forgetting a case is a compile error.
- `String(i)`: turns the integer into text.

## Common mistakes

- Checking "multiple of 3" before "multiple of 15".
- Using `0...n` and producing an extra line for 0.
- Forgetting that `1...n` with `n` less than 1 crashes the program.

## Variation

Generalize the rules: take a list of `(divisor, word)` pairs and concatenate the words for every divisor that matches. With `[(3, "Fizz"), (5, "Buzz")]` you get classic FizzBuzz; adding `(7, "Bazz")` adds a rule without touching the function.

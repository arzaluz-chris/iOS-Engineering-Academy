---
id: readings-without-separators
title: Readings Without Separators
difficulty: medium
order: 91
patterns: [1-D dynamic programming over suffixes, Counting splits]
prerequisites: [m20-l03, m20-l04]
summary: Count the ways a run of digits can be read as a list of numbers up to a limit. The decoder from Module 20 with a limit of any size and a modulus.
solutionFile: ReadingsWithoutSeparators.swift
testFile: ReadingsWithoutSeparatorsTests.swift
starter: |
  func countReadings(_ digits: String, maxValue: Int) -> Int {
      // Your solution
      return 0
  }
time: O(n · d), where d is the number of digits in maxValue
space: O(n)
edgeCases:
  - A string that starts with 0 (no way to read it)
  - Zeros in the middle, which have to be part of the number before them
  - A single digit larger than maxValue
  - maxValue at its upper limit, 10^9
  - Long strings, where the count needs the modulus
askInterviewer:
  - Can a number be 0, or have leading zeros?
  - Is maxValue inclusive?
  - How long can the string be, and should the count be returned modulo something?
  - Is the empty string possible, and what should it return?
hints:
  - Let ways[i] be the number of ways to read the digits from position i to the end. What's the first number in any reading of that suffix?
  - The first number is digits i through some end. Which ends are allowed, and how many are there at most?
  - Build the number one digit at a time as you move the end forward, and stop as soon as it exceeds maxValue.
followUps:
  - Return one valid reading, or all of them for short inputs.
  - What if the minimum value is also a parameter?
  - Can you make the space O(d) instead of O(n)?
rubric:
  - I defined ways[i] over suffixes with ways[n] = 1.
  - I rejected numbers with a leading zero.
  - I built the number incrementally and stopped the inner loop as soon as it exceeded maxValue, giving O(n · d).
  - I applied the modulus at every addition.
codeStatus: tested
---

A sensor logs integer readings, each between 1 and `maxValue`, written in decimal with no leading zeros. A firmware bug dropped the separators, so the log is just a run of digits. Return how many different lists of readings could have produced it, **modulo 1,000,000,007**.

```swift
countReadings("1225", maxValue: 26)     // 5: 1 2 2 5, 12 2 5, 1 22 5, 1 2 25, 12 25
countReadings("123", maxValue: 1000)    // 4: 1 2 3, 12 3, 1 23, 123
countReadings("1000", maxValue: 100)    // 0: "100" leaves "0", and 0 isn't a reading
```

**Constraints:** `1 ≤ digits.count ≤ 10^5`; `digits` contains only ASCII digits; `1 ≤ maxValue ≤ 10^9`.

<!-- reveal -->

## First approach

Every reading of the suffix that starts at `i` begins with one number: the digits from `i` to some `end`. That number can't start with 0 and can't be larger than `maxValue`, and once it's chosen, the rest is a reading of the suffix starting at `end + 1`. Different first numbers give different readings, so the counts add up. With `maxValue = 26` this is exactly the decoder from Module 20, lessons 3 and 4. The new part is that the first number can be up to ten digits long.

## Naive solution

Try every possible first number and recurse:

```swift
func countReadings(_ digits: String, maxValue: Int) -> Int {
    let characters = Array(digits)
    func ways(from start: Int) -> Int {
        guard start < characters.count else { return 1 }
        guard characters[start] != "0" else { return 0 }
        var total = 0
        for end in start..<characters.count {
            guard let number = Int(String(characters[start...end])), number <= maxValue else { break }
            total += ways(from: end + 1)
        }
        return total
    }
    return ways(from: 0)
}
```

## Problems with the naive solution

The number of calls is the number of readings, which grows exponentially: a run of `1`s with `maxValue = 11` already grows like Fibonacci. The same suffix is counted again for every way of reading the part before it. It also builds a `String` and parses an `Int` for every candidate, and without a modulus the total overflows long before the input gets long.

## Optimized solution

Fill `ways` from the end. `ways[n] = 1`: the empty suffix has one reading, the empty list. For each `start` whose digit isn't 0, extend `end` one digit at a time, updating `number = number * 10 + digit`. While `number ≤ maxValue`, add `ways[end + 1]`. As soon as it's bigger, stop: adding digits only makes it bigger. Positions that start with 0 keep `ways[start] = 0`.

## Line by line

- `let values = digits.map { $0.wholeNumberValue! }`: one `Int` per digit, so the loop does arithmetic instead of parsing strings.
- `ways[count] = 1`: the base case for the empty suffix.
- `for start in stride(from: count - 1, through: 0, by: -1) where values[start] != 0`: right to left, because `ways[start]` reads larger indexes. A leading zero is skipped and its entry stays 0.
- `number = number * 10 + values[end]`: the first number grows by one digit per step. It's at most `maxValue` before the multiplication, so it stays below 10^10 + 9: no overflow.
- `if number > maxValue { break }`: this runs at most `d + 1` times per start, which is what makes the whole loop O(n · d).
- `total = (total + ways[end + 1]) % modulus`: reduce at every addition so `total` never grows past twice the modulus.
- `return ways[0]`: the count for the whole string.

## Common mistakes

- Allowing a number that starts with 0, like reading `"07"` as 7.
- Forgetting to stop the inner loop and walking to the end of the string for every start: O(n²).
- Applying the modulus only at the end, after the counts have already overflowed.
- Setting `ways[n] = 0`, which makes every count 0.

## Variation

**O(d) space:** `ways[start]` reads only `ways[start + 1]` through `ways[start + d + 1]`, so a ring buffer of `d + 2` entries indexed by position modulo `d + 2` is enough. Worth it only when the input is a stream too long to hold.

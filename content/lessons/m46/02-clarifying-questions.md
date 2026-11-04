---
id: m46-l02
title: Clarifying questions and examples
description: You learn which questions to ask before solving a coding problem (input size, value range, duplicates, empty input, ordering, mutation and what a "character" means in a Swift String), see how each answer changes the code or the complexity you're allowed, and turn the answers into a list of test cases you'll use later to trace your solution.
module: m46
order: 2
level: intermediate
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m46-l01]
objectives:
  - Ask clarifying questions about size, range, duplicates, empty input, ordering, mutation and Unicode, and say why each one matters.
  - Translate an input size into the complexity a solution can afford.
  - Explain how Character, Unicode scalars and UTF-8 bytes count the same String differently.
  - Turn every clarifying answer into a concrete test case with an expected result.
terms:
  - term: Clarifying question
    definition: A question about the problem's inputs, outputs or constraints whose answer changes the solution. Asked before designing anything.
  - term: Grapheme cluster
    definition: What a reader sees as one character. Swift's Character is one extended grapheme cluster, which can be made of several Unicode scalars (like "e" plus a combining accent, or a flag).
  - term: Unicode scalar
    definition: One Unicode code point, such as U+0065 (e) or U+0301 (combining acute accent). A String's unicodeScalars view walks them one by one.
  - term: Canonical equivalence
    definition: Two different scalar sequences that mean the same text, like the single scalar é and e followed by a combining accent. Swift's String comparison treats them as equal.
  - term: Precondition
    definition: Something the function assumes about its input and doesn't check, such as "the word is lowercase ASCII". State it out loud when the interviewer agrees to it.
mastery:
  - Ask at least five relevant clarifying questions for a new problem without a checklist in front of you.
  - Explain how a constraint like n ≤ 10⁵ rules out an O(n²) solution.
  - Predict count, unicodeScalars.count and utf8.count for a short string with an accent or a flag.
  - Write a list of test cases where every case traces back to a clarifying answer or an edge case.
resources: [swift-book-strings, swift-dictionary, swift-set, swift-array]
cards:
  - id: m46-l02-c1
    front: Which clarifying questions apply to almost every array problem?
    back: "How big can it be? What range are the values? Can there be duplicates? Can it be empty, and what do I return then? Is it sorted, and does the output order matter? May I modify the input?"
  - id: m46-l02-c2
    front: Why ask about input size first?
    back: "It sets the complexity budget. Around 10⁵ elements rules out O(n²) (about 10¹⁰ steps); around 20 allows exponential search over subsets."
  - id: m46-l02-c3
    front: "\"cafe\\u{301}\" (e plus a combining accent): count, unicodeScalars.count, utf8.count?"
    back: "4, 5 and 6. Swift counts the accented e as one Character, but it's two scalars, and the accent takes two UTF-8 bytes. It also compares equal to \"café\" written with a single é."
  - id: m46-l02-c4
    front: What should you ask about Strings in a coding problem?
    back: "Is it ASCII only, or any Unicode? Is the comparison case-sensitive? Which characters count (letters, digits, spaces, punctuation)? Is a \"character\" what a user sees (Character) or a code point?"
  - id: m46-l02-c5
    front: How do clarifying answers turn into tests?
    back: "Each answer becomes at least one input with an expected output: \"empty returns nil\" becomes firstUnique(\"\") == nil; \"duplicates allowed\" becomes an input with duplicates."
---

## The idea in one sentence

Every clarifying question is worth asking only if its answer changes your code, your complexity budget or your test cases, so ask the ones that do and write the answers down as tests.

## What to ask, and what each answer changes

| Ask about | Example question | What the answer changes |
| --- | --- | --- |
| **Size** | "How many elements, at most?" | The complexity you can afford |
| **Range** | "Can values be negative, zero or huge?" | Overflow, `%` with negatives, whether you can index an array by value |
| **Duplicates** | "Can values repeat? If several answers exist, which one?" | Set versus dictionary of counts, which index to return |
| **Empty input** | "Can it be empty? What do I return then?" | A `guard`, the return type (`nil`, 0, `[]`) |
| **Ordering** | "Is the input sorted? Does the output order matter?" | Binary search and two pointers become available, or not |
| **Mutation** | "May I modify the input?" | Whether sorting in place is allowed or you need a copy |
| **Strings** | "ASCII only? Case-sensitive? Which characters count?" | `Character` versus bytes, a 26-slot array versus a dictionary |
| **Output** | "Indices or values? A count or the list?" | The return type, and sometimes the whole algorithm |

You don't need every row for every problem. Read the statement, find the words that are vague ("character", "pair", "sorted?", "return the answer"), and ask about those.

## Size sets the budget

The input size is the most useful answer you can get, because it tells you which complexities are even possible. Module 20 gave a rough rule, assuming around 10⁸ simple steps per second:

| Largest n | What fits |
| --- | --- |
| About 20 | 2ⁿ: try every subset |
| About 10³ to 5 × 10³ | n²: every pair |
| About 10⁵ to 10⁶ | n log n or n: sorting, hashing, one pass |
| Bigger than memory, or a stream | One pass, O(1) or small extra space |

These are estimates. But if the answer is "up to 10⁵", saying "so O(n²) is about 10¹⁰ steps, too slow; I'm aiming for O(n log n) or better" shows you can connect constraints to design. If the interviewer says "it's small, maybe 50", the brute force might be the right answer, and you've saved yourself ten minutes.

## Duplicates and ordering

Both questions decide which tools are on the table. Take "remove repeated tags from a post": if the output order doesn't matter, `Set(tags)` is enough. If it must keep the order of first appearance, you need a set **and** a walk:

```swift
let tags = ["swift", "ios", "swift", "ui", "ios"]
var seen = Set<String>()
var uniqueTags: [String] = []
for tag in tags where seen.insert(tag).inserted {
    uniqueTags.append(tag)
}
print(uniqueTags)
print(Set(tags).count)
```

```output
["swift", "ios", "ui"]
3
```

`insert(_:)` returns a tuple whose `inserted` is `false` when the tag was already there, so each tag is appended once, the first time. The block prints the set's count instead of the set itself: a `Set` has no defined order, and its printed order can change from run to run.

## Mutation

Swift function parameters are constants, and arrays are values (Module 6). So "may I modify the input?" means something slightly different than in languages where arrays are shared references:

- If the answer is **no**, you're already safe: sorting a `var` copy inside the function can't affect the caller. It costs O(n) extra space, which you should mention.
- If the answer is **yes**, and the interviewer wants O(1) extra space, the function needs an `inout` parameter so it can sort the caller's array in place.

```swift
func median(of values: [Int]) -> Int {
    var sortedValues = values
    sortedValues.sort()
    return sortedValues[sortedValues.count / 2]
}

let scores = [7, 1, 9, 3, 5]
print(median(of: scores))
print(scores)
```

```output
5
[7, 1, 9, 3, 5]
```

`scores` is unchanged; the copy was sorted. (`median(of:)` also assumes a non-empty array with an odd count. Those are two more clarifying questions.)

## Strings: what's a "character"?

String problems hide the most assumptions. Swift's `String` gives you three ways to count the same text:

```swift
let composed = "café"
let decomposed = "cafe\u{301}"
let flag = "🇯🇵"

print(composed == decomposed)
print(composed.count, decomposed.count, flag.count)
print(composed.unicodeScalars.count, decomposed.unicodeScalars.count, flag.unicodeScalars.count)
print(composed.utf8.count, decomposed.utf8.count, flag.utf8.count)
```

```output
true
4 4 1
4 5 2
5 6 8
```

Line by line:

1. `"café"` uses the single scalar é (U+00E9). `"cafe\u{301}"` is a plain e followed by U+0301, a combining acute accent. They look identical.
2. Swift compares strings by **canonical equivalence**, so they're equal.
3. `count` counts `Character`s, which are grapheme clusters: what a reader sees as one character. Both words have 4; the flag is 1.
4. `unicodeScalars` counts code points: the decomposed é is 2, and a flag is two "regional indicator" scalars.
5. `utf8` counts bytes: é takes 2 bytes, U+0301 takes 2, and each regional indicator takes 4.

This is why the question "what counts as a character?" changes the solution. Here's "find the first character that appears exactly once" with `Character`:

```swift
func firstUniqueCharacter(in text: String) -> Character? {
    var counts: [Character: Int] = [:]
    for character in text {
        counts[character, default: 0] += 1
    }
    return text.first { counts[$0] == 1 }
}

print(firstUniqueCharacter(in: "racecar") ?? "-")
print(firstUniqueCharacter(in: "aabb") ?? "-")
print(firstUniqueCharacter(in: "") ?? "-")
print(firstUniqueCharacter(in: "e\u{301}xe\u{301}") ?? "-")
```

```output
e
-
-
x
```

In the last call, the two accented e's are each one `Character`, they match, and `x` is the first unique one. Count by `unicodeScalars` instead, and the answer is different:

```swift
func firstUniqueScalar(in text: String) -> Unicode.Scalar? {
    var counts: [Unicode.Scalar: Int] = [:]
    for scalar in text.unicodeScalars {
        counts[scalar, default: 0] += 1
    }
    return text.unicodeScalars.first { counts[$0] == 1 }
}

if let scalar = firstUniqueScalar(in: "e\u{301}xe") {
    print(String(scalar.value, radix: 16))
}
```

```output
301
```

In `"e\u{301}xe"`, the plain e appears twice as a scalar, so the first unique scalar is the lone combining accent, U+0301: half of a character. Nobody wants that answer. Working with `Character` costs a dictionary with hashing of grapheme clusters, but it's correct for any text.

If the interviewer says "lowercase English letters only", you can trade generality for speed with a 26-slot array:

```swift
func firstUniqueLowercaseLetter(in word: String) -> Character? {
    let letters = Array(word)
    var counts = Array(repeating: 0, count: 26)
    let aValue = Character("a").asciiValue!
    for letter in letters {
        counts[Int(letter.asciiValue! - aValue)] += 1
    }
    return letters.first { counts[Int($0.asciiValue! - aValue)] == 1 }
}

print(firstUniqueLowercaseLetter(in: "swiss") ?? "-")
print(firstUniqueLowercaseLetter(in: "racecar") ?? "-")
```

```output
w
e
```

The force unwraps (`asciiValue!`) are only safe because of the agreed precondition. With an uppercase or accented letter, `asciiValue` is `nil` or the subtraction underflows, and the program stops. Say the precondition out loud when you write it: "I'm relying on lowercase ASCII, as you said."

## Turning answers into tests

Every answer you get is a test case you'll use in step 11. Write them down as you go, in a list like this one for `firstUniqueCharacter(in:)`:

| Answer or edge case | Input | Expected |
| --- | --- | --- |
| Statement example | `"racecar"` | `e` |
| Empty string returns nil | `""` | `nil` |
| No unique character returns nil | `"aabb"` | `nil` |
| One character | `"z"` | `z` |
| Case-sensitive | `"aA"` | `a` |
| Any Unicode, a user-visible character counts once | `"e\u{301}xe\u{301}"` | `x` |
| The unique one is last | `"aab"` | `b` |

And if you can run code, run them all at once:

```swift
func firstUniqueCharacter(in text: String) -> Character? {
    var counts: [Character: Int] = [:]
    for character in text {
        counts[character, default: 0] += 1
    }
    return text.first { counts[$0] == 1 }
}

let cases: [(input: String, expected: Character?)] = [
    ("racecar", "e"),
    ("", nil),
    ("aabb", nil),
    ("z", "z"),
    ("aA", "a"),
    ("e\u{301}xe\u{301}", "x"),
    ("aab", "b"),
]
var failures = 0
for (input, expected) in cases where firstUniqueCharacter(in: input) != expected {
    failures += 1
    print("FAIL for input with \(input.count) characters")
}
print("\(cases.count - failures) of \(cases.count) passed")
```

```output
7 of 7 passed
```

Seven cases, each traceable to a question you asked or an edge case you listed. That's the list the interviewer wants to hear about when you say "let me test this".

## Common mistakes

> [!error] Asking questions that don't change anything
> "What language should I use?" when the interview is in Swift, or a long list read from memory. Each question should have a visible consequence: say it. "Can it be empty? If so I'll return nil."

> [!error] Assuming one byte per character
> `Array(text.utf8)` is fast and tempting, but with "é" or an emoji it splits one character into several bytes. Ask whether the input is ASCII before you choose a byte-based approach.

> [!error] Not writing the answers down
> Ten minutes later you won't remember whether "duplicates" was a yes. Write each answer in a comment at the top of your code; those comments become your test list.

> [!error] Treating the interviewer's "you decide" as no answer
> Sometimes the interviewer says "your choice". Make the choice, say it ("I'll return nil for empty input"), and stay consistent.

## Exercises

````exercise
id: m46-l02-e1
type: comprehension
prompt: "The statement says: \"Given a list of transaction amounts, find whether two of them sum to zero.\" You ask how big the list can be and the interviewer says \"up to 50 items\". What's the best response?"
choices:
  - text: "\"Then checking every pair is at most about 1,200 checks. I'll start with that, and mention the hashing version if you want something that scales.\""
    correct: true
    why: The size says the brute force is fine. Saying so, and naming the scalable version, shows you connected the constraint to the design.
  - text: "\"I'll still use a dictionary to get O(n), since O(n²) is always too slow.\""
    correct: false
    why: O(n²) on 50 items is trivial. "Always too slow" ignores the constraint you just asked about.
  - text: "\"I'll sort the list first so I can use binary search.\""
    correct: false
    why: It works, but nothing about the constraint motivates it, and you didn't say why it's better than the obvious solution.
  - text: Nothing; the answer to that question never changes the solution.
    correct: false
    why: Size is the question whose answer most often changes the solution.
solution: |
  With n = 50 there are 50 × 49 / 2 = 1,225 pairs, so the brute force is instant. The point of asking about size is to use the answer: here it tells you the simple solution is acceptable, and the best move is to say that and offer the O(n) dictionary version as an extension, rather than spending time on an optimization nobody needs.
````

````exercise
id: m46-l02-e2
type: prediction
prompt: Predict the exact output.
code: |
  let word = "naïve"
  let decomposedWord = "nai\u{308}ve"
  print(word == decomposedWord)
  print(word.count, decomposedWord.count)
  print(word.unicodeScalars.count, decomposedWord.unicodeScalars.count)
  print(Array(decomposedWord).count)
output: |
  true
  5 5
  5 6
  5
hints:
  - U+0308 is a combining diaeresis. It attaches to the i before it.
  - "Array(decomposedWord) builds an array of Characters, not scalars."
solution: |
  ```output
  true
  5 5
  5 6
  5
  ```

  `"naïve"` uses the single scalar ï (U+00EF); `"nai\u{308}ve"` uses i plus a combining diaeresis. They're canonically equivalent, so `==` is true, and both have 5 `Character`s. As scalars, the decomposed one has 6. `Array(decomposedWord)` is an array of `Character`s, so it has 5 elements. That's why `Array(text)` is the safe way to index a String by position (lesson 5): it keeps each user-visible character whole.
````

````exercise
id: m46-l02-e3
type: find-errors
prompt: "The agreed answers were: the input can be empty (return an empty array), values can be negative, values can repeat, and the output must keep the order of first appearance. This function is supposed to return the values that appear more than once. Which statements are true?"
code: |
  func repeatedValues(_ values: [Int]) -> [Int] {
      var counts = Array(repeating: 0, count: values.max()! + 1)
      for value in values {
          counts[value] += 1
      }
      var result: [Int] = []
      for value in values where counts[value] > 1 && !result.contains(value) {
          result.append(value)
      }
      return result
  }
choices:
  - text: "With an empty array, values.max()! stops the program."
    correct: true
    why: max() returns nil for an empty array, and the force unwrap traps. The agreed answer was to return [].
  - text: "With a negative value, counts[value] is an out-of-range index."
    correct: true
    why: Indexing an array by value only works for a known non-negative range. Negatives need a dictionary.
  - text: "result.contains inside the loop makes the second loop O(n · k), where k is the number of repeated values."
    correct: true
    why: contains walks the result array. A Set of already-reported values would make each check O(1) on average.
  - text: The output order is wrong, because it's sorted by value.
    correct: false
    why: The second loop walks the input in order, so values come out in order of first appearance.
rubric:
  - I found the crash on empty input and the crash on negative values.
  - I traced both back to clarifying answers that the code ignored.
  - I replaced the array of counts with a dictionary and the contains check with a set.
solution: |
  Three real problems, and each one contradicts a clarifying answer: empty input crashes (`values.max()!`), negatives crash (`counts[-3]`), and the `contains` check is a hidden linear scan. A version that honors all the answers:

  ```swift
  func repeatedValues(_ values: [Int]) -> [Int] {
      var counts: [Int: Int] = [:]
      for value in values {
          counts[value, default: 0] += 1
      }
      var reported = Set<Int>()
      var result: [Int] = []
      for value in values where counts[value, default: 0] > 1 && reported.insert(value).inserted {
          result.append(value)
      }
      return result
  }

  print(repeatedValues([4, -2, 4, 7, -2, 4]))
  print(repeatedValues([]))
  print(repeatedValues([1, 2, 3]))
  ```

  ```output
  [4, -2]
  []
  []
  ```

  O(n) time on average and O(n) space. The array of counts would have been fine, and faster, if the answers had been "values are between 0 and 100", which is exactly why you ask.
````

````exercise
id: m46-l02-e4
type: solve
prompt: |
  Problem: "Given a list of usernames, return the usernames that appear more than once, each reported once, in order of first appearance." The interviewer's answers: up to 10⁵ names; comparison is case-insensitive ("Ana" and "ana" are the same user); report the first spelling seen; an empty list returns `[]`.

  Write `func duplicateUsernames(_ names: [String]) -> [String]` and a list of test cases where each case comes from one of those answers. Use `lowercased()` to compare. Expected output for the starter's calls:

  ```output
  ["Ana", "bo"]
  []
  []
  ["Zoe"]
  ```
starter: |
  func duplicateUsernames(_ names: [String]) -> [String] {
      return []
  }

  print(duplicateUsernames(["Ana", "bo", "ana", "Cy", "BO", "ANA"]))
  print(duplicateUsernames([]))
  print(duplicateUsernames(["a", "b"]))
  print(duplicateUsernames(["Zoe", "zoe"]))
hints:
  - Count by the lowercased name, not by the name as written.
  - Walk the original list a second time to keep the order and the first spelling, and remember which keys you've already reported.
rubric:
  - Counts by a normalized key and reports the first spelling.
  - Reports each duplicate once and keeps the order of first appearance.
  - Handles the empty list.
  - Each test case is tied to one of the answers (case-insensitive, first spelling, order, empty).
  - "States O(n · L) time, where L is the name length (lowercasing and hashing look at every character), and O(n) space."
solution: |
  ```swift
  func duplicateUsernames(_ names: [String]) -> [String] {
      var counts: [String: Int] = [:]
      for name in names {
          counts[name.lowercased(), default: 0] += 1
      }
      var reported = Set<String>()
      var result: [String] = []
      for name in names {
          let key = name.lowercased()
          if counts[key, default: 0] > 1 && reported.insert(key).inserted {
              result.append(name)
          }
      }
      return result
  }

  print(duplicateUsernames(["Ana", "bo", "ana", "Cy", "BO", "ANA"]))
  print(duplicateUsernames([]))
  print(duplicateUsernames(["a", "b"]))
  print(duplicateUsernames(["Zoe", "zoe"]))
  ```

  ```output
  ["Ana", "bo"]
  []
  []
  ["Zoe"]
  ```

  The test calls map to the answers: the first checks case-insensitivity, order of first appearance, reporting once and the first spelling ("Ana", not "ana" or "ANA"); the second, empty input; the third, no duplicates; the fourth, the smallest case-insensitive pair.

  Cost: two passes over n names. Lowercasing and hashing each look at every character of a name, so it's O(n · L) for names of length L, which is usually just called O(n) when names are short. Space is O(n) for the dictionary and the set.
````

````exercise
id: m46-l02-e5
type: design
prompt: |
  Statement: "Given two lists of contact phone numbers, one from the phone and one from the server, return the numbers that are on the phone but not on the server."

  Write the clarifying questions you'd ask (at least six), the answer you'd propose if the interviewer says "you decide", and the test case each answer produces.
rubric:
  - Asks about sizes of both lists (and whether they differ a lot).
  - Asks about formatting differences (spaces, dashes, country codes) and what counts as the same number.
  - Asks about duplicates within a list and in the output.
  - Asks about empty lists and the output order.
  - Asks whether either list is sorted.
  - Every answer has a concrete test case with an expected output.
solution: |
  A possible list:

  | Question | Proposed answer | Test case |
  | --- | --- | --- |
  | How big is each list? | Up to 10⁴ each | (sets the budget: O(n + m) with a set) |
  | Is "+1 555 0100" the same as "5550100"? | Normalize: keep digits only, compare the last 10 | `["+1 555 0100"]` vs `["5550100"]` → `[]` |
  | Can a list contain the same number twice? | Yes; report each missing number once | `["111", "111"]` vs `[]` → `["111"]` |
  | Can a list be empty? | Yes | `[]` vs `["1"]` → `[]`; `["1"]` vs `[]` → `["1"]` |
  | Does the output order matter? | Keep the phone list's order | `["3", "1", "2"]` vs `["1"]` → `["3", "2"]` |
  | Are the lists sorted? | No | (rules out a merge-style walk without sorting first) |
  | Return the original spelling or the normalized one? | The original, as stored on the phone | `["555-0100"]` vs `[]` → `["555-0100"]` |

  The second row matters most. Two strings that look different but mean the same number are the real problem here; the set difference is the easy part. With answers like these, the solution is: normalize every server number into a set, then walk the phone list, normalize each number, and keep it if it's not in the set and not already reported. O(n + m) on average.
````

````exercise
id: m46-l02-e6
type: fill-in
prompt: Complete the function so it counts by user-visible characters and returns the first one that appears exactly once. It should print `x` and then `-`.
code: |
  func firstUniqueCharacter(in text: String) -> Character? {
      var counts: [Character: Int] = [:]
      for character in [[1]] {
          counts[character, [[2]]: 0] += 1
      }
      return text.[[3]] { counts[$0] == 1 }
  }

  print(firstUniqueCharacter(in: "e\u{301}xe\u{301}") ?? "-")
  print(firstUniqueCharacter(in: "abab") ?? "-")
blanks:
  - id: "1"
    answers: ["text"]
  - id: "2"
    answers: ["default"]
  - id: "3"
    answers: ["first"]
solution: |
  ```swift
  func firstUniqueCharacter(in text: String) -> Character? {
      var counts: [Character: Int] = [:]
      for character in text {
          counts[character, default: 0] += 1
      }
      return text.first { counts[$0] == 1 }
  }

  print(firstUniqueCharacter(in: "e\u{301}xe\u{301}") ?? "-")
  print(firstUniqueCharacter(in: "abab") ?? "-")
  ```

  ```output
  x
  -
  ```

  Iterating a `String` directly yields `Character`s, so the accented e (two scalars) is counted as one character. `counts[character, default: 0] += 1` reads 0 for a missing key and stores the incremented value. `first(where:)`, written here with a trailing closure, returns the first character whose count is 1, or `nil`. Two passes, O(n) on average.
````

## Summary

- Ask a question only if its answer changes the code, the complexity budget or the tests, and say what it changes.
- Size first: it decides whether O(n²) is fine or hopeless. Then range, duplicates, empty input, ordering, mutation, Strings and output format.
- In Swift, an unmodifiable input is already safe (parameters are constants, arrays are values); sorting a copy costs O(n) space. Sorting in place for the caller needs `inout`.
- A Swift `String` counts three ways: `count` (characters as users see them), `unicodeScalars` and `utf8`. `"cafe\u{301}"` is 4, 5 and 6, and equals `"café"`.
- Use `Character` for correctness with any text; a 26-slot array only under an agreed "lowercase ASCII" precondition, stated out loud.
- Write every answer down as a test case with an expected result. That list is what you trace in step 11.

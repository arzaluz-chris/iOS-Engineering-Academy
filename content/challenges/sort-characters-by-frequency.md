---
id: sort-characters-by-frequency
title: Sort Characters by Frequency
difficulty: medium
order: 8
patterns: [Frequency counter, Bucket sort]
prerequisites: [m07, m15, m16-l05]
summary: Rearrange a string so the most common characters come first. Counting is easy; ordering by count without a full sort is the interesting part.
solutionFile: SortCharactersByFrequency.swift
testFile: SortCharactersByFrequencyTests.swift
starter: |
  func sortedByFrequency(_ text: String) -> String {
      // Your solution
      return ""
  }
time: O(n) on average
space: O(n)
edgeCases:
  - Empty string
  - Every character different, so every count ties
  - Uppercase and lowercase versions of the same letter, which are different characters
  - Spaces, digits and emoji
askInterviewer:
  - How should ties be ordered?
  - Are "A" and "a" the same character?
  - What counts as a character? Do emoji and accented letters count as one?
  - How long can the string be, and how many distinct characters can it have?
hints:
  - "Start with a dictionary of counts. Sorting the distinct characters by count already gives a correct answer: what does it cost?"
  - "A count is an integer between 1 and n. Instead of comparing counts, could you put each character in a slot numbered by its count?"
  - "To get ties in first-appearance order, fill the slots by walking the distinct characters in the order they first appeared."
followUps:
  - When is the sorting version just as good in practice? (Think about how many distinct characters there are.)
  - How would you return only the k most frequent characters?
  - What changes if you have to count Unicode scalars instead of Characters?
rubric:
  - I counted with a dictionary in one pass.
  - I explained the O(n + u log u) sorting version, then the O(n) bucket version.
  - Ties followed the stated rule, independently of dictionary order.
  - I treated Character as the unit and mentioned what that means for emoji.
codeStatus: tested
---

A keyboard app wants to show which keys a user typed most. Given a string, return its characters rearranged so that all copies of each character sit together and the most frequent character comes first. Characters with the same count appear in the order of their **first appearance** in the input.

Write `sortedByFrequency(_ text: String) -> String`.

```swift
sortedByFrequency("banana")  // "aaannb"
sortedByFrequency("tree")    // "eetr": t and r tie, and t appeared first
sortedByFrequency("Aabb")    // "bbAa": A and a are different characters
```

**Constraints:** `0 ≤ text.count ≤ 5·10^5`. A character is a Swift `Character`, so an emoji counts as one.

<!-- reveal -->

## First approach

Two steps: count every character, then output them from the highest count to the lowest. Counting is a dictionary. For the second step, notice that a count can only be a number from 1 to n, so you can **index** by it instead of sorting by it.

## Naive solution

Count each distinct character by scanning the whole text again, then sort by count. `enumerated()` keeps each character's first-appearance position to break ties:

```swift
func sortedByFrequency(_ text: String) -> String {
    var distinct: [Character] = []
    for character in text where !distinct.contains(character) {
        distinct.append(character)
    }
    let counted = distinct.map { character in
        (character: character, count: text.filter { $0 == character }.count)
    }
    let ranked = counted.enumerated().sorted { first, second in
        if first.element.count != second.element.count {
            return first.element.count > second.element.count
        }
        return first.offset < second.offset
    }
    return ranked.map { String(repeating: $0.element.character, count: $0.element.count) }.joined()
}
```

## Problems with the naive solution

With u distinct characters, building `distinct` with `contains` and counting with `filter` are both **O(n · u)**. For text in a single alphabet, u is small and this is fine. For text with thousands of distinct characters (Chinese, or emoji), it's slow. Counting with a dictionary fixes that part and leaves the sort, O(u log u), which is already a good answer. The bucket version removes the sort too.

## Optimized solution

Count in one pass with a dictionary, and record each character the first time it appears. Then make an array of buckets, one per possible count from 0 to n, and drop each character into the bucket of its count, in first-appearance order. Reading the buckets from the highest count down gives the answer, with ties already in the right order.

## Line by line

- `counts[character] == nil` is true only the first time a character shows up, so `firstAppearance` lists each distinct character once, in input order.
- `counts[character, default: 0] += 1`: the usual frequency counter.
- `buckets` has `text.count + 1` slots because a count can be anything from 1 to `text.count`. Slot 0 stays empty. Note that `text.count` walks the string: it's O(n), not O(1).
- `buckets[counts[character, default: 0]].append(character)`: walking `firstAppearance` in order means each bucket lists its characters in first-appearance order.
- `for count in buckets.indices.reversed()`: highest count first.
- `String(repeating: character, count: count)` writes all copies of the character at once.
- Everything is one pass over the text plus one pass over n + 1 buckets: **O(n) time on average** (dictionary operations are O(1) on average), **O(n) space**.

## Common mistakes

- Iterating `counts` directly to fill the buckets or to sort: dictionary order isn't stable, so ties come out in a different order on each run.
- Making `text.count` buckets instead of `text.count + 1`. A string with one repeated character, like `"aaa"`, has a count of n, and `buckets[n]` traps with "Index out of range".
- Calling it O(n) when you sort the distinct characters. It's O(n + u log u). That's usually fine; just say it accurately.

## Variation

**Top k frequent elements:** given integers, return the k most frequent. Use the same buckets and stop as soon as you've collected k values. A heap of size k (Module 19) is the other standard answer, at O(n log k).

---
id: m16-l05
title: Hash maps and frequency counters
description: You replace the search inside a loop with a hash lookup, compare two collections by their counts instead of sorting them, count down to check whether one collection covers another, group values under a computed key, keep first positions in an index map, and use a Set to find runs in O(n), with the cost of each stated and the bugs that come with dictionaries.
module: m16
order: 5
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m16-l04]
objectives:
  - Spot the hidden inner search in a loop and replace it with a Set or Dictionary lookup.
  - Compare two collections as multisets with a frequency counter, and handle zero counts correctly.
  - Group values by a computed key, including a custom Hashable struct, and state the cost of building the key.
  - Use an index map (value to first position) to answer distance questions in one pass.
  - Choose an array of counts over a dictionary when the keys are a small, fixed range.
terms:
  - term: Hash map
    definition: A structure that stores values under keys and finds a key's slot by hashing it. Swift's Dictionary is one; Set is the same idea with keys only. Lookups and inserts are O(1) on average.
  - term: Frequency counter
    definition: A dictionary from each distinct value to how many times it appears. Two collections with equal frequency counters have the same elements with the same multiplicities.
  - term: Multiset
    definition: A collection where order doesn't matter but repetitions do. [a, b, a] and [b, a, a] are the same multiset; [a, b] is different.
  - term: Index map
    definition: A dictionary from a value to a position where it appeared (often the first). It replaces "search backward for this value" with one lookup.
  - term: Canonical key
    definition: A normalized form of a value used as a dictionary key so that values you consider equal map to the same key, like a word's sorted letters for anagrams.
mastery:
  - Turn an O(n²) "search inside a loop" into O(n) on average with a Set or Dictionary, and say what the extra space is.
  - Check whether two strings are anagrams with one counter, counting up and down, and explain why zero counts must be removed before comparing dictionaries.
  - Group items with Dictionary(grouping:by:) and a canonical key, and print groups in a stable order.
  - Find the longest run of consecutive integers in O(n) average with a Set, and explain why it isn't O(n²).
  - Explain when a [Int] of counts indexed by the key is better than a dictionary.
resources: [swift-dictionary, swift-set, swift-dictionary-grouping, swift-book-collection-types, swift-book-protocols]
cards:
  - id: m16-l05-c1
    front: What's the general move behind most hash map solutions?
    back: Find the search inside the loop ("is it there?", "how many?", "where was it?") and answer it with a Set or Dictionary lookup instead. O(n) per search becomes O(1) on average, for O(n) extra space.
  - id: m16-l05-c2
    front: How do you check that two strings are anagrams in O(n)?
    back: "One counter: +1 for each character of the first, −1 for each of the second. They're anagrams if every count ends at 0. If you compare two dictionaries with ==, remove keys whose count is 0 first: [\"a\": 0] isn't equal to [:]."
  - id: m16-l05-c3
    front: What's the cost of grouping n words by their sorted letters?
    back: Sorting a word of k characters is O(k log k), so building all keys is O(n · k log k), plus O(n) average for the dictionary inserts. Space is O(n · k) for the groups.
  - id: m16-l05-c4
    front: Why is the Set-based longest consecutive run O(n) and not O(n²)?
    back: You only start counting at x when x − 1 isn't in the set. Each number is then counted by exactly one run's inner loop, so all the inner loops together do n steps, plus n lookups for the starts.
  - id: m16-l05-c5
    front: When is an array of counts better than a dictionary?
    back: When keys are a small fixed range of integers, like 24 hours or 26 lowercase letters. counts[key] is O(1) in the worst case, needs no hashing, and the keys come out in order.
---

## The idea in one sentence

When a loop contains a search ("have I seen this?", "how many of these?", "where was this?"), a `Set` or `Dictionary` can usually answer it in one lookup, turning O(n²) into **O(n) on average** for O(n) extra memory.

## Recognizing the pattern

Module 15 already made the trade once: an array's `contains` inside a loop is O(n²), and a `Set` makes it O(n) on average. Module 7 counted votes with `counts[vote, default: 0] += 1`. This lesson generalizes both moves. The signals:

- **"appears", "frequency", "most common", "duplicate", "unique"**: counts.
- **"same letters", "same elements in any order", "rearrangement"**: compare counts.
- **"group", "bucket", "categorize"**: a dictionary from a key to a list.
- **"seen before", "earlier", "distance between equal…"**: a set, or a dictionary from value to position.
- **Unsorted input** where sorting would cost O(n log n) or would lose the original positions.

A dictionary does one of four jobs in these solutions:

| Job | Type | Question it answers in O(1) average |
| --- | --- | --- |
| Membership | `Set<Value>` | Have I seen this value? |
| Counting | `[Value: Int]` | How many times has it appeared? |
| Index map | `[Value: Int]` | Where did it first (or last) appear? |
| Grouping | `[Key: [Value]]` | Which values share this key? |

The [Two Sum](#/challenge/two-sum) and [Contains Duplicate](#/challenge/contains-duplicate) challenges each use one of these. The examples here are different problems.

## Comparing two collections by their counts

Two words are **anagrams** if one is a rearrangement of the other: "listen" and "silent". In other words, the two strings are the same **multiset** of characters.

**Naive version**: for each character of the first word, find it in the second and remove it.

```swift
func areAnagramsNaive(_ first: String, _ second: String) -> Bool {
    var remaining = Array(second)
    for character in first {
        guard let index = remaining.firstIndex(of: character) else { return false }
        remaining.remove(at: index)
    }
    return remaining.isEmpty
}

print(areAnagramsNaive("listen", "silent"))
print(areAnagramsNaive("apple", "paple"))
print(areAnagramsNaive("apple", "applee"))
```

```output
true
true
false
```

Each `firstIndex(of:)` and each `remove(at:)` is O(n), done n times: **O(n²)**.

**Sorting version**: `first.sorted() == second.sorted()`. Two sorts, **O(n log n)**. Short and correct, and often the right answer when n is small.

**Counting version**: one dictionary. Count up for the first word and down for the second. They're anagrams exactly when every count ends at zero.

```swift
func areAnagrams(_ first: String, _ second: String) -> Bool {
    guard first.count == second.count else { return false }
    var balance: [Character: Int] = [:]
    for character in first {
        balance[character, default: 0] += 1
    }
    for character in second {
        balance[character, default: 0] -= 1
    }
    return balance.values.allSatisfy { $0 == 0 }
}

print(areAnagrams("listen", "silent"))
print(areAnagrams("apple", "paple"))
print(areAnagrams("apple", "appel"))
print(areAnagrams("rat", "car"))
print(areAnagrams("", ""))
```

```output
true
true
true
false
true
```

1. The length check is a cheap early exit. It isn't needed for correctness: different lengths always leave a nonzero count. `String.count` walks the string (O(n), Module 15), but that's still cheaper than the dictionary work it can skip.
2. The first loop builds the frequency counter of `first`.
3. The second loop subtracts. A character only in `second` gets a count of −1.
4. All counts at zero means every character appears equally often in both.

Cost: two passes over strings of length n, each doing an O(1)-average dictionary update: **O(n) time on average**. Extra space: one entry per distinct character, O(u) for u distinct characters, at most O(n).

"rat" and "car" leave `r: 0, t: 1, c: -1`, so the answer is `false`. If you compared two separate counters with `==` instead, watch out for keys whose count reached zero after subtracting: a dictionary with `"a": 0` isn't equal to one without the key `"a"`:

```swift
let afterSubtracting: [Character: Int] = ["a": 1, "b": 0]
let fresh: [Character: Int] = ["a": 1]
print(afterSubtracting == fresh)
```

```output
false
```

Either check the values, as `areAnagrams` does, or remove a key when its count reaches zero (`counts[key] = nil`), as lesson 4's genre window did.

## Counting down: does one collection cover another?

A word game gives the player a rack of letter tiles. Can they spell a word with them? Each tile can be used once.

This is a one-sided comparison: the tiles must contain every letter of the word **at least** as many times as the word uses it. Count the tiles, then spend them:

```swift
func canSpell(_ word: String, with tiles: [Character]) -> Bool {
    var available: [Character: Int] = [:]
    for tile in tiles {
        available[tile, default: 0] += 1
    }
    for letter in word {
        guard let count = available[letter], count > 0 else { return false }
        available[letter] = count - 1
    }
    return true
}

let rack: [Character] = ["s", "t", "a", "r", "e", "e", "l"]
for word in ["steel", "treats", "least", "teller"] {
    print(word, canSpell(word, with: rack))
}
```

```output
steel true
treats false
least true
teller false
```

"treats" needs two t's and the rack has one; "teller" needs two l's. The `guard let` handles both "letter never in the rack" (`nil`) and "all used up" (0). Cost: **O(t + w) time on average** for t tiles and a word of w letters, and O(t) extra space. The naive alternative, finding and removing each letter from an array of tiles, is O(t · w).

## Grouping by a computed key

A puzzle app shows the player groups of words that are anagrams of each other. Two words belong to the same group exactly when they have the same letters, so give every word a **canonical key** that's equal for anagrams and different otherwise: its letters, sorted.

```swift
let words = ["listen", "enlist", "google", "inlets", "banana", "silent", "gogole"]
let groups = Dictionary(grouping: words) { word in String(word.sorted()) }

for key in groups.keys.sorted() {
    print(key, groups[key, default: []])
}
```

```output
aaabnn ["banana"]
eggloo ["google", "gogole"]
eilnst ["listen", "enlist", "inlets", "silent"]
```

`Dictionary(grouping:by:)` (Module 7) calls the closure for each word and appends the word to the array under that key, keeping the original order within each group. `word.sorted()` returns `[Character]`; `String(...)` turns it back into a string so it can be the key.

Cost, for n words of up to k letters: building each key sorts k characters, O(k log k), so all keys cost **O(n · k log k)**, plus n dictionary inserts at O(1) average each. For short words that's close to O(n). If k were large, a counter of the 26 letters (see "When an array beats a dictionary" below) would make each key O(k).

Printing goes through `groups.keys.sorted()` because a dictionary's iteration order isn't stable, as Module 7 showed. Never let a test, or a UI, depend on it.

### Keys that are more than one value

Keys can be any `Hashable` type. A heat map of taps on a screen counts taps per grid cell, where a cell is a row and a column. A tuple seems natural, but tuples can't be keys:

```swift no-compile type '(Int, Int)' does not conform to protocol 'Hashable'
var taps: [(Int, Int): Int] = [:]
taps[(2, 3), default: 0] += 1
print(taps)
```

A struct whose stored properties are all `Hashable` gets `Hashable` synthesized (Module 10), so declare one:

```swift
struct Cell: Hashable {
    let row: Int
    let column: Int
}

let tapPoints = [(x: 25, y: 130), (x: 30, y: 140), (x: 210, y: 40), (x: 28, y: 95)]
let cellSize = 50
var taps: [Cell: Int] = [:]
for point in tapPoints {
    let cell = Cell(row: point.y / cellSize, column: point.x / cellSize)
    taps[cell, default: 0] += 1
}

let busiest = taps.max { first, second in first.value < second.value }
if let busiest {
    print("row \(busiest.key.row), column \(busiest.key.column): \(busiest.value) taps")
}
print("cells touched: \(taps.count)")
```

```output
row 2, column 0: 2 taps
cells touched: 3
```

Integer division maps each point to its cell: (25, 130) and (30, 140) both land in row 2, column 0, and (28, 95) lands one row up. `max(by:)` on a dictionary compares its `(key, value)` pairs; the closure says which of two is smaller. With a tie for the most taps, which cell wins would depend on the dictionary's order, so a real heat map would add a tie-breaker, as Module 7 did.

## Index maps: where did I see it?

A navigation log records the ID of every screen the user visited, in order. Product wants the widest gap between two visits to the **same** screen: how many steps apart are the first and last visit, for the screen where that's largest?

**Naive version**: for each position, search the rest of the log for the same screen. O(n²).

**The pattern**: remember where each screen was **first** seen. At every later visit, the gap to the first visit is one subtraction:

```swift
func widestRevisit(_ log: [String]) -> (screen: String, gap: Int)? {
    var firstSeen: [String: Int] = [:]
    var best: (screen: String, gap: Int)?
    for (position, screen) in log.enumerated() {
        if let first = firstSeen[screen] {
            let gap = position - first
            if gap > (best?.gap ?? 0) {
                best = (screen, gap)
            }
        } else {
            firstSeen[screen] = position
        }
    }
    return best
}

let log = ["home", "search", "detail", "home", "cart", "detail", "checkout", "search"]
if let result = widestRevisit(log) {
    print("\(result.screen): \(result.gap) steps")
}
print(widestRevisit(["home", "cart"]) == nil)
```

```output
search: 6 steps
true
```

1. `firstSeen` is the index map: screen → position of its first visit.
2. On a repeat visit, the gap is `position - first`. Because only the **first** position is stored (the `else` branch never overwrites it), this is always the widest gap for that screen so far.
3. `best?.gap ?? 0` treats "no revisit yet" as a gap of 0. The comparison is strict, so on ties the earliest screen to reach that gap wins.
4. With no screen visited twice, the result stays `nil`.

"search" is visited at 1 and 7: 6 steps. "detail" (2 and 5) and "home" (0 and 3) are 3 each. **O(n) time on average, O(u) extra space** for u distinct screens. Store the **last** position instead (overwrite on every visit) when the question is about the gap since the most recent visit.

## A Set that finds runs

A habit app stores the days (as day numbers) on which the user opened it, unsorted and possibly with repeats: `[103, 4, 200, 1, 3, 2, 104, 3, 102]`. What's the longest run of consecutive days?

**Sorting version**: sort, then one pass counting runs, skipping repeats. **O(n log n)**.

**Set version**: put the days in a `Set`. A day starts a run exactly when the day before it isn't in the set. Only from those starting days, count forward:

```swift
func longestRunOfDays(_ days: [Int]) -> Int {
    let present = Set(days)
    var longest = 0
    for day in present where !present.contains(day - 1) {
        var length = 1
        while present.contains(day + length) {
            length += 1
        }
        longest = max(longest, length)
    }
    return longest
}

print(longestRunOfDays([103, 4, 200, 1, 3, 2, 104, 3, 102]))
print(longestRunOfDays([7]))
print(longestRunOfDays([]))
```

```output
4
1
0
```

The runs are 1–4 (length 4), 102–104 (3) and 200 (1).

It looks quadratic: a `while` inside a `for`. It isn't, and the reason is the `where` clause. The inner loop only starts at the **first** day of a run, and from there it walks through that run's days. Every day in the set belongs to exactly one run, so it's walked over by exactly one inner loop. All the inner loops together take u steps for u distinct days, and the outer loop does u lookups. **O(n) time on average** (n to build the set, then O(u)), O(u) extra space. Without the `where`, a run of length L would be counted from each of its L days: L + (L − 1) + … + 1, which is O(n²) for one long run.

## When an array beats a dictionary

If the keys are a **small, fixed range of integers**, an array indexed by the key does the same job with no hashing, O(1) in the worst case rather than on average, and with the keys already in order. Counting app launches per hour of the day:

```swift
let launchHours = [9, 13, 9, 22, 8, 9, 13, 23, 22, 9]
var perHour = Array(repeating: 0, count: 24)
for hour in launchHours {
    perHour[hour] += 1
}

for (hour, count) in perHour.enumerated() where count > 0 {
    print("\(hour):00 \(String(repeating: "#", count: count))")
}
```

```output
8:00 #
9:00 ####
13:00 ##
22:00 ##
23:00 #
```

The array always has 24 slots, so its space is O(1) no matter how many launches there are, and printing in hour order needs no sorting. The same trick works for lowercase English letters (26 slots, indexed with `Int(letter.asciiValue! - 97)` once you've checked the letter really is a–z). The limit: it only works when every key is known to be in the range. An out-of-range hour crashes with `Index out of range`, and a character like "é" has no ASCII value at all.

## Common mistakes

> [!error] Comparing counters that contain zeros
> After counting down, a key can remain with a count of 0. `["a": 0] == [:]` is `false`. Check the values (`allSatisfy { $0 == 0 }`) or remove keys when they reach 0.

> [!error] Depending on dictionary order
> Iterating a `Dictionary` or `Set` gives an order that can change between runs. Sort the keys before printing or comparing, and add a tie-breaker when choosing a "most frequent" item.

> [!error] Using a tuple as a key
> Tuples aren't `Hashable`, so `[(Int, Int): Int]` doesn't compile. Declare a small struct with `Hashable` and let the compiler synthesize it.

> [!error] A key that doesn't capture "equal"
> If "Listen" and "silent" should be anagrams, the key must lowercase first. Any difference you want to ignore (case, spaces, accents) has to be removed in the key, or equal items land in different groups.

> [!error] Saying "O(1)" without "on average"
> Hash lookups are O(1) on average. In the worst case, when many keys collide, they're O(n). In an interview, say "O(n) on average".

> [!warning] Reaching for a dictionary on tiny or sorted inputs
> For 10 elements, a nested loop is fine and may be faster. For sorted input, two pointers (lesson 3) do many of the same jobs with O(1) extra space.

## Exercises

````exercise
id: m16-l05-e1
type: comprehension
prompt: "A function checks whether two arrays of n order IDs contain the same IDs with the same multiplicities, in any order. It builds one counter, adds 1 for each ID in the first array and subtracts 1 for each in the second, then checks that all counts are 0. What are its time and extra space?"
choices:
  - text: "O(n) time on average, O(u) extra space for u distinct IDs"
    correct: true
    why: "2n dictionary updates at O(1) average each, and one entry per distinct ID."
  - text: "O(n log n) time, O(1) extra space"
    correct: false
    why: That's sorting both arrays in place and comparing, a different approach.
  - text: "O(n²) time, O(n) extra space"
    correct: false
    why: There's no search inside the loop. Each update is one hash lookup.
  - text: "O(n) time in the worst case, O(1) extra space"
    correct: false
    why: "Hash operations are O(1) only on average, and the counter grows with the number of distinct IDs."
solution: |
  **O(n) time on average and O(u) extra space**, where u ≤ n is the number of distinct IDs. Each of the 2n updates is an O(1)-average dictionary operation, and the final check looks at u values. "On average" matters: with many colliding hashes, a dictionary operation degrades to O(n). The alternative, sorting both arrays and comparing them, is O(n log n) time and needs no dictionary.
````

````exercise
id: m16-l05-e2
type: prediction
prompt: Predict the exact output.
code: |
  let tags = ["swift", "ios", "swift", "ui", "ios", "swift"]
  var counts: [String: Int] = [:]
  for tag in tags {
      counts[tag, default: 0] += 1
  }
  counts["ui", default: 0] -= 1
  print(counts.count)
  for tag in counts.keys.sorted() {
      print(tag, counts[tag, default: 0])
  }
  let byCount = Dictionary(grouping: counts.keys) { counts[$0, default: 0] }
  print(byCount.keys.sorted())
output: |
  3
  ios 2
  swift 3
  ui 0
  [0, 2, 3]
hints:
  - Subtracting down to 0 doesn't remove the key.
  - The grouping uses each tag's count as the key, so the keys are counts.
solution: |
  ```output
  3
  ios 2
  swift 3
  ui 0
  [0, 2, 3]
  ```

  After counting, "swift" is 3, "ios" 2 and "ui" 1. Subtracting 1 leaves "ui" at 0, but the key stays, so `counts.count` is still 3, and "ui 0" prints. Grouping the tags by their counts gives keys 0, 2 and 3, printed sorted. To make "ui" disappear, you'd set `counts["ui"] = nil`.
````

````exercise
id: m16-l05-e3
type: find-errors
prompt: "This function should report whether `note` can be written using the letters of `magazine`, each letter used at most once (spaces in the note don't need letters). Which statements are true?"
code: |
  func canWrite(_ note: String, from magazine: String) -> Bool {
      var available: [Character: Int] = [:]
      for letter in magazine {
          available[letter] = 1
      }
      for letter in note where letter != " " {
          if available[letter, default: 0] == 0 {
              return false
          }
          available[letter, default: 0] -= 1
      }
      return true
  }
choices:
  - text: "It stores 1 for every magazine letter instead of counting, so a magazine with two e's can only supply one."
    correct: true
    why: "available[letter] = 1 overwrites. canWrite(\"ee\", from: \"eel\") returns false."
  - text: "The spending loop is correct: it checks for 0 before decrementing."
    correct: true
    why: Checking first means a count never goes below 0, and a missing letter reads as 0 through the default.
  - text: "It's O(n · m) because of the dictionary lookups inside the loop."
    correct: false
    why: "Each lookup is O(1) on average. It's O(n + m) on average."
  - text: "It crashes when the note contains a letter that isn't in the magazine."
    correct: false
    why: "The default subscript returns 0 for missing keys. No force unwrap, no crash."
rubric:
  - I found that the counting loop assigns instead of incrementing.
  - I gave an input that shows it.
  - I confirmed the spending loop is right and why it can't crash.
  - "I fixed it with += 1 and stated O(n + m) average time."
solution: |
  The second loop is right. The first one doesn't count: `available[letter] = 1` resets the count every time the letter appears again. The fix is the counting idiom:

  ```swift
  func canWrite(_ note: String, from magazine: String) -> Bool {
      var available: [Character: Int] = [:]
      for letter in magazine {
          available[letter, default: 0] += 1
      }
      for letter in note where letter != " " {
          if available[letter, default: 0] == 0 {
              return false
          }
          available[letter, default: 0] -= 1
      }
      return true
  }

  print(canWrite("ee", from: "eel"))
  print(canWrite("see you", from: "yes, you see"))
  print(canWrite("zoo", from: "zero"))
  ```

  ```output
  true
  true
  false
  ```

  "zoo" needs two o's; "zero" has one. Cost: **O(n + m) on average** for a note of n characters and a magazine of m, and O(u) extra space for the distinct magazine characters.
````

````exercise
id: m16-l05-e4
type: fill-in
prompt: Complete the grouping so that words that are anagrams of each other, ignoring case, end up in the same group. It should print `[["Listen", "Silent", "enlist"], ["stop", "Pots"]]`.
code: |
  let words = ["Listen", "stop", "Silent", "Pots", "enlist"]
  let groups = Dictionary(grouping: words) { word in String(word.[[1]]().[[2]]()) }
  let ordered = groups.values.sorted { $0.count > $1.count }
  print(ordered)
blanks:
  - id: "1"
    answers: ["lowercased"]
  - id: "2"
    answers: ["sorted"]
solution: |
  ```swift
  let words = ["Listen", "stop", "Silent", "Pots", "enlist"]
  let groups = Dictionary(grouping: words) { word in String(word.lowercased().sorted()) }
  let ordered = groups.values.sorted { $0.count > $1.count }
  print(ordered)
  ```

  ```output
  [["Listen", "Silent", "enlist"], ["stop", "Pots"]]
  ```

  The key has to erase every difference you want to ignore. Lowercase first, then sort the letters: "Listen", "Silent" and "enlist" all become "eilnst", and "stop" and "Pots" become "opst". The order matters: sorting first and lowercasing after doesn't work, because uppercase letters sort before lowercase ones. "Listen" would become "leinst" while "enlist" becomes "eilnst". Within each group, words keep their original order. The groups are sorted by size so the output doesn't depend on the dictionary's order; with two groups of different sizes, that's enough.
````

````exercise
id: m16-l05-e5
type: solve
prompt: |
  A search screen suggests the most used tags. Write `func topTags(_ tags: [String], k: Int) -> [String]` that returns the `k` most frequent tags, most frequent first, breaking ties alphabetically. If there are fewer than `k` distinct tags, return all of them.

  Expected output for the starter's calls:

  ```output
  ["swift", "ios", "ui"]
  ["swift"]
  []
  ```
starter: |
  func topTags(_ tags: [String], k: Int) -> [String] {
      // Count, then sort the distinct tags
      return []
  }

  let used = ["ui", "swift", "ios", "swift", "data", "ui", "ios", "swift", "net"]
  print(topTags(used, k: 3))
  print(topTags(used, k: 1))
  print(topTags([], k: 2))
hints:
  - "Count with counts[tag, default: 0] += 1."
  - "Sort counts.keys with sorted(by:): higher count first, and on equal counts, the alphabetically smaller tag first."
  - "Array(...prefix(k)) takes at most k elements, and fewer if there aren't k."
rubric:
  - Counts with a dictionary in one pass.
  - Sorts the distinct tags with a two-level comparison (count, then name).
  - Uses prefix(k) so fewer than k tags don't crash.
  - "States the cost: O(n) average to count plus O(u log u) to sort u distinct tags."
solution: |
  ```swift
  func topTags(_ tags: [String], k: Int) -> [String] {
      var counts: [String: Int] = [:]
      for tag in tags {
          counts[tag, default: 0] += 1
      }
      let ranked = counts.keys.sorted { first, second in
          let firstCount = counts[first, default: 0]
          let secondCount = counts[second, default: 0]
          if firstCount != secondCount {
              return firstCount > secondCount
          }
          return first < second
      }
      return Array(ranked.prefix(k))
  }

  let used = ["ui", "swift", "ios", "swift", "data", "ui", "ios", "swift", "net"]
  print(topTags(used, k: 3))
  print(topTags(used, k: 1))
  print(topTags([], k: 2))
  ```

  ```output
  ["swift", "ios", "ui"]
  ["swift"]
  []
  ```

  "swift" appears 3 times; "ios" and "ui" twice each, so the tie goes to "ios" alphabetically. The tie-breaker also makes the result independent of the dictionary's order. `prefix(k)` returns at most k elements, so asking for more than exist is safe.

  Cost: counting is **O(n) on average**. Sorting the u distinct tags is **O(u log u)**, with u ≤ n. Extra space O(u). When k is much smaller than u, a heap (Module 19) gets the top k in O(u log k).
````

````exercise
id: m16-l05-e6
type: design
prompt: |
  A contacts import brings in 50,000 entries from several sources. Each has a name and a phone number, typed inconsistently: "Ana Pérez" and "ana  pérez", "+34 600 123 456" and "600123456". Design how you'd find groups of likely duplicates (same person, same number) in roughly O(n) time. Describe the key, how you'd build it, the type you'd use for it, what you'd do with the groups, and the cost.
rubric:
  - "I proposed a canonical key with two parts: a normalized name and a normalized phone."
  - "I described the normalization: lowercase, collapse spaces, keep only digits, and handle the country prefix consistently."
  - I used a Hashable struct (or a combined string) as the key and grouped with a dictionary.
  - I said groups with more than one entry are the candidates, and suggested showing them to the user rather than merging automatically.
  - "I stated the cost: O(n · L) to build keys of length L, plus O(n) average for grouping, and O(n) extra space."
solution: |
  **Key**: two entries are duplicates when they have the same normalized name and the same normalized phone, so make that pair the key:

  ```swift
  struct ContactKey: Hashable {
      let name: String
      let phone: String
  }

  func normalizedName(_ name: String) -> String {
      name.lowercased().split(separator: " ").joined(separator: " ")
  }

  func normalizedPhone(_ phone: String) -> String {
      let digits = phone.filter { $0.isNumber }
      return digits.count > 9 ? String(digits.suffix(9)) : digits
  }

  let entries = [("Ana Pérez", "+34 600 123 456"), ("ana  pérez", "600123456"),
                 ("Luis Gil", "611 222 333"), ("Ana Pérez", "699 000 111")]
  let groups = Dictionary(grouping: entries) { entry in
      ContactKey(name: normalizedName(entry.0), phone: normalizedPhone(entry.1))
  }
  let duplicates = groups.values.filter { $0.count > 1 }
  print(duplicates.count, duplicates.first?.count ?? 0)
  ```

  ```output
  1 2
  ```

  **Normalization**: lowercase the name, and split on spaces and join again to collapse repeated spaces. For the phone, keep only digits and drop the country prefix consistently; here, keeping the last 9 digits works for Spanish numbers, but a real app would use the region to parse numbers properly. Each rule is a decision about what "the same" means, and it belongs in the key.

  **Type**: a `Hashable` struct, so the compiler synthesizes hashing over both fields. A tuple can't be a key.

  **Result**: groups with more than one entry are candidates. Show them to the user to confirm rather than merging silently: two people can share a landline.

  **Cost**: building each key is O(L) for an entry of length L, so O(n · L) in total, and grouping is O(n) on average. Extra space O(n) for the groups. With 50,000 entries, that's one pass; comparing every pair would be about 1.25 billion comparisons.
````

## Summary

- Look for **the search inside the loop**. A `Set` answers "seen it?", a counter answers "how many?", an index map answers "where?", and a grouping dictionary answers "which ones share this?", each in **O(1) on average**, for O(n) extra space.
- **Compare multisets with counts**: +1 for one collection, −1 for the other, all zero at the end. O(n) average, versus O(n log n) for sorting and O(n²) for find-and-remove. Zero counts don't disappear on their own.
- **Counting down** checks whether one collection covers another (tiles and a word, a magazine and a note) in O(t + w).
- **Group by a canonical key** that erases every difference you want to ignore. Building the key has a cost (sorted letters: O(k log k) per word). Use a `Hashable` struct for multi-part keys; tuples can't be keys.
- A `Set` finds runs of consecutive integers in O(n) average if you only start counting where `x − 1` is absent.
- For small fixed integer ranges, an **array of counts** is O(1) worst case, ordered, and needs no hashing. Never rely on dictionary order: sort keys and break ties explicitly.

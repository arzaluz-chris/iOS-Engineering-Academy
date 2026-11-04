---
id: time-based-key-value-store
title: Time-Based Key-Value Store
difficulty: medium
order: 49
patterns: [Binary search, Upper bound, Hash map]
prerequisites: [m07, m16-l02]
summary: Store every version of a value and answer "what was it at time t?". A dictionary of sorted histories, with an upper-bound search per lookup.
solutionFile: TimestampedStore.swift
testFile: TimestampedStoreTests.swift
starter: |
  struct TimestampedStore {
      mutating func set(_ key: String, _ value: String, at timestamp: Int) {
          // Your solution
      }

      func value(for key: String, at timestamp: Int) -> String? {
          // Your solution
          return nil
      }
  }
time: O(1) amortized per set, O(log k) per lookup for a key with k versions
space: O(total number of set calls)
edgeCases:
  - A key that was never set
  - A time before the key's first version
  - A time exactly equal to a version's timestamp
  - Several keys whose histories interleave
askInterviewer:
  - Do timestamps for one key always arrive in increasing order?
  - Can the same key be set twice at the same timestamp?
  - Do I need to delete keys or old versions?
  - How many sets compared with lookups? That decides what to optimize.
hints:
  - Keep every version per key, not just the latest. What data structure fits "one list per key"?
  - If timestamps arrive in increasing order, what do you know about each key's list without sorting it?
  - You want the last version with a timestamp <= t. That's the element just before the first one with a timestamp > t.
followUps:
  - What if timestamps can arrive out of order? (Insert in sorted position, O(k), or use a balanced tree.)
  - How would you cap memory by keeping only the last N versions per key?
  - How does this relate to multiversion storage in databases, or to an undo history?
rubric:
  - I stored a per-key history in a dictionary instead of only the latest value.
  - I used the increasing timestamps to keep each history sorted for free.
  - I wrote the lookup as an upper bound and handled "before the first version".
  - I gave the cost of both operations separately.
codeStatus: tested
---

A feature-flag service needs to answer questions like "what was the value of `checkout` at 10:24?", so it keeps every version instead of overwriting. Write a `TimestampedStore` with two operations:

- `set(_ key:_ value:at:)` records `value` for `key` at `timestamp`. Timestamps for the same key strictly increase from one call to the next.
- `value(for:at:)` returns the value that `key` had at `timestamp`: the one set at the latest time that is `<= timestamp`. If the key had no value yet, it returns `nil`.

```swift
var flags = TimestampedStore()
flags.set("checkout", "old", at: 10)
flags.set("checkout", "new", at: 25)
flags.value(for: "checkout", at: 5)    // nil, nothing set yet
flags.value(for: "checkout", at: 24)   // "old"
flags.value(for: "checkout", at: 25)   // "new"
flags.value(for: "search", at: 30)     // nil, never set
```

**Constraints:** up to `2 · 10^5` calls in total; timestamps are between 1 and `10^9`.

<!-- reveal -->

## First approach

Two questions, two tools. "Which key?" is a dictionary lookup. "Which version of that key?" is a search in time. Because each key's timestamps arrive in increasing order, appending keeps each history sorted with no extra work, and "the latest version at or before t" is a boundary in a sorted array.

## Naive solution

Store the history the same way, but look it up by walking it from the newest version back:

```swift
func value(for key: String, at timestamp: Int) -> String? {
    guard let entries = history[key] else { return nil }
    for entry in entries.reversed() where entry.timestamp <= timestamp {
        return entry.value
    }
    return nil
}
```

## Problems with the naive solution

A lookup is **O(k)** for a key with k versions. For questions about recent times it stops quickly, but asking about the early history of a key that has 10^5 versions walks almost all of them, every time. With 10^5 such lookups that's 10^10 steps. Storing only the latest value instead is O(1), and it can't answer the question at all.

## Optimized solution

Keep `[String: [(timestamp, value)]]`. `set` appends. `value(for:at:)` runs an upper-bound search over the key's history: the first entry whose timestamp is **greater** than `t`. The entry right before it is the answer; if there's none before it, the key had no value yet.

## Line by line

- `private var history: [String: [(timestamp: Int, value: String)]]`: one array of versions per key, in the order they were set, which is also timestamp order.
- `precondition(timestamp > previous.timestamp, ...)`: the sorted order depends on this promise, so the code checks it instead of silently returning wrong answers later.
- `history[key, default: []].append((timestamp, value))`: the `default:` subscript creates the empty array the first time a key shows up and appends in place, without copying the array out and back.
- `guard let entries = history[key] else { return nil }`: an unknown key has no history.
- The loop is the lesson's upper bound: `entries[mid].timestamp <= timestamp` moves `low` past `mid`; otherwise `mid` becomes the edge. When it ends, `low` is the first version from **after** the requested time.
- `return low == 0 ? nil : entries[low - 1].value`: `low == 0` means every version is from later, so there was no value yet. Otherwise the previous entry is the latest one at or before the time.

## Common mistakes

- Using lower bound (`<` instead of `<=`). For a lookup at exactly 25, lower bound stops **on** the version from 25, and `low - 1` returns the one before it.
- Returning `entries[low]` instead of `entries[low - 1]`.
- Sorting the history on every `set` "to be safe". It's already sorted; sorting turns an O(1) append into O(k log k).
- Making the store a class with a shared dictionary and forgetting that the starter is a struct with a `mutating` set. Either works; be consistent about value or reference semantics.

## Variation

**Out-of-order writes:** if timestamps can arrive in any order, find the insertion point with a lower bound and `insert(_:at:)` there, which is O(k) because the array shifts. If writes are frequent, a balanced search tree keyed by timestamp makes both operations O(log k).

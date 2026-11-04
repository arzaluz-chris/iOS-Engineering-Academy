---
id: minimum-sync-speed
title: Minimum Sync Speed
difficulty: medium
order: 46
patterns: [Binary search on the answer, Feasibility check]
prerequisites: [m16-l02]
summary: Find the slowest speed that still finishes a batch job before the deadline. Binary search over speeds, with a check that rounds up per item.
solutionFile: MinimumSyncSpeed.swift
testFile: MinimumSyncSpeedTests.swift
starter: |
  func minimumSyncSpeed(_ folders: [Int], hours: Int) -> Int {
      // Your solution
      return 0
  }
time: O(n log M), where M is the largest folder
space: O(1)
edgeCases:
  - Hours equal to the number of folders, which forces the largest folder's size
  - So many hours that a speed of 1 is enough
  - A single folder
  - Folder sizes near 10^9, where the total doesn't fit a naive search
askInterviewer:
  - Can the job work on two folders in the same hour? (No, and that's why each folder rounds up.)
  - Is hours always at least the number of folders? Otherwise there's no answer.
  - Does the speed have to be a whole number?
  - How big can a folder and the number of hours get?
hints:
  - If the sync finishes in time at speed k, does it also finish at speed k + 1?
  - For one speed, how many hours does one folder take? Remember a folder can't share its last hour.
  - What's the slowest speed worth trying, and which speed is always fast enough?
followUps:
  - What changes if the job can move on to the next folder in the same hour? (It becomes a total-sum problem with a direct formula.)
  - How do you write ceil(a / b) with integers, without Double?
  - Which other problems have the same shape? (Ship packages within d days, split an array into k parts with the smallest largest sum.)
rubric:
  - I noticed that "fast enough" is monotonic in the speed and searched over speeds.
  - I wrote the hours check with a correct integer ceiling.
  - I justified the range 1...max(folders).
  - I stated O(n log M) time and compared it with trying every speed.
codeStatus: tested
---

A backup app syncs a list of folders. At speed `k` it uploads `k` files per hour, but each hour it works on a single folder: if a folder has fewer than `k` files left, it finishes that folder and sits idle until the next hour starts. Write `minimumSyncSpeed(_:hours:)` that returns the smallest whole speed that syncs every folder within `hours` hours. `folders[i]` is the number of files in folder `i`.

```swift
minimumSyncSpeed([30, 11, 23, 4, 20], hours: 5)  // 30, one folder per hour
minimumSyncSpeed([30, 11, 23, 4, 20], hours: 6)  // 23: 2 + 1 + 1 + 1 + 1 = 6 hours
minimumSyncSpeed([3, 6, 7, 11], hours: 8)        // 4: 1 + 2 + 2 + 3 = 8 hours
```

**Constraints:** `1 ≤ folders.count ≤ 10^4`; `1 ≤ folders[i] ≤ 10^9`; `folders.count ≤ hours ≤ 10^9`.

<!-- reveal -->

## First approach

It's Module 16's podcast problem with a different check. "Can speed `k` finish in time?" is false for slow speeds and true from some speed on: going faster never makes a folder take longer. So the answer is the first speed where the check says yes, and you binary search over speeds. The only new part is the check itself: a folder of `p` files takes ⌈p / k⌉ hours, rounded up, because its last partial hour can't be shared.

## Naive solution

Try speeds 1, 2, 3… until one works:

```swift
func hoursNeeded(_ folders: [Int], speed: Int) -> Int {
    var hours = 0
    for files in folders {
        hours += (files + speed - 1) / speed
    }
    return hours
}

func minimumSyncSpeed(_ folders: [Int], hours: Int) -> Int {
    var speed = 1
    while hoursNeeded(folders, speed: speed) > hours {
        speed += 1
    }
    return speed
}
```

## Problems with the naive solution

Each check is O(n), and the answer can be as large as the biggest folder, M. That's **O(n · M)** in the worst case: with 10^4 folders and M = 10^9, about 10^13 operations. It's correct, and it's the right thing to say first, but it can't run at these sizes.

## Optimized solution

Search the speeds `1...max(folders)` with the half-open first-true loop. The upper end always works: at the largest folder's size, every folder takes exactly one hour, and the problem promises `hours >= folders.count`. Each step runs the O(n) hours check once, and there are about log₂ M steps.

## Line by line

- `minimumSyncSpeedHours`: adds up ⌈files / speed⌉ for each folder. `(files + speed - 1) / speed` is the integer ceiling: adding `speed - 1` pushes any remainder over the next multiple. Both values are at most 10^9, so the sum can't overflow.
- `precondition(... hours >= folders.count ...)`: with fewer hours than folders, no speed works, and the problem rules that out.
- `var low = 1` and `var high = folders.max()!`: the slowest speed worth trying and one that always works. The force unwrap is safe because the precondition checked the list isn't empty.
- `if minimumSyncSpeedHours(folders, speed: mid) <= hours { high = mid }`: `mid` is fast enough, so it might be the answer; keep it as the edge.
- `else { low = mid + 1 }`: `mid` is too slow, and so is everything below it.
- `return low`: when the range is empty, `low` is the first speed that finishes in time.

## Common mistakes

- Dividing without rounding up: `files / speed` says 7 files at speed 4 take 1 hour; they take 2.
- Writing the ceiling as `Int((Double(files) / Double(speed)).rounded(.up))`. It works for small values, but it's slower and invites floating-point surprises. The integer formula is exact.
- Starting the range at 0, which divides by zero, or ending it at the total of all folders, which is correct but searches a far larger range than needed.

## Variation

**Capacity to ship packages within d days:** packages go in order, each day ships consecutive packages up to a capacity, and you want the smallest capacity that finishes in d days. Same search; the check fills each day greedily, as in the podcast example. The range starts at the heaviest package and ends at the total weight.

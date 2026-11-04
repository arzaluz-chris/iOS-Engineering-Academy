/// Hours the sync needs at `speed` files per hour: each folder takes ⌈files / speed⌉ hours,
/// because an hour is spent on one folder only.
func minimumSyncSpeedHours(_ folders: [Int], speed: Int) -> Int {
    var hours = 0
    for files in folders {
        hours += (files + speed - 1) / speed
    }
    return hours
}

/// Returns the smallest whole speed, in files per hour, that syncs every folder within `hours`.
///
/// Binary search on the answer: if a speed finishes in time, every faster speed does too.
/// The answer is between 1 and the largest folder (at that speed each folder takes one hour,
/// and `hours >= folders.count`). Each check is O(n), so the total is O(n log M) time,
/// with M the largest folder, and O(1) space.
public func minimumSyncSpeed(_ folders: [Int], hours: Int) -> Int {
    precondition(!folders.isEmpty && hours >= folders.count, "needs at least one hour per folder")
    var low = 1
    var high = folders.max()!
    while low < high {
        let mid = low + (high - low) / 2
        if minimumSyncSpeedHours(folders, speed: mid) <= hours {
            high = mid
        } else {
            low = mid + 1
        }
    }
    return low
}

/// Naive solution: try speeds 1, 2, 3… until one is fast enough. O(n · M) time, O(1) space.
public func minimumSyncSpeedBruteForce(_ folders: [Int], hours: Int) -> Int {
    precondition(!folders.isEmpty && hours >= folders.count, "needs at least one hour per folder")
    var speed = 1
    while minimumSyncSpeedHours(folders, speed: speed) > hours {
        speed += 1
    }
    return speed
}

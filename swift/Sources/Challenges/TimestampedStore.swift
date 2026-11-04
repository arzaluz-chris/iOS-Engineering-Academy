/// A key-value store that remembers every value a key has had, and answers
/// "what was this key's value at time t?".
///
/// Each key keeps its history as an array of `(timestamp, value)` pairs. Timestamps for one key
/// arrive in strictly increasing order, so appending keeps the array sorted, and a lookup is an
/// upper-bound binary search: the first entry with a timestamp greater than `t`; the entry just
/// before it is the answer.
/// `set` is O(1) amortized (plus hashing the key); `value(for:at:)` is O(log k) for a key with
/// k entries. Space is O(total number of `set` calls).
public struct TimestampedStore {
    private var history: [String: [(timestamp: Int, value: String)]] = [:]

    public init() {}

    /// Records `value` for `key` at `timestamp`. Timestamps for the same key must strictly increase.
    public mutating func set(_ key: String, _ value: String, at timestamp: Int) {
        if let previous = history[key]?.last {
            precondition(timestamp > previous.timestamp, "timestamps for a key must increase")
        }
        history[key, default: []].append((timestamp, value))
    }

    /// The value `key` had at `timestamp`: the one set at the latest time `<= timestamp`,
    /// or `nil` if the key had no value yet.
    public func value(for key: String, at timestamp: Int) -> String? {
        guard let entries = history[key] else { return nil }
        var low = 0
        var high = entries.count
        while low < high {
            let mid = low + (high - low) / 2
            if entries[mid].timestamp <= timestamp {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low == 0 ? nil : entries[low - 1].value
    }

    /// Naive lookup: walk the key's history from newest to oldest. O(k) time.
    public func valueBruteForce(for key: String, at timestamp: Int) -> String? {
        guard let entries = history[key] else { return nil }
        for entry in entries.reversed() where entry.timestamp <= timestamp {
            return entry.value
        }
        return nil
    }
}

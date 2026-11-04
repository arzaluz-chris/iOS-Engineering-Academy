/// A cache that holds at most `capacity` entries. When it's full and a new key arrives, it evicts
/// the entry that has been used the fewest times; among those, the least recently used one.
/// Both `get` (on a hit) and `put` count as a use. A capacity of 0 stores nothing.
///
/// Each entry records its use count and its neighbors in a doubly linked list of the entries with
/// that same use count, ordered from newest to oldest use. `buckets` gives each list's two ends, and
/// `fewestUses` is the smallest count in use, so the victim is always `buckets[fewestUses].oldest`.
/// The links are keys, not object references, as in the course's LRU cache.
/// `get` and `put` are O(1) on average (dictionary operations); O(capacity) space.
public final class LFUCache<Key: Hashable, Value> {
    private struct Entry {
        var value: Value
        var uses: Int
        var newer: Key?
        var older: Key?
    }

    private struct Bucket {
        var newest: Key?
        var oldest: Key?
    }

    public let capacity: Int
    private var entries: [Key: Entry] = [:]
    private var buckets: [Int: Bucket] = [:]
    private var fewestUses = 0

    public init(capacity: Int) {
        precondition(capacity >= 0, "capacity can't be negative")
        self.capacity = capacity
    }

    public var count: Int { entries.count }

    /// Returns the value for `key` and counts a use, or returns `nil` without changing anything.
    public func get(_ key: Key) -> Value? {
        guard let entry = entries[key] else { return nil }
        recordUse(of: key)
        return entry.value
    }

    /// Inserts or replaces the value for `key` and counts a use, evicting first if a new key
    /// arrives while the cache is full.
    public func put(_ key: Key, _ value: Value) {
        guard capacity > 0 else { return }
        if entries[key] != nil {
            entries[key]!.value = value
            recordUse(of: key)
            return
        }
        if entries.count == capacity, let victim = buckets[fewestUses]?.oldest {
            unlink(victim)
            entries[victim] = nil
        }
        entries[key] = Entry(value: value, uses: 1, newer: nil, older: nil)
        link(key)
        fewestUses = 1
    }

    /// Moves `key` from the list for its count to the newest end of the list for count + 1.
    private func recordUse(of key: Key) {
        let uses = entries[key]!.uses
        unlink(key)
        if uses == fewestUses && buckets[uses] == nil {
            fewestUses = uses + 1
        }
        entries[key]!.uses = uses + 1
        link(key)
    }

    /// Puts `key` at the newest end of the list for its current use count.
    private func link(_ key: Key) {
        let uses = entries[key]!.uses
        var bucket = buckets[uses] ?? Bucket()
        entries[key]!.newer = nil
        entries[key]!.older = bucket.newest
        if let previousNewest = bucket.newest {
            entries[previousNewest]!.newer = key
        } else {
            bucket.oldest = key
        }
        bucket.newest = key
        buckets[uses] = bucket
    }

    /// Takes `key` out of its list and drops the list if it's now empty. The entry stays in `entries`.
    private func unlink(_ key: Key) {
        let entry = entries[key]!
        var bucket = buckets[entry.uses]!
        if let newer = entry.newer {
            entries[newer]!.older = entry.older
        } else {
            bucket.newest = entry.older
        }
        if let older = entry.older {
            entries[older]!.newer = entry.newer
        } else {
            bucket.oldest = entry.newer
        }
        buckets[entry.uses] = bucket.newest == nil ? nil : bucket
    }
}

/// Naive solution: an array of entries with a use count and the time of the last use.
/// Lookups and evictions scan the array: O(capacity) per operation, O(capacity) space.
public final class LFUCacheLinearScan<Key: Hashable, Value> {
    private struct Entry {
        let key: Key
        var value: Value
        var uses: Int
        var lastUsed: Int
    }

    public let capacity: Int
    private var entries: [Entry] = []
    private var clock = 0

    public init(capacity: Int) {
        self.capacity = capacity
    }

    public var count: Int { entries.count }

    public func get(_ key: Key) -> Value? {
        guard let index = entries.firstIndex(where: { $0.key == key }) else { return nil }
        clock += 1
        entries[index].uses += 1
        entries[index].lastUsed = clock
        return entries[index].value
    }

    public func put(_ key: Key, _ value: Value) {
        guard capacity > 0 else { return }
        clock += 1
        if let index = entries.firstIndex(where: { $0.key == key }) {
            entries[index].value = value
            entries[index].uses += 1
            entries[index].lastUsed = clock
            return
        }
        if entries.count == capacity {
            let victim = entries.indices.min { a, b in
                (entries[a].uses, entries[a].lastUsed) < (entries[b].uses, entries[b].lastUsed)
            }!
            entries.remove(at: victim)
        }
        entries.append(Entry(key: key, value: value, uses: 1, lastUsed: clock))
    }
}

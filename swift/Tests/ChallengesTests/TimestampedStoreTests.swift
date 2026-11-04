import Testing
@testable import Challenges

@Suite("Time-Based Key-Value Store")
struct TimestampedStoreTests {
    @Test("Example from the problem statement")
    func example() {
        var flags = TimestampedStore()
        flags.set("checkout", "old", at: 10)
        flags.set("checkout", "new", at: 25)
        #expect(flags.value(for: "checkout", at: 5) == nil)
        #expect(flags.value(for: "checkout", at: 10) == "old")
        #expect(flags.value(for: "checkout", at: 24) == "old")
        #expect(flags.value(for: "checkout", at: 25) == "new")
        #expect(flags.value(for: "checkout", at: 1_000) == "new")
        #expect(flags.value(for: "search", at: 30) == nil)
    }

    @Test("Unknown key and empty store")
    func unknownKey() {
        let store = TimestampedStore()
        #expect(store.value(for: "anything", at: 0) == nil)
    }

    @Test("Exact timestamps, and times before the first one")
    func exactAndBefore() {
        var store = TimestampedStore()
        store.set("k", "a", at: 1)
        store.set("k", "b", at: 2)
        store.set("k", "c", at: 3)
        #expect(store.value(for: "k", at: 0) == nil)
        #expect(store.value(for: "k", at: 1) == "a")
        #expect(store.value(for: "k", at: 2) == "b")
        #expect(store.value(for: "k", at: 3) == "c")
    }

    @Test("Keys keep separate histories")
    func separateKeys() {
        var store = TimestampedStore()
        store.set("a", "a1", at: 5)
        store.set("b", "b1", at: 1)
        store.set("a", "a2", at: 9)
        #expect(store.value(for: "b", at: 9) == "b1")
        #expect(store.value(for: "a", at: 8) == "a1")
        #expect(store.value(for: "b", at: 0) == nil)
    }

    @Test("The same value set twice still answers by time")
    func repeatedValues() {
        var store = TimestampedStore()
        store.set("k", "x", at: 1)
        store.set("k", "y", at: 4)
        store.set("k", "x", at: 7)
        #expect(store.value(for: "k", at: 5) == "y")
        #expect(store.value(for: "k", at: 7) == "x")
    }

    @Test("Binary search lookup agrees with the linear one on random histories")
    func agreesWithBruteForce() {
        var random = LCG(state: 49)
        var store = TimestampedStore()
        let keys = ["a", "b", "c", "d"]
        var latest: [String: Int] = [:]
        for step in 0..<2_000 {
            let key = keys[random.next(0...3)]
            let time = (latest[key] ?? 0) + random.next(1...5)
            latest[key] = time
            store.set(key, "v\(step)", at: time)
        }
        for _ in 0..<2_000 {
            let key = keys[random.next(0...3)] + (random.next(0...9) == 0 ? "missing" : "")
            let time = random.next(-5...(latest.values.max()! + 5))
            #expect(store.value(for: key, at: time) == store.valueBruteForce(for: key, at: time))
        }
    }
}

/// Small deterministic generator so failures reproduce.
private struct LCG {
    var state: UInt64
    mutating func next(_ range: ClosedRange<Int>) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return range.lowerBound + Int((state >> 33) % UInt64(range.count))
    }
}

import Testing
@testable import Challenges

@Suite("LFU Cache")
struct LFUCacheTests {
    @Test("Example from the problem statement")
    func example() {
        let cache = LFUCache<String, Int>(capacity: 2)
        cache.put("a", 1)
        cache.put("b", 2)
        #expect(cache.get("a") == 1)    // a: 2 uses, b: 1 use
        cache.put("c", 3)               // full: evicts b, the least used
        #expect(cache.get("b") == nil)
        #expect(cache.get("c") == 3)    // a and c: 2 uses each, c more recent
        cache.put("d", 4)               // tie on uses: evicts a, the least recently used
        #expect(cache.get("a") == nil)
        #expect(cache.get("c") == 3)
        #expect(cache.get("d") == 4)
    }

    @Test("Capacity 0 stores nothing")
    func zeroCapacity() {
        let cache = LFUCache<Int, Int>(capacity: 0)
        cache.put(1, 1)
        #expect(cache.get(1) == nil)
        #expect(cache.count == 0)
    }

    @Test("Capacity 1 always replaces")
    func capacityOne() {
        let cache = LFUCache<Int, String>(capacity: 1)
        cache.put(1, "one")
        _ = cache.get(1)
        _ = cache.get(1)
        cache.put(2, "two")
        #expect(cache.get(1) == nil)
        #expect(cache.get(2) == "two")
        #expect(cache.count == 1)
    }

    @Test("Updating a key counts as a use and doesn't evict")
    func update() {
        let cache = LFUCache<String, Int>(capacity: 2)
        cache.put("a", 1)
        cache.put("b", 2)
        cache.put("a", 10)              // a: 2 uses
        #expect(cache.count == 2)
        cache.put("c", 3)               // evicts b
        #expect(cache.get("a") == 10)
        #expect(cache.get("b") == nil)
        #expect(cache.get("c") == 3)
    }

    @Test("A miss changes nothing")
    func miss() {
        let cache = LFUCache<String, Int>(capacity: 2)
        cache.put("a", 1)
        cache.put("b", 2)
        #expect(cache.get("zzz") == nil)
        cache.put("c", 3)               // a and b both have 1 use; a is older
        #expect(cache.get("a") == nil)
        #expect(cache.get("b") == 2)
    }

    @Test("The new key is never the one evicted next, even with the lowest count")
    func newKeyResetsMinimum() {
        let cache = LFUCache<Int, Int>(capacity: 2)
        cache.put(1, 1)
        cache.put(2, 2)
        for _ in 0..<5 { _ = cache.get(1); _ = cache.get(2) }
        cache.put(3, 3)                 // evicts 1 (6 uses, older than 2)
        cache.put(4, 4)                 // evicts 3 (1 use), not 2
        #expect(cache.get(2) == 2)
        #expect(cache.get(3) == nil)
        #expect(cache.get(4) == 4)
    }

    @Test("Agrees with a linear-scan cache on random operations")
    func agreesWithLinearScan() {
        var generator = LFUCacheLCG(seed: 1)
        for _ in 0..<200 {
            let capacity = generator.next(below: 5)
            let fast = LFUCache<Int, Int>(capacity: capacity)
            let slow = LFUCacheLinearScan<Int, Int>(capacity: capacity)
            for step in 0..<60 {
                let key = generator.next(below: 7)
                if generator.next(below: 2) == 0 {
                    #expect(fast.get(key) == slow.get(key))
                } else {
                    fast.put(key, step)
                    slow.put(key, step)
                }
                #expect(fast.count == slow.count)
            }
        }
    }
}

/// Deterministic generator so failures reproduce.
private struct LFUCacheLCG {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}

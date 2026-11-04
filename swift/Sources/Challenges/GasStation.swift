/// Returns the stop where a scooter with an empty battery can start and ride the whole loop once,
/// or `nil` if no stop works. At stop i it picks up `charge[i]` units, and riding from stop i to the
/// next one (stop 0 after the last) uses `cost[i]`. The battery has no upper limit and must never go
/// below zero. If several stops work, returns the smallest index.
///
/// Greedy, one pass. If the battery goes negative after stop i, no stop between the current start
/// and i can be the start either, so the next candidate is i + 1. If the total net charge is
/// non-negative, the last candidate completes the loop.
/// O(n) time, O(1) extra space.
public func startingChargerIndex(charge: [Int], cost: [Int]) -> Int? {
    guard !charge.isEmpty else { return nil }
    var totalNet = 0
    var battery = 0
    var start = 0
    for index in charge.indices {
        let net = charge[index] - cost[index]
        totalNet += net
        battery += net
        if battery < 0 {
            start = index + 1
            battery = 0
        }
    }
    return totalNet >= 0 ? start : nil
}

/// Naive solution: simulate the ride from every stop. O(n²) time, O(1) extra space.
public func startingChargerIndexBruteForce(charge: [Int], cost: [Int]) -> Int? {
    for start in charge.indices {
        var battery = 0
        var completed = true
        for step in 0..<charge.count {
            let index = (start + step) % charge.count
            battery += charge[index] - cost[index]
            if battery < 0 {
                completed = false
                break
            }
        }
        if completed { return start }
    }
    return nil
}

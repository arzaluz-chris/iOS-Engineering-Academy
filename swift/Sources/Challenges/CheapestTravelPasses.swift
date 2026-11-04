/// Returns the lowest total price that covers every day in `travelDays` with transit passes.
/// A day pass covers 1 day, a week pass 7 consecutive days and a month pass 30 consecutive days,
/// starting on the day you buy it. `travelDays` is strictly increasing, with days from 1 to 365.
///
/// cost[d] is the cheapest way to cover every travel day up to day d. A day you don't travel costs
/// nothing extra; on a travel day, the last pass bought covering it was a day, week or month pass.
/// O(D) time and space, where D is the last travel day (at most 365).
public func cheapestPassCost(travelDays: [Int], dayPrice: Int, weekPrice: Int, monthPrice: Int) -> Int {
    guard let lastDay = travelDays.last else { return 0 }
    var isTravelDay = Array(repeating: false, count: lastDay + 1)
    for day in travelDays {
        isTravelDay[day] = true
    }
    var cost = Array(repeating: 0, count: lastDay + 1)   // cost[0] = 0: nothing to cover yet
    for day in 1...lastDay {
        guard isTravelDay[day] else {
            cost[day] = cost[day - 1]
            continue
        }
        cost[day] = min(
            cost[day - 1] + dayPrice,
            cost[max(0, day - 7)] + weekPrice,
            cost[max(0, day - 30)] + monthPrice
        )
    }
    return cost[lastDay]
}

/// Naive solution: at the first uncovered travel day, try buying each of the three passes and recurse.
/// O(3ⁿ) time for n travel days, O(n) stack depth.
public func cheapestPassCostBruteForce(travelDays: [Int], dayPrice: Int, weekPrice: Int, monthPrice: Int) -> Int {
    func cheapest(from index: Int) -> Int {
        guard index < travelDays.count else { return 0 }
        var best = Int.max
        for (length, price) in [(1, dayPrice), (7, weekPrice), (30, monthPrice)] {
            let coveredThrough = travelDays[index] + length - 1
            var next = index
            while next < travelDays.count && travelDays[next] <= coveredThrough {
                next += 1
            }
            best = min(best, price + cheapest(from: next))
        }
        return best
    }
    return cheapest(from: 0)
}

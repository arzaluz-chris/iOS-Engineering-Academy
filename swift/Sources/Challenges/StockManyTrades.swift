/// Given a product's price on each day, returns the largest total gain from buying and selling
/// any number of times, holding at most one unit at a time. Selling and buying again on the
/// same day is allowed. Returns 0 if no trade gains anything.
///
/// Any trade's gain equals the sum of the daily changes between its buy and sell days, so the
/// best total is the sum of every positive daily change: buy before each rise, sell after it.
/// O(n) time, O(1) space.
public func totalGainFromTrades(_ prices: [Int]) -> Int {
    var total = 0
    for (yesterday, today) in zip(prices, prices.dropFirst()) where today > yesterday {
        total += today - yesterday
    }
    return total
}

/// Naive solution: try every choice on every day (buy, sell or wait) with recursion.
/// Exponential time, O(n) space for the recursion. Only usable for a handful of days.
public func totalGainFromTradesBruteForce(_ prices: [Int]) -> Int {
    func best(from day: Int, holdingBoughtAt price: Int?) -> Int {
        guard day < prices.count else { return 0 }
        let wait = best(from: day + 1, holdingBoughtAt: price)
        if let price {
            let sellToday = prices[day] - price
            let sellAndStop = sellToday + best(from: day + 1, holdingBoughtAt: nil)
            let sellAndRebuy = sellToday + best(from: day + 1, holdingBoughtAt: prices[day])
            return max(wait, sellAndStop, sellAndRebuy)
        } else {
            return max(wait, best(from: day + 1, holdingBoughtAt: prices[day]))
        }
    }
    return best(from: 0, holdingBoughtAt: nil)
}

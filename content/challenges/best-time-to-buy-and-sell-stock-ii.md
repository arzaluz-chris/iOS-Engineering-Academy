---
id: best-time-to-buy-and-sell-stock-ii
title: Best Time to Buy and Sell Stock II
difficulty: easy
order: 16
patterns: [Linear traversal, Greedy, Neighbor comparison]
prerequisites: [m07, m15, m16-l01]
summary: Buy and sell as many times as you like, holding one unit at most. The best total turns out to be a one-line sum, and the work is in proving it.
solutionFile: StockManyTrades.swift
testFile: StockManyTradesTests.swift
starter: |
  func totalGainFromTrades(_ prices: [Int]) -> Int {
      // Your solution
      return 0
  }
time: O(n)
space: O(1)
edgeCases:
  - Empty history and a single day
  - Prices that only fall
  - Flat prices
  - Prices that alternate up and down every day
askInterviewer:
  - Can I hold more than one unit at a time?
  - Can I sell and buy again on the same day?
  - Are there fees per trade?
  - What do I return if no trade makes money?
hints:
  - "Write down the gain of a single trade from day i to day j as a sum of daily changes. What do you notice?"
  - "If a trade's gain is the sum of the daily changes inside it, which daily changes would you like your trades to cover?"
  - "Walk the neighbors once with zip(prices, prices.dropFirst()) and add every rise."
followUps:
  - "What if each trade pays a fixed fee? (The greedy sum stops working; keep two states, holding and not holding.)"
  - What if you can make at most one trade? At most two?
  - How would you return the actual buy and sell days?
rubric:
  - I clarified the rules (one unit at a time, same-day sell and buy).
  - I explained why the answer is the sum of positive daily changes.
  - I walked neighbors without crashing on empty or one-day input.
  - I stated O(n) time and O(1) space.
codeStatus: tested
---

A trading simulator gives you a product's price for each day. You can buy one unit and later sell it, as many times as you like, but you can hold **at most one unit at a time**. Selling and then buying again on the same day is allowed. Return the largest total gain you can make, or 0 if no trade gains anything.

Write `totalGainFromTrades(_ prices: [Int]) -> Int`.

```swift
totalGainFromTrades([8, 3, 6, 4, 9, 10])  // 9: buy 3 sell 6, buy 4 sell 10
totalGainFromTrades([1, 2, 3, 4])         // 3: one trade, or three one-day trades
totalGainFromTrades([9, 7, 4, 1])         // 0
```

**Constraints:** `0 ≤ prices.count ≤ 3·10^4`; `0 ≤ prices[i] ≤ 10^4`.

<!-- reveal -->

## First approach

A trade from day `i` to day `j` gains `prices[j] − prices[i]`, which is the sum of the daily changes from `i` to `j`. So any set of trades gains the sum of the daily changes they cover. The best you could hope for is to cover every positive change and none of the negative ones, and you can: a one-day trade over every rise does exactly that.

## Naive solution

Try everything: on each day, decide to wait, buy, or sell (and possibly buy again), and keep the best outcome:

```swift
func totalGainFromTrades(_ prices: [Int]) -> Int {
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
```

## Problems with the naive solution

Each day branches into two or three calls, so the work grows exponentially: up to 3^n calls. Fifteen days already means millions of calls; 3·10^4 days is out of the question. It's still useful as a checker for small inputs, which is how the tests use it.

## Optimized solution

Add up every positive difference between consecutive days. That total is an upper bound on any strategy, because every strategy's gain is a sum of daily changes, each counted at most once. And it's reachable, by buying the day before each rise and selling the day of it. Consecutive rises chain into one longer trade with the same total.

## Line by line

- `zip(prices, prices.dropFirst())` pairs each day with the next one. An empty or one-day array gives no pairs, so there's no range to crash on.
- `where today > yesterday`: only rises are collected; falls and flat days are skipped.
- `total += today - yesterday`: the gain of a one-day trade over that rise.
- **O(n) time, O(1) space.** The total is at most 10^4 × 3·10^4 = 3·10^8, comfortably within `Int`.

## Common mistakes

- Solving the one-trade version (lowest price before the highest) and returning that. With several trades allowed, `[8, 3, 6, 4, 9, 10]` makes 9, not 7.
- Looping with `for i in 1..<prices.count`, which traps on an empty array.
- Trying to find "valleys and peaks" with nested `while` loops. It works, but it's easy to get the bounds wrong, and it computes the same total.

## Variation

**With a fee per trade:** each sale costs `fee`. Now many small trades can lose to one big one, so the greedy sum is wrong. Keep two numbers for each day: the best total if you're not holding (`cash`) and if you are (`hold`). Each day, `cash = max(cash, hold + price − fee)` (sell today or don't) and `hold = max(hold, previousCash − price)` (buy today or don't), where `previousCash` is the value before today's update. That's dynamic programming with O(1) state, Module 20's territory.

import Testing
@testable import Challenges

@Suite("Last Stone Weight")
struct LastStoneWeightTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(lastStoneWeight([3, 7, 2, 4]) == 2)
        #expect(lastStoneWeight([10, 4, 1]) == 5)
        #expect(lastStoneWeight([6]) == 6)
    }

    @Test("Empty pile")
    func empty() {
        #expect(lastStoneWeight([]) == 0)
    }

    @Test("Two equal stones destroy each other")
    func equalPair() {
        #expect(lastStoneWeight([5, 5]) == 0)
        #expect(lastStoneWeight([5, 5, 5]) == 5)
    }

    @Test("A stone of weight 1 among large ones")
    func mixed() {
        #expect(lastStoneWeight([1, 1_000, 1_000]) == 1)
    }

    @Test("The heap pops in descending order")
    func heapOrder() {
        var heap = StoneMaxHeap([4, 9, 1, 7, 7, 3])
        heap.push(8)
        var popped: [Int] = []
        while let value = heap.pop() { popped.append(value) }
        #expect(popped == [9, 8, 7, 7, 4, 3, 1])
    }

    @Test("Agrees with the sorting version on random piles")
    func agreesWithBruteForce() {
        var generator = TreeChallengeLCG(seed: 75)
        for _ in 0..<300 {
            let stones = (0..<generator.next(in: 0...30)).map { _ in generator.next(in: 1...50) }
            #expect(lastStoneWeight(stones) == lastStoneWeightBySorting(stones))
        }
    }
}

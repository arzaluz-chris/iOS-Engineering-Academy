import Testing
@testable import Challenges

@Suite("Find Median from Data Stream")
struct FindMedianFromDataStreamTests {
    private func medians(_ values: [Int]) -> [Double?] {
        var stream = RunningMedian()
        var result: [Double?] = [stream.median()]
        for value in values {
            stream.add(value)
            result.append(stream.median())
        }
        return result
    }

    @Test("Examples from the problem statement")
    func examples() {
        #expect(medians([5, 15, 1, 3]) == [nil, 5, 10, 5, 4])
    }

    @Test("No values yet")
    func empty() {
        #expect(RunningMedian().median() == nil)
    }

    @Test("Duplicates and negatives")
    func duplicatesAndNegatives() {
        #expect(medians([-2, -2, -2]) == [nil, -2, -2, -2])
        #expect(medians([-5, 5]) == [nil, -5, 0])
    }

    @Test("Sorted and reverse-sorted input")
    func sortedInput() {
        #expect(medians([1, 2, 3, 4, 5]) == [nil, 1, 1.5, 2, 2.5, 3])
        #expect(medians([5, 4, 3, 2, 1]) == [nil, 5, 4.5, 4, 3.5, 3])
    }

    @Test("The average of two large values doesn't overflow")
    func largeValues() {
        #expect(medians([Int.max, Int.max]).last == Double(Int.max))
    }

    @Test("Agrees with the sorted-array version on a random stream")
    func agreesWithSortedArray() {
        var generator = TreeChallengeLCG(seed: 76)
        var fast = RunningMedian()
        var slow = RunningMedianSortedArray()
        for _ in 0..<2_000 {
            let value = generator.next(in: -100...100)
            fast.add(value)
            slow.add(value)
            #expect(fast.median() == slow.median())
        }
    }
}

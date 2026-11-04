import Testing
@testable import Challenges

@Suite("Minimum Sync Speed")
struct MinimumSyncSpeedTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(minimumSyncSpeed([30, 11, 23, 4, 20], hours: 5) == 30)
        #expect(minimumSyncSpeed([30, 11, 23, 4, 20], hours: 6) == 23)
        #expect(minimumSyncSpeed([3, 6, 7, 11], hours: 8) == 4)
    }

    @Test("Hours equal to the number of folders means the largest folder's size")
    func oneHourPerFolder() {
        #expect(minimumSyncSpeed([5, 9, 2], hours: 3) == 9)
    }

    @Test("Plenty of hours brings the speed down to 1")
    func plentyOfHours() {
        #expect(minimumSyncSpeed([5, 9, 2], hours: 16) == 1)
        #expect(minimumSyncSpeed([5, 9, 2], hours: 1_000) == 1)
        #expect(minimumSyncSpeed([5, 9, 2], hours: 15) == 2)
    }

    @Test("A single folder")
    func singleFolder() {
        #expect(minimumSyncSpeed([10], hours: 3) == 4)
        #expect(minimumSyncSpeed([1], hours: 1) == 1)
    }

    @Test("Large sizes don't overflow and stay fast")
    func largeSizes() {
        let folders = Array(repeating: 1_000_000_000, count: 1_000)
        #expect(minimumSyncSpeed(folders, hours: 1_000) == 1_000_000_000)
        #expect(minimumSyncSpeed(folders, hours: 1_000_000_000) == 1_000)
        #expect(minimumSyncSpeed([1_000_000_000], hours: 2) == 500_000_000)
    }

    @Test("Agrees with trying every speed on random inputs")
    func agreesWithBruteForce() {
        var random = LCG(state: 46)
        for _ in 0..<500 {
            let folders = (0..<random.next(1...8)).map { _ in random.next(1...60) }
            let hours = random.next(folders.count...(folders.count + 70))
            #expect(minimumSyncSpeed(folders, hours: hours) == minimumSyncSpeedBruteForce(folders, hours: hours))
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

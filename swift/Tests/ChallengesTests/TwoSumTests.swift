import Testing
@testable import Challenges

@Suite("Two Sum")
struct TwoSumTests {
    @Test("Ejemplos del enunciado")
    func ejemplos() {
        #expect(twoSum([2, 7, 11, 15], 9) == [0, 1])
        #expect(twoSum([3, 2, 4], 6) == [1, 2])
        #expect(twoSum([3, 3], 6) == [0, 1])
    }

    @Test("Un elemento no se empareja consigo mismo")
    func noReutilizaElMismoIndice() {
        #expect(twoSum([3, 5], 6) == nil)
    }

    @Test("Sin solución")
    func sinSolucion() {
        #expect(twoSum([1, 2, 3], 100) == nil)
        #expect(twoSum([], 0) == nil)
        #expect(twoSum([5], 5) == nil)
    }

    @Test("Negativos y cero")
    func negativos() {
        #expect(twoSum([-3, 4, 3, 90], 0) == [0, 2])
        #expect(twoSum([0, 4, 3, 0], 0) == [0, 3])
    }

    @Test("La solución optimizada coincide con la ingenua", arguments: [
        ([2, 7, 11, 15], 9),
        ([1, 5, 1, 5], 10),
        ([4, -2, 8, 0, 6], 6),
        ([1, 2, 3], 7),
    ])
    func coincideConFuerzaBruta(nums: [Int], target: Int) {
        let fast = twoSum(nums, target)
        let slow = twoSumBruteForce(nums, target)
        #expect((fast == nil) == (slow == nil))
        if let fast {
            #expect(fast[0] < fast[1])
            #expect(nums[fast[0]] + nums[fast[1]] == target)
        }
    }
}

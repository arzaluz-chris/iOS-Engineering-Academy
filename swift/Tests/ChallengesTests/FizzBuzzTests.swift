import Testing
@testable import Challenges

@Suite("FizzBuzz")
struct FizzBuzzTests {
    @Test("1 through 15")
    func firstFifteen() {
        let expected = [
            "1", "2", "Fizz", "4", "Buzz", "Fizz", "7", "8", "Fizz", "Buzz",
            "11", "Fizz", "13", "14", "FizzBuzz",
        ]
        #expect(fizzBuzz(15) == expected)
    }

    @Test("A single number")
    func one() {
        #expect(fizzBuzz(1) == ["1"])
    }

    @Test("Zero and negatives produce an empty list", arguments: [0, -1, -15])
    func noNumbers(n: Int) {
        #expect(fizzBuzz(n).isEmpty)
    }

    @Test("Multiples of 15 end in FizzBuzz", arguments: [15, 30, 45])
    func multiplesOfFifteen(n: Int) {
        #expect(fizzBuzz(n).last == "FizzBuzz")
    }

    @Test("Length matches n")
    func length() {
        #expect(fizzBuzz(100).count == 100)
    }
}

import Testing
@testable import Challenges

@Suite("FizzBuzz")
struct FizzBuzzTests {
    @Test("Del 1 al 15")
    func primerosQuince() {
        let expected = [
            "1", "2", "Fizz", "4", "Buzz", "Fizz", "7", "8", "Fizz", "Buzz",
            "11", "Fizz", "13", "14", "FizzBuzz",
        ]
        #expect(fizzBuzz(15) == expected)
    }

    @Test("Un solo número")
    func uno() {
        #expect(fizzBuzz(1) == ["1"])
    }

    @Test("Cero y negativos producen una lista vacía", arguments: [0, -1, -15])
    func sinNumeros(n: Int) {
        #expect(fizzBuzz(n).isEmpty)
    }

    @Test("Los múltiplos de 15 terminan en FizzBuzz", arguments: [15, 30, 45])
    func multiplosDeQuince(n: Int) {
        #expect(fizzBuzz(n).last == "FizzBuzz")
    }

    @Test("La longitud coincide con n")
    func longitud() {
        #expect(fizzBuzz(100).count == 100)
    }
}

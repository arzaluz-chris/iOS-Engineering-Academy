import Testing
@testable import Challenges

@Suite("Phone Keypad Letter Combinations")
struct KeypadCombinationsTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(keypadCombinations("29") == ["aw", "ax", "ay", "az", "bw", "bx", "by", "bz", "cw", "cx", "cy", "cz"])
        #expect(keypadCombinations("5") == ["j", "k", "l"])
        #expect(keypadCombinations("") == [])
    }

    @Test("Keys with four letters")
    func fourLetterKeys() {
        #expect(keypadCombinations("7").count == 4)
        #expect(keypadCombinations("79").count == 16)
        #expect(keypadCombinations("7979").count == 256)
    }

    @Test("Repeated digit")
    func repeatedDigit() {
        #expect(keypadCombinations("22") == ["aa", "ab", "ac", "ba", "bb", "bc", "ca", "cb", "cc"])
    }

    @Test("Count is the product of the key sizes, and there are no repeats")
    func counts() {
        let result = keypadCombinations("234789")
        #expect(result.count == 3 * 3 * 3 * 4 * 3 * 4)
        #expect(Set(result).count == result.count)
        #expect(result == result.sorted())
    }

    @Test("Agrees with the iterative version on every two- and three-digit input")
    func agreesWithIterative() {
        for a in 2...9 {
            for b in 2...9 {
                #expect(keypadCombinations("\(a)\(b)") == keypadCombinationsIterative("\(a)\(b)"))
                for c in [2, 7, 9] {
                    #expect(keypadCombinations("\(a)\(b)\(c)") == keypadCombinationsIterative("\(a)\(b)\(c)"))
                }
            }
        }
    }
}

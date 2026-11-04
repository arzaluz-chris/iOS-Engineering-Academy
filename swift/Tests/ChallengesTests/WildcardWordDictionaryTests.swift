import Testing
@testable import Challenges

@Suite("Wildcard Word Dictionary")
struct WildcardWordDictionaryTests {
    @Test("Examples from the problem statement")
    func examples() {
        let dictionary = WildcardWordDictionary()
        for word in ["cat", "car", "card", "dog"] { dictionary.addWord(word) }
        #expect(dictionary.search("car"))
        #expect(!dictionary.search("ca"))
        #expect(dictionary.search("c.r"))
        #expect(dictionary.search("..g"))
        #expect(dictionary.search("...."))
        #expect(!dictionary.search("....."))
        #expect(!dictionary.search("d.t"))
    }

    @Test("A prefix of a stored word isn't a word")
    func prefixIsNotAWord() {
        let dictionary = WildcardWordDictionary()
        dictionary.addWord("planet")
        #expect(!dictionary.search("plan"))
        #expect(!dictionary.search("pla."))
        dictionary.addWord("plan")
        #expect(dictionary.search("pla."))
    }

    @Test("Only dots")
    func onlyDots() {
        let dictionary = WildcardWordDictionary()
        #expect(!dictionary.search("."))
        dictionary.addWord("a")
        #expect(dictionary.search("."))
        #expect(!dictionary.search(".."))
    }

    @Test("Empty word and empty pattern")
    func emptyWord() {
        let dictionary = WildcardWordDictionary()
        #expect(!dictionary.search(""))
        dictionary.addWord("")
        #expect(dictionary.search(""))
    }

    @Test("Adding the same word twice changes nothing")
    func duplicates() {
        let dictionary = WildcardWordDictionary()
        dictionary.addWord("ok")
        dictionary.addWord("ok")
        #expect(dictionary.search("o."))
        #expect(!dictionary.search("o"))
    }

    @Test("A dot has to backtrack when the first branch fails")
    func backtracking() {
        let dictionary = WildcardWordDictionary()
        dictionary.addWord("abx")
        dictionary.addWord("acy")
        dictionary.addWord("adz")
        #expect(dictionary.search("a.z"))
        #expect(dictionary.search(".c."))
        #expect(!dictionary.search("a.w"))
    }

    @Test("Agrees with the word list on random words and patterns")
    func agreesWithWordList() {
        var generator = TreeChallengeLCG(seed: 74)
        let letters: [Character] = ["a", "b", "c"]
        func randomWord(maxLength: Int, dots: Bool) -> String {
            let length = generator.next(in: 0...maxLength)
            return String((0..<length).map { _ in
                if dots && generator.next() % 3 == 0 { return Character(".") }
                return letters[generator.next(in: 0...2)]
            })
        }
        for _ in 0..<30 {
            let trie = WildcardWordDictionary()
            let list = WildcardWordList()
            for _ in 0..<generator.next(in: 0...15) {
                let word = randomWord(maxLength: 5, dots: false)
                trie.addWord(word)
                list.addWord(word)
            }
            for _ in 0..<60 {
                let pattern = randomWord(maxLength: 6, dots: true)
                #expect(trie.search(pattern) == list.search(pattern))
            }
        }
    }
}

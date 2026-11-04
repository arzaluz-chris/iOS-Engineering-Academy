import Testing
@testable import Challenges

@Suite("Text Justification")
struct TextJustificationTests {
    @Test("Example from the problem statement")
    func example() {
        #expect(justifyText(["Your", "order", "is", "on", "its", "way", "to", "you"], width: 12) == [
            "Your   order",
            "is   on  its",
            "way to you  ",
        ])
    }

    @Test("A line with one word is left-aligned")
    func singleWordLine() {
        #expect(justifyText(["Hello", "world"], width: 7) == ["Hello  ", "world  "])
    }

    @Test("A word exactly as wide as the line")
    func exactWord() {
        #expect(justifyText(["Notifications"], width: 13) == ["Notifications"])
        #expect(justifyText(["ab", "cd"], width: 2) == ["ab", "cd"])
    }

    @Test("The last line is left-aligned and padded")
    func lastLine() {
        #expect(justifyText(["a", "bb"], width: 5) == ["a bb "])
    }

    @Test("Extra spaces go to the leftmost gaps")
    func extraSpacesLeft() {
        // 4 letters, 7 spaces over 3 gaps: 3, 2, 2.
        #expect(justifyText(["a", "b", "c", "d", "ending"], width: 11) == ["a   b  c  d", "ending     "])
    }

    @Test("No words, no lines")
    func empty() {
        #expect(justifyText([], width: 10) == [])
    }

    @Test("Agrees with inserting spaces one at a time, and every line has the full width")
    func agreesWithNaive() {
        var generator = JustificationLCG(seed: 17)
        for _ in 0..<300 {
            let width = 1 + generator.next(below: 20)
            let words = (0..<generator.next(below: 15)).map { _ in
                String(repeating: "w", count: 1 + generator.next(below: width))
            }
            let lines = justifyText(words, width: width)
            #expect(lines == justifyTextBySpaceInsertion(words, width: width), "\(words) \(width)")
            #expect(lines.allSatisfy { $0.count == width })
            #expect(lines.flatMap { $0.split(separator: " ").map(String.init) } == words)
        }
    }
}

/// Deterministic generator so failures reproduce.
private struct JustificationLCG {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}

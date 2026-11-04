import Testing
@testable import Challenges

@Suite("Semantic Version Precedence")
struct SemanticVersionPrecedenceTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(compareSemanticVersions("1.10.0", "1.9.3") == 1)
        #expect(compareSemanticVersions("2.0.0-beta.2", "2.0.0-beta.10") == -1)
        #expect(compareSemanticVersions("3.1.0-rc.1", "3.1.0") == -1)
        #expect(compareSemanticVersions("1.4.2+build.7", "1.4.2") == 0)
    }

    @Test("Equal versions")
    func equal() {
        #expect(compareSemanticVersions("0.0.0", "0.0.0") == 0)
        #expect(compareSemanticVersions("4.2.0-alpha.1", "4.2.0-alpha.1") == 0)
        #expect(compareSemanticVersions("1.0.0-rc.1+ios", "1.0.0-rc.1+mac") == 0)
    }

    @Test("A numeric identifier comes before an alphanumeric one")
    func numericFirst() {
        #expect(compareSemanticVersions("1.0.0-9", "1.0.0-a") == -1)
        #expect(compareSemanticVersions("1.0.0-beta.9", "1.0.0-beta.x") == -1)
    }

    @Test("Alphanumeric identifiers compare by ASCII, so uppercase sorts first")
    func ascii() {
        #expect(compareSemanticVersions("1.0.0-Beta", "1.0.0-alpha") == -1)
        #expect(compareSemanticVersions("1.0.0-alpha", "1.0.0-alpha2") == -1)
    }

    @Test("A longer pre-release list wins when the shared part is equal")
    func longerList() {
        #expect(compareSemanticVersions("1.0.0-alpha", "1.0.0-alpha.0") == -1)
        #expect(compareSemanticVersions("1.0.0-rc.1.1", "1.0.0-rc.1") == 1)
    }

    @Test("Hyphens inside the pre-release and build metadata")
    func hyphens() {
        #expect(compareSemanticVersions("1.0.0-x-y", "1.0.0-x") == 1)
        #expect(compareSemanticVersions("1.0.0+build-5", "1.0.0") == 0)
        #expect(compareSemanticVersions("1.0.0-rc.1+build-5", "1.0.0") == -1)
    }

    @Test("Numbers too big for Int still compare correctly")
    func hugeNumbers() {
        #expect(compareSemanticVersions("18446744073709551616.0.0", "2.0.0") == 1)
        #expect(compareSemanticVersions("1.0.0-99999999999999999999999", "1.0.0-100000000000000000000000") == -1)
    }

    @Test("A full ordering: every pair compares by position")
    func fullOrdering() {
        let ordered = [
            "0.9.12",
            "1.0.0-0",
            "1.0.0-3",
            "1.0.0-21",
            "1.0.0-RC",
            "1.0.0-beta",
            "1.0.0-beta.1",
            "1.0.0-beta.1.0",
            "1.0.0-beta.4",
            "1.0.0-beta.12",
            "1.0.0-beta.b",
            "1.0.0-rc.1",
            "1.0.0",
            "1.0.1",
            "1.2.0",
            "1.10.0",
            "2.0.0-alpha",
            "2.0.0",
            "10.0.0",
        ]
        for i in ordered.indices {
            for j in ordered.indices {
                let expected = i < j ? -1 : (i > j ? 1 : 0)
                #expect(compareSemanticVersions(ordered[i], ordered[j]) == expected, "\(ordered[i]) vs \(ordered[j])")
            }
        }
        #expect(ordered.reversed().sorted { compareSemanticVersions($0, $1) < 0 } == ordered)
    }
}

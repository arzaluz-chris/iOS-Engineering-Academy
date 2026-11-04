/// A word list that answers searches where `.` stands for any single letter.
///
/// Words are stored in a trie, one node per prefix. A search walks the trie one pattern character
/// at a time; a letter follows one child, a `.` tries every child. Because the pattern position
/// always equals the node's depth, a search visits each trie node at most once.
///
/// - `addWord`: O(L) time for a word of length L, O(L) new nodes at most.
/// - `search`: O(L) without dots; O(total characters stored) in the worst case with dots.
public final class WildcardWordDictionary {
    private final class Node {
        var children: [Character: Node] = [:]
        var endsWord = false
    }

    private let root = Node()

    public init() {}

    public func addWord(_ word: String) {
        var node = root
        for character in word {
            if let next = node.children[character] {
                node = next
            } else {
                let next = Node()
                node.children[character] = next
                node = next
            }
        }
        node.endsWord = true
    }

    public func search(_ pattern: String) -> Bool {
        let characters = Array(pattern)

        func matches(from node: Node, at position: Int) -> Bool {
            if position == characters.count { return node.endsWord }
            let character = characters[position]
            if character == "." {
                for child in node.children.values where matches(from: child, at: position + 1) {
                    return true
                }
                return false
            }
            guard let child = node.children[character] else { return false }
            return matches(from: child, at: position + 1)
        }

        return matches(from: root, at: 0)
    }
}

/// Naive solution: keep the words in a list and compare the pattern against each one of the same
/// length. `addWord` is O(1) amortized; `search` is O(N · L) for N stored words.
public final class WildcardWordList {
    private var words: [[Character]] = []

    public init() {}

    public func addWord(_ word: String) {
        words.append(Array(word))
    }

    public func search(_ pattern: String) -> Bool {
        let characters = Array(pattern)
        return words.contains { word in
            word.count == characters.count
                && zip(word, characters).allSatisfy { $1 == "." || $0 == $1 }
        }
    }
}

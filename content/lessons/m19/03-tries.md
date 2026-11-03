---
id: m19-l03
title: Tries
description: You build a trie, a tree whose edges are characters, so that words sharing a prefix share nodes; insert and look up words and prefixes in time proportional to their length; return autocomplete suggestions in alphabetical order; remove words and prune empty branches; and weigh the trie's memory cost against a Set of strings or a sorted array.
module: m19
order: 3
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m19-l02]
objectives:
  - Explain how a trie stores strings and why words with a common prefix share nodes.
  - Implement insert, exact lookup and prefix lookup in O(L) for a string of length L.
  - Implement autocomplete that returns words with a given prefix in a deterministic order, with a limit.
  - Remove a word and prune the nodes nothing else needs.
  - Compare a trie with a Set of strings and with a sorted array for membership, prefix queries and memory.
terms:
  - term: Trie
    definition: A tree for storing strings where each edge is labeled with a character and each node represents the prefix spelled by the path from the root. Also called a prefix tree.
  - term: Terminal node
    definition: A trie node marked as the end of a stored word. A word can end at a node that still has children, like "car" inside "card".
  - term: Prefix query
    definition: Asking which stored strings start with a given string, or whether any do.
  - term: Grapheme cluster
    definition: What a reader sees as one character, possibly made of several Unicode scalars. Swift's Character type represents one grapheme cluster.
mastery:
  - Write a trie node with a children dictionary and an end-of-word flag.
  - Insert words and answer contains and hasPrefix queries, and state their cost.
  - Return up to k autocomplete suggestions in alphabetical order with a DFS from the prefix node.
  - Remove a word without breaking longer or shorter words that share its nodes.
  - Choose between a trie, a Set and a sorted array for a given mix of queries, and justify the choice with costs and memory.
resources: [swift-dictionary, swift-set, swift-book-strings, swift-book-structures-classes, swift-array]
cards:
  - id: m19-l03-c1
    front: What does each node of a trie represent?
    back: "A prefix: the characters on the path from the root to that node. Children are keyed by the next character, and a flag marks whether the prefix is itself a stored word."
  - id: m19-l03-c2
    front: What does a trie do that a Set of strings can't do efficiently?
    back: "Prefix queries. hasPrefix and \"all words starting with p\" cost O(|p|) to find the node, plus the size of the results. A Set has to check every stored string."
  - id: m19-l03-c3
    front: Why does a trie need an isWord flag instead of just checking for a leaf?
    back: "Words can be prefixes of other words. \"car\" ends at a node that still has a child for \"card\", so being a leaf can't be the test."
  - id: m19-l03-c4
    front: What's the memory downside of a trie?
    back: "A node object (with its own dictionary) per distinct prefix. Unless many words share long prefixes, that's far more memory than storing each string once in a Set or an array."
  - id: m19-l03-c5
    front: Why must autocomplete sort a node's children before recursing?
    back: "Dictionary iteration order is unspecified and can change between runs, so suggestions would come out in a random order. Sorting the keys gives alphabetical results."
---

## The idea in one sentence

A trie stores a set of strings as a tree where every path from the root spells a prefix, so finding a word or **everything that starts with a prefix** takes time proportional to the prefix's length, not to the number of words stored.

## The shape of a trie

Store "car", "card", "care", "cart", "cat" and "dog":

```text
            (root)
           /      \
          c        d
          |        |
          a        o
         / \       |
        r*  t*     g*
      / | \
     d*  e* t*
```

- Each edge is one character. Each node stands for the prefix spelled on the way down: the node under c-a-r is "car".
- `*` marks a **terminal** node, the end of a stored word. "car" is a word and a prefix of "card", so its node is terminal and also has children. That's why a trie needs a flag; "is a leaf" isn't the same as "is a word".
- Five words starting with "ca" share the c and a nodes. That sharing is what makes prefix queries cheap, and it's also the only place the trie saves memory.

The name comes from re**trie**val. Many people pronounce it "try" to tell it apart from "tree".

## The node and insert

Each node needs a map from the next character to the child, and a flag. A `Dictionary` with `Character` keys handles any alphabet. The node is a class for the same reason as in the earlier lessons: it refers to nodes of its own type and you mutate it in place.

```swift
final class TrieNode {
    var children: [Character: TrieNode] = [:]
    var isWord = false
}

struct Trie {
    private let root = TrieNode()

    func insert(_ word: String) {
        var node = root
        for character in word {
            if let next = node.children[character] {
                node = next
            } else {
                let next = TrieNode()
                node.children[character] = next
                node = next
            }
        }
        node.isWord = true
    }

    private func node(for prefix: String) -> TrieNode? {
        var node = root
        for character in prefix {
            guard let next = node.children[character] else { return nil }
            node = next
        }
        return node
    }

    func contains(_ word: String) -> Bool {
        node(for: word)?.isWord ?? false
    }

    func hasPrefix(_ prefix: String) -> Bool {
        node(for: prefix) != nil
    }
}

let trie = Trie()
for word in ["car", "card", "care", "cart", "cat", "dog"] {
    trie.insert(word)
}
print(trie.contains("car"), trie.contains("ca"), trie.contains("cards"))
print(trie.hasPrefix("ca"), trie.hasPrefix("do"), trie.hasPrefix("x"), trie.hasPrefix(""))
```

```output
true false false
true true false true
```

1. `insert` walks down one character at a time, creating children that don't exist yet, and marks the final node. Inserting a word twice just sets the flag again.
2. `node(for:)` is the shared walk: it returns the node for a prefix, or `nil` as soon as a character has no child.
3. `contains` needs the node **and** the flag. "ca" has a node, but nobody inserted "ca", so it's `false`.
4. `hasPrefix` only needs the node. The empty prefix is the root, so every trie "has" it.
5. `Trie` is a struct whose only property is a reference to the root, and `insert` isn't `mutating`: it changes the nodes, not the struct. Copies of this struct share nodes, as with the linked list struct in Module 17. For a learning tool that's fine; a library type would add copy-on-write.

**Cost.** Each step is one dictionary lookup, O(1) on average, so insert, `contains` and `hasPrefix` are **O(L)** for a string of length L. The number of stored words doesn't appear at all.

> [!note] Characters, not bytes
> Iterating a `String` gives `Character`s, which are grapheme clusters: "é" is one Character whether it's stored as one Unicode scalar or as "e" plus a combining accent, and Swift compares them by canonical equivalence. So a trie keyed by `Character` treats both spellings as the same word. It doesn't fold case, though: "Car" and "car" are different paths. Normalize first, for example with `lowercased()`, if the feature should ignore case.

## Autocomplete

To list every word that starts with a prefix, find the prefix's node, then do a depth-first traversal of its subtree, building each word as you go down. This is backtracking from Module 18: append a character, recurse, remove it.

Dictionary order is unspecified, and Swift randomizes hashing per process, so iterating `children` directly would give a different order on different runs. Sort the keys to get alphabetical suggestions, and stop once you have enough:

```swift
final class TrieNode {
    var children: [Character: TrieNode] = [:]
    var isWord = false
}

func insert(_ word: String, into root: TrieNode) {
    var node = root
    for character in word {
        if node.children[character] == nil {
            node.children[character] = TrieNode()
        }
        node = node.children[character]!
    }
    node.isWord = true
}

func suggestions(for prefix: String, in root: TrieNode, limit: Int) -> [String] {
    var node = root
    for character in prefix {
        guard let next = node.children[character] else { return [] }
        node = next
    }
    var results: [String] = []
    var current = prefix

    func collect(_ node: TrieNode) {
        if results.count == limit { return }
        if node.isWord { results.append(current) }
        for character in node.children.keys.sorted() {
            current.append(character)
            collect(node.children[character]!)
            current.removeLast()
            if results.count == limit { return }
        }
    }

    collect(node)
    return results
}

let root = TrieNode()
for name in ["anna", "andrew", "andy", "angela", "ann", "bob", "anne"] {
    insert(name, into: root)
}
print(suggestions(for: "an", in: root, limit: 10))
print(suggestions(for: "an", in: root, limit: 3))
print(suggestions(for: "ann", in: root, limit: 10))
print(suggestions(for: "z", in: root, limit: 10))
```

```output
["andrew", "andy", "angela", "ann", "anna", "anne"]
["andrew", "andy", "angela"]
["ann", "anna", "anne"]
[]
```

1. The first loop is the same prefix walk as before. No node means no suggestions.
2. `collect` is a nested function that captures `results` and `current`, so the recursion doesn't have to pass them around.
3. A node's own word is recorded **before** its children. That's preorder, and with sorted children it produces alphabetical order, because a word comes before every longer word that extends it ("ann" before "anna").
4. `current.append` and `current.removeLast()` are the choose and un-choose steps of backtracking. The string always spells the path to the node being visited.
5. The two `limit` checks stop the search as soon as there are enough results, so asking for 3 suggestions under a prefix with 10,000 words doesn't walk all 10,000.

**Cost.** O(P) to find the prefix node, then the DFS visits the nodes it needs to produce the results, sorting each node's children as it goes. Without a limit that's the whole subtree; with a limit of k it's roughly the nodes on the paths to the first k words. Neither depends on the total number of words in the trie.

## Removing a word

Removing has to be careful: the word's nodes may be shared. Removing "car" must keep the nodes for "card"; removing "card" must keep "car". The rule: unmark the terminal node, then, on the way back up, delete any node that is neither a word nor on the path to one (no children). A recursive function that returns "this node can be pruned" does it in one pass:

```swift
final class TrieNode {
    var children: [Character: TrieNode] = [:]
    var isWord = false
}

func insert(_ word: String, into root: TrieNode) {
    var node = root
    for character in word {
        if node.children[character] == nil {
            node.children[character] = TrieNode()
        }
        node = node.children[character]!
    }
    node.isWord = true
}

func remove(_ word: Substring, from node: TrieNode) -> Bool {
    guard let first = word.first else {
        node.isWord = false
        return node.children.isEmpty
    }
    guard let child = node.children[first] else { return false }
    if remove(word.dropFirst(), from: child) {
        node.children[first] = nil
    }
    return !node.isWord && node.children.isEmpty
}

func countNodes(_ node: TrieNode) -> Int {
    1 + node.children.values.reduce(0) { $0 + countNodes($1) }
}

let root = TrieNode()
for word in ["car", "card", "cat"] {
    insert(word, into: root)
}
print(countNodes(root))
_ = remove("card", from: root)
print(countNodes(root), root.children["c"]?.children["a"]?.children["r"]?.isWord ?? false)
_ = remove("car", from: root)
print(countNodes(root))
_ = remove("dog", from: root)
print(countNodes(root))
```

```output
6
5 true
4
4
```

1. The function takes a `Substring` so `dropFirst()` doesn't copy the rest of the word at every level.
2. At the end of the word it clears the flag and reports whether the node has no children left.
3. Each parent removes the child if the child said it can go, then reports whether **it** can go: only if it's not a word and has no remaining children.
4. Removing "card" deletes the d node only; "car" stays a word. Removing "car" then deletes the r node, since it's no longer a word and has no children. The c and a nodes stay for "cat". Removing "dog", which isn't there, changes nothing.

The root is never deleted, because nothing holds a reference to it that could be cleared; the return value at the top is ignored. Cost: O(L).

## Trie, Set or sorted array?

A trie isn't the default container for strings. Compare it with the two structures you already know:

| Need | `Set<String>` | Sorted `[String]` | Trie |
| --- | --- | --- | --- |
| Is "word" stored? | O(L) average (hash the string) | O(L log n) with binary search | O(L) |
| Any word starting with p? | O(n · P), check every word | O(P log n), find where p would go | O(P) |
| All k words starting with p | O(n · P) | O(P log n + k·L) | O(P + size of the results' subtree) |
| Insert | O(L) average | O(n) shift | O(L) |
| Memory | each string once | each string once | a node object per distinct prefix |

The trie wins on prefix queries with frequent inserts. The cost is **memory**. Every node is a separate heap-allocated class instance with its own dictionary, and the dictionary allocates storage once it has elements. Count the nodes for some real words:

```swift
final class TrieNode {
    var children: [Character: TrieNode] = [:]
    var isWord = false
}

func insert(_ word: String, into root: TrieNode) {
    var node = root
    for character in word {
        if node.children[character] == nil {
            node.children[character] = TrieNode()
        }
        node = node.children[character]!
    }
    node.isWord = true
}

func countNodes(_ node: TrieNode) -> Int {
    1 + node.children.values.reduce(0) { $0 + countNodes($1) }
}

let groups = [
    ["car", "card", "care", "cart", "cat", "dog"],
    ["zebra", "apple", "mango", "kiwi", "plum"],
    ["internationalization", "internationalize", "international", "internet"],
]
for words in groups {
    let root = TrieNode()
    for word in words { insert(word, into: root) }
    let characters = words.reduce(0) { $0 + $1.count }
    print(characters, countNodes(root) - 1)
}
```

```output
21 10
23 23
57 23
```

Each line shows the total number of characters stored, and the number of trie nodes (not counting the root). With no shared prefixes, the trie has one node per character, each a full object with a dictionary, where a Set would store each short string compactly. Swift stores short strings, up to 15 UTF-8 bytes on 64-bit platforms, directly inside the `String` value without a heap allocation, so a `Set` of short words can be very compact. Only when many words share long prefixes, as in the third group, does the node count drop well below the character count.

In practice:

- Only exact membership? Use a **Set**.
- A word list that rarely changes, with prefix searches? A **sorted array** with a binary search for the first word ≥ the prefix, then read forward while words still have the prefix. It's compact and fast enough for tens of thousands of entries.
- Many inserts interleaved with prefix queries, or the problem is literally about prefixes (word games, routing tables, "replace each word with its shortest root")? Use a **trie**.

> [!tip] Smaller tries
> If the alphabet is fixed and small, say 26 lowercase letters, a node can hold a fixed array of 26 optional children instead of a dictionary. Lookups get faster and there's no hashing, but each node now reserves 26 slots whether it uses them or not. Compressed tries (radix trees) merge chains of single-child nodes into one edge labeled with a whole substring, which removes most of the memory overhead.

## Common mistakes

> [!error] Treating "has a node" as "is a word"
> After inserting "card", the path c-a-r exists, but "car" wasn't inserted. `contains` must check the terminal flag, not just reach the node.

> [!error] Treating "is a leaf" as "is a word"
> "car" can be a word and still have children. Use the flag, and in removal don't delete a node that still has children.

> [!error] Iterating children in dictionary order
> Suggestions come out in a different order between runs. Sort the keys (or store children in a sorted structure) whenever order matters.

> [!error] Recording a node's word after its children
> With postorder, "ann" would be reported after "anna" and "anne". For alphabetical results, record the word before visiting children.

> [!error] Removing a word by deleting its whole path
> Other words share those nodes. Unmark the terminal node and prune only nodes with no children that aren't words, from the bottom up.

## Exercises

````exercise
id: m19-l03-e1
type: comprehension
prompt: An app checks every word a user types against a list of 200,000 banned words, and only needs to know whether the exact word is banned. Which structure fits best?
choices:
  - text: A Set<String>, because exact membership is all that's needed and it stores each word compactly.
    correct: true
    why: Lookup is O(L) on average, and there's no per-character node overhead.
  - text: A trie, because lookups are O(L) instead of O(n).
    correct: false
    why: A Set lookup is also O(L) on average. The trie's advantage is prefix queries, which this feature doesn't need, and it uses far more memory.
  - text: A sorted array, because binary search is faster than hashing.
    correct: false
    why: Binary search costs O(log n) string comparisons, about 18 for 200,000 words. A hash lookup is one hash and usually one comparison.
  - text: An unsorted array, because it's simplest.
    correct: false
    why: Each lookup would scan 200,000 strings.
solution: |
  **A Set.** The query is exact membership, which a hash set answers in O(L) on average: hash the word, compare with the few strings in that bucket. A trie answers the same question in O(L) too, but pays with a node object for every distinct prefix of 200,000 words. Reach for a trie when the question involves **prefixes**, such as "does any banned word start with what the user has typed so far?"
````

````exercise
id: m19-l03-e2
type: prediction
prompt: Predict the exact output.
code: |
  final class Node {
      var children: [Character: Node] = [:]
      var isWord = false
  }

  let root = Node()
  var created = 0
  for word in ["tea", "ten", "te", "tea", "to"] {
      var node = root
      for character in word {
          if node.children[character] == nil {
              node.children[character] = Node()
              created += 1
          }
          node = node.children[character]!
      }
      node.isWord = true
  }
  let t = root.children["t"]!
  print(created, t.isWord, t.children.count)
  print(t.children["e"]!.isWord, t.children["e"]!.children.count)
output: |
  5 false 2
  true 2
hints:
  - "Count new nodes: tea creates t, e, a. Then ten creates only n."
  - "te and the second tea create nothing; they only set flags."
solution: |
  ```output
  5 false 2
  true 2
  ```

  `created` is 5 (t, e, a for "tea", n for "ten", o for "to"; "te" and the repeated "tea" create nothing). `t.isWord` is `false`, because "t" alone was never inserted, and t has 2 children, e and o. Then the node for "te" is a word (it was inserted), with 2 children, a and n.
````

````exercise
id: m19-l03-e3
type: fill-in
prompt: Complete the trie so the program prints `true false true`.
code: |
  final class Node {
      var children: [Character: Node] = [:]
      var isWord = false
  }

  func insert(_ word: String, into root: Node) {
      var node = root
      for character in word {
          if node.children[character] == nil {
              node.children[character] = [[1]]
          }
          node = node.children[character]!
      }
      node.[[2]] = true
  }

  func contains(_ word: String, in root: Node) -> Bool {
      var node = root
      for character in word {
          guard let next = node.children[[[3]]] else { return false }
          node = next
      }
      return node.[[4]]
  }

  let root = Node()
  insert("swift", into: root)
  insert("sw", into: root)
  print(contains("swift", in: root), contains("swi", in: root), contains("sw", in: root))
blanks:
  - id: "1"
    answers: ["Node()"]
  - id: "2"
    answers: ["isWord"]
  - id: "3"
    answers: ["character"]
  - id: "4"
    answers: ["isWord"]
solution: |
  ```swift
  final class Node {
      var children: [Character: Node] = [:]
      var isWord = false
  }

  func insert(_ word: String, into root: Node) {
      var node = root
      for character in word {
          if node.children[character] == nil {
              node.children[character] = Node()
          }
          node = node.children[character]!
      }
      node.isWord = true
  }

  func contains(_ word: String, in root: Node) -> Bool {
      var node = root
      for character in word {
          guard let next = node.children[character] else { return false }
          node = next
      }
      return node.isWord
  }

  let root = Node()
  insert("swift", into: root)
  insert("sw", into: root)
  print(contains("swift", in: root), contains("swi", in: root), contains("sw", in: root))
  ```

  ```output
  true false true
  ```

  Insert creates missing children and marks the last node. `contains` walks the same path and returns the flag, not just "the path exists": "swi" has a node (it's a prefix of "swift") but was never inserted, so it's `false`. The force unwrap after the `if` is safe because the child was just created if it was missing.
````

````exercise
id: m19-l03-e4
type: solve
prompt: |
  A text tool shortens words to their roots. Given a list of roots and a sentence, replace every word that starts with some root by the **shortest** root it starts with; leave other words alone. Write `replaceWithRoots(_ roots: [String], _ sentence: String) -> String`. With R total characters in the roots and S characters in the sentence, it should run in O(R + S).

  Expected output for the starter's calls:

  ```output
  the cat was rat by the bat
  a a b c
  hello world
  ```
starter: |
  func replaceWithRoots(_ roots: [String], _ sentence: String) -> String {
      return sentence
  }

  print(replaceWithRoots(["cat", "bat", "rat"], "the cattle was rattled by the battery"))
  print(replaceWithRoots(["a", "b", "c"], "aadsfasf absbs bbab cadsfafs"))
  print(replaceWithRoots(["xyz"], "hello world"))
hints:
  - Put the roots in a trie.
  - For each word, walk the trie character by character and stop at the first terminal node. That's the shortest root.
  - If you fall off the trie before reaching a terminal node, keep the word.
rubric:
  - Builds a trie of the roots once.
  - For each word, walks the trie and stops at the first terminal node.
  - Keeps words with no matching root unchanged.
  - "States the cost: O(R) to build and O(S) to process the sentence, compared with O(S · number of roots) for checking every root with hasPrefix."
solution: |
  ```swift
  final class Node {
      var children: [Character: Node] = [:]
      var isWord = false
  }

  func replaceWithRoots(_ roots: [String], _ sentence: String) -> String {
      let root = Node()
      for word in roots {
          var node = root
          for character in word {
              if node.children[character] == nil {
                  node.children[character] = Node()
              }
              node = node.children[character]!
          }
          node.isWord = true
      }

      func shortestRoot(of word: Substring) -> Substring {
          var node = root
          var length = 0
          for character in word {
              guard let next = node.children[character] else { return word }
              node = next
              length += 1
              if node.isWord { return word.prefix(length) }
          }
          return word
      }

      return sentence.split(separator: " ").map { String(shortestRoot(of: $0)) }.joined(separator: " ")
  }

  print(replaceWithRoots(["cat", "bat", "rat"], "the cattle was rattled by the battery"))
  print(replaceWithRoots(["a", "b", "c"], "aadsfasf absbs bbab cadsfafs"))
  print(replaceWithRoots(["xyz"], "hello world"))
  ```

  ```output
  the cat was rat by the bat
  a a b c
  hello world
  ```

  Building the trie touches each root character once: O(R). For each word, the walk stops at the first terminal node, which is the shortest root, or as soon as there's no child, so it reads at most the word's own characters: O(S) in total for the sentence. Checking every root with `hasPrefix` on every word would be O(S × number of roots) and would also need care to pick the shortest one. A word that is shorter than every root it partly matches ("ca" with root "cat") falls out of the loop and is kept as is.
````

````exercise
id: m19-l03-e5
type: find-errors
prompt: This autocomplete is supposed to return all words with the prefix, alphabetically. Which statements are true?
code: |
  func suggestions(for prefix: String, in root: Node) -> [String] {
      var node = root
      for character in prefix {
          guard let next = node.children[character] else { return [] }
          node = next
      }
      var results: [String] = []
      func collect(_ node: Node, _ current: String) {
          for (character, child) in node.children {
              collect(child, current + String(character))
          }
          if node.isWord { results.append(current) }
      }
      collect(node, prefix)
      return results
  }
choices:
  - text: The order of the results can change from run to run.
    correct: true
    why: It iterates the dictionary directly, and Dictionary's order is unspecified.
  - text: Even with sorted children, a word would come after the longer words that extend it.
    correct: true
    why: The word is appended after the children are visited (postorder), so "ann" lands after "anna" and "anne".
  - text: It never returns the prefix itself, even when the prefix is a stored word.
    correct: false
    why: collect starts at the prefix node, and that node's isWord is checked like any other.
  - text: It crashes when the prefix is not in the trie.
    correct: false
    why: The guard returns an empty array.
rubric:
  - I found the unsorted dictionary iteration.
  - I found the postorder placement of the word check.
  - I fixed both by checking isWord first and iterating node.children.keys.sorted().
solution: |
  Two order bugs. Iterating `node.children` directly gives Dictionary's unspecified order, and appending the word after the loop puts each word after its extensions. The fix: check `isWord` first, then iterate the sorted keys.

  ```swift
  final class Node {
      var children: [Character: Node] = [:]
      var isWord = false
  }

  func insert(_ word: String, into root: Node) {
      var node = root
      for character in word {
          if node.children[character] == nil {
              node.children[character] = Node()
          }
          node = node.children[character]!
      }
      node.isWord = true
  }

  func suggestions(for prefix: String, in root: Node) -> [String] {
      var node = root
      for character in prefix {
          guard let next = node.children[character] else { return [] }
          node = next
      }
      var results: [String] = []
      func collect(_ node: Node, _ current: String) {
          if node.isWord { results.append(current) }
          for character in node.children.keys.sorted() {
              collect(node.children[character]!, current + String(character))
          }
      }
      collect(node, prefix)
      return results
  }

  let root = Node()
  for name in ["anne", "ann", "anna", "andy"] {
      insert(name, into: root)
  }
  print(suggestions(for: "an", in: root))
  ```

  ```output
  ["andy", "ann", "anna", "anne"]
  ```

  `current + String(character)` builds a new string at each level, which costs O(L) per node. That's acceptable for short words; the lesson's version appends and removes on one shared string instead.
````

````exercise
id: m19-l03-e6
type: design
prompt: |
  A contacts app has 50,000 contacts and a search field that shows matching names after each keystroke, matching from the start of the first name or the last name, ignoring case. Contacts change a few times a day. Choose a structure for the search and justify it: what you store, how a query runs, what each keystroke costs, how much memory it uses, and how you update it when a contact changes.
rubric:
  - Normalizes names (lowercasing, and possibly removing accents) before indexing and before querying.
  - Indexes both first and last names, mapping each back to the contact.
  - Compares a trie with a sorted array plus binary search, with the cost of a query in each.
  - Considers memory, and that updates are rare.
  - Limits the number of results shown and says why.
solution: |
  One reasonable answer. Normalize each first and last name (lowercased, accents removed if the product wants "jose" to match "José") and build a list of `(key, contactID)` pairs, two per contact, 100,000 in total. Sort it by key.

  A keystroke gives a prefix p. Binary search (Module 16) for the first key ≥ p, O(|p| log n), about 17 string comparisons for 100,000 keys, then read forward while keys start with p, stopping after, say, 50 results because the screen can't show more. Deduplicate contact IDs, since a contact whose first and last names both match appears twice. That's fast enough for every keystroke, and the array stores each name once.

  A trie also works: each node can store the IDs of contacts below it, or you DFS to collect them, and each keystroke only walks one more character from the previous node. But 100,000 names make hundreds of thousands of nodes, each a separate object with a dictionary, which is much more memory than the array for a query the array already answers quickly. Because contacts change rarely, re-sorting the array (O(n log n)) or inserting at the binary-searched position (O(n)) on each change is cheap. I'd pick the sorted array and switch to a trie only if profiling showed the search was a bottleneck or the matching rules became prefix-heavy, like matching every word in a company name.
````

## Summary

- A **trie** stores strings as paths from the root, one character per edge. Words with a common prefix share nodes, and a **terminal flag** marks where stored words end.
- Insert, `contains` and `hasPrefix` are **O(L)** for a string of length L, independent of how many words are stored.
- **Autocomplete** walks to the prefix node and runs a preorder DFS with backtracking. Sort the children for a deterministic, alphabetical order, and stop at a limit.
- **Remove** unmarks the terminal node and prunes, bottom up, nodes that have no children and aren't words.
- Tries cost a node object per distinct prefix. For exact membership use a **Set**; for a mostly static list with prefix searches a **sorted array** with binary search is compact and fast; use a trie when prefix queries and inserts are both frequent.

---
id: m17-l03
title: Linked lists
description: You build a singly linked list from class nodes, insert and delete in O(1) once you hold the right node, use a dummy head to stop special-casing the first node, reverse a list in place, see why nodes have reference semantics even inside a struct, and learn when Swift code actually uses a linked list and when an Array wins.
module: m17
order: 3
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m17-l02]
objectives:
  - Explain why a linked list node has to be a class (or an indirect enum) and not a struct.
  - Build, traverse, insert into and delete from a singly linked list, and give the cost of each operation.
  - Use a dummy head node to handle changes at the front of the list with the same code as everywhere else.
  - Reverse a singly linked list in place with three pointers.
  - Predict what happens when two variables share nodes, and compare that with Array's value semantics.
  - Decide when a linked list beats an Array in Swift, and when it doesn't.
terms:
  - term: Linked list
    definition: A sequence stored as separate nodes, where each node holds a value and a reference to the next node. The list is reached through its first node, the head.
  - term: Node
    definition: One element of a linked list, holding a value and a link (next) to the following node, or nil at the end.
  - term: Head and tail
    definition: The first node of the list, and the last one (whose next is nil).
  - term: Dummy head
    definition: An extra node placed before the real head, so that every real node has a predecessor and inserting or deleting at the front needs no special case. Also called a sentinel.
  - term: Identity (===)
    definition: Whether two references point to the same instance. Two nodes can hold equal values and still be different instances.
mastery:
  - Write a ListNode class and convert between an array and a list.
  - Insert after a node and delete after a node in O(1), and explain why reaching a position is O(n).
  - Remove every node matching a condition with a dummy head, including at the front.
  - Reverse a list with prev, current and next, and state the invariant.
  - Explain why copying a struct that holds the head doesn't copy the nodes.
  - Argue for Array over a linked list for typical app data, and name cases where nodes make sense.
resources: [swift-book-structures-classes, swift-book-arc, swift-book-generics, swift-book-enumerations, swift-array]
cards:
  - id: m17-l03-c1
    front: Why can't a linked list node be a struct with a property of its own type?
    back: "A struct stores its properties inline, so a struct containing itself would have infinite size. Swift 6.3 reports: value type 'Node' cannot have a stored property that recursively contains it. A class stores a reference, which has a fixed size."
  - id: m17-l03-c2
    front: What does a linked list do in O(1) that an Array can't, and what does it pay for it?
    back: "Inserting or removing next to a node you already hold, without shifting anything. It pays with O(n) access by position (you walk from the head), a separate heap allocation per node, and poor memory locality."
  - id: m17-l03-c3
    front: What is a dummy head for?
    back: It gives the real first node a predecessor, so deleting or inserting at the front uses the same code as anywhere else. At the end you return dummy.next.
  - id: m17-l03-c4
    front: What three references does an iterative reverse keep, and what's the invariant?
    back: "prev, current and next. Invariant: prev is the head of the already-reversed part, and current is the head of the part not yet reversed."
  - id: m17-l03-c5
    front: "If a struct holds the head node and you copy the struct, do you get a copy of the list?"
    back: "No. Both copies hold a reference to the same nodes. Changing a node's value through one is visible through the other. Value semantics would need copy-on-write (for example with isKnownUniquelyReferenced)."
---

## The idea in one sentence

A linked list stores each element in its own node that points to the next one, so you can splice nodes in and out without moving anything, but you can only reach a position by walking to it.

## Why a node is a class

An Array keeps its elements side by side in one block of memory. That's why `values[5000]` is O(1): the address is computed, not searched. It's also why inserting at the front is O(n): everything has to move over.

A **linked list** gives up the single block. Each element lives in a **node** that holds the value and a reference to the next node. The last node's `next` is `nil`. The list is the chain you can reach from the first node, the **head**.

The natural first try is a struct, and Swift rejects it:

```swift no-compile value type 'Node' cannot have a stored property that recursively contains it
struct Node {
    var value: Int
    var next: Node?
}
```

A struct stores its properties **inline**: a `Node` would contain an optional `Node`, which contains another, without end, so it has no finite size. A class property stores a **reference**, which is always pointer-sized, whatever it points to. So nodes are classes:

```swift
final class ListNode<Value> {
    var value: Value
    var next: ListNode?

    init(_ value: Value, next: ListNode? = nil) {
        self.value = value
        self.next = next
    }
}

func makeList<Value>(_ values: [Value]) -> ListNode<Value>? {
    var head: ListNode<Value>? = nil
    for value in values.reversed() {
        head = ListNode(value, next: head)
    }
    return head
}

func describe<Value>(_ head: ListNode<Value>?) -> String {
    var parts: [String] = []
    var current = head
    while let node = current {
        parts.append("\(node.value)")
        current = node.next
    }
    return parts.isEmpty ? "(empty)" : parts.joined(separator: " -> ")
}

let playlist = makeList(["Intro", "Verse", "Chorus", "Outro"])
print(describe(playlist))
print(describe(makeList([Int]())))
```

```output
Intro -> Verse -> Chorus -> Outro
(empty)
```

1. `final class ListNode<Value>` is generic, like `Stack` in lesson 1. Inside the class, `ListNode?` means `ListNode<Value>?`. `final` says no subclass will override anything, which you'd want for a small building block like this.
2. `makeList` builds from the back: each new node points to the list built so far, then becomes the new head. Prepending is O(1), so building is O(n).
3. `describe` is the standard traversal. `current` starts at the head; `while let node = current` stops at `nil`; `current = node.next` steps forward. Every operation that needs a position starts with a loop like this.

A Swift alternative is an `indirect enum` (Module 9 showed `indirect` for recursive enums), which stores the recursive case behind a reference. It gives you an immutable list. The class version is what interview problems and most textbooks use, so this module uses it.

## What it costs

| Operation | Linked list | Array |
| --- | --- | --- |
| Read or write position i | O(i): walk from the head | O(1) |
| Insert or remove at the front | O(1) | O(n) |
| Insert or remove right after a node you hold | O(1) | O(n) (shift the rest) |
| Append at the end | O(n), or O(1) if you keep a tail reference | O(1) amortized |
| Search for a value | O(n) | O(n) |
| Memory per element | value + `next` + an object header, one heap allocation each | value only, in one allocation |

The linked list's strength is the middle rows, with an important condition: **you already hold the node**. If you have to find the position first, that walk is O(n), and the O(1) splice doesn't save you anything over an Array.

## Inserting and deleting

Both operations change one or two `next` references:

```swift
final class ListNode<Value> {
    var value: Value
    var next: ListNode?
    init(_ value: Value, next: ListNode? = nil) {
        self.value = value
        self.next = next
    }
}

func describe<Value>(_ head: ListNode<Value>?) -> String {
    var parts: [String] = []
    var current = head
    while let node = current {
        parts.append("\(node.value)")
        current = node.next
    }
    return parts.isEmpty ? "(empty)" : parts.joined(separator: " -> ")
}

func insert<Value>(_ value: Value, after node: ListNode<Value>) {
    node.next = ListNode(value, next: node.next)
}

func removeNode<Value>(after node: ListNode<Value>) {
    node.next = node.next?.next
}

let intro = ListNode("Intro")
let chorus = ListNode("Chorus")
intro.next = chorus
print(describe(intro))

insert("Verse", after: intro)
print(describe(intro))

insert("Bridge", after: chorus)
removeNode(after: intro)
print(describe(intro))

var head: ListNode<String>? = intro
head = ListNode("Countdown", next: head)
print(describe(head))
head = head?.next
print(describe(head))
```

```output
Intro -> Chorus
Intro -> Verse -> Chorus
Intro -> Chorus -> Bridge
Countdown -> Intro -> Chorus -> Bridge
Intro -> Chorus -> Bridge
```

1. `insert(_:after:)` creates a node that points to whatever came after `node`, then makes `node` point to it. **The order matters**: if you set `node.next` first, you lose the rest of the list.
2. `removeNode(after:)` makes `node` skip its successor. The skipped node loses its only strong reference, so ARC (Module 13) frees it. The `?.` makes it a no-op when `node` is the tail.
3. You can't remove a node in a singly linked list knowing only that node: you need its **predecessor**, because the predecessor's `next` is what changes. That's why the function is "remove **after**".
4. Prepending creates a node pointing to the old head. Removing the head is `head = head?.next`.

The front of the list is the awkward case: the head has no predecessor, so changes there update the `head` variable instead of some node's `next`. Code that handles both ends up with two branches. A dummy head removes the difference.

## The dummy head

Say you want to remove every node matching a condition: all the skipped tracks from a play queue. Matching nodes can be at the front, several in a row, or at the end. Put an extra node **before** the head, and every real node has a predecessor:

```swift
final class ListNode<Value> {
    var value: Value
    var next: ListNode?
    init(_ value: Value, next: ListNode? = nil) {
        self.value = value
        self.next = next
    }
}

func makeList<Value>(_ values: [Value]) -> ListNode<Value>? {
    var head: ListNode<Value>? = nil
    for value in values.reversed() {
        head = ListNode(value, next: head)
    }
    return head
}

func describe<Value>(_ head: ListNode<Value>?) -> String {
    var parts: [String] = []
    var current = head
    while let node = current {
        parts.append("\(node.value)")
        current = node.next
    }
    return parts.isEmpty ? "(empty)" : parts.joined(separator: " -> ")
}

func removeAll(from head: ListNode<Int>?, where shouldRemove: (Int) -> Bool) -> ListNode<Int>? {
    let dummy = ListNode(0, next: head)
    var previous = dummy
    while let current = previous.next {
        if shouldRemove(current.value) {
            previous.next = current.next
        } else {
            previous = current
        }
    }
    return dummy.next
}

let skipped: Set = [3, 7]
print(describe(removeAll(from: makeList([3, 3, 5, 7, 8, 7]), where: { skipped.contains($0) })))
print(describe(removeAll(from: makeList([3, 7]), where: { skipped.contains($0) })))
print(describe(removeAll(from: makeList([1, 2]), where: { skipped.contains($0) })))
```

```output
5 -> 8
(empty)
1 -> 2
```

1. `dummy` points to the real head. Its value is never read; 0 is a placeholder.
2. `previous` is always the last node **kept** so far. The loop looks at the node after it.
3. To remove `current`, link `previous` past it. Don't move `previous`: the new `previous.next` hasn't been checked yet, which handles runs like `3, 3`.
4. To keep `current`, move `previous` to it.
5. Return `dummy.next`, which is the new head, whether or not the original head was removed. When every node goes, it's `nil`.

One pass, O(1) work per node: **O(n) time, O(1) extra space.** The dummy turns "is this the head?" into a question you never ask. Use one whenever the head itself might change.

## Reversing a list

A play queue's "reverse order" button, or a standard interview problem. You can't walk backward in a singly linked list, so instead you flip each `next` pointer as you walk forward:

```swift
final class ListNode<Value> {
    var value: Value
    var next: ListNode?
    init(_ value: Value, next: ListNode? = nil) {
        self.value = value
        self.next = next
    }
}

func makeList<Value>(_ values: [Value]) -> ListNode<Value>? {
    var head: ListNode<Value>? = nil
    for value in values.reversed() {
        head = ListNode(value, next: head)
    }
    return head
}

func describe<Value>(_ head: ListNode<Value>?) -> String {
    var parts: [String] = []
    var current = head
    while let node = current {
        parts.append("\(node.value)")
        current = node.next
    }
    return parts.isEmpty ? "(empty)" : parts.joined(separator: " -> ")
}

func reversed<Value>(_ head: ListNode<Value>?) -> ListNode<Value>? {
    var previous: ListNode<Value>? = nil
    var current = head
    while let node = current {
        let next = node.next
        node.next = previous
        previous = node
        current = next
    }
    return previous
}

print(describe(reversed(makeList([1, 2, 3, 4]))))
print(describe(reversed(makeList(["solo"]))))
print(describe(reversed(makeList([Int]()))))
```

```output
4 -> 3 -> 2 -> 1
solo
(empty)
```

Each pass does four things, in this order:

1. Save `node.next`, because the next line overwrites it and it's the only way to reach the rest of the list.
2. Point `node` backward, at `previous`.
3. Move `previous` forward to `node`.
4. Move `current` forward to the saved `next`.

The invariant: **`previous` is the head of the part already reversed, and `current` is the head of the part not yet touched.** At the start, the reversed part is empty (`nil`) and the untouched part is the whole list. At the end, `current` is `nil`, so `previous` is the head of the whole reversed list.

Trace `1 -> 2 -> 3`:

| After pass | Reversed part (from `previous`) | Untouched part (from `current`) |
| --- | --- | --- |
| start | (empty) | 1 -> 2 -> 3 |
| 1 | 1 | 2 -> 3 |
| 2 | 2 -> 1 | 3 |
| 3 | 3 -> 2 -> 1 | (empty) |

**O(n) time, O(1) extra space**: the same nodes, relinked. A recursive version is shorter to write but uses O(n) space on the call stack (Module 15), which can overflow on a long list.

## Reference semantics, even inside a struct

Nodes are class instances, so every variable holding a node shares it. Compare with an Array:

```swift
final class ListNode<Value> {
    var value: Value
    var next: ListNode?
    init(_ value: Value, next: ListNode? = nil) {
        self.value = value
        self.next = next
    }
}

func describe<Value>(_ head: ListNode<Value>?) -> String {
    var parts: [String] = []
    var current = head
    while let node = current {
        parts.append("\(node.value)")
        current = node.next
    }
    return parts.isEmpty ? "(empty)" : parts.joined(separator: " -> ")
}

struct LinkedList {
    var head: ListNode<Int>?

    mutating func prepend(_ value: Int) {
        head = ListNode(value, next: head)
    }
}

var original = LinkedList(head: ListNode(1, next: ListNode(2)))
var copy = original
copy.head?.value = 100
copy.prepend(0)
print("original:", describe(original.head))
print("copy:    ", describe(copy.head))

let array = [1, 2]
var arrayCopy = array
arrayCopy[0] = 100
print(array, arrayCopy)
```

```output
original: 100 -> 2
copy:     0 -> 100 -> 2
[1, 2] [100, 2]
```

`===` confirms that the two heads started out as the same instance:

```swift
final class ListNode<Value> {
    var value: Value
    var next: ListNode?
    init(_ value: Value, next: ListNode? = nil) {
        self.value = value
        self.next = next
    }
}

struct LinkedList {
    var head: ListNode<Int>?
}

var original = LinkedList(head: ListNode(1, next: ListNode(2)))
var copy = original
copy.head?.value = 100
print(original.head?.value ?? 0, copy.head?.value ?? 0)
print(original.head === copy.head)
```

```output
100 100
true
```

1. `LinkedList` is a struct, so `var copy = original` copies the struct. But the struct's only property is a **reference**, so the copy points to the same nodes.
2. `copy.head?.value = 100` changes a shared node. The original sees it.
3. `copy.prepend(0)` changes the copy's `head` property only. The original still starts at the old head. So the two "lists" now share their tail but have different heads: some changes leak across, others don't.
4. `===` tests **identity**: whether two references point to the same instance (Module 10). Two different nodes with equal values aren't `===`.
5. Array behaves as a value: the copy is independent (copy-on-write makes that cheap until you write).

Being a struct doesn't make a type a value. To give `LinkedList` real value semantics, every mutating method would have to copy the nodes when they're shared. The standard library offers `isKnownUniquelyReferenced(_:)` to check that, which is how copy-on-write types are built. For interview code and internal helpers, people usually skip it and document that nodes are shared.

## When Swift code uses a linked list

Less often than textbooks suggest. Array wins most of the time because:

- **Access by position** is everywhere in app code: `IndexPath` in a table or collection view, `ForEach` over indices, binary search. A list makes each of those O(n).
- **Memory**: every node is its own heap allocation, with an object header and a reference count, and ARC has to retain and release references as you walk them. An Array of n integers is one allocation.
- **Locality**: an Array's elements sit next to each other, so the processor reads them in big chunks. Nodes are scattered across the heap. So shifting a few thousand array elements can be faster than walking a few thousand nodes, even though the Big O says otherwise. Measure before you assume.

Where nodes do make sense:

- **O(1) splicing at a node you already hold**, with no position lookups. The classic example is an **LRU cache**: a dictionary maps each key to its node in a doubly linked list, so you can move a node to the front in O(1). Lesson 6 designs one.
- **Chains that are naturally linked**: UIKit's responder chain is a linked structure, where each `UIResponder` has a `next` property pointing to the next responder.
- **Interviews**, where linked lists test whether you can manipulate references without losing parts of the structure. The next lesson is the most common family of those problems.

## Common mistakes

> [!error] error: value type 'Node' cannot have a stored property that recursively contains it
> Swift 6.3 rejects a struct that contains itself, even through an optional. Use a class for the node, or an `indirect enum`.

> [!error] Overwriting next before saving it
> In reverse or insert, assigning `node.next` first loses the only reference to the rest of the list. ARC frees it, and your list silently ends early. Save `let next = node.next` before changing anything.

> [!error] Special-casing the head, and missing a case
> Code that handles "remove at the head" separately often misses two matching nodes in a row at the front. A dummy head gives every node a predecessor and makes the head ordinary.

> [!error] Advancing previous after a removal
> When you unlink `current`, the node now after `previous` hasn't been checked. Moving `previous` forward skips it, so the second of two adjacent matches survives.

> [!error] Assuming a struct wrapper copies the list
> A struct holding the head copies the reference, not the nodes. Mutating a node through one copy changes the other.

## Exercises

````exercise
id: m17-l03-e1
type: comprehension
prompt: An app keeps 10,000 chat messages and shows them in a table view, which asks for the message at an index path whenever a cell appears. New messages are appended at the end. Should the messages be stored in a linked list or an Array?
choices:
  - text: An Array, because the table view reads by position, which is O(1) for an Array and O(i) for a list.
    correct: true
    why: Access by index is the dominant operation here, and appending at the end is O(1) amortized for an Array.
  - text: A linked list, because inserting is O(1).
    correct: false
    why: Insertion only happens at the end, which an Array already does in O(1) amortized. The O(1) splice of a list only helps in the middle, at a node you hold.
  - text: A linked list, because it uses less memory than an Array.
    correct: false
    why: It uses more. Each node is a separate heap object with a header, a reference count and a next reference.
  - text: Either one; both have O(1) access by index.
    correct: false
    why: A linked list has to walk from the head to reach position i.
solution: |
  **An Array.** The table view asks for `messages[indexPath.row]` every time a cell scrolls into view. That's O(1) for an Array and O(i) for a linked list, which would make scrolling to the bottom of 10,000 messages walk about 10,000 nodes per cell. Appending at the end is O(1) amortized for an Array, so the list's one advantage, splicing in the middle at a node you already hold, doesn't come up.
````

````exercise
id: m17-l03-e2
type: prediction
prompt: Predict the exact output.
code: |
  final class Node {
      var value: Int
      var next: Node?
      init(_ value: Int, next: Node? = nil) {
          self.value = value
          self.next = next
      }
  }

  struct Playlist {
      var head: Node?
      mutating func prepend(_ value: Int) {
          head = Node(value, next: head)
      }
  }

  var morning = Playlist(head: Node(1, next: Node(2)))
  var evening = morning
  evening.head?.next?.value = 20
  evening.prepend(0)
  morning.head?.value = 10
  print(morning.head?.value ?? -1, morning.head?.next?.value ?? -1)
  print(evening.head?.value ?? -1, evening.head?.next?.value ?? -1, evening.head?.next?.next?.value ?? -1)
output: |
  10 20
  0 10 20
hints:
  - Copying the struct copies the head reference, not the nodes.
  - prepend changes only evening's head property. The old nodes are still shared.
solution: |
  ```output
  10 20
  0 10 20
  ```

  `var evening = morning` copies the struct, so both `head` properties point to the same node 1, which points to node 2. Setting `evening.head?.next?.value = 20` changes the shared second node. `evening.prepend(0)` gives `evening` a new head (0) pointing to the shared node 1, while `morning.head` still points to node 1. Then `morning.head?.value = 10` changes the shared first node, so `evening` sees it too. The two playlists are `10 -> 20` and `0 -> 10 -> 20`. Being a struct didn't make `Playlist` a value: its contents are shared references.
````

````exercise
id: m17-l03-e3
type: fill-in
prompt: Complete the in-place reverse so the program prints `c b a`.
code: |
  final class Node {
      let value: String
      var next: Node?
      init(_ value: String, next: Node? = nil) {
          self.value = value
          self.next = next
      }
  }

  func reversed(_ head: Node?) -> Node? {
      var previous: Node? = nil
      var current = head
      while let node = current {
          let next = node.[[1]]
          node.next = [[2]]
          previous = [[3]]
          current = [[4]]
      }
      return previous
  }

  var node = reversed(Node("a", next: Node("b", next: Node("c"))))
  var names: [String] = []
  while let current = node {
      names.append(current.value)
      node = current.next
  }
  print(names.joined(separator: " "))
blanks:
  - id: "1"
    answers: ["next"]
  - id: "2"
    answers: ["previous"]
  - id: "3"
    answers: ["node", "current"]
  - id: "4"
    answers: ["next"]
solution: |
  ```swift
  final class Node {
      let value: String
      var next: Node?
      init(_ value: String, next: Node? = nil) {
          self.value = value
          self.next = next
      }
  }

  func reversed(_ head: Node?) -> Node? {
      var previous: Node? = nil
      var current = head
      while let node = current {
          let next = node.next
          node.next = previous
          previous = node
          current = next
      }
      return previous
  }

  var node = reversed(Node("a", next: Node("b", next: Node("c"))))
  var names: [String] = []
  while let current = node {
      names.append(current.value)
      node = current.next
  }
  print(names.joined(separator: " "))
  ```

  ```output
  c b a
  ```

  Save the rest of the list, point the node backward, then move both pointers forward. `previous = current` is also accepted for blank 3, since `current` and `node` are the same reference at that moment. The invariant: `previous` heads the reversed part and `current` heads the untouched part. O(n) time, O(1) extra space.
````

````exercise
id: m17-l03-e4
type: find-errors
prompt: This function should remove every node whose value is negative and return the new head. Which statements about it are true?
code: |
  final class Node {
      var value: Int
      var next: Node?
      init(_ value: Int, next: Node? = nil) {
          self.value = value
          self.next = next
      }
  }

  func removeNegatives(_ head: Node?) -> Node? {
      if let first = head, first.value < 0 {
          return removeNegatives(first.next)
      }
      var current = head
      while let node = current, let following = node.next {
          if following.value < 0 {
              node.next = following.next
          }
          current = node.next
      }
      return head
  }
choices:
  - text: "For 1 -> -2 -> -3 -> 4, it returns 1 -> -3 -> 4: the second of two adjacent negatives survives."
    correct: true
    why: After unlinking -2, it moves current to -3 without checking whether -3 itself should go.
  - text: "Negatives at the front, like -1 -> -2 -> 5, are handled correctly."
    correct: true
    why: The recursive call strips leading negatives one at a time before the loop starts.
  - text: The function leaks the removed nodes, because they still point into the list.
    correct: false
    why: An unlinked node has no strong references left (nothing points to it), so ARC frees it. Its own next reference doesn't keep it alive.
  - text: "It crashes on an empty list."
    correct: false
    why: With head nil, the if let fails, the while let fails, and it returns nil.
rubric:
  - I found that adjacent negatives aren't all removed, and explained why.
  - I noted that the separate head case works but adds a second code path, recursive, using stack space for long runs of leading negatives.
  - I rewrote it with a dummy head that only advances when it keeps a node.
  - I gave O(n) time and O(1) extra space for the fix.
solution: |
  The loop always advances after looking at `following`, even when it just removed it, so the node that slid into its place is never checked. The head case works but is a separate, recursive code path. A dummy head fixes both:

  ```swift
  final class Node {
      var value: Int
      var next: Node?
      init(_ value: Int, next: Node? = nil) {
          self.value = value
          self.next = next
      }
  }

  func removeNegatives(_ head: Node?) -> Node? {
      let dummy = Node(0, next: head)
      var previous = dummy
      while let current = previous.next {
          if current.value < 0 {
              previous.next = current.next
          } else {
              previous = current
          }
      }
      return dummy.next
  }

  func values(_ head: Node?) -> [Int] {
      var result: [Int] = []
      var current = head
      while let node = current {
          result.append(node.value)
          current = node.next
      }
      return result
  }

  print(values(removeNegatives(Node(1, next: Node(-2, next: Node(-3, next: Node(4)))))))
  print(values(removeNegatives(Node(-1, next: Node(-2, next: Node(5))))))
  print(values(removeNegatives(nil)))
  ```

  ```output
  [1, 4]
  [5]
  []
  ```

  `previous` only moves when it keeps a node, so after a removal the new successor gets checked. O(n) time, O(1) extra space, and no recursion.
````

````exercise
id: m17-l03-e5
type: solve
prompt: |
  Two devices each keep a sorted linked list of reminder times. Write `func merged(_ a: Node?, _ b: Node?) -> Node?` that merges them into one sorted list by **relinking the existing nodes**: no new nodes except a dummy. Use the merge from Module 16 as your guide.

  Expected output for the starter's calls:

  ```output
  [1, 2, 3, 5, 8, 9]
  [4, 6]
  []
  ```
starter: |
  final class Node {
      var value: Int
      var next: Node?
      init(_ value: Int, next: Node? = nil) {
          self.value = value
          self.next = next
      }
  }

  func merged(_ a: Node?, _ b: Node?) -> Node? {
      // A dummy head and a tail pointer
      return nil
  }

  func makeList(_ values: [Int]) -> Node? {
      var head: Node? = nil
      for value in values.reversed() {
          head = Node(value, next: head)
      }
      return head
  }

  func values(_ head: Node?) -> [Int] {
      var result: [Int] = []
      var current = head
      while let node = current {
          result.append(node.value)
          current = node.next
      }
      return result
  }

  print(values(merged(makeList([1, 3, 8]), makeList([2, 5, 9]))))
  print(values(merged(nil, makeList([4, 6]))))
  print(values(merged(nil, nil)))
hints:
  - Keep a tail pointer that starts at the dummy. Each step, attach the smaller front node to tail.next and advance both that list and tail.
  - When one list runs out, attach the rest of the other in one step. No loop needed.
rubric:
  - Uses a dummy head and a tail pointer, and creates no other nodes.
  - Takes the smaller front node each step, using <= to keep equal values from a first.
  - Attaches the remaining list in O(1) when one runs out.
  - Output matches, and the answer states O(n + m) time and O(1) extra space.
solution: |
  ```swift
  final class Node {
      var value: Int
      var next: Node?
      init(_ value: Int, next: Node? = nil) {
          self.value = value
          self.next = next
      }
  }

  func merged(_ a: Node?, _ b: Node?) -> Node? {
      let dummy = Node(0)
      var tail = dummy
      var first = a
      var second = b
      while let x = first, let y = second {
          if x.value <= y.value {
              tail.next = x
              first = x.next
          } else {
              tail.next = y
              second = y.next
          }
          tail = tail.next!
      }
      tail.next = first ?? second
      return dummy.next
  }

  func makeList(_ values: [Int]) -> Node? {
      var head: Node? = nil
      for value in values.reversed() {
          head = Node(value, next: head)
      }
      return head
  }

  func values(_ head: Node?) -> [Int] {
      var result: [Int] = []
      var current = head
      while let node = current {
          result.append(node.value)
          current = node.next
      }
      return result
  }

  print(values(merged(makeList([1, 3, 8]), makeList([2, 5, 9]))))
  print(values(merged(nil, makeList([4, 6]))))
  print(values(merged(nil, nil)))
  ```

  ```output
  [1, 2, 3, 5, 8, 9]
  [4, 6]
  []
  ```

  The dummy means the first attached node needs no special case, and `dummy.next` is the answer even when both lists are empty. `tail` is always the last node of the merged part. The force unwrap `tail.next!` is safe because the line before just set it. After the loop, at most one list has nodes left, and they're already sorted and linked to each other, so `tail.next = first ?? second` attaches all of them at once. That's the difference from the Array merge in Module 16, which had to append the leftovers one by one. Each node is visited once: **O(n + m) time, O(1) extra space**, since the nodes are reused.
````

````exercise
id: m17-l03-e6
type: design
prompt: |
  In an interview, you're asked: "Insertion into a linked list is O(1) and into an Array is O(n). So why do Swift developers almost always use Array?" Give the answer you'd say out loud, in a few sentences, with at least three concrete reasons and one case where you would pick a linked list.
rubric:
  - Points out that O(1) insertion needs a reference to the node already, and finding a position is O(n).
  - Mentions O(1) random access for Array and that app code (index paths, binary search) relies on it.
  - Mentions memory and locality (one allocation versus one heap object per node, plus ARC traffic).
  - Names a fitting use, such as an LRU cache with a dictionary from key to node.
solution: |
  "The O(1) is only for splicing at a node you already hold. If I have to find the position first, that's an O(n) walk, so for 'insert at index i' both structures are O(n). Meanwhile Array gives me O(1) access by index, which app code uses constantly: table views ask for row i, and binary search needs random access. Array also stores everything in one contiguous allocation, which is compact and fast to scan, whereas a list allocates a separate heap object per node, each with a header and a reference count that ARC updates as I walk it, scattered in memory. So in practice, even shifting a few thousand array elements often beats walking a list. I'd use a linked list when I keep direct references to nodes and need to move them around in O(1), like an LRU cache, where a dictionary maps each key to its node in a doubly linked list."
````

## Summary

- A linked list stores each element in a **node** with a `next` reference. Nodes are **classes**, because a struct can't contain itself.
- Access by position and search are O(n). Insert or remove **after a node you hold** is O(1). Inserting at the front is O(1).
- To remove a node you need its **predecessor**. A **dummy head** gives every node one, so the head needs no special case; return `dummy.next`.
- Reverse in place with `previous`, `current` and a saved `next`. Invariant: `previous` heads the reversed part. O(n) time, O(1) space.
- Nodes have **reference semantics**. A struct holding the head doesn't copy the nodes, so changes to nodes are shared.
- Prefer Array in app code: O(1) indexing, one allocation, good locality. Use nodes when you hold references and splice in O(1), as in an LRU cache.

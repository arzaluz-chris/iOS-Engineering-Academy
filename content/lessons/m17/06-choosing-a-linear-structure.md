---
id: m17-l06
title: Choosing a linear structure
description: You compare Array, stack, queue, ring-buffer deque and linked lists operation by operation, look at what node-based structures cost in memory and ARC (headers, reference counts, weak back links, and freeing a very long chain), build a doubly linked list with O(1) removal, and practice explaining a choice the way an interviewer wants to hear it.
module: m17
order: 6
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m17-l05]
objectives:
  - Pick a linear structure from the operations a feature needs and how often it needs them.
  - Compare the memory cost of an Array with that of node-based structures.
  - Use weak back links in a doubly linked list to avoid reference cycles.
  - Remove a node from a doubly linked list in O(1), updating head and tail.
  - Explain what happens when a very long linked list is freed, and write an iterative teardown.
  - Explain a data structure choice in an interview in terms of operations, costs and trade-offs.
terms:
  - term: Doubly linked list
    definition: A linked list where each node also references the node before it, so you can walk backward and remove a node in O(1) without searching for its predecessor.
  - term: Object header
    definition: The space at the start of every class instance that the Swift runtime uses for the instance's type and its reference counts. 16 bytes on 64-bit platforms.
  - term: Memory locality
    definition: How close together in memory the data you use is. Contiguous data (an Array) is read efficiently in large chunks; scattered nodes are not.
  - term: LRU cache
    definition: A cache with a fixed capacity that evicts the least recently used entry when it's full. Usually built from a dictionary and a doubly linked list.
mastery:
  - Fill in a comparison table of Array, stack, queue, deque and linked list costs from memory.
  - Choose the structure for a feature description and justify it in two or three sentences.
  - Explain why a node holding an Int uses several times the memory of an Int in an Array.
  - Write a doubly linked list with a weak previous reference and O(1) removal of a given node.
  - "Write an iterative deinit that tears down a long list, and say what was and wasn't verified about recursive deallocation."
  - Outline an LRU cache with O(1) get and put.
resources: [swift-array, swift-book-arc, swift-book-deinitialization, swift-book-structures-classes, swift-dictionary]
cards:
  - id: m17-l06-c1
    front: Which structure keeps the last N items and drops the oldest in O(1)?
    back: "A ring buffer: a fixed-size array with a head index. Adding when full overwrites the oldest slot and advances head."
  - id: m17-l06-c2
    front: Why does a list of n Int nodes use much more memory than an [Int] of n elements?
    back: "Each node is its own heap object: a 16-byte header (type and reference counts) plus the Int plus the next reference, 32 bytes on 64-bit platforms, versus 8 bytes per element in the array's single buffer."
  - id: m17-l06-c3
    front: In a doubly linked list of class nodes, why is previous declared weak?
    back: "With strong next and strong previous, every pair of neighbors holds each other, which is a reference cycle, and the list is never freed. One direction (usually previous) must be weak."
  - id: m17-l06-c4
    front: What does removing a node from a doubly linked list need to update?
    back: "The previous node's next (or head, if it was first) and the next node's previous (or tail, if it was last). With both links, that's O(1) given the node."
  - id: m17-l06-c5
    front: How do you structure an answer to "which data structure would you use?"
    back: "Name the operations the feature needs and how often, give each candidate's cost for those operations, pick one, and state the trade-off you accept (memory, worst case, complexity of code)."
---

## The idea in one sentence

Choose a linear structure by listing the operations your feature does most often, then pick the one that makes those cheap, and in Swift, start from Array and move away from it only for a reason you can name.

## The comparison table

Costs per operation, with n elements. "Amortized" means O(1) on average over many calls, with an occasional O(n) step for growth or cleanup.

| Operation | Array | Stack (Array) | Head-index queue | Ring-buffer deque | Singly linked list | Doubly linked list |
| --- | --- | --- | --- | --- | --- | --- |
| Read position i | O(1) | top only | front only | O(1) | O(i) | O(i) |
| Add at back | O(1) amortized | push: O(1) amortized | O(1) amortized | O(1) amortized | O(1) with a tail reference | O(1) |
| Remove at back | O(1) | pop: O(1) | — | O(1) | O(n) (needs the predecessor) | O(1) |
| Add at front | O(n) | — | — | O(1) amortized | O(1) | O(1) |
| Remove at front | O(n) | — | O(1) amortized | O(1) | O(1) | O(1) |
| Insert/remove at a node you hold | O(n) (shift) | — | — | O(n) | O(1) after it | O(1), the node itself |
| Search for a value | O(n) | — | — | O(n) | O(n) | O(n) |
| Memory | one buffer | one buffer | one buffer | one buffer (with spare slots) | one object per node | one object per node, two links |

Three things to notice:

1. **Only the linked lists offer O(1) changes in the middle**, and only at a node you already hold. Finding that node is O(n) unless something else, like a dictionary, hands it to you.
2. **The ring buffer gets O(1) at both ends without giving up indexing or the single buffer.** When you need a deque, it's usually the better choice over a linked list.
3. **Array is the only one with no restrictions**, and its weak spot is the front. If your feature never touches the front, use Array.

## What nodes cost in memory

An `[Int]` stores its elements in one heap buffer, 8 bytes each on 64-bit platforms, side by side. A linked list of `Int` allocates one **object per element**, and every class instance in Swift starts with a 16-byte **header** that the runtime uses for the instance's type and its reference counts. Then come the fields:

```swift
final class Node {
    var value: Int
    var next: Node?
    init(_ value: Int) {
        self.value = value
    }
}

print(MemoryLayout<Int>.stride)
print(MemoryLayout<Node?>.stride)
print(MemoryLayout<Node>.size)
```

```output
8
8
8
```

`MemoryLayout` measures what a **variable** of each type takes. For a class, that's a reference: 8 bytes, whatever the object holds. The object itself lives on the heap with its header, its 8-byte `value` and its 8-byte `next`: 32 bytes for one `Int` of data. (The compiled code that frees a `Node` passes that size, 32, to the runtime. The allocator may round it up.) So the list uses about **four times** the memory of the array for the same numbers, plus one allocation per element instead of one in total.

There's more:

- **Locality.** An array's elements sit next to each other, so the processor loads many of them with one memory read. Nodes end up wherever the allocator put them, so walking a list jumps around memory.
- **ARC traffic.** Each node's reference count changes when references to it are created and dropped. Walking a list with `current = node.next` can retain and release every node along the way; the optimizer removes much of this in release builds, but not all.
- **Allocation.** Creating n nodes is n heap allocations, and freeing them is n deallocations. An array that grows by doubling does about log n.

None of this changes the Big O. It's why, at the sizes apps deal with, an Array can win benchmarks it "should" lose, and why you should measure before replacing one.

## Doubly linked lists and weak back links

A **doubly linked list** gives each node a `previous` reference as well as `next`. That's what makes removing a node in O(1) possible: the node itself knows both neighbors, so you don't need to walk from the head to find its predecessor.

It also creates a problem you know from Module 13. If both links are strong, every pair of neighbors holds each other: A holds B through `next`, and B holds A through `previous`. That's a reference cycle, and nothing in the list is ever freed. One direction has to be **weak**:

```swift
final class StrongLinkNode {
    let name: String
    var next: StrongLinkNode?
    var previous: StrongLinkNode?
    init(_ name: String) {
        self.name = name
    }
    deinit {
        print("freed", name)
    }
}

final class WeakLinkNode {
    let name: String
    var next: WeakLinkNode?
    weak var previous: WeakLinkNode?
    init(_ name: String) {
        self.name = name
    }
    deinit {
        print("freed", name)
    }
}

func makeStrongPair() {
    let first = StrongLinkNode("strong A")
    let second = StrongLinkNode("strong B")
    first.next = second
    second.previous = first
}

func makeWeakPair() {
    let first = WeakLinkNode("weak A")
    let second = WeakLinkNode("weak B")
    first.next = second
    second.previous = first
}

makeStrongPair()
print("after the strong pair")
makeWeakPair()
print("after the weak pair")
```

```output
after the strong pair
freed weak A
freed weak B
after the weak pair
```

The strong pair is never freed. In the weak pair, `next` holds the list together from front to back, and `previous` just points back without owning anything. When the function ends, A loses its last strong reference, is freed, and releases B.

Why `weak` and not `unowned`? A node's predecessor can be removed or freed while the node stays in the list (removing the head is exactly that), and `weak` turns into `nil` when that happens. Module 13's rule applies: `weak` when the other object can go away first, `unowned` only when it can't.

Here's a doubly linked list with O(1) removal of a node you hold:

```swift
final class Node {
    let name: String
    var next: Node?
    weak var previous: Node?
    init(_ name: String) {
        self.name = name
    }
}

final class DoublyLinkedList {
    private(set) var head: Node?
    private(set) var tail: Node?

    @discardableResult
    func append(_ name: String) -> Node {
        let node = Node(name)
        node.previous = tail
        if let tail {
            tail.next = node
        } else {
            head = node
        }
        tail = node
        return node
    }

    func remove(_ node: Node) {
        if let previous = node.previous {
            previous.next = node.next
        } else {
            head = node.next
        }
        if let next = node.next {
            next.previous = node.previous
        } else {
            tail = node.previous
        }
        node.next = nil
        node.previous = nil
    }

    var names: [String] {
        var result: [String] = []
        var current = head
        while let node = current {
            result.append(node.name)
            current = node.next
        }
        return result
    }
}

let queue = DoublyLinkedList()
let first = queue.append("Intro")
let middle = queue.append("Verse")
let last = queue.append("Outro")
queue.remove(middle)
print(queue.names, queue.head?.name ?? "-", queue.tail?.name ?? "-")
queue.remove(first)
queue.remove(last)
print(queue.names, queue.head?.name ?? "-", queue.tail?.name ?? "-")
```

```output
["Intro", "Outro"] Intro Outro
[] - -
```

1. `append` links the new node after the current tail. If there's no tail, the list was empty, and the node is also the head. `if let tail` (Swift 5.7 shorthand) unwraps the property into a local constant of the same name.
2. `remove` updates **two** sides. The node's predecessor (or `head`, if there's none) skips forward past it, and its successor (or `tail`, if there's none) points back past it.
3. Clearing the removed node's links isn't required for correctness, but it stops a detached node from keeping the rest of the list alive if someone still holds it.
4. The list's own `tail` property is a strong reference. That's fine: the cycle problem is between nodes, and the list object isn't referenced by any node.

`remove` is O(1). The catch is that you need the node, and that's where a dictionary comes in: the LRU cache in the exercises keeps a `[Key: Node]` so it can find any node in O(1) on average and then move it in O(1).

## Freeing a very long list

When the last reference to a list's head goes away, ARC frees the head. Freeing it releases its `next`, which frees the second node, which releases the third, and so on. In languages where each node frees the next from its destructor, that chain is **recursive**, and a long enough list overflows the stack when it's freed. It's a classic problem with node-based lists.

What Swift does here isn't something the language documentation specifies. The course's test environment checked two things in Swift 6.3.3 on 64-bit Linux: freeing a list of 10 million nodes completed without a crash, and a deinit that recorded the address of a local variable showed the stack depth **not** growing with the list's length. So that runtime did not recurse once per node. That was not checked on Apple platforms or in other Swift versions, and it's an implementation detail that could change.

If a type of yours may hold millions of nodes, you don't have to rely on it. Tear the list down in a loop in its `deinit`, so that every node is freed with its `next` already cleared:

```swift
final class Node {
    let value: Int
    var next: Node?
    init(_ value: Int, next: Node? = nil) {
        self.value = value
        self.next = next
    }
    deinit {
        print("freed", value)
    }
}

final class LinkedList {
    private(set) var head: Node?

    func prepend(_ value: Int) {
        head = Node(value, next: head)
    }

    deinit {
        var current = head
        head = nil
        while let node = current {
            current = node.next
            node.next = nil
        }
    }
}

var list: LinkedList? = LinkedList()
for value in [3, 2, 1] {
    list?.prepend(value)
}
list = nil
print("done")
```

```output
freed 1
freed 2
freed 3
done
```

1. `current` takes over the reference to the head, and `head = nil` drops the list's own.
2. In each pass, `current = node.next` holds on to the rest of the list, then `node.next = nil` cuts the node off from it.
3. When the pass ends, `node` goes out of scope. That was the last reference to the node, so it's freed, and since its `next` is already `nil`, freeing it doesn't free anything else. The depth of each release is constant, whatever the length.

The output is the same as without the custom `deinit`; the difference is only in how deep the releases go. It's a few lines and O(n) work, which freeing n nodes costs anyway.

## Explaining a choice in an interview

Interviewers asking "which structure would you use?" want the reasoning more than the name. A shape that works:

1. **Name the operations** the feature needs, and which are frequent.
2. **Give the cost** of those operations for the candidates.
3. **Pick one**, and **state the trade-off** you're accepting.

Three examples of what that sounds like:

- **"Keep the last 1,000 log lines in memory."** "I need to append constantly and drop the oldest line when full, and occasionally read them all in order. A ring buffer with capacity 1,000 does append-and-evict in O(1) with one fixed allocation. An Array with `removeFirst()` would be O(n) per line once full. A linked list would also be O(1) but with an allocation per line."
- **"Implement undo."** "Undo and redo always act on the most recent action: two stacks, O(1) each. If there's a cap on history, dropping the oldest needs a deque or a ring buffer instead of the bottom of an Array."
- **"Process download jobs in order with a max of three at once."** "Jobs leave in arrival order, so it's a queue. I'd use an Array with a head index, which gives amortized O(1) dequeue; `removeFirst()` would be O(n). The three-at-a-time limit is a counter, not a structure question."

What to avoid: naming a structure because it's the textbook answer ("linked list, because insertion is O(1)") without checking whether the feature ever inserts in the middle at a node it already holds.

## Common mistakes

> [!error] Strong references in both directions
> A doubly linked list with strong `next` and strong `previous` is a chain of reference cycles. Make `previous` weak.

> [!error] Updating only one side when removing from a doubly linked list
> Removing a node changes its predecessor's `next` and its successor's `previous`, and `head` or `tail` when it was at an end. Forgetting one leaves the list inconsistent: walking forward and backward give different results.

> [!error] Choosing a linked list for O(1) insertion when you insert by index
> "Insert at position i" first walks i nodes. That's O(n), the same as an Array's insert, with worse constants.

> [!error] Reaching for a custom structure before measuring
> Array's single buffer and locality often beat the "better" Big O at app-sized inputs. Make the case with the operations and, when it matters, with Instruments.

## Exercises

````exercise
id: m17-l06-e1
type: comprehension
prompt: "A diagnostics screen keeps the 500 most recent network requests. New requests arrive constantly; when there are 500, the oldest is dropped. The screen sometimes shows request number i, counting from the oldest. Which structure fits best?"
choices:
  - text: A ring buffer with capacity 500
    correct: true
    why: Adding when full overwrites the oldest slot in O(1), and request i is at slot (head + i) % 500, also O(1). One fixed allocation.
  - text: An Array, appending at the end and calling removeFirst() when it's full
    correct: false
    why: "Correct, but each removeFirst() is O(n) once the buffer is full, which is on every request from then on."
  - text: A singly linked list with a tail reference
    correct: false
    why: Adding at the tail and dropping the head are O(1), but reading request i is O(i), and every request is a separate allocation.
  - text: A stack
    correct: false
    why: The oldest request is the one to drop, and a stack only gives access to the newest.
solution: |
  **A ring buffer.** The operations are "add at the back, drop the front when full" (constant) and "read by position" (occasional). A ring buffer does all three in O(1): the oldest slot is overwritten, `head` moves forward, and position i is `(head + i) % capacity`. The Array works but pays O(n) per request once full; with 500 elements that's small, but there's no reason to pay it. The linked list matches on the ends but loses indexing and allocates per request.
````

````exercise
id: m17-l06-e2
type: prediction
prompt: Predict the exact output.
code: |
  final class Node {
      let name: String
      var next: Node?
      weak var previous: Node?
      init(_ name: String) {
          self.name = name
      }
      deinit {
          print("freed", name)
      }
  }

  func build() -> Node {
      let a = Node("A")
      let b = Node("B")
      let c = Node("C")
      a.next = b
      b.previous = a
      b.next = c
      c.previous = b
      return a
  }

  var head: Node? = build()
  print(head?.next?.next?.previous?.name ?? "-")
  head = head?.next
  print("moved head", head?.previous?.name ?? "nil")
  head = nil
  print("done")
output: |
  B
  freed A
  moved head nil
  freed B
  freed C
  done
hints:
  - Only next references keep nodes alive. previous is weak.
  - After head = head?.next, nothing strong points to A anymore.
  - A weak reference becomes nil when its object is freed.
solution: |
  ```output
  B
  freed A
  moved head nil
  freed B
  freed C
  done
  ```

  `head?.next?.next?.previous` is C's previous, which is B. Moving `head` to B drops the only strong reference to A (B's `previous` is weak), so A is freed right away, and B's `previous` becomes `nil`. Setting `head = nil` drops B's last strong reference; freeing B releases its `next`, so C is freed too. If `previous` were strong, A and B would hold each other and nothing would be freed.
````

````exercise
id: m17-l06-e3
type: find-errors
prompt: This doubly linked list is used for a "recently played" list. Which statements about it are true?
code: |
  final class Node {
      let title: String
      var next: Node?
      var previous: Node?
      init(_ title: String) {
          self.title = title
      }
  }

  final class RecentList {
      var head: Node?
      var tail: Node?

      func remove(_ node: Node) {
          if let previous = node.previous {
              previous.next = node.next
          } else {
              head = node.next
          }
          if node.next == nil {
              tail = node.previous
          }
      }
  }
choices:
  - text: "Nodes are never freed, even after the RecentList is gone, because neighbors hold each other strongly."
    correct: true
    why: "next and previous are both strong, so every adjacent pair is a reference cycle."
  - text: "After removing a middle node, walking backward from the tail still visits the removed node."
    correct: true
    why: The successor's previous still points to the removed node; only the forward link was updated.
  - text: Removing the head node crashes, because node.previous is nil.
    correct: false
    why: The if let handles a nil previous by updating head instead.
  - text: remove is O(n), because it has to find the node's predecessor.
    correct: false
    why: "The node's previous reference gives the predecessor directly. That's the point of a doubly linked list: O(1)."
rubric:
  - I identified the strong reference cycle between neighbors.
  - I identified the missing update of the successor's previous.
  - I fixed it with weak var previous and the symmetric else branch.
  - I kept remove at O(1).
solution: |
  Two problems, both about the backward direction:

  ```swift
  final class Node {
      let title: String
      var next: Node?
      weak var previous: Node?
      init(_ title: String) {
          self.title = title
      }
  }

  final class RecentList {
      var head: Node?
      var tail: Node?

      func remove(_ node: Node) {
          if let previous = node.previous {
              previous.next = node.next
          } else {
              head = node.next
          }
          if let next = node.next {
              next.previous = node.previous
          } else {
              tail = node.previous
          }
          node.next = nil
          node.previous = nil
      }
  }

  let list = RecentList()
  let a = Node("A")
  let b = Node("B")
  let c = Node("C")
  list.head = a
  a.next = b
  b.previous = a
  b.next = c
  c.previous = b
  list.tail = c
  list.remove(b)
  print(list.tail?.previous?.title ?? "-", list.head?.next?.title ?? "-")
  ```

  ```output
  A C
  ```

  `weak var previous` breaks the cycles: `next` owns the nodes front to back, and `previous` only points back. The second `if let` updates the successor's `previous`, mirroring the first branch, so walking backward from C now goes to A. `remove` stays O(1).
````

````exercise
id: m17-l06-e4
type: fill-in
prompt: "Complete this deinit so a very long list is torn down one node at a time, with no node's release freeing the rest of the chain. It should print `cleared` and then `done`."
code: |
  final class Node {
      var next: Node?
      init(next: Node? = nil) {
          self.next = next
      }
  }

  final class LongList {
      var head: Node?

      deinit {
          var current = [[1]]
          head = nil
          while let node = current {
              current = node.[[2]]
              node.next = [[3]]
          }
          print("cleared")
      }
  }

  var list: LongList? = LongList()
  for _ in 0..<1_000 {
      list?.head = Node(next: list?.head)
  }
  list = nil
  print("done")
blanks:
  - id: "1"
    answers: ["head"]
  - id: "2"
    answers: ["next"]
  - id: "3"
    answers: ["nil"]
solution: |
  ```swift
  final class Node {
      var next: Node?
      init(next: Node? = nil) {
          self.next = next
      }
  }

  final class LongList {
      var head: Node?

      deinit {
          var current = head
          head = nil
          while let node = current {
              current = node.next
              node.next = nil
          }
          print("cleared")
      }
  }

  var list: LongList? = LongList()
  for _ in 0..<1_000 {
      list?.head = Node(next: list?.head)
  }
  list = nil
  print("done")
  ```

  ```output
  cleared
  done
  ```

  `current` holds the remaining list while each node's `next` is cut, so when a node is freed at the end of its pass, it has nothing left to release. Every release is one level deep, whatever the length. Without this loop, freeing the head releases its `next`, and so on down the chain; whether that recurses depends on the runtime, which the lesson explains. The work is O(n) either way.
````

````exercise
id: m17-l06-e5
type: solve
prompt: |
  Write a `LogBuffer` struct that keeps only the most recent `capacity` lines. `mutating func append(_ line: String)` adds a line in O(1), overwriting the oldest when full, and `var lines: [String]` returns the kept lines from oldest to newest. Use a fixed-size array and a head index, with no `removeFirst()`. Assume `capacity` is at least 1.

  Expected output for the starter's calls:

  ```output
  ["boot", "login"]
  ["fetch", "render", "idle"]
  ```
starter: |
  struct LogBuffer {
      let capacity: Int
      // storage, head, count

      init(capacity: Int) {
          self.capacity = capacity
      }

      mutating func append(_ line: String) {
      }

      var lines: [String] {
          []
      }
  }

  var log = LogBuffer(capacity: 3)
  log.append("boot")
  log.append("login")
  print(log.lines)
  log.append("fetch")
  log.append("render")
  log.append("idle")
  print(log.lines)
hints:
  - "Store [String?] with capacity slots. While not full, write at (head + count) % capacity and increment count."
  - When full, the oldest line is at head. Overwrite it and move head forward by one, wrapping.
  - "lines reads count slots starting at head: storage[(head + offset) % capacity]."
rubric:
  - Uses a fixed array of capacity slots, a head index and a count.
  - Appends in O(1), overwriting the oldest slot and advancing head when full.
  - Returns lines in order from oldest to newest, handling wraparound.
  - Output matches, and the answer states O(1) append, O(k) for lines, and O(capacity) space.
solution: |
  ```swift
  struct LogBuffer {
      let capacity: Int
      private var storage: [String?]
      private var head = 0
      private var count = 0

      init(capacity: Int) {
          self.capacity = capacity
          storage = Array(repeating: nil, count: capacity)
      }

      mutating func append(_ line: String) {
          if count < capacity {
              storage[(head + count) % capacity] = line
              count += 1
          } else {
              storage[head] = line
              head = (head + 1) % capacity
          }
      }

      var lines: [String] {
          (0..<count).compactMap { storage[(head + $0) % capacity] }
      }
  }

  var log = LogBuffer(capacity: 3)
  log.append("boot")
  log.append("login")
  print(log.lines)
  log.append("fetch")
  log.append("render")
  log.append("idle")
  print(log.lines)
  ```

  ```output
  ["boot", "login"]
  ["fetch", "render", "idle"]
  ```

  While there's room, lines go into the slot after the newest one. Once full, the oldest line is at `head`: overwrite it and advance `head`, so the slot after the newest is now the oldest again. After five appends with capacity 3, "render" overwrote "boot", "idle" overwrote "login", and `head` points to "fetch". `lines` walks from `head` for `count` slots, wrapping with `%`. `compactMap` unwraps the optionals; every slot in that range is filled, so nothing is dropped. **O(1) per append, O(k) to read k lines, O(capacity) space**, and no element ever moves.
````

````exercise
id: m17-l06-e6
type: design
prompt: |
  Design an image cache for a feed: at most 100 images in memory, `get(url)` returns the image and marks it as most recently used, and `put(url, image)` adds or updates one, evicting the **least recently used** image when the cache is full. Both must be O(1) on average. Describe the data structures, what `get` and `put` do step by step, and the memory and ARC details you'd watch for.
rubric:
  - "Combines a dictionary from URL to node with a doubly linked list ordered by recency."
  - "get: look up the node, move it to the front (unlink and relink in O(1)), return the image."
  - "put: update and move to front if present; otherwise insert at the front, and if over capacity, remove the tail node and its dictionary entry."
  - Explains why both structures are needed (dictionary alone has no order; list alone has O(n) lookup).
  - Uses weak previous links (or otherwise avoids cycles) and keeps the dictionary and list in sync.
solution: |
  **A dictionary plus a doubly linked list.** The list keeps entries ordered by recency: the head is the most recently used, the tail the least. Each node holds the URL, the image, `next` and `weak previous`. The dictionary maps each URL to its node, so you can find any node in O(1) on average without walking the list.

  - **get(url)**: look up the node in the dictionary; if it's missing, return `nil`. Otherwise unlink it (update its neighbors, or head/tail, as in the lesson's `remove`) and insert it at the head. Return its image. All O(1).
  - **put(url, image)**: if the URL is already there, replace the node's image and move it to the head. If not, create a node, insert it at the head and add it to the dictionary. Then, if the count is over 100, take the **tail** node, unlink it and remove its URL from the dictionary. That's why the node stores its URL: you need the key to delete the dictionary entry. All O(1) on average.

  **Why both.** A dictionary alone can't tell you which entry is least recently used without scanning all of them, O(n). A list alone can't find an entry by URL without walking it, O(n). Together, each covers the other's weakness.

  **Memory and ARC.** `previous` must be weak, or every pair of neighbors is a reference cycle and evicted images are never freed. The dictionary holds strong references to nodes, so eviction has to remove the dictionary entry too, or the "evicted" image stays in memory. Clearing the evicted node's links prevents a stray reference from keeping its neighbors alive. And the cache should respond to memory warnings by evicting more. Foundation's `NSCache` evicts automatically under memory pressure, but its documentation doesn't say which entries go first, which is why apps write this structure themselves when the order matters.
````

## Summary

- Pick a structure from the **operations** it must make cheap. In Swift, start with **Array**; its only weak spot is the front.
- **Stack**: one end. **Queue**: back in, front out (head index or two stacks). **Ring-buffer deque**: both ends and indexing in O(1), in one buffer. **Linked lists**: O(1) splicing only at a node you already hold.
- Nodes cost a 16-byte header plus fields each (32 bytes for an `Int` node on 64-bit platforms), one allocation each, poor locality and ARC traffic. Measure before replacing an Array.
- In a **doubly linked list**, make `previous` weak, and update both neighbors (or head/tail) when removing.
- Freeing a long chain can be recursive in some runtimes. Swift 6.3.3 on Linux didn't recurse in the course's test; that's not a documented guarantee, and an iterative `deinit` removes the question.
- In interviews, name the operations, give their costs, pick, and state the trade-off.

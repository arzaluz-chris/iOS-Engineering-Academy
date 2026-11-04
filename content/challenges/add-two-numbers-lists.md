---
id: add-two-numbers-lists
title: Add Two Numbers as Linked Lists
difficulty: medium
order: 37
patterns: [Linked list, Dummy head, Carry]
prerequisites: [m17-l03, m08]
summary: Add two arbitrarily long numbers stored digit by digit in linked lists. Grade-school addition with a carry and a dummy head.
solutionFile: AddTwoNumbersLists.swift
testFile: AddTwoNumbersListsTests.swift
starter: |
  final class DigitListNode {
      let digit: Int
      var next: DigitListNode?

      init(_ digit: Int, next: DigitListNode? = nil) {
          self.digit = digit
          self.next = next
      }
  }

  func addDigitLists(_ first: DigitListNode?, _ second: DigitListNode?) -> DigitListNode? {
      // Your solution
      return nil
  }
time: O(max(n, m))
space: O(max(n, m)) for the result
edgeCases:
  - Lists of different lengths, in either order
  - A carry out of the last digit, like 999 + 1
  - 0 + 0
  - Numbers with more digits than fit in an Int
  - Empty lists, which count as zero
askInterviewer:
  - Which end of the list holds the least significant digit?
  - Can the numbers have leading zeros, or be negative?
  - May I reuse the input nodes, or should the inputs stay unchanged?
  - How long can the numbers be?
hints:
  - The lists start with the ones digit. That's the same order you add numbers by hand. What do you carry from one column to the next?
  - When one list is longer, what does the shorter one contribute once it runs out?
  - "Loop while either list has digits left or the carry isn't zero. A dummy head saves you from special-casing the first digit."
followUps:
  - What if the most significant digit came first? (Reverse both lists, or push the digits on two stacks.)
  - How would you subtract, or multiply?
  - How would you store the number more compactly than one digit per node? (Several digits per node, in base 10^9 for example.)
rubric:
  - I explained why converting to Int fails for long numbers.
  - I added digit by digit with a carry, treating a finished list as 0.
  - I kept looping for a final carry so 999 + 1 gets its extra digit.
  - I used a dummy head and a tail pointer to build the result in O(1) per digit.
codeStatus: tested
---

A storage dashboard adds up byte counts from many servers, and the totals can be longer than any built-in integer type. Each number is stored as a singly linked list of decimal digits, **least significant digit first**: 465 is `5 → 6 → 4`. Write `addDigitLists(_:_:)` that returns the sum of two such numbers as a new list in the same format. Don't modify the inputs. An empty list (`nil`) counts as zero, and adding two empty lists returns `nil`.

In the examples, `makeList` is a test helper that builds a list from an array of digits, least significant first.

```swift
addDigitLists(makeList([5, 6, 4]), makeList([8, 7]))   // 3 → 4 → 5   (465 + 78 = 543)
addDigitLists(makeList([9, 9, 9]), makeList([1]))      // 0 → 0 → 0 → 1   (999 + 1 = 1000)
addDigitLists(makeList([0]), makeList([0]))            // 0
```

**Constraints:** each list has 0 to 10^4 digits; every digit is 0–9; numbers have no leading zeros, except the number 0 itself, which is the single digit 0.

<!-- reveal -->

## First approach

This is column addition from school, and the digit order makes it convenient: the ones digits come first, which is where addition starts. In each column, add the two digits and the carry; write down `sum % 10` and carry `sum / 10`. A list that has run out contributes 0. When both lists are done, a leftover carry is one more digit.

## Naive solution

Convert both lists to `Int`, add them, and convert back:

```swift
func addDigitLists(_ first: DigitListNode?, _ second: DigitListNode?) -> DigitListNode? {
    func number(_ head: DigitListNode?) -> Int {
        var total = 0
        var place = 1
        var current = head
        while let node = current {
            total += node.digit * place
            place *= 10
            current = node.next
        }
        return total
    }
    var sum = number(first) + number(second)
    if first == nil && second == nil {
        return nil
    }
    let head = DigitListNode(sum % 10)
    var tail = head
    sum /= 10
    while sum > 0 {
        let node = DigitListNode(sum % 10)
        tail.next = node
        tail = node
        sum /= 10
    }
    return head
}
```

## Problems with the naive solution

`Int` is 64 bits on Apple platforms, so it can't go past `Int.max`, about 9.2 · 10^18. As soon as a list has 19 digits, `place *= 10` reaches 10^19 and overflows, and Swift **stops the program** on integer overflow rather than wrapping. The lists can have 10,000 digits. The point of storing digits in a list is that the number has no size limit, so the addition must not have one either.

## Optimized solution

Walk both lists together with a carry. Each step reads the current digit of each list (0 if that list is finished), adds the carry, appends a node with `sum % 10` to the result, and keeps `sum / 10` as the new carry. The loop continues while either list has digits **or** the carry is non-zero. A dummy head and a `tail` reference make appending O(1) and mean the first digit isn't a special case.

## Line by line

- `let dummy = DigitListNode(0)` and `var tail = dummy`: the result is built after the dummy; `tail` is always its last node.
- `while a != nil || b != nil || carry > 0`: the `carry > 0` part is what produces the extra digit in 999 + 1.
- `let sum = (a?.digit ?? 0) + (b?.digit ?? 0) + carry`: optional chaining reads a digit if the list hasn't ended, and `?? 0` supplies 0 if it has. The sum is at most 9 + 9 + 1 = 19.
- `let node = DigitListNode(sum % 10)`, `tail.next = node`, `tail = node`: append the column's digit.
- `carry = sum / 10`: 0 or 1.
- `a = a?.next` and `b = b?.next`: advance. On a finished list, `nil?.next` stays `nil`.
- `return dummy.next`: the first real digit, or `nil` if both inputs were empty.

One node is created per column, and there are max(n, m) or max(n, m) + 1 columns: **O(max(n, m)) time and space** for the result, O(1) extra besides it. The inputs are only read.

## Common mistakes

- Stopping when both lists end and forgetting the final carry, so 999 + 1 becomes 000.
- Stopping when the **shorter** list ends, which drops the longer list's high digits.
- Force-unwrapping `a!.digit` without checking for `nil`.
- Building the result by prepending, which reverses the digit order.
- Converting to `Int` or `Double`. `Int` traps on overflow; `Double` silently loses digits past about 15–17 significant figures.

## Variation

**Most significant digit first** (465 as `4 → 6 → 5`): the columns now start at the end of the lists. Push each list's digits onto a stack (lesson m17-l01), pop both stacks together to add from the ones column up, and **prepend** each new digit to the result, which now builds it in the right order.

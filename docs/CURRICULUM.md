# Curriculum

The source of truth for the map is `content/curriculum.yaml`. This document explains the reasoning behind it.

## Sequence

| Stage | Modules | Main prerequisite |
| --- | --- | --- |
| 1. Programming fundamentals | 1–3 | None |
| 2. Swift essentials | 4–8 | Stage 1 |
| 3. Intermediate and advanced Swift | 9–13 | Stage 2 |
| 4. Tools and software engineering | 14 | Stage 3 |
| 5. Algorithms and data structures | 15–20 | Collections (M7), optionals (M8), protocols (M10) |
| 6. iOS development fundamentals | 21 | M14 |
| 7. UIKit from zero to advanced | 22–27 | M21 |
| 8. Concurrency and memory | 28–29 | M26, M13 |
| 9. Data, architecture and testing | 30–33 | M29 |
| 10. SwiftUI | 34–39 | M27, M29 |
| 11. UIKit and SwiftUI integration | 40 | M39 |
| 12. Professional quality and security | 41–43 | M33, M31, M40 |
| 13. System technologies (optional) | 44–45 | M37 |
| 14. Technical interviews | 46–48 | M20, M42, M43 |
| 15. Working as an iOS engineer | 49 | M48 |

Algorithms (stage 5) can be studied alongside stages 6 and 7 once module 10 is done: they only depend on Swift.

The validator checks that every prerequisite exists and comes earlier in the numbering, so the sequence has no cycles and no forward jumps.

## Assessment criteria

- **Lesson completed:** all its exercises attempted and the learner marked it done.
- **Lesson mastered:** completed, with the latest attempt at each exercise correct.
- **Auto-graded exercises (A–D):** correct or incorrect; fill-in allows partial credit.
- **Rubric exercises (E–H), challenges and questions:** score = fraction of criteria met; 100% is correct, 50% or more is partial, anything less is incorrect. Anything not correct goes into review.
- **Challenge mastered:** solved again without help, marked by the learner.
- **Project:** milestones completed and acceptance criteria checked.

## Projects

| # | Project | After |
| --- | --- | --- |
| 1 | Console expense tracker | M8 |
| 2 | Algorithm library with tests | M16 |
| 3 | First UIKit app: reading list | M25 |
| 4 | UIKit app with a public API | M33 |
| 5 | The same app in SwiftUI | M37 |
| 6 | Hybrid app | M40 |
| 7 | Professional app (security, accessibility, CI) | M43 |
| 8 | Capstone project | M48 |

## Initial challenge bank

Written: FizzBuzz, Contains Duplicate, Two Sum, Valid Palindrome, Valid Parentheses.

Planned (in production order): Reverse String, Valid Anagram, First Non-Repeating Character, Character Frequency, Find Maximum and Minimum, Remove Duplicates, Missing Number, Intersection of Two Arrays, Move Zeroes, Merge Sorted Arrays, Binary Search, Best Time to Buy and Sell Stock, Palindrome Number, Reverse Integer, Factorial, Fibonacci, Climbing Stairs, Maximum Subarray, Product of Array Except Self, Group Anagrams, Longest Substring Without Repeating Characters, Merge Intervals, Implement Stack, Implement Queue, Reverse Linked List, Detect Cycle in Linked List, Maximum Depth of Binary Tree, Level Order Traversal, Number of Islands, Coin Change, Subsets, Permutations, LRU Cache, and the rest of NeetCode 150 by pattern until the bank passes 100 challenges.

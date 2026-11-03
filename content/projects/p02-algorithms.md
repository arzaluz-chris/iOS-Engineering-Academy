---
id: p02
number: 2
title: Tested Algorithms Library
summary: Your own Swift package with your challenge solutions, each one with tests. You learn to structure problems and check solutions automatically.
prerequisites: [m14, m16]
objectives:
  - Organize solutions by pattern in a Swift package.
  - Write parameterized tests that cover edge cases.
  - Compare two solutions to the same problem with equivalence tests.
requirements:
  - A package with one target per pattern or one file per problem.
  - Each solution has at least one test for every edge case listed in its challenge.
  - Each file documents its time and space complexity.
acceptance:
  - "`swift test` passes on your Mac."
  - At least 10 challenges solved without looking at the reference solution.
  - Each challenge has a test that compares the optimized solution with a naive one.
milestones:
  - id: p02-h1
    title: Package structure
    tasks: ["Create the package with a library target and a test target.", "Add a CI workflow that runs `swift test`."]
    concepts: [Swift Package Manager, CI]
  - id: p02-h2
    title: Hashing and two-pointer patterns
    tasks: ["Solve Two Sum, Contains Duplicate, Valid Palindrome and Valid Anagram, with tests."]
    concepts: [Hash map, Two pointers]
  - id: p02-h3
    title: Stacks, windows and binary search
    tasks: ["Solve Valid Parentheses, Best Time to Buy and Sell Stock and Binary Search, with tests."]
    concepts: [Stack, Sliding window, Binary search]
  - id: p02-h4
    title: Equivalence tests
    tasks: ["For each challenge, test that the naive and optimized solutions agree on generated cases."]
    concepts: [Parameterized tests]
---

## How this relates to this repository

The `swift/` directory in the academy's repository is an example of this structure: solutions in `Sources/Challenges` and tests in `Tests/ChallengesTests`. Your library is separate. Look at the reference one only after you've attempted each challenge.

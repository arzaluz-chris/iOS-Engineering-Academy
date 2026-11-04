---
id: semantic-version-precedence
title: Semantic Version Precedence
difficulty: easy
order: 98
patterns: [String parsing, Lexicographic comparison]
prerequisites: [m41-l03]
summary: Order version strings like 2.0.0-beta.10 and 2.0.0-rc.1 by the Semantic Versioning rules, pre-releases included. Careful parsing plus one comparison rule per part.
solutionFile: SemanticVersionPrecedence.swift
testFile: SemanticVersionPrecedenceTests.swift
starter: |
  func compareSemanticVersions(_ lhs: String, _ rhs: String) -> Int {
      // Your solution
      return 0
  }
time: O(n), where n is the total length of both strings
space: O(n)
edgeCases:
  - A release against its own pre-release (the release comes after)
  - Numeric pre-release identifiers with different digit counts, like beta.2 and beta.10
  - A numeric identifier against an alphanumeric one
  - Uppercase against lowercase identifiers (ASCII order)
  - Pre-release lists of different lengths with an equal shared part
  - Build metadata, which doesn't affect precedence
  - Hyphens inside the pre-release or the build metadata
  - Numbers too large for Int
askInterviewer:
  - Are the inputs guaranteed to be valid versions, or should invalid ones be rejected?
  - Should build metadata be ignored?
  - How should I report the result, an Int, a Bool for "less than", or Comparable?
  - Can numbers be larger than Int.max?
hints:
  - Split off the build metadata first, then the pre-release. Which separator do you split on, and how many times?
  - Major, minor and patch compare as numbers. When they're equal, how does "has a pre-release" decide the order?
  - Pre-release identifiers compare one at a time, and there are three cases, number vs number, number vs text, text vs text.
followUps:
  - Make a SemanticVersion struct that conforms to Comparable and rejects invalid strings.
  - Check whether a version satisfies a requirement like ">=2.1.0 <3.0.0".
  - Why does App Store Connect not accept 1.0.0-beta as CFBundleShortVersionString?
rubric:
  - I compared numbers as numbers, not as text.
  - I put a pre-release before its release.
  - I implemented the three identifier rules and the shorter-list rule.
  - I ignored build metadata and split on the first "+" and first "-" only.
codeStatus: tested
---

A library's update checker compares the version a user has with the one the server offers. Versions follow [Semantic Versioning 2.0.0](https://semver.org): `MAJOR.MINOR.PATCH`, then optionally `-` and a pre-release made of dot-separated identifiers, then optionally `+` and build metadata. Write `compareSemanticVersions(lhs, rhs)` that returns `-1` if `lhs` has lower precedence, `1` if it has higher precedence, and `0` if they're equal. The rules:

1. Compare major, minor and patch numerically, in that order.
2. If those are equal, a version **with** a pre-release comes before the same version without one: `3.1.0-rc.1` < `3.1.0`.
3. Two pre-releases compare identifier by identifier, left to right. Identifiers made only of digits compare as numbers. Other identifiers compare by their ASCII characters. A numeric identifier comes before a non-numeric one.
4. If every shared identifier is equal, the version with more identifiers comes after: `alpha` < `alpha.0`.
5. Build metadata is ignored: `1.4.2+build.7` and `1.4.2` are equal.

```swift
compareSemanticVersions("1.10.0", "1.9.3")               // 1
compareSemanticVersions("2.0.0-beta.2", "2.0.0-beta.10") // -1
compareSemanticVersions("3.1.0-rc.1", "3.1.0")           // -1
compareSemanticVersions("1.4.2+build.7", "1.4.2")        // 0
```

**Constraints:** both inputs are valid Semantic Versioning 2.0.0 strings (so numbers have no leading zeros), up to 256 characters each. Numbers may be larger than `Int.max`.

<!-- reveal -->

## First approach

Module 41, lesson 3 compared plain `MAJOR.MINOR.PATCH` versions by parsing the three numbers. Pre-releases add the rest of the rules, and the order of operations matters: strip the build metadata at the first `+` (it may contain `-`), then split the pre-release off at the first `-` (the pre-release itself may contain `-`). After that, it's a lexicographic comparison where each part has its own rule.

## Naive solution

Split on dots and compare numbers, which is enough for plain versions:

```swift
func compareSemanticVersions(_ lhs: String, _ rhs: String) -> Int {
    let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
    let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
    for (a, b) in zip(left, right) where a != b {
        return a < b ? -1 : 1
    }
    return 0
}
```

## Problems with the naive solution

It gets `1.10.0` vs `1.9.3` right, which plain string comparison doesn't (`"1.10.0" < "1.9.3"` is `true` in Swift). But the pre-release breaks it: `"0-beta"` doesn't parse, becomes 0, and `1.0.0-beta` compares equal to `1.0.0`. Text identifiers all become 0 too, so `1.0.0-rc.1` comes out before `1.0.0-beta.2`, the wrong way round. And `Int($0)` fails for numbers larger than `Int.max`.

## Optimized solution

Parse each string into its core parts and its pre-release identifiers, without converting to `Int`. Compare the core parts as numbers. If they're equal, apply rule 2. Then compare identifiers pairwise with rule 3, and fall back to the number of identifiers (rule 4). Numbers are compared as digit strings: with no leading zeros, a longer string is a bigger number, and equal lengths compare digit by digit. That never overflows.

## Line by line

- `semverPrecedenceParts(of:)`: `split(separator: "+", maxSplits: 1, ...)[0]` drops the build metadata. Then `split(separator: "-", maxSplits: 1, ...)` separates the core from the pre-release; `maxSplits: 1` keeps a pre-release like `x-y` in one piece. `omittingEmptySubsequences: false` keeps the shape predictable even for odd input.
- The first loop zips the three core numbers and returns at the first difference.
- `switch (left.preRelease.isEmpty, right.preRelease.isEmpty)`: rule 2. Only when both have a pre-release does the comparison continue.
- The second loop applies `semverComparePreReleaseIdentifiers` pair by pair.
- `semverCompareInts(left.preRelease.count, right.preRelease.count)`: rule 4, reached only when every shared identifier was equal.
- `semverIsNumericIdentifier`: non-empty and every UTF-8 byte is an ASCII digit. Checking bytes avoids `Character.isNumber`, which also accepts digits from other scripts.
- `semverComparePreReleaseIdentifiers`: numeric pairs go to the digit-string comparison; a numeric identifier against a text one returns -1 or 1 directly; two text identifiers compare by `utf8.lexicographicallyPrecedes`, which is exactly ASCII order (uppercase before lowercase).
- `semverCompareDigitStrings`: length first, then bytes.

## Common mistakes

- Comparing whole version strings as text, so `1.10.0` sorts before `1.9.3`.
- Treating a pre-release as newer than its release because it's longer.
- Comparing `beta.10` and `beta.2` as text, which puts 10 first.
- Splitting on every `-`, which cuts `1.0.0-x-y` into three parts.
- Letting build metadata affect the order.

## Variation

**Requirement matching:** given a requirement like `>=2.1.0 <3.0.0`, split it into comparator and version pairs and check each with this function. One rule worth knowing from tools like npm: pre-releases usually only satisfy a range if the range itself mentions a pre-release of the same core version, so `3.0.0-beta` doesn't silently match `>=2.1.0`. That's a convention of those tools, not part of the Semantic Versioning spec.

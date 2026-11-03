# Challenge solutions and lesson snippets

A Swift package with one solution and its tests (Swift Testing) for each challenge in `content/challenges/`. The site shows these same files.

```bash
swift test                          # all tests
swift test --filter TwoSumTests     # one challenge
```

Requires Swift 6 (Xcode 16 or later). To practice with your own solution, replace the challenge's file in `Sources/Challenges/` on a separate branch and run its tests.

## Lesson snippets

`Tests/LessonSnippetsTests` compiles and runs the snippets in `content/lessons/` (prediction exercises and, in `tested` lessons, every Swift block) and compares their output with what the lesson claims. The rules are in `docs/CONTENT.md`. It needs `swiftc` on the `PATH`.

```bash
swift test --filter LessonSnippetsTests
```

# Phase 6. Content production

## Batch 1 (November 3, 2026)

| Item | Count | Details |
| --- | --- | --- |
| Lessons | 4 | M1: what programming is; from source code to program; Swift, Xcode and iOS. M4: print, comments, literals and expressions |
| Exercises | 16 | All eight formats; the seven in `m04-l01` cover B to G |
| Review cards | 13 | In each lesson's frontmatter |
| Challenges | 5 | FizzBuzz, Contains Duplicate, Two Sum, Valid Palindrome, Valid Parentheses |
| Interview questions | 17 | Swift (4), memory (1), concurrency (2), UIKit (2), SwiftUI (1), architecture (2), security (3), testing (1), system design (1) |
| Projects | 8 | Specified with requirements, acceptance criteria and milestones |
| Resources | 20 | Verified on 3 Nov 2026 |

## Batch checklist

| Step | Result |
| --- | --- |
| 1. Write lessons | Done |
| 2. Review technical accuracy | Static review. Prediction outputs worked out by hand and reviewed; the behavior of `print`, integer division, precedence, nested comments and compiler error messages checked against the Swift documentation |
| 3. Check prerequisites | Validator reports no errors |
| 4. Verify examples | Lesson examples: **reviewed, not run** (`codeStatus: reviewed` or `illustrative`). Challenge code: run in CI |
| 5. Check solutions | `swift test`: 18 tests in 5 suites pass |
| 6. Verify links | 20/20 |
| 7. Tests and rubrics | Every item has a rubric or automatic grading |
| 8. Automated validation | `npm run validate` with no errors |
| 9. Fix errors | Fixed 9 YAML errors caught by the validator (values containing ": " without quotes) |

## Pending for the next batch

Resolved in batch 2: the predictions in `m04-l01` and `m01-l02` were verified by running them, and both lessons are `tested`.

## Batch 2 (November 3, 2026)

| Item | Count | Details |
| --- | --- | --- |
| Lessons | 15 new (19 total) | M2: decomposition, patterns and abstraction; pseudocode; flowcharts; trace tables; edge cases and a design method. M3: installing Xcode and checking versions; project, window and simulator; Swift from the terminal and Swift packages; errors, warnings and runtime errors; breakpoints and documentation. M4: constants and variables; types and inference; annotations and conversion; comparison and logical operators; interpolation |
| Exercises | 76 new (92 total) | Every lesson has at least 4, with at least one prediction and one solve exercise |
| Review cards | 61 new (74 total) | |
| Resources | 10 new (30 total) | Control Flow, Functions and Strings and Characters from the Swift book; four Xcode documentation pages (components, creating a project, breakpoints, stepping through code); SwiftPM documentation; swift.org's guide to command-line tools; the LLDB tutorial. Marked `status: unverified`; they returned 200 to `npm run check-links` |

### Batch checklist

| Step | Result |
| --- | --- |
| 1. Verify the pending predictions in m01-l02 and m04-l01 | They match the real run. Both lessons moved to `tested` |
| 2. Write lessons | Done: M2 and M3 complete, M4 complete (lessons 1 to 6) |
| 3. Review technical accuracy | Xcode and Swift versions taken from `02-research.md`; lesson m03-l01 teaches how to check them and points to the official table, without assuming the installed version. Xcode menus, Components, breakpoints and the `v`/`p`/`po` commands checked against Apple's documentation (JSON from developer.apple.com). Output of `swift package init`, `swift run` and `swift test` obtained by running them with Swift 6.3.3 |
| 4. Check prerequisites | Validator reports no errors |
| 5. Verify examples | Every Swift block in the 17 lessons with code runs in `LessonSnippetsTests` (except the `illustrative` ones, listed in `docs/STATUS.md`) |
| 6. Fix what running the code revealed | 36.6 °C gives `97.88000000000001` °F, not `97.88` (m04-l04-e5, which now explains `Double` precision). A block with `terminator: ""` followed by an expected output with a trailing newline (m03-l05). A prompt that claimed the compiler flagged line 3 when it flags the end of line 2 (m03-l04-e3). The validator also caught a YAML error in a card (m04-l03) |
| 7. Verify links | 30/30 with `npm run check-links` |
| 8. Automated validation | `npm run validate`, `npm test`, `npm run build` and `swift test` with no errors |

### Decisions

- **Pseudocode predictions.** Module 2 comes before the learner knows Swift, but every prediction has to be verified. `lang: pseudo` was added to prediction exercises: the code is shown as pseudocode and the solution includes its Swift translation, which is what the tests run.
- **Compiler messages.** Lessons quote Swift 6.3 messages and say so. The tests check that the quoted text still appears, so a wording change in a future version will fail the test instead of leaving the lesson out of date.

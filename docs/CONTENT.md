# Writing content

The whole course lives in `content/` and `swift/`. You don't touch the app to add content. After any change:

```bash
npm run validate && npm test
cd swift && swift test --filter LessonSnippetsTests
```

## Language and voice

The academy is written in **American English**. Write the way a good senior engineer explains something to a colleague they respect:

- Plain, direct sentences. Second person ("you"). Contractions are fine.
- Say the thing. No warm-up ("In this lesson, we'll explore…"), no sign-off ("Happy coding!").
- No filler words or phrases: *delve, crucial, essential, robust, seamless, leverage, journey, unlock, dive in, it's important to note, in today's world, let's take a look*.
- No stacked triplets for rhythm ("fast, safe, and expressive") unless all three are the point.
- Em dashes sparingly. Prefer a period or a colon.
- Bold only the one phrase per paragraph that really matters, if any.
- Precise beats friendly. If a claim wasn't verified, say so.
- Code identifiers are English and descriptive: `coffeePrice`, not `cp` or `precioCafe`.

## Lessons

File: `content/lessons/<module>/<order>-<slug>.md`:

```markdown
---
id: m05-l01                 # unique across the course; never change an existing id
title: …
description: …
module: m05                 # must exist in curriculum.yaml
order: 1                    # unique within the module
level: beginner             # beginner | intermediate | advanced
minutes: 40
codeStatus: tested          # tested | reviewed | illustrative | no-code
swiftVersion: "6.4"         # when it applies
prerequisites: [m04-l03]    # earlier lessons in the sequence
objectives: [ … ]
terms: [{ term: …, definition: … }]
mastery: [ … ]              # "What you should be able to do now": observable skills
resources: [swift-book]     # ids from resources.yaml
cards: [{ id: m05-l01-c1, front: …, back: … }]   # added to review when the lesson is completed
---

## Sections with ## …
```

Recommended shape for each concept: a plain definition, the precise explanation, an analogy with its limits (if it helps), a minimal example, a line-by-line walkthrough, a practical example, common mistakes, exercises, summary.

`codeStatus` has to be honest: `tested` only when the snippet tests compiled and ran the code (see below); `reviewed` if it was read but not compiled; `illustrative` for explanatory fragments; `no-code` when there's no code.

### Callouts

```markdown
> [!error] error: cannot find 'Print' in scope
> Explanation…

> [!warning] …     > [!note] …     > [!tip] …     > [!version] …
```

### Code blocks run by the tests

The `swift/Tests/LessonSnippetsTests` target reads `content/lessons/`, compiles each snippet as a standalone program (`swiftc -swift-version 6`, line-buffered like a terminal), runs it and checks the output:

- **Every `prediction` exercise**, in any lesson: `code` must compile and its standard output must be exactly `output` (if the program stops with a runtime error, what it printed before counts). Write `code` and `output` as `|` literal blocks (or `|-` if the output doesn't end in a newline). If the solution repeats the output in an ```` ```output ```` block, it must match `output`. With `lang: pseudo`, `code` is pseudocode and the solution must include its Swift translation in a ```` ```swift ```` block; the tests run that translation (the validator requires it).
- **In lessons with `codeStatus: tested`**, every ```` ```swift ```` block in the prose and in exercise solutions:
  - ```` ```swift ```` must compile and run cleanly. If the next fenced block is ```` ```output ````, the output must match exactly.
  - ```` ```swift no-compile <diagnostic text> ```` must fail to compile with a diagnostic containing that text. Use it for compiler-error examples.
  - ```` ```swift warning <text> ```` must compile with a warning containing `warning: <text>` and run cleanly.
  - ```` ```swift runtime-error <text> ```` must compile, stop with a runtime error and write `<text>` to stderr (for example `Index out of range`). With an ```` ```output ```` block after it, what it printed before the error is compared.
  - ```` ```swift illustrative ```` isn't run: code that depends on another block, or a fragment that can't stand alone.
- **In any lesson**, ```` ```swift ios ```` (or ```` ```swift ios 18.0 ```` for a deployment target other than the default iOS 17.0) marks self-contained Apple-framework code (UIKit, SwiftUI, OSLog…). It is type-checked, not run, against the iOS simulator SDK in Swift 6 mode (`swiftc -typecheck`, compiled as `main.swift`, so top-level statements are allowed and `@main` isn't). That needs Xcode, so it happens on the macOS CI runner; on Linux the test is skipped. Include the imports and keep each block self-contained; use `illustrative` for fragments and `@main` entry points. A self-test proves the check rejects broken UIKit code.

The site only uses the first word of the fence for highlighting, so these markers are invisible to readers.

Run them with `cd swift && swift test --filter LessonSnippetsTests`, or on Linux with `docker run --rm -v "$PWD":/w -w /w/swift swift:6.3 swift test`. The "Swift · challenge tests" workflow runs them on macOS on every push that touches `content/lessons/`.

### Pseudocode conventions

Used in ```` ```pseudo ```` blocks and in `lang: pseudo` predictions:

| Write | Meaning | In Swift |
| --- | --- | --- |
| `Input:` and `Output:` | What the algorithm receives and returns | Parameters and return value |
| `total ← 0` | Store 0 in `total` | `var total = 0` |
| `Print total` | Write the value to the output | `print(total)` |
| `If condition then` … `Else` | Decision | `if … { } else { }` |
| `For each x in list` | Repeat once per element | `for x in list { }` |
| `While condition` | Repeat while the condition holds | `while … { }` |
| `Return value` | Stop and hand back the answer | `return value` |

Use `+ − × ÷` for arithmetic and `= ≠ < ≤ > ≥` for comparison. Say "integer division" when that's what you mean.

### YAML

If a value contains `: ` (colon and space), or starts with a backtick, `*`, `[`, `{`, `!`, `&`, `>`, `|`, `%` or `@`, quote it. The validator catches invalid YAML.

## Exercises

Inside the lesson, in **four**-backtick blocks so their fields can contain ``` blocks:

`````markdown
````exercise
id: m05-l01-e1
type: comprehension | prediction | fill-in | find-errors | solve | explain | refactor | design
prompt: …
hints: [ … ]          # optional, revealed one at a time
solution: |           # required, explained
  …
# fields by type:
# comprehension: choices [{text, correct, why}], multiple (bool)
# prediction:    code, output (exact), accept (alternatives), lang (swift | pseudo; default swift)
# fill-in:       code with blanks [[1]], blanks [{id: "1", answers: [...]}]
# find-errors:   code, choices (real problems and distractors), rubric
# solve:         starter, rubric, tests (optional, Swift Testing)
# explain / refactor: code, rubric
# design:        rubric
````
`````

Rules: prediction output must be verified (the tests do it); blanks must match `blanks`, each id used once; single-choice questions need exactly one correct option.

## Coding challenges

1. Solution in `swift/Sources/Challenges/<Name>.swift` (`public` functions).
2. Tests in `swift/Tests/ChallengesTests/<Name>Tests.swift` with Swift Testing (`@Test`, `#expect`).
3. Card in `content/challenges/<slug>.md`: frontmatter (difficulty `easy | medium | hard`, patterns, `solutionFile`, `testFile`, `starter`, complexity, edge cases, questions for the interviewer, hints, follow-ups, rubric), the problem statement, the `<!-- reveal -->` marker and then the sections `## First approach`, `## Naive solution`, `## Problems with the naive solution`, `## Optimized solution` (the code from `swift/` is inserted here), `## Line by line`, `## Common mistakes`, `## Variation`.
4. `cd swift && swift test`. Once CI passes, set `codeStatus: tested`.

## Interview questions

In `content/interview/<category>.yaml`, category one of `swift`, `uikit`, `swiftui`, `concurrency`, `architecture`, `memory`, `testing`, `security`, `networking`, `persistence`, `performance`, `tooling`, `platform`, `system-design`. Fields: `id`, `category`, `difficulty`, `question`, `answer` (Markdown), `keyPoints` (the rubric), `followUps` [{question, answer}], `writesCode`, `related`.

## Projects

`content/projects/pNN-<slug>.md` with objectives, requirements, acceptance criteria and milestones (`milestones` with `tasks` and `concepts`).

## Resources

`content/resources.yaml`. No videos. Each resource has a source, a kind (`official`, `tutorial`, `article`, `reference`), a topic, why to read it, and a `status` (`verified`, `unverified`, `broken`). Mark `verified` with a date only after checking it (`npm run check-links` or the weekly workflow). Link the specific API page, not a landing page.

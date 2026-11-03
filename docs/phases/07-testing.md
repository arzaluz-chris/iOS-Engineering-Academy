# Phase 7. Testing

Run on November 3, 2026.

| Test | Where it ran | Result |
| --- | --- | --- |
| `npm run validate` | Local and CI | No errors; 47 warnings for modules without lessons |
| `tsc --noEmit` | Local and CI | No errors |
| `npm test` (Vitest) | Local and CI | 32 tests in 5 files, all pass |
| `vite build` | Local and CI | Succeeds |
| `swift test` | GitHub Actions, macOS (Xcode 26.6, Swift 6.3.3) | 18 tests in 5 suites, all pass |
| `check-links` | GitHub Actions, Linux | 20/20 links respond |
| Visual check | Local headless Chrome | No console errors on the dashboard, curriculum, lessons, challenges, interviews and review; desktop 1440 px and mobile 390 px; light and dark |
| Deployment | GitHub Pages | Published at https://arzaluz-chris.github.io/iOS-Engineering-Academy/ |

## Web test coverage

| File | What it tests |
| --- | --- |
| `tests/content.test.ts` | Real content with no errors; 12–16 stages; security module; lessons with objectives, exercises and solutions; challenges with Swift code and tests; no videos. The validator with negative cases: missing prerequisites, duplicate IDs, blanks without an answer, single choice with two correct options, invalid frontmatter |
| `tests/grade.test.ts` | Single and multiple choice, prediction (whitespace, CRLF, alternatives), blanks, blank separation |
| `tests/persistence.test.ts` | Opening doesn't complete; completing adds cards; misses go to review; FSRS reschedules and logs history; review priority; export, clear and import without loss; rejection of invalid backups; an invalid import doesn't touch data |
| `tests/search-router.test.ts` | Accent-insensitive search, by pattern and across questions; hash routes; lesson mastery based on the latest attempt |
| `tests/ui.test.tsx` | A comprehension exercise records an auto-graded attempt; the solution isn't shown before it's requested; empty dashboard with no made-up metrics; curriculum with every stage |

## Not covered yet

- Automated accessibility tests (axe, for example) and end-to-end navigation tests in a real browser in CI.
- Persistence across a reload in a real browser (tested with fake-indexeddb, not with a real reload in CI).

## Content batch 2 (November 3, 2026)

| Test | Where it ran | Result |
| --- | --- | --- |
| `npm run validate` | Local and CI | No errors; 19 lessons, 92 exercises, 30 resources |
| `npm test` (Vitest) | Local and CI | 35 tests in 5 files, all pass |
| `npm run build` | Local and CI | Succeeds |
| `swift test` | Local, `swift:6.3` container (Swift 6.3.3, Linux x86_64) | 22 tests in 6 suites, all pass |
| `swift test` | GitHub Actions, macOS (Xcode 26.6, Swift 6.3.3), commit `bf42911` | 22 tests in 6 suites, all pass; the lesson snippets add up to 17 prediction cases and 97 Swift blocks |
| `npm run check-links` | Local | 30/30 links respond |
| Visual check | Local headless Chromium | Lessons m02-l02, m02-l03, m03-l04 and m04-l05 with no console errors; text diagrams, tables with `\|\|` and the pseudocode prediction exercise render correctly |

### New tests

| File | What it tests |
| --- | --- |
| `swift/Tests/LessonSnippetsTests` | Reads `content/lessons/`. Runs every prediction exercise and compares its exact output with `output` (with `lang: pseudo`, it runs the Swift translation from the solution). In `tested` lessons, runs every Swift block in the text and the solutions and compares it with the `output` block that follows; checks the compiler errors (`no-compile`), warnings (`warning`) and runtime errors (`runtime-error`) the text quotes. Checks that prediction solutions repeat the same `output`. A sanity test fails if the extractor stops finding exercises |
| `tests/content.test.ts` | The validator requires the Swift translation in pseudocode predictions; `lang` defaults to `swift` |
| `tests/ui.test.tsx` | A pseudocode prediction is labeled as pseudocode, shows its own instructions and is auto-graded |

### What the tests found

- An inaccurate expected output: 36.6 °C is `97.88000000000001` °F when you print a `Double` (m04-l04-e5).
- An output block that expected a newline after `terminator: ""` (m03-l05-e4).
- What was printed before a runtime error got lost when output went to a pipe. The snippet runner now uses line-buffered output, like a terminal or the Xcode console.

### Limitations

- The tests run with Swift 6.3.3; the lessons declare Swift 6.4. No snippet uses anything specific to 6.4.
- What Module 3 describes about the Xcode UI has no automated test.

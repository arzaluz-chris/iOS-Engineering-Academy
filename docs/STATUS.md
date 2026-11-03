# Project status

Last updated: November 3, 2026.

## Done

**Language and design (3 Nov 2026):** the whole academy (content, UI and docs) was moved to English, and the site was redesigned after swift.org's visual language. The owner's original specification (`docs/ESPECIFICACION.md`) stays in Spanish.

- Content: all 19 lessons, 5 challenges, 17 interview questions, 8 projects, the curriculum map and the resources were rewritten in English (not word-for-word translations). Code identifiers and string literals are English now, so outputs changed; every output was re-verified by the snippet tests (17 predictions and 98 Swift blocks pass). Some examples were adapted: amounts in pesos became dollars or unlabeled numbers (the m02-l01 restaurant bill is now $200, the m02-l01-e6 tickets $12/$8), Mexican places became generic ones, "NIP" became "PIN". IDs did not change, so saved progress still lines up.
- Format: frontmatter enums, exercise types, callouts and snippet markers are English (`tested`, `prediction`, `[!note]`, `swift no-compile`…; see `docs/CONTENT.md`). Routes are English (`#/lesson/…`, `#/curriculum`, `#/challenges`…); old Spanish URLs no longer resolve. Values stored in IndexedDB (lesson status, attempt results, card sources) stay in Spanish on purpose, because renaming them would orphan existing progress; they're never shown on screen.
- Design: system font stack (SF Pro on Apple devices), translucent sticky top navigation, a swift.org-style peach hero on the home page with an orange gradient pill button, 22px rounded cards, Xcode-like syntax colors, an indigo footer with a Light/Dark/Auto switch, and a navy dark mode. The IBM Plex and Source Serif fonts were removed. Checked in Chromium at 1440 px and 390 px, light and dark, with no console errors and no horizontal page scroll.

**Platform (Phase 5 complete):** curriculum navigation, lessons, all eight exercise formats, automatic and rubric grading, challenges with progressive reveal and three practice modes, an interview simulator with follow-ups and results by category, projects with milestones, FSRS spaced review, notes, bookmarks, global search, a dashboard with real data, validated export and import, light and dark mode, responsive layout, deployment to GitHub Pages.

**Content:**

| Type | Written | Planning target |
| --- | --- | --- |
| Stages | 15 (full map) | 12–16 |
| Modules | 49 on the map; 4 with lessons (M1 to M4) | — |
| Lessons | 19 (M1: 3, M2: 5, M3: 5, M4: 6) | more than 100 |
| Lesson exercises | 92 (comprehension 27, prediction 17, solve 16, explain 8, find-errors 8, fill-in 7, design 5, refactor 4) | at least 100 |
| Review cards | 74 | — |
| Coding challenges | 5, with Swift solutions and tests | at least 100 |
| Interview questions | 17 across 9 categories, including security | a broad bank |
| Projects | 8 specified with milestones | 8 |
| Resources | 30; 20 verified and 10 new ones with `status: unverified` (all 30 returned 200 to `npm run check-links` on 3 Nov 2026) | — |

Stage 1 (M1–M3) and all of Module 4 in stage 2 are written.

**Lesson code:** 17 of 19 lessons have `codeStatus: tested`; the other two (m01-l01 and m01-l03) are `no-code`. No lesson is left at `reviewed`. "Tested" means the `swift/Tests/LessonSnippetsTests` target compiles and runs every Swift block in the lesson and in its exercise solutions, and compares the output with what the text claims. Every prediction exercise, in any lesson, is run and its `output` compared exactly; for pseudocode predictions (`lang: pseudo`, Module 2) the Swift translation is what runs. The tests also check the compiler errors (`swift no-compile`), warnings (`swift warning`) and runtime errors (`swift runtime-error`) the lessons quote. What isn't run: blocks marked `swift illustrative` (the `Package.swift` manifest, a package's `@main` template and the declaration of `print` in m03; the `@main` solution in m03-l03-e4), terminal commands, and what's described about the Xcode UI, which was taken from Apple's documentation and couldn't be checked in Xcode from the build environment.

**Tests run in the build environment:** `npm run validate` (no errors), `npm test` (35 tests, all pass), `npm run build` (succeeds), `swift test` in the `swift:6.3` container (Swift 6.3.3, Linux), a visual check in Chromium with no console errors.

**Swift in CI:** the `swift.yml` workflow ("Swift · challenge tests") runs `swift test` on macOS (Xcode 26.6, Swift 6.3.3) on every push that touches `swift/` or `content/lessons/`. It passed for every batch in this increment. The runner doesn't use Xcode 27 / Swift 6.4 yet; the code uses nothing specific to 6.4.

**Published:** https://arzaluz-chris.github.io/iOS-Engineering-Academy/

**Links:** the `links.yml` workflow checks that links exist (for Apple's documentation it queries the JSON data). It checks that a link responds, not that the content matches the topic; that was reviewed when each resource was written.

## Platform changes in this increment

- Prediction exercises with `lang: pseudo` (schema, component and validator, with tests in `tests/content.test.ts` and `tests/ui.test.tsx`): they're shown as pseudocode, and the validator requires a Swift translation in the solution.
- The `LessonSnippetsTests` Swift target and the code block markers `no-compile`, `warning`, `runtime-error` and `illustrative`, documented in `docs/CONTENT.md`.

## Acceptance criteria not yet met

- More than 100 lessons, 100 exercises and 100 challenges: modules 5 to 49 and almost all challenges are missing.
- Swift taught in depth, UIKit and SwiftUI with full stages: today only their plan exists.
- Automated accessibility tests: not implemented.
- The Xcode UI instructions in Module 3 (menus, shortcuts, *Settings › Components*, the debugger) haven't been checked in a real Xcode.

## Next step

1. Module 5, Control flow (`if`, `switch`, `guard` in its basic form, `for-in`, `while`, `repeat-while`, `break`, `continue`), with at least 6 lessons. Pick up what M4 promised: the ternary operator, `if` to choose "year" or "years", the loop in the leap-year solution.
2. Modules 6 to 8 (functions, collections, optionals), closing stage 2.
3. Array and hashing challenges alongside M7.
4. Check Module 3's Xcode UI instructions in Xcode 27 and, if they match, note it here.
5. If the links workflow confirms the 10 new resources, change their `status` to `verified` with a date.

For each batch: write the lessons, run `cd swift && swift test` (or the `swift:6.3` container), set `codeStatus` according to what the tests ran, `npm run validate && npm test && npm run build`, check in the browser, commit and push, and check the Swift workflow.

## Picking this up in another session

Read `CLAUDE.md` at the root, then this file and `docs/CONTENT.md`. The schema is in `src/content/schema.ts`; lesson m04-l01 is the reference model of a lesson (it uses seven of the eight exercise formats; it has no `design` exercise). To run Swift without Xcode: `docker run --rm -v "$PWD":/w -w /w/swift swift:6.3 swift test` (if the Docker daemon isn't running, start it with `dockerd`).

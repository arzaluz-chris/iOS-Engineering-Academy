# Phase 3. Curriculum design

Deliverables the spec asked for and where they live:

| Deliverable | Location |
| --- | --- |
| 1. Full course map | `content/curriculum.yaml` (15 stages, 49 modules with objectives and topics); summary in `docs/CURRICULUM.md` |
| 2. Prerequisite sequence | Each module's `prerequisites`; table in `docs/CURRICULUM.md`. The validator rejects prerequisites that don't exist or come later |
| 3. Content schema | `src/content/schema.ts`; guide in `docs/CONTENT.md` |
| 4. Assessment criteria | `docs/CURRICULUM.md`, "Assessment criteria" section |
| 5. Project catalog | `content/projects/` (8 projects); table in `docs/CURRICULUM.md` |
| 6. Initial coding challenge bank | 5 written in `content/challenges/` + planned list in `docs/CURRICULUM.md` |
| 7. Persistence strategy | `docs/ARCHITECTURE.md`, "Data model" and "Backup" |
| 8. Quality criteria | Below |

## Skills matrix

| Skill | Stages and modules | Prerequisites | Exercises and assessment | Project | Official resources | Observable outcome |
| --- | --- | --- | --- | --- | --- | --- |
| Computational thinking | S1: M1–M3 | None | Algorithm design (H), error classification (A) | — | Swift Book, Xcode | Writes precise algorithms with edge cases |
| Swift essentials | S2: M4–M8 | M3 | Prediction (B), fill-in (C), find-errors (D), solve (E) | P1 | Swift Book | Correct console programs |
| Modeling and abstraction | S3: M9–M13 | M8 | Refactor (G), explain (F) | P1 | Swift Book, Swift Evolution | Picks struct/class/enum, designs with protocols, avoids cycles |
| Software engineering | S4: M14 | M13 | Code review, design (H) | P2 | Swift Package Manager | Works with Git, packages and PRs |
| Algorithms | S5: M15–M20 | M7, M8, M10 | Challenges with Swift tests | P2 | — | Solves mediums and defends their complexity |
| iOS platform | S6: M21 | M14 | Comprehension and design | P3 | UIKit, TN3187 | Explains the app and scene life cycle |
| UIKit | S7: M22–M27 | M21 | Solve and debug in Xcode | P3, P4 | UIKit, HIG | Builds and maintains UIKit apps |
| Concurrency | S8: M28–M29 | M26, M13 | Find data race errors, refactor to async/await | P4, P7 | Swift Book (Concurrency), Migration Guide | Data-race-free code in Swift 6 |
| Data, architecture, testing | S9: M30–M33 | M29 | Layer design, tests with test doubles | P4 | URLSession, SwiftData, Swift Testing | Testable data layer |
| SwiftUI | S10: M34–M39 | M27, M29 | Where state lives, value-based navigation | P5 | SwiftUI, Observation | SwiftUI apps with correct state |
| Interoperability | S11: M40 | M39 | Integration | P6 | SwiftUI, UIKit | Hybrid app without leaks |
| Quality and security | S12: M41–M43 | M33, M31, M40 | Quality checklist, MASVS | P7 | OWASP MASVS/MASTG, Keychain, Review Guidelines | App ready for production and audit |
| Interviews | S14: M46–M48 | M20, M42, M43 | Mock interviews, follow-ups, system design | P8 | — | Defends decisions under follow-up questions |
| Professional practice | S15: M49 | M48 | Capstone project and review | P8 | — | Documented, defended delivery |

Stage 13 (system technologies) is optional and isn't a prerequisite for the main path.

## Gap review

- Between fundamentals and advanced: covered by M13 (memory) before UIKit, M21 (how an app works) before UIKit, and M28 (threads, GCD, concurrency concepts) before Swift Concurrency.
- Adjusted order: concurrency (S8) before networking (S9), because networking uses `async/await`.
- Added on request: Module 42, Secure iOS development, and the "Security" interview category.

## Content quality criteria

- Every lesson: objectives, valid prerequisites, at least one exercise with an explained solution, a "What you should be able to do now" section with observable skills, verified resources.
- Every concept: a plain definition, a technical explanation, a minimal example explained line by line, common mistakes.
- Code with an honest `codeStatus`; prediction outputs verified.
- Every challenge: statement, constraints, edge cases, questions for the interviewer, hints, naive and optimized solutions, explanation, complexity, Swift tests, common mistakes, follow-ups, a variation and a rubric.
- No videos, no filler, no duplicate questions.

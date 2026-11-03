# iOS Engineering Academy

A personal academy for learning iOS development from zero to a professional level and preparing for technical interviews. The course is written in English.

Site: https://arzaluz-chris.github.io/iOS-Engineering-Academy/

There's no backend and no accounts. Progress, notes, code drafts and spaced review are stored in the browser (IndexedDB) and backed up by exporting and importing a validated JSON file.

## What's included

- **Curriculum:** 15 stages and 49 modules, from programming fundamentals to mobile system design, with UIKit and SwiftUI as full stages and a secure development module (OWASP MASVS). The map is in [`content/curriculum.yaml`](content/curriculum.yaml).
- **Lessons** with objectives, prerequisites, terminology, explanation, common mistakes, exercises and a "What you should be able to do now" section.
- **Eight exercise formats** (A–H). Structured-answer formats are graded automatically; code and design formats are self-assessed against a rubric. No Swift code is ever marked correct by comparing text.
- **Coding challenges** with hints and sections revealed one at a time, three practice modes (guided, independent, mock interview with an optional timer) and reference solutions in Swift with real tests.
- **Interviews:** a question bank by category with a model answer, key points and follow-ups; mock interviews and results by category.
- **Spaced review** with FSRS (ts-fsrs), fed by concepts from completed lessons and by misses.
- **Projects:** eight cumulative projects with milestones and acceptance criteria.
- Accent-insensitive global search, notes, bookmarks, light and dark mode, responsive layout.

The actual state of the content (what's written and what's missing) is in [`docs/STATUS.md`](docs/STATUS.md).

## Running locally

Requirements: Node.js 22 or later. For the Swift tests, Xcode 16 or later (or a Swift 6 toolchain).

```bash
npm install
npm run dev          # development server
npm run validate     # validate content (schema and integrity)
npm test             # web tests (Vitest)
npm run build        # validation + types + build into dist/
npm run preview      # serve dist/
npm run check-links  # check resource links (needs network)
```

Tests for the Swift solutions:

```bash
cd swift
swift test                        # all of them
swift test --filter TwoSumTests   # one challenge
```

## Continuous integration

- `.github/workflows/deploy.yml` ("Web · validate, test and deploy"): validates content, types and tests, builds and publishes to GitHub Pages (push to `main`).
- `.github/workflows/swift.yml` ("Swift · challenge tests"): runs `swift test` on macOS when `swift/` changes.
- `.github/workflows/links.yml`: weekly link check.

GitHub Pages must be set to **Settings → Pages → Source: GitHub Actions**.

## Documentation

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md): stack, decisions, data model, persistence and tests.
- [`docs/CONTENT.md`](docs/CONTENT.md): how to write lessons, exercises, challenges, questions and projects.
- [`docs/CURRICULUM.md`](docs/CURRICULUM.md): map, prerequisite sequence and assessment criteria.
- [`docs/RESEARCH.md`](docs/RESEARCH.md): sources, current versions and researched technical decisions.
- [`docs/STATUS.md`](docs/STATUS.md): production progress, open acceptance criteria and next step.
- [`docs/phases/`](docs/phases/README.md): the report for each phase (audit, full research, design, build, content, testing, audit).
- [`docs/ESPECIFICACION.md`](docs/ESPECIFICACION.md): the original project specification (in Spanish).

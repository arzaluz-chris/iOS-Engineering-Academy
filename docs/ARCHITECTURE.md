# Architecture

## Constraints that shape it

- It's published on **GitHub Pages**: a 100% static site, no server, no route rewriting.
- One user; no accounts or backend. Progress lives in the browser.
- The browser **can't compile Swift** (see `RESEARCH.md`): code is written here and run in Xcode or with `swift test`.
- Content has to be able to grow without touching the app.

## Stack

| Piece | Choice | Why |
| --- | --- | --- |
| Build | Vite 8 | Static site; `import.meta.glob` loads content as text at build time. |
| UI | React 19 + strict TypeScript | Reusable components and end-to-end typing. |
| Routing | Custom hash router (`src/router.ts`, ~40 lines) | GitHub Pages doesn't rewrite routes; with `#/...` no reload ever returns a 404. Saves a dependency. |
| Content schema | Zod 4 | One schema for the browser, the validation script and the tests. |
| Content | Markdown with YAML frontmatter; exercises in ````` ````exercise ````` blocks | Written as text, reviewed in diffs, no CMS needed. |
| Markdown | marked + highlight.js (Swift, bash, JSON) | Client-side rendering with highlighting and custom callouts (`> [!error]`). |
| Editor | CodeMirror 6 with the Swift mode from `@codemirror/legacy-modes`, loaded on demand | Lightweight and accessible; only downloaded on pages that have an editor. |
| Persistence | IndexedDB with Dexie 4; `localStorage` only for the theme | Handles the volume of attempts and drafts; indexed queries; transactions for import. |
| Search | MiniSearch, in-memory index built on first use | Prefix, fuzzy and accent-insensitive search over all content. |
| Spaced review | ts-fsrs 6, **FSRS-7** model pinned explicitly | More accurate than SM-2; the full history (`revlog`) is kept so cards can be rescheduled if the model changes. |
| Typography | IBM Plex Sans, IBM Plex Mono and Source Serif 4, bundled | Works offline; serif for long-form reading. |
| Tests | Vitest + Testing Library + fake-indexeddb; Swift Testing for the challenges | See "Tests". |

Next.js and Astro were ruled out: their strengths (SSR, per-route pages) don't help here, and nearly all the interactivity is client-side.

## File layout

```
content/                 The course (data, no UI code)
  curriculum.yaml        Stages and modules with objectives, topics and prerequisites
  resources.yaml         Registry of external links with verification status
  lessons/mNN/*.md       Lessons, each with its exercises embedded
  challenges/*.md        Challenges; code lives in swift/
  interview/*.yaml       Interview questions by category
  projects/*.md          Projects with milestones
swift/                   Swift package with the challenge solutions and tests
src/
  content/               schema.ts, parse.ts (pure), validate.ts (pure), index.ts (browser loading)
  db/                    db.ts (Dexie), actions.ts, backup.ts, stats.ts
  srs/                   scheduler.ts (FSRS)
  search/                search index
  exercises/             grading (grade.ts) and the exercise component
  components/            Markdown, editor, shared UI
  pages/                 one page per section
scripts/                 validate-content.ts, check-links.ts, load-content.ts
tests/                   Vitest tests
```

`parse.ts` and `validate.ts` depend on neither the browser nor Node: the browser hands them content through `import.meta.glob`, and the scripts and tests through `fs` (`scripts/load-content.ts`). That way the validation that runs in CI is exactly the logic the app uses.

## Data model

Content (read-only, see `src/content/schema.ts`): `Stage`, `Module`, `Lesson` (with Markdown and exercise `segments` and review `cards`), `Exercise` (a union discriminated by `type`), `Challenge`, `InterviewQuestion`, `Project`, `Resource`. IDs are kebab-case and unique across the whole course, because progress is stored by ID.

Progress (IndexedDB, `src/db/db.ts`):

| Table | Contents |
| --- | --- |
| `lessons` | status per lesson (in progress, completed) and the last section viewed |
| `attempts` | every attempt at an exercise, challenge or question, with result, score and whether it was auto-graded or self-assessed |
| `drafts` | code drafts per exercise or challenge |
| `notes`, `bookmarks` | notes and bookmarks attached to lessons, exercises, challenges, questions, projects or resources |
| `challenges`, `questions`, `projects` | status of challenges, questions and project milestones |
| `cards`, `revlog` | FSRS cards and their full history |
| `activity` | log for "Recent activity" |

Domain rules:

- Opening a lesson marks it **in progress**, never completed.
- To complete a lesson you have to **attempt** all its exercises. Once it's completed, its concepts enter review.
- A lesson is **mastered** if it's completed and the latest attempt at each exercise is correct.
- Any attempt that isn't correct adds the item to review (or makes it due again today).
- Review prioritizes topics marked as hard, then misses, then due date.
- Study time is **not** tracked: there's no reliable way to measure it.

## Backup

`src/db/backup.ts` exports every table to a JSON file with `format` and `version`. Import validates the whole file with Zod before touching the database and replaces everything inside one transaction. An invalid file changes nothing. GitHub Pages shares the `arzaluz-chris.github.io` origin across repositories; the database is named `iea:ios-engineering-academy` so it won't collide with other projects.

## Exercises and running Swift

- Types A to D (comprehension, prediction, fill-in, find-errors): structured answer, **auto-graded**.
- Types E to H (solve, explain, refactor, design): editor plus a **self-assessment rubric**. The UI says which applies on every exercise.
- Solutions stay hidden until the learner asks for them; if there's no previous attempt, the app asks for confirmation.
- Challenge solutions are shown from the same files in `swift/` that CI compiles and tests, so what's published matches what was tested.

## Tests

- `npm run validate`: schema and integrity (duplicate IDs, missing or out-of-order prerequisites, missing resources, exercises without a solution, blanks without an answer, single choice with several correct options, unclosed code blocks, links to videos, duplicate URLs, challenges without Swift files or without `@Test`).
- `npm test`: real content, the validator with negative cases, grading, persistence, review, backup and invalid import, search, the router, lesson mastery and components.
- `swift test`: reference solutions.
- `npm run check-links`: resource links (weekly in CI).

## Recorded decisions

1. **No backend.** The only reason for one would be running Swift on a server, and the cost and security risk are out of proportion for personal use.
2. **Hash routing** instead of a fallback `404.html`: simpler and no flicker.
3. **Content in Markdown + YAML** instead of TypeScript: Swift code inside lessons doesn't need escaping.
4. **FSRS-7 pinned** and a full `revlog` for future migrations.
5. **Concurrency before networking.** The stage order puts "Concurrency and memory" (8) before "Data, architecture and testing" (9) because networking with `async/await` depends on it. The original spec listed networking first; teaching progression won.

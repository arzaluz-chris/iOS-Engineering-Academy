# Phase 4. Technical design

The full document is `docs/ARCHITECTURE.md`. This file records the decisions made in this phase and the reasons for them.

| Topic | Decision |
| --- | --- |
| Stack | Vite 8, React 19, strict TypeScript (`noUncheckedIndexedAccess`) |
| Architecture | Content as data (`content/`), pure parser and validator (`src/content/`), progress layer (`src/db/`), one page per section (`src/pages/`) |
| Components | Markdown with callouts and code copying, deferred CodeMirror editor, exercises by type, rubrics, notes, bookmarks |
| Data model | Discriminated union of exercises in Zod; global kebab-case IDs; 11 tables in IndexedDB |
| Persistence | Dexie 4; `localStorage` only for the theme; validated, transactional JSON backup |
| Navigation | Custom hash routing, compatible with GitHub Pages and with `base: './'` |
| Search | In-memory MiniSearch, accent-insensitive, prefix and fuzzy |
| Exercises | A–D auto-graded, E–H by rubric; Swift runs outside the browser |
| Review | ts-fsrs 6, FSRS-7 pinned, full history |
| Testing | Vitest (jsdom, fake-indexeddb, Testing Library), content validator, Swift Testing on macOS, link checking |
| CI/CD | `deploy.yml` (Linux), `swift.yml` (macOS), `links.yml` (weekly), monthly Dependabot |

## Alternatives ruled out

| Alternative | Why not |
| --- | --- |
| Own backend to run Swift | Cost, maintenance and security risk out of proportion for personal use |
| Next.js | Its strengths (SSR, server routes) don't apply to a static site on Pages |
| Astro (recommended by the research) | Major version newer than the one researched; nearly all the app is interactive |
| react-router | A hash router of about 40 lines is enough |
| Content in TypeScript | Would require escaping Swift code blocks |
| SM-2 | Less accurate than FSRS |
| Compiling Swift to Wasm in the browser | No maintained option compiles user code on the client |

## Technical risks

- **Main bundle size** (about 920 kB uncompressed, 285 kB gzip). Mitigated by lazy-loading the editor. It can be split further per page if the content grows.
- **Shared origin on GitHub Pages:** the database has its own name.
- **Swift version in CI:** the runner uses whatever Xcode version GitHub preinstalls; it may lag behind the latest release.

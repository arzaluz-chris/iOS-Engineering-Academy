# Phase 5. Incremental build

The minimum working version the spec asked for, and its status:

| Requirement | Status | Where |
| --- | --- | --- |
| Curriculum navigation | Done | `src/pages/Curriculum.tsx` |
| One complete lesson | Done (4 lessons) | `content/lessons/` |
| One exercise of each format | Done (A–H in `m04-l01`) | `src/exercises/ExerciseBlock.tsx` |
| Assessment | Done: automatic A–D, rubric E–H, challenges and interviews | `src/exercises/grade.ts`, `src/components/ui.tsx` |
| Persistent progress | Done | `src/db/` |
| Search | Done | `src/search/`, `src/pages/Search.tsx` |
| Notes and bookmarks | Done | `src/components/ui.tsx`, `src/pages/Notes.tsx` |
| Dashboard with real data | Done; study time isn't measured, and the dashboard says so | `src/pages/Dashboard.tsx` |
| Responsive layout, light and dark mode | Done | `src/styles.css` |
| Challenges with progressive reveal and practice modes | Done | `src/pages/Challenges.tsx` |
| Interview simulator | Done | `src/pages/Interview.tsx` |
| Spaced review | Done | `src/srs/`, `src/pages/Review.tsx` |
| Export and import | Done | `src/db/backup.ts`, `src/pages/Settings.tsx` |
| Deployment | Done | `.github/workflows/deploy.yml` |

## Visual design

Concept: an engineering lab notebook. IBM Plex Sans for the UI, Source Serif 4 for lesson prose, IBM Plex Mono for code. A cool palette (blue-gray background, teal accent) with status colors for correct, warning and error. The one strong visual gesture is common mistakes, presented as compiler diagnostics. The curriculum is shown as a numbered path because it's a real sequence. Fonts are bundled so the site works offline.

This was the original design. On 3 Nov 2026 the site was redesigned after swift.org's visual language (see `docs/STATUS.md`).

## History

| Commit | Contents |
| --- | --- |
| `b22ac10` | Base platform, initial content, CI |
| `446dde8` | Challenges marked as tested after `swift test` on macOS |
| `08e49a5` | Resources marked as verified after `links.yml` |

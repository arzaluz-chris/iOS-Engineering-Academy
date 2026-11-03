# Instructions for development sessions

A personal iOS academy for Christian. Static site on GitHub Pages, no backend.

**Language: everything is in English** — content, UI, code identifiers, comments, tests and docs. Write natural, direct American English that doesn't read as AI-generated; the voice rules are in `docs/CONTENT.md`. The only Spanish file is `docs/ESPECIFICACION.md`, the owner's original spec, kept as written.

**Design: the site follows swift.org's visual language** (system font, warm peach hero gradient, orange gradient pill buttons, 22px cards, translucent sticky nav, indigo footer, navy dark mode, Xcode-style syntax colors). Keep new UI consistent with `src/styles.css`. Don't copy Apple's or the Swift project's logos or present the site as swift.org.

## Before you start

1. Read `docs/STATUS.md` (what's done and what's next), `docs/CONTENT.md` (content format and voice) and, if you need background, `docs/ESPECIFICACION.md` and `docs/phases/`.
2. Content lives in `content/`, Swift solutions and snippet tests in `swift/`, the app in `src/`.

## Rules

- Technical accuracy first. Don't invent versions, signatures or API behavior; if something wasn't verified, say so.
- `codeStatus: tested` only if the code was compiled and run (the `LessonSnippetsTests` target does this). Prediction outputs must be verified by those tests.
- Swift code is never graded by comparing text.
- No videos in resources. Link specific API documentation.
- Don't reveal solutions before the learner asks for them.
- Never change existing ids (lessons, exercises, cards, modules, challenges, questions, projects): saved progress is keyed on them.
- Don't mark something done if it's partial; update `docs/STATUS.md` when you close each batch.

## Commands

```bash
npm run validate   # content schema and integrity
npm test           # web tests
npm run build      # validation + types + build
cd swift && swift test
```

Without Xcode, run Swift in a container: `docker run --rm -v "$PWD":/w -w /w/swift swift:6.3 swift test` (start the daemon with `dockerd` if it isn't running).

Run `npm run validate && npm test` before every commit.

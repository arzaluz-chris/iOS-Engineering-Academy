import { useLiveQuery } from 'dexie-react-hooks'
import { useEffect, useMemo } from 'react'
import { Markdown, slugify } from '../components/Markdown'
import { Badge, BookmarkButton, CODE_STATUS_LABEL, Empty, LEVEL_LABEL, NotesPanel, PageHeader } from '../components/ui'
import { getLesson, getModule, getResource, neighbors } from '../content'
import { completeLesson, reopenLesson, setLessonAnchor, startLesson } from '../db/actions'
import { db } from '../db/db'
import { latestByRef, lessonMastery } from '../db/stats'
import { ExerciseBlock } from '../exercises/ExerciseBlock'

const RESOURCE_KIND = { official: 'Official documentation', tutorial: 'Tutorial', article: 'Article', reference: 'Reference' } as const

export function LessonPage({ id, focus }: { id: string; focus?: string }) {
  const lesson = getLesson(id)
  const progress = useLiveQuery(() => db.lessons.get(id), [id])
  const attempts = useLiveQuery(() => db.attempts.where('kind').equals('ejercicio').toArray(), []) ?? []
  const prereqProgress = useLiveQuery(() => db.lessons.bulkGet(lesson?.prerequisites ?? []), [id]) ?? []

  useEffect(() => {
    if (lesson) void startLesson(lesson.id, lesson.title)
  }, [lesson])

  // Jump to a linked exercise (#/lesson/x/exercise) or resume the last section.
  useEffect(() => {
    if (!lesson) return
    const target = focus || undefined
    const t = setTimeout(() => {
      if (target) document.getElementById(target)?.scrollIntoView({ block: 'start' })
    }, 60)
    return () => clearTimeout(t)
  }, [lesson, focus])

  // Remember the last visible section so the learner can pick up where they left off.
  useEffect(() => {
    if (!lesson || typeof IntersectionObserver === 'undefined') return
    const headings = [...document.querySelectorAll<HTMLElement>('.lesson-body h2[id]')]
    const obs = new IntersectionObserver(
      (entries) => {
        const visible = entries.find((e) => e.isIntersecting)
        if (visible) void setLessonAnchor(lesson.id, visible.target.id)
      },
      { rootMargin: '0px 0px -70% 0px' },
    )
    headings.forEach((h) => obs.observe(h))
    return () => obs.disconnect()
  }, [lesson])

  const toc = useMemo(
    () =>
      lesson?.segments
        .flatMap((s) => (s.kind === 'md' ? [...s.text.matchAll(/^## (.+)$/gm)].map((m) => m[1] ?? '') : []))
        .map((h) => ({ text: h.replace(/`/g, ''), id: slugify(h.replace(/`/g, '')) })) ?? [],
    [lesson],
  )

  if (!lesson) return <Empty title="Lesson not found"><a href="#/curriculum">Back to the curriculum</a></Empty>

  const mod = getModule(lesson.module)
  const latest = latestByRef(attempts)
  const mastery = lessonMastery(lesson, latest)
  const allAttempted = mastery.attempted === mastery.total
  const { prev, next } = neighbors(lesson.id)
  let exerciseCount = 0

  return (
    <div className="page lesson-page">
      <div className="lesson-layout">
        <article className="lesson">
          <PageHeader
            kicker={
              <>
                <a href="#/curriculum">Curriculum</a> / <a href={`#/module/${lesson.module}`}>Module {mod?.number}. {mod?.title}</a> / Lesson {lesson.order}
              </>
            }
            title={lesson.title}
          >
            <p>{lesson.description}</p>
          </PageHeader>

          <div className="lesson-meta row">
            <Badge>{LEVEL_LABEL[lesson.level]}</Badge>
            <Badge>About {lesson.minutes} min</Badge>
            {lesson.swiftVersion && <Badge>Swift {lesson.swiftVersion}</Badge>}
            <Badge tone={lesson.codeStatus === 'tested' ? 'ok' : 'neutral'}>{CODE_STATUS_LABEL[lesson.codeStatus]}</Badge>
            {progress?.status === 'completada' && <Badge tone={mastery.mastered ? 'ok' : 'accent'}>{mastery.mastered ? 'Mastered' : 'Completed'}</Badge>}
            <BookmarkButton type="leccion" id={lesson.id} />
          </div>

          <section className="lesson-intro" aria-label="Before you start">
            <div>
              <h2 className="section-title">Goals</h2>
              <ul>
                {lesson.objectives.map((o) => (
                  <li key={o}>{o}</li>
                ))}
              </ul>
            </div>
            <div>
              <h2 className="section-title">Prerequisites</h2>
              {lesson.prerequisites.length === 0 ? (
                <p className="muted">None. This lesson starts from zero.</p>
              ) : (
                <ul>
                  {lesson.prerequisites.map((p, i) => {
                    const pl = getLesson(p)
                    const done = prereqProgress[i]?.status === 'completada'
                    return (
                      <li key={p}>
                        <a href={`#/lesson/${p}`}>{pl?.title ?? p}</a> {done ? <Badge tone="ok">Completed</Badge> : <Badge tone="warn">Not yet</Badge>}
                      </li>
                    )
                  })}
                </ul>
              )}
            </div>
          </section>

          {lesson.terms.length > 0 && (
            <section aria-labelledby="terms">
              <h2 id="terms" className="section-title">Terms</h2>
              <dl className="terms">
                {lesson.terms.map((t) => (
                  <div key={t.term}>
                    <dt>{t.term}</dt>
                    <dd>{t.definition}</dd>
                  </div>
                ))}
              </dl>
            </section>
          )}

          <div className="lesson-body">
            {lesson.segments.map((s, i) => {
              if (s.kind === 'md') return <Markdown key={i} text={s.text} />
              exerciseCount++
              return <ExerciseBlock key={s.exercise.id} exercise={s.exercise} label={`${lesson.title} · exercise ${exerciseCount}`} />
            })}
          </div>

          <section className="mastery" aria-labelledby="mastery">
            <h2 id="mastery">What you should be able to do now</h2>
            <p className="muted">Check each one without looking back at the lesson. If one is shaky, reread that section before moving on.</p>
            <ul className="checklist">
              {lesson.mastery.map((m) => (
                <li key={m}>{m}</li>
              ))}
            </ul>
          </section>

          {lesson.resources.length > 0 && (
            <section aria-labelledby="resources">
              <h2 id="resources" className="section-title">Go deeper</h2>
              <ul className="resources">
                {lesson.resources.map((rid) => {
                  const r = getResource(rid)
                  if (!r) return null
                  return (
                    <li key={rid}>
                      <a href={r.url} target="_blank" rel="noopener noreferrer">
                        {r.title}
                      </a>
                      <span className="muted small">
                        {' '}
                        {r.source} · {RESOURCE_KIND[r.kind]}
                        {r.status === 'verified' && r.verifiedAt ? ` · link checked ${r.verifiedAt}` : ' · link not checked yet'}
                      </span>
                      <p>{r.why}</p>
                    </li>
                  )
                })}
              </ul>
            </section>
          )}

          <section className="complete" aria-labelledby="complete">
            <h2 id="complete" className="section-title">Finish the lesson</h2>
            <p>
              Exercises tried: {mastery.attempted}/{mastery.total}. Right on the latest attempt: {mastery.correct}/{mastery.total}.
            </p>
            {progress?.status === 'completada' ? (
              <div className="row">
                <span>Completed{progress.completedAt ? ` on ${new Date(progress.completedAt).toLocaleDateString('en-US', { dateStyle: 'long' })}` : ''}.</span>
                <button type="button" className="btn btn-quiet" onClick={() => void reopenLesson(lesson.id)}>
                  Mark as in progress
                </button>
              </div>
            ) : (
              <>
                <button type="button" className="btn btn-primary" disabled={!allAttempted} onClick={() => void completeLesson(lesson.id, lesson.title, lesson.cards.map((c) => c.id))}>
                  Mark lesson as complete
                </button>
                {!allAttempted && <p className="muted small">Try every exercise before you finish. They don’t all have to be right; the ones you miss go into your review queue.</p>}
                {lesson.cards.length > 0 && <p className="muted small">Finishing adds {lesson.cards.length} key concepts to your spaced review.</p>}
              </>
            )}
          </section>

          <NotesPanel type="leccion" id={lesson.id} />

          <nav className="pager" aria-label="Lessons">
            {prev ? (
              <a href={`#/lesson/${prev.id}`} rel="prev">
                <span className="muted small">Previous</span>
                {prev.title}
              </a>
            ) : (
              <span />
            )}
            {next && (
              <a href={`#/lesson/${next.id}`} rel="next" className="pager-next">
                <span className="muted small">Next</span>
                {next.title}
              </a>
            )}
          </nav>
        </article>

        {toc.length > 2 && (
          <nav className="toc" aria-label="On this page">
            <p className="nav-heading">On this page</p>
            <ol>
              {toc.map((t) => (
                <li key={t.id}>
                  <a href={`#/lesson/${lesson.id}/${t.id}`} aria-current={progress?.lastAnchor === t.id ? 'location' : undefined}>
                    {t.text}
                  </a>
                </li>
              ))}
              <li>
                <a href={`#/lesson/${lesson.id}/mastery`}>What you should be able to do now</a>
              </li>
            </ol>
          </nav>
        )}
      </div>
    </div>
  )
}

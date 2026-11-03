import { useLiveQuery } from 'dexie-react-hooks'
import { content, getModule, getStage, lessonsOf, modulesOf } from '../content'
import { db } from '../db/db'
import { latestByRef, lessonMastery } from '../db/stats'
import { Badge, Empty, LEVEL_LABEL, PageHeader } from '../components/ui'

function useLessonState() {
  return useLiveQuery(async () => {
    const [progress, attempts] = await Promise.all([db.lessons.toArray(), db.attempts.toArray()])
    return { progress: new Map(progress.map((p) => [p.lessonId, p])), latest: latestByRef(attempts) }
  })
}

export function CurriculumPage() {
  const state = useLessonState()
  const written = content.lessons.length
  return (
    <div className="page">
      <PageHeader kicker="The path" title="Curriculum">
        <p>
          {content.stages.length} stages and {content.modules.length} modules, each building on the last. {written} lessons are written so far. Modules without lessons yet show their plan
          and are marked as coming soon.
        </p>
      </PageHeader>
      <ol className="route">
        {content.stages.map((s) => (
          <li key={s.id} id={s.id} className="route-stage">
            <div className="route-marker" aria-hidden="true">
              {s.number}
            </div>
            <div className="route-body">
              <h2>{s.title}</h2>
              <p>{s.summary}</p>
              <p className="muted small">By the end: {s.outcome}</p>
              <ul className="module-list">
                {modulesOf(s.id).map((m) => {
                  const ls = lessonsOf(m.id)
                  const done = ls.filter((l) => state?.progress.get(l.id)?.status === 'completada').length
                  return (
                    <li key={m.id}>
                      <a href={`#/module/${m.id}`} className="module-link">
                        <span className="module-num">Module {m.number}</span>
                        <span className="module-title">{m.title}</span>
                        <span className="module-meta">
                          {ls.length === 0 ? <Badge>Coming soon</Badge> : <span>{done}/{ls.length} lessons</span>}
                          {m.optional && <Badge>Optional track</Badge>}
                        </span>
                      </a>
                    </li>
                  )
                })}
              </ul>
            </div>
          </li>
        ))}
      </ol>
    </div>
  )
}

export function ModulePage({ id }: { id: string }) {
  const m = getModule(id)
  const state = useLessonState()
  if (!m) return <Empty title="Module not found"><a href="#/curriculum">Back to the curriculum</a></Empty>
  const stage = getStage(m.stage)
  const ls = lessonsOf(m.id)
  return (
    <div className="page">
      <PageHeader kicker={<><a href="#/curriculum">Curriculum</a> / Stage {stage?.number}. {stage?.title}</>} title={`Module ${m.number}. ${m.title}`}>
        <p>{m.summary}</p>
      </PageHeader>

      {m.prerequisites.length > 0 && (
        <p className="prereq">
          Requires:{' '}
          {m.prerequisites.map((p, i) => {
            const pm = getModule(p)
            return (
              <span key={p}>
                {i > 0 && ', '}
                <a href={`#/module/${p}`}>
                  Module {pm?.number}. {pm?.title}
                </a>
              </span>
            )
          })}
        </p>
      )}

      <div className="two-col">
        <section>
          <h2 className="section-title">Module goals</h2>
          <ul>
            {m.objectives.map((o) => (
              <li key={o}>{o}</li>
            ))}
          </ul>
        </section>
        <section>
          <h2 className="section-title">Topics</h2>
          <ul className="topics">
            {m.topics.map((t) => (
              <li key={t}>{t}</li>
            ))}
          </ul>
        </section>
      </div>

      <section>
        <h2 className="section-title">Lessons</h2>
        {ls.length === 0 ? (
          <Empty title="No lessons in this module yet">
            The plan is above. Lessons are written in batches, one module at a time, and tested before they go up. <code>docs/STATUS.md</code> in the repository has the
            production order.
          </Empty>
        ) : (
          <ol className="lesson-list">
            {ls.map((l) => {
              const p = state?.progress.get(l.id)
              const mastery = state ? lessonMastery(l, state.latest) : undefined
              return (
                <li key={l.id}>
                  <a href={`#/lesson/${l.id}`}>
                    <span className="lesson-order">{l.order}</span>
                    <span className="lesson-main">
                      <span className="lesson-title">{l.title}</span>
                      <span className="muted small">
                        {LEVEL_LABEL[l.level]} · {l.minutes} min · {l.exercises.length} exercises
                      </span>
                    </span>
                    <span className="lesson-state">
                      {p?.status === 'completada' ? (
                        <Badge tone={mastery?.mastered ? 'ok' : 'accent'}>{mastery?.mastered ? 'Mastered' : 'Completed'}</Badge>
                      ) : p ? (
                        <Badge tone="warn">In progress</Badge>
                      ) : null}
                    </span>
                  </a>
                </li>
              )
            })}
          </ol>
        )}
      </section>
    </div>
  )
}

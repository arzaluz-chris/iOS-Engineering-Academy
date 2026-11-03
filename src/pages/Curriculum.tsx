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
      <PageHeader title="Currículo">
        <p>
          {content.stages.length} etapas y {content.modules.length} módulos, en orden acumulativo. Hay {written} lecciones escritas por ahora; los módulos sin lecciones muestran su plan de estudio
          y se marcan como en preparación.
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
              <p className="muted small">Al terminar: {s.outcome}</p>
              <ul className="module-list">
                {modulesOf(s.id).map((m) => {
                  const ls = lessonsOf(m.id)
                  const done = ls.filter((l) => state?.progress.get(l.id)?.status === 'completada').length
                  return (
                    <li key={m.id}>
                      <a href={`#/modulo/${m.id}`} className="module-link">
                        <span className="module-num">Módulo {m.number}</span>
                        <span className="module-title">{m.title}</span>
                        <span className="module-meta">
                          {ls.length === 0 ? <Badge>En preparación</Badge> : <span>{done}/{ls.length} lecciones</span>}
                          {m.optional && <Badge>Ruta opcional</Badge>}
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
  if (!m) return <Empty title="Módulo no encontrado"><a href="#/curriculo">Volver al currículo</a></Empty>
  const stage = getStage(m.stage)
  const ls = lessonsOf(m.id)
  return (
    <div className="page">
      <PageHeader kicker={<><a href="#/curriculo">Currículo</a> / Etapa {stage?.number}. {stage?.title}</>} title={`Módulo ${m.number}. ${m.title}`}>
        <p>{m.summary}</p>
      </PageHeader>

      {m.prerequisites.length > 0 && (
        <p className="prereq">
          Requiere:{' '}
          {m.prerequisites.map((p, i) => {
            const pm = getModule(p)
            return (
              <span key={p}>
                {i > 0 && ', '}
                <a href={`#/modulo/${p}`}>
                  Módulo {pm?.number}. {pm?.title}
                </a>
              </span>
            )
          })}
        </p>
      )}

      <div className="two-col">
        <section>
          <h2 className="section-title">Objetivos del módulo</h2>
          <ul>
            {m.objectives.map((o) => (
              <li key={o}>{o}</li>
            ))}
          </ul>
        </section>
        <section>
          <h2 className="section-title">Temas</h2>
          <ul className="topics">
            {m.topics.map((t) => (
              <li key={t}>{t}</li>
            ))}
          </ul>
        </section>
      </div>

      <section>
        <h2 className="section-title">Lecciones</h2>
        {ls.length === 0 ? (
          <Empty title="Este módulo todavía no tiene lecciones">
            Su plan está definido arriba. Las lecciones se escriben por lotes, módulo por módulo, y se validan antes de publicarse. Consulta <code>docs/ESTADO.md</code> en el repositorio para
            ver el orden de producción.
          </Empty>
        ) : (
          <ol className="lesson-list">
            {ls.map((l) => {
              const p = state?.progress.get(l.id)
              const mastery = state ? lessonMastery(l, state.latest) : undefined
              return (
                <li key={l.id}>
                  <a href={`#/leccion/${l.id}`}>
                    <span className="lesson-order">{l.order}</span>
                    <span className="lesson-main">
                      <span className="lesson-title">{l.title}</span>
                      <span className="muted small">
                        {LEVEL_LABEL[l.level]} · {l.minutes} min · {l.exercises.length} ejercicios
                      </span>
                    </span>
                    <span className="lesson-state">
                      {p?.status === 'completada' ? (
                        <Badge tone={mastery?.mastered ? 'ok' : 'accent'}>{mastery?.mastered ? 'Dominada' : 'Completada'}</Badge>
                      ) : p ? (
                        <Badge tone="warn">En curso</Badge>
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

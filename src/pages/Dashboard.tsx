import { useLiveQuery } from 'dexie-react-hooks'
import { content, getChallenge, getExercise, getLesson, getModule, getProject, lessonSequence } from '../content'
import { db } from '../db/db'
import { currentLesson, overview } from '../db/stats'
import { Empty, Meter } from '../components/ui'
import { TYPE_LABEL } from '../exercises/ExerciseBlock'

const ACTIVITY_LABEL: Record<string, string> = {
  'leccion-iniciada': 'Iniciaste la lección',
  'leccion-completada': 'Completaste la lección',
  ejercicio: 'Intento en ejercicio',
  reto: 'Intento en reto',
  entrevista: 'Pregunta de entrevista',
  repaso: 'Repaso',
  nota: 'Nota',
  proyecto: 'Proyecto',
  importacion: 'Importación de respaldo',
}

export function Dashboard() {
  const data = useLiveQuery(async () => {
    const nowIso = new Date().toISOString()
    const [progress, attempts, challenges, projects, activity, dueCards, difficult] = await Promise.all([
      db.lessons.toArray(),
      db.attempts.toArray(),
      db.challenges.toArray(),
      db.projects.toArray(),
      db.activity.orderBy('at').reverse().limit(8).toArray(),
      db.cards.where('dueAt').belowOrEqual(nowIso).toArray(),
      db.cards.filter((c) => c.difficult).count(),
    ])
    return { progress, attempts, challenges, projects, activity, dueCards, difficult }
  })

  if (!data) return <div className="page" aria-busy="true" />
  const o = overview(content, data.progress, data.attempts, data.challenges)
  const current = currentLesson(lessonSequence, data.progress)
  const fresh = data.progress.length === 0 && data.attempts.length === 0
  const currentModule = current ? getModule(current.module) : undefined
  const currentStatus = current ? data.progress.find((p) => p.lessonId === current.id) : undefined

  return (
    <div className="page dashboard">
      <header className="page-header">
        <h1>{fresh ? 'Empieza desde cero' : 'Tu progreso'}</h1>
        <p className="page-lede">
          {fresh
            ? 'El curso asume que nunca has programado. Cada lección se apoya solo en lo que ya aprendiste. Avanza por orden.'
            : 'Todo lo que ves aquí sale de lo que has hecho en este navegador.'}
        </p>
      </header>

      {current && (
        <section className="next-up" aria-labelledby="next-title">
          <p className="next-label">{currentStatus?.status === 'en-curso' ? 'Continúa donde te quedaste' : 'Siguiente lección'}</p>
          <h2 id="next-title">
            <a href={`#/leccion/${current.id}${currentStatus?.lastAnchor ? '' : ''}`}>{current.title}</a>
          </h2>
          <p className="muted">
            Módulo {currentModule?.number}. {currentModule?.title} · {current.minutes} min
          </p>
          <p>{current.description}</p>
          <a className="btn btn-primary" href={`#/leccion/${current.id}`}>
            {currentStatus ? 'Continuar la lección' : 'Comenzar la lección'}
          </a>
        </section>
      )}

      <div className="dash-grid">
        <section aria-labelledby="g-progress">
          <h2 id="g-progress" className="section-title">Avance general</h2>
          <dl className="figures">
            <div>
              <dt>Lecciones completadas</dt>
              <dd>
                <Meter value={o.lessonsCompleted} max={o.lessonsTotal} label="Lecciones completadas" />
              </dd>
            </div>
            <div>
              <dt>Lecciones dominadas</dt>
              <dd>
                <Meter value={o.lessonsMastered} max={o.lessonsTotal} label="Lecciones dominadas" />
                <span className="muted small">Completada y con todos sus ejercicios correctos en el último intento.</span>
              </dd>
            </div>
            <div>
              <dt>Ejercicios correctos</dt>
              <dd>
                <Meter value={o.exercisesCorrect} max={o.exercisesTotal} label="Ejercicios correctos" />
              </dd>
            </div>
            <div>
              <dt>Retos resueltos</dt>
              <dd>
                <Meter value={o.challengesSolved} max={content.challenges.length} label="Retos resueltos" />
              </dd>
            </div>
          </dl>
          <p className="muted small">El tiempo de estudio no se registra: no hay una forma fiable de medirlo sin contar tiempo con la pestaña abierta y sin estudiar.</p>
        </section>

        <section aria-labelledby="g-review">
          <h2 id="g-review" className="section-title">Por reforzar</h2>
          {data.dueCards.length === 0 && data.difficult === 0 && o.pendingExercises.length === 0 ? (
            <Empty title="Nada pendiente por ahora">Los ejercicios fallados, los retos incompletos y los conceptos de lecciones terminadas aparecerán aquí.</Empty>
          ) : (
            <ul className="plain-list">
              <li>
                <a href="#/repaso">
                  {data.dueCards.length} tarjeta{data.dueCards.length === 1 ? '' : 's'} de repaso para hoy
                </a>
                {data.difficult > 0 && <span className="muted"> · {data.difficult} marcada{data.difficult === 1 ? '' : 's'} como difícil</span>}
              </li>
              {o.pendingExercises.slice(0, 5).map((p) => {
                const ex = getExercise(p.exerciseId)
                return (
                  <li key={p.exerciseId}>
                    <a href={`#/leccion/${p.lessonId}/${p.exerciseId}`}>
                      {ex ? TYPE_LABEL[ex.exercise.type] : 'Ejercicio'} en «{getLesson(p.lessonId)?.title}»
                    </a>
                    <span className="muted"> · {p.status === 'sin-intento' ? 'sin intento' : p.status}</span>
                  </li>
                )
              })}
              {o.pendingExercises.length > 5 && (
                <li>
                  <a href="#/ejercicios?estado=pendiente">Ver los {o.pendingExercises.length} ejercicios pendientes</a>
                </li>
              )}
            </ul>
          )}
          {o.failedChallenges.length > 0 && (
            <>
              <h3 className="sub-title">Retos fallados</h3>
              <ul className="plain-list">
                {o.failedChallenges.map((id) => (
                  <li key={id}>
                    <a href={`#/reto/${id}`}>{getChallenge(id)?.title}</a>
                  </li>
                ))}
              </ul>
            </>
          )}
        </section>

        <section aria-labelledby="g-stages" className="span-2">
          <h2 id="g-stages" className="section-title">Avance por etapa</h2>
          <table className="stage-table">
            <thead>
              <tr>
                <th scope="col">Etapa</th>
                <th scope="col">Lecciones completadas</th>
                <th scope="col">Módulos con contenido</th>
              </tr>
            </thead>
            <tbody>
              {o.byStage.map((s) => (
                <tr key={s.stageId}>
                  <th scope="row">
                    <span className="stage-num">{s.number}</span> {s.title}
                  </th>
                  <td>{s.lessons ? <Meter value={s.completed} max={s.lessons} label={`Lecciones de ${s.title}`} /> : <span className="muted">En preparación</span>}</td>
                  <td>
                    {s.modulesWithContent}/{s.modules}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>

        <section aria-labelledby="g-projects">
          <h2 id="g-projects" className="section-title">Proyectos en curso</h2>
          {data.projects.length === 0 ? (
            <Empty title="Aún no inicias un proyecto">
              El primero, una aplicación de consola, se desbloquea con los módulos de fundamentos. <a href="#/proyectos">Ver los proyectos</a>.
            </Empty>
          ) : (
            <ul className="plain-list">
              {data.projects.map((p) => {
                const proj = getProject(p.projectId)
                return (
                  <li key={p.projectId}>
                    <a href={`#/proyecto/${p.projectId}`}>{proj?.title}</a>
                    <span className="muted">
                      {' '}
                      · {p.milestonesDone.length}/{proj?.milestones.length} hitos
                    </span>
                  </li>
                )
              })}
            </ul>
          )}
        </section>

        <section aria-labelledby="g-activity">
          <h2 id="g-activity" className="section-title">Actividad reciente</h2>
          {data.activity.length === 0 ? (
            <Empty title="Sin actividad todavía" />
          ) : (
            <ol className="activity">
              {data.activity.map((a) => (
                <li key={a.id}>
                  <time dateTime={a.at}>{new Date(a.at).toLocaleString('es-MX', { dateStyle: 'short', timeStyle: 'short' })}</time>
                  <span>
                    {ACTIVITY_LABEL[a.type] ?? a.type}: {a.label}
                  </span>
                </li>
              ))}
            </ol>
          )}
        </section>
      </div>
    </div>
  )
}

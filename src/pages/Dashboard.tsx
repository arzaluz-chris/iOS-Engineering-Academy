import { useLiveQuery } from 'dexie-react-hooks'
import { content, getChallenge, getExercise, getLesson, getModule, getProject, lessonSequence } from '../content'
import { db } from '../db/db'
import { currentLesson, overview } from '../db/stats'
import { EXERCISE_STATUS_LABEL, Empty, Meter } from '../components/ui'
import { TYPE_LABEL } from '../exercises/ExerciseBlock'

const ACTIVITY_LABEL: Record<string, string> = {
  'leccion-iniciada': 'Started lesson',
  'leccion-completada': 'Completed lesson',
  ejercicio: 'Exercise attempt',
  reto: 'Challenge attempt',
  entrevista: 'Interview question',
  repaso: 'Review',
  nota: 'Note',
  proyecto: 'Project',
  importacion: 'Backup import',
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

  const lessonCount = content.lessons.length
  const exerciseCount = content.lessons.reduce((n, l) => n + l.exercises.length, 0)

  return (
    <div className="dashboard">
      <section className="hero" aria-labelledby="hero-title">
        <div className="hero-inner">
          <p className="hero-kicker">iOS Engineering Academy</p>
          <h1 id="hero-title">{fresh ? 'From your first line of code to shipping iOS apps.' : 'Pick up where you left off.'}</h1>
          <p className="hero-lede">
            {fresh
              ? 'No experience assumed. Every lesson builds only on what came before, so go in order.'
              : 'Everything below comes from what you’ve done in this browser.'}
          </p>
          {current && (
            <div className="hero-cta">
              <a className="btn btn-pill" href={`#/lesson/${current.id}`}>
                {currentStatus ? 'Continue' : 'Start'}: {current.title}
              </a>
              <p className="hero-note">
                Module {currentModule?.number} · {currentModule?.title} · {current.minutes} min
              </p>
            </div>
          )}
          <p className="hero-stats">
            {lessonCount} lessons · {exerciseCount} exercises · {content.challenges.length} coding challenges · {content.questions.length} interview questions
          </p>
        </div>
      </section>

      <div className="page dash-body">
      <div className="dash-grid">
        <section aria-labelledby="g-progress">
          <h2 id="g-progress" className="section-title">Overall progress</h2>
          <dl className="figures">
            <div>
              <dt>Lessons completed</dt>
              <dd>
                <Meter value={o.lessonsCompleted} max={o.lessonsTotal} label="Lessons completed" />
              </dd>
            </div>
            <div>
              <dt>Lessons mastered</dt>
              <dd>
                <Meter value={o.lessonsMastered} max={o.lessonsTotal} label="Lessons mastered" />
                <span className="muted small">Completed, with every exercise right on the latest attempt.</span>
              </dd>
            </div>
            <div>
              <dt>Exercises correct</dt>
              <dd>
                <Meter value={o.exercisesCorrect} max={o.exercisesTotal} label="Exercises correct" />
              </dd>
            </div>
            <div>
              <dt>Challenges solved</dt>
              <dd>
                <Meter value={o.challengesSolved} max={content.challenges.length} label="Challenges solved" />
              </dd>
            </div>
          </dl>
          <p className="muted small">Study time isn’t tracked. There’s no reliable way to measure it without counting time the tab sat open while you did something else.</p>
        </section>

        <section aria-labelledby="g-review">
          <h2 id="g-review" className="section-title">Needs work</h2>
          {data.dueCards.length === 0 && data.difficult === 0 && o.pendingExercises.length === 0 ? (
            <Empty title="Nothing due right now">Missed exercises, unfinished challenges and concepts from completed lessons show up here.</Empty>
          ) : (
            <ul className="plain-list">
              <li>
                <a href="#/review">
                  {data.dueCards.length} review card{data.dueCards.length === 1 ? '' : 's'} due today
                </a>
                {data.difficult > 0 && <span className="muted"> · {data.difficult} marked hard</span>}
              </li>
              {o.pendingExercises.slice(0, 5).map((p) => {
                const ex = getExercise(p.exerciseId)
                return (
                  <li key={p.exerciseId}>
                    <a href={`#/lesson/${p.lessonId}/${p.exerciseId}`}>
                      {ex ? TYPE_LABEL[ex.exercise.type] : 'Exercise'} in “{getLesson(p.lessonId)?.title}”
                    </a>
                    <span className="muted"> · {EXERCISE_STATUS_LABEL[p.status]}</span>
                  </li>
                )
              })}
              {o.pendingExercises.length > 5 && (
                <li>
                  <a href="#/exercises?status=pending">See all {o.pendingExercises.length} open exercises</a>
                </li>
              )}
            </ul>
          )}
          {o.failedChallenges.length > 0 && (
            <>
              <h3 className="sub-title">Failed challenges</h3>
              <ul className="plain-list">
                {o.failedChallenges.map((id) => (
                  <li key={id}>
                    <a href={`#/challenge/${id}`}>{getChallenge(id)?.title}</a>
                  </li>
                ))}
              </ul>
            </>
          )}
        </section>

        <section aria-labelledby="g-stages" className="span-2">
          <h2 id="g-stages" className="section-title">Progress by stage</h2>
          <table className="stage-table">
            <thead>
              <tr>
                <th scope="col">Stage</th>
                <th scope="col">Lessons completed</th>
                <th scope="col">Modules with lessons</th>
              </tr>
            </thead>
            <tbody>
              {o.byStage.map((s) => (
                <tr key={s.stageId}>
                  <th scope="row">
                    <span className="stage-num">{s.number}</span> {s.title}
                  </th>
                  <td>{s.lessons ? <Meter value={s.completed} max={s.lessons} label={`${s.title} lessons`} /> : <span className="muted">Coming soon</span>}</td>
                  <td>
                    {s.modulesWithContent}/{s.modules}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>

        <section aria-labelledby="g-projects">
          <h2 id="g-projects" className="section-title">Projects in progress</h2>
          {data.projects.length === 0 ? (
            <Empty title="No projects started yet">
              The first one, a console app, opens up once you finish the fundamentals. <a href="#/projects">See the projects</a>.
            </Empty>
          ) : (
            <ul className="plain-list">
              {data.projects.map((p) => {
                const proj = getProject(p.projectId)
                return (
                  <li key={p.projectId}>
                    <a href={`#/project/${p.projectId}`}>{proj?.title}</a>
                    <span className="muted">
                      {' '}
                      · {p.milestonesDone.length}/{proj?.milestones.length} milestones
                    </span>
                  </li>
                )
              })}
            </ul>
          )}
        </section>

        <section aria-labelledby="g-activity">
          <h2 id="g-activity" className="section-title">Recent activity</h2>
          {data.activity.length === 0 ? (
            <Empty title="No activity yet" />
          ) : (
            <ol className="activity">
              {data.activity.map((a) => (
                <li key={a.id}>
                  <time dateTime={a.at}>{new Date(a.at).toLocaleString('en-US', { dateStyle: 'short', timeStyle: 'short' })}</time>
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
    </div>
  )
}

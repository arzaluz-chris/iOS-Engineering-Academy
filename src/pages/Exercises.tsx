import { useLiveQuery } from 'dexie-react-hooks'
import { content, getModule } from '../content'
import type { ExerciseType } from '../content/schema'
import { AUTO_TYPES } from '../content/schema'
import { db } from '../db/db'
import { exerciseStatus, latestByRef } from '../db/stats'
import { Badge, Empty, PageHeader, RESULT_LABEL } from '../components/ui'
import { TYPE_LABEL } from '../exercises/ExerciseBlock'
import { navigate } from '../router'

const STATUS = { all: 'All', pending: 'Not yet correct', 'not-tried': 'Not tried', incorrect: 'Incorrect', partial: 'Partial', correct: 'Correct' } as const
type StatusFilter = keyof typeof STATUS
// URL filter values (English) mapped to the stored result values.
const STORED = { 'not-tried': 'sin-intento', incorrect: 'incorrecto', partial: 'parcial', correct: 'correcto' } as const

export function ExercisesPage({ query }: { query: URLSearchParams }) {
  const type = (query.get('type') ?? 'all') as ExerciseType | 'all'
  const status = (query.get('status') ?? 'all') as StatusFilter
  const attempts = useLiveQuery(() => db.attempts.where('kind').equals('ejercicio').toArray(), []) ?? []
  const latest = latestByRef(attempts)

  const set = (k: string, v: string) => {
    const q = new URLSearchParams(query)
    if (v === 'all') q.delete(k)
    else q.set(k, v)
    navigate(`/exercises${q.toString() ? `?${q}` : ''}`)
  }

  const rows = content.lessons.flatMap((l) =>
    l.exercises.map((e) => ({ lesson: l, exercise: e, status: exerciseStatus(e.id, latest) })),
  ).filter((r) => (type === 'all' || r.exercise.type === type) && (status === 'all' || (status === 'pending' ? r.status !== 'correcto' : r.status === STORED[status])))

  return (
    <div className="page">
      <PageHeader kicker="Practice" title="Exercises">
        <p>
          Every exercise in the course, in order. Types A to D are graded automatically because the answer has a fixed shape. Types E to H use a rubric: Swift code gets tested in Xcode,
          not by comparing text.
        </p>
      </PageHeader>
      <div className="filters" role="group" aria-label="Filters">
        <label>
          Type
          <select value={type} onChange={(e) => set('type', e.target.value)}>
            <option value="all">All</option>
            {(Object.keys(TYPE_LABEL) as ExerciseType[]).map((t) => (
              <option key={t} value={t}>
                {TYPE_LABEL[t]}
              </option>
            ))}
          </select>
        </label>
        <label>
          Status
          <select value={status} onChange={(e) => set('status', e.target.value)}>
            {(Object.keys(STATUS) as StatusFilter[]).map((s) => (
              <option key={s} value={s}>
                {STATUS[s]}
              </option>
            ))}
          </select>
        </label>
        <span className="muted small">{rows.length} exercises</span>
      </div>
      {rows.length === 0 ? (
        <Empty title="No exercises match these filters">Try a different type or status.</Empty>
      ) : (
        <table className="data-table">
          <thead>
            <tr>
              <th scope="col">Exercise</th>
              <th scope="col">Type</th>
              <th scope="col">Lesson</th>
              <th scope="col">Status</th>
            </tr>
          </thead>
          <tbody>
            {rows.map(({ lesson, exercise, status: st }) => (
              <tr key={exercise.id}>
                <td>
                  <a href={`#/lesson/${lesson.id}/${exercise.id}`}>{exercise.prompt.split('\n')[0]?.replace(/[`*_#]/g, '').slice(0, 80)}</a>
                </td>
                <td>
                  {TYPE_LABEL[exercise.type]}
                  <span className="muted small"> · {AUTO_TYPES.includes(exercise.type) ? 'auto-graded' : 'rubric'}</span>
                </td>
                <td className="small">
                  M{getModule(lesson.module)?.number} · {lesson.title}
                </td>
                <td>{st === 'sin-intento' ? <span className="muted">Not tried</span> : <Badge tone={st === 'correcto' ? 'ok' : st === 'parcial' ? 'warn' : 'bad'}>{RESULT_LABEL[st]}</Badge>}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  )
}

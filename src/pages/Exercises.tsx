import { useLiveQuery } from 'dexie-react-hooks'
import { content, getModule } from '../content'
import type { ExerciseType } from '../content/schema'
import { AUTO_TYPES } from '../content/schema'
import { db } from '../db/db'
import { exerciseStatus, latestByRef } from '../db/stats'
import { Badge, Empty, PageHeader, RESULT_LABEL } from '../components/ui'
import { TYPE_LABEL } from '../exercises/ExerciseBlock'
import { navigate } from '../router'

const STATUS = { todos: 'Todos', pendiente: 'Pendientes', 'sin-intento': 'Sin intento', incorrecto: 'Incorrectos', parcial: 'Parciales', correcto: 'Correctos' } as const
type StatusFilter = keyof typeof STATUS

export function ExercisesPage({ query }: { query: URLSearchParams }) {
  const type = (query.get('tipo') ?? 'todos') as ExerciseType | 'todos'
  const status = (query.get('estado') ?? 'todos') as StatusFilter
  const attempts = useLiveQuery(() => db.attempts.where('kind').equals('ejercicio').toArray(), []) ?? []
  const latest = latestByRef(attempts)

  const set = (k: string, v: string) => {
    const q = new URLSearchParams(query)
    if (v === 'todos') q.delete(k)
    else q.set(k, v)
    navigate(`/ejercicios${q.toString() ? `?${q}` : ''}`)
  }

  const rows = content.lessons.flatMap((l) =>
    l.exercises.map((e) => ({ lesson: l, exercise: e, status: exerciseStatus(e.id, latest) })),
  ).filter((r) => (type === 'todos' || r.exercise.type === type) && (status === 'todos' || (status === 'pendiente' ? r.status !== 'correcto' : r.status === status)))

  return (
    <div className="page">
      <PageHeader title="Ejercicios">
        <p>
          Todos los ejercicios del curso, en orden. Los de tipo A a D se califican automáticamente porque su respuesta es estructurada. Los de tipo E a H se evalúan con una rúbrica: el código
          Swift se prueba en Xcode, no comparando texto.
        </p>
      </PageHeader>
      <div className="filters" role="group" aria-label="Filtros">
        <label>
          Tipo
          <select value={type} onChange={(e) => set('tipo', e.target.value)}>
            <option value="todos">Todos</option>
            {(Object.keys(TYPE_LABEL) as ExerciseType[]).map((t) => (
              <option key={t} value={t}>
                {TYPE_LABEL[t]}
              </option>
            ))}
          </select>
        </label>
        <label>
          Estado
          <select value={status} onChange={(e) => set('estado', e.target.value)}>
            {(Object.keys(STATUS) as StatusFilter[]).map((s) => (
              <option key={s} value={s}>
                {STATUS[s]}
              </option>
            ))}
          </select>
        </label>
        <span className="muted small">{rows.length} ejercicios</span>
      </div>
      {rows.length === 0 ? (
        <Empty title="No hay ejercicios con esos filtros">Cambia el tipo o el estado.</Empty>
      ) : (
        <table className="data-table">
          <thead>
            <tr>
              <th scope="col">Ejercicio</th>
              <th scope="col">Tipo</th>
              <th scope="col">Lección</th>
              <th scope="col">Estado</th>
            </tr>
          </thead>
          <tbody>
            {rows.map(({ lesson, exercise, status: st }) => (
              <tr key={exercise.id}>
                <td>
                  <a href={`#/leccion/${lesson.id}/${exercise.id}`}>{exercise.prompt.split('\n')[0]?.replace(/[`*_#]/g, '').slice(0, 80)}</a>
                </td>
                <td>
                  {TYPE_LABEL[exercise.type]}
                  <span className="muted small"> · {AUTO_TYPES.includes(exercise.type) ? 'automática' : 'rúbrica'}</span>
                </td>
                <td className="small">
                  M{getModule(lesson.module)?.number} · {lesson.title}
                </td>
                <td>{st === 'sin-intento' ? <span className="muted">Sin intento</span> : <Badge tone={st === 'correcto' ? 'ok' : st === 'parcial' ? 'warn' : 'bad'}>{RESULT_LABEL[st]}</Badge>}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  )
}

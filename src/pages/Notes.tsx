import { useLiveQuery } from 'dexie-react-hooks'
import { Empty, PageHeader } from '../components/ui'
import { getChallenge, getExercise, getLesson, getProject, getQuestion, getResource } from '../content'
import { deleteNote, toggleBookmark } from '../db/actions'
import { db, type Bookmark, type Note } from '../db/db'

function target(type: Note['targetType'] | Bookmark['targetType'], id: string): { label: string; href: string } {
  switch (type) {
    case 'leccion':
      return { label: `Lección: ${getLesson(id)?.title ?? id}`, href: `#/leccion/${id}` }
    case 'ejercicio': {
      const e = getExercise(id)
      return { label: `Ejercicio en «${e?.lesson.title ?? '?'}»`, href: e ? `#/leccion/${e.lesson.id}/${id}` : '#/ejercicios' }
    }
    case 'reto':
      return { label: `Reto: ${getChallenge(id)?.title ?? id}`, href: `#/reto/${id}` }
    case 'pregunta':
      return { label: `Entrevista: ${getQuestion(id)?.question ?? id}`, href: `#/entrevistas/pregunta/${id}` }
    case 'proyecto':
      return { label: `Proyecto: ${getProject(id)?.title ?? id}`, href: `#/proyecto/${id}` }
    case 'recurso':
      return { label: `Recurso: ${getResource(id)?.title ?? id}`, href: getResource(id)?.url ?? '#/' }
  }
}

export function NotesPage() {
  const notes = useLiveQuery(() => db.notes.orderBy('updatedAt').reverse().toArray(), []) ?? []
  const bookmarks = useLiveQuery(() => db.bookmarks.toArray(), []) ?? []
  return (
    <div className="page">
      <PageHeader title="Notas y marcadores">
        <p>Tus notas de lecciones, ejercicios, retos, preguntas y proyectos. Se guardan solo en este navegador y viajan en el respaldo.</p>
      </PageHeader>
      <section aria-labelledby="bm">
        <h2 id="bm" className="section-title">Marcadores</h2>
        {bookmarks.length === 0 ? (
          <Empty title="Sin marcadores">Usa «Guardar en marcadores» en cualquier lección o reto.</Empty>
        ) : (
          <ul className="plain-list">
            {bookmarks.map((b) => {
              const t = target(b.targetType, b.targetId)
              return (
                <li key={b.key}>
                  <a href={t.href}>{t.label}</a>{' '}
                  <button type="button" className="link" onClick={() => void toggleBookmark(b.targetType, b.targetId)}>
                    Quitar
                  </button>
                </li>
              )
            })}
          </ul>
        )}
      </section>
      <section aria-labelledby="nt">
        <h2 id="nt" className="section-title">Notas</h2>
        {notes.length === 0 ? (
          <Empty title="Sin notas todavía">Cada lección y reto tiene un espacio de notas al final.</Empty>
        ) : (
          notes.map((n) => {
            const t = target(n.targetType, n.targetId)
            return (
              <div key={n.id} className="note">
                <p className="small">
                  <a href={t.href}>{t.label}</a>
                </p>
                <p className="note-text">{n.text}</p>
                <div className="row note-meta">
                  <span>{new Date(n.updatedAt).toLocaleString('es-MX', { dateStyle: 'medium', timeStyle: 'short' })}</span>
                  <button type="button" className="link" onClick={() => n.id !== undefined && confirm('¿Eliminar esta nota?') && void deleteNote(n.id)}>
                    Eliminar
                  </button>
                </div>
              </div>
            )
          })
        )}
      </section>
    </div>
  )
}

import { useLiveQuery } from 'dexie-react-hooks'
import { Empty, PageHeader } from '../components/ui'
import { getChallenge, getExercise, getLesson, getProject, getQuestion, getResource } from '../content'
import { deleteNote, toggleBookmark } from '../db/actions'
import { db, type Bookmark, type Note } from '../db/db'

function target(type: Note['targetType'] | Bookmark['targetType'], id: string): { label: string; href: string } {
  switch (type) {
    case 'leccion':
      return { label: `Lesson: ${getLesson(id)?.title ?? id}`, href: `#/lesson/${id}` }
    case 'ejercicio': {
      const e = getExercise(id)
      return { label: `Exercise in “${e?.lesson.title ?? '?'}”`, href: e ? `#/lesson/${e.lesson.id}/${id}` : '#/exercises' }
    }
    case 'reto':
      return { label: `Challenge: ${getChallenge(id)?.title ?? id}`, href: `#/challenge/${id}` }
    case 'pregunta':
      return { label: `Interview: ${getQuestion(id)?.question ?? id}`, href: `#/interviews/question/${id}` }
    case 'proyecto':
      return { label: `Project: ${getProject(id)?.title ?? id}`, href: `#/project/${id}` }
    case 'recurso':
      return { label: `Recurso: ${getResource(id)?.title ?? id}`, href: getResource(id)?.url ?? '#/' }
  }
}

export function NotesPage() {
  const notes = useLiveQuery(() => db.notes.orderBy('updatedAt').reverse().toArray(), []) ?? []
  const bookmarks = useLiveQuery(() => db.bookmarks.toArray(), []) ?? []
  return (
    <div className="page">
      <PageHeader kicker="Yours" title="Notes and bookmarks">
        <p>Your notes on lessons, exercises, challenges, questions and projects. They live only in this browser and travel with your backup.</p>
      </PageHeader>
      <section aria-labelledby="bm">
        <h2 id="bm" className="section-title">Bookmarks</h2>
        {bookmarks.length === 0 ? (
          <Empty title="No bookmarks">Use “Bookmark” on any lesson or challenge.</Empty>
        ) : (
          <ul className="plain-list">
            {bookmarks.map((b) => {
              const t = target(b.targetType, b.targetId)
              return (
                <li key={b.key}>
                  <a href={t.href}>{t.label}</a>{' '}
                  <button type="button" className="link" onClick={() => void toggleBookmark(b.targetType, b.targetId)}>
                    Remove
                  </button>
                </li>
              )
            })}
          </ul>
        )}
      </section>
      <section aria-labelledby="nt">
        <h2 id="nt" className="section-title">Notes</h2>
        {notes.length === 0 ? (
          <Empty title="No notes yet">Every lesson and challenge has a notes area at the bottom.</Empty>
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
                  <span>{new Date(n.updatedAt).toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'short' })}</span>
                  <button type="button" className="link" onClick={() => n.id !== undefined && confirm('Delete this note?') && void deleteNote(n.id)}>
                    Delete
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

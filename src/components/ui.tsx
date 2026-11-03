import { useLiveQuery } from 'dexie-react-hooks'
import { useState, type ReactNode } from 'react'
import { deleteNote, saveNote, toggleBookmark } from '../db/actions'
import { db, type NoteTarget } from '../db/db'

export function PageHeader({ kicker, title, children }: { kicker?: ReactNode; title: string; children?: ReactNode }) {
  return (
    <header className="page-header">
      {kicker && <p className="kicker">{kicker}</p>}
      <h1>{title}</h1>
      {children && <div className="page-lede">{children}</div>}
    </header>
  )
}

export function Meter({ value, max, label }: { value: number; max: number; label: string }) {
  const pct = max === 0 ? 0 : Math.round((value / max) * 100)
  return (
    <div className="meter" role="meter" aria-valuenow={value} aria-valuemin={0} aria-valuemax={max} aria-label={label}>
      <div className="meter-track">
        <div className="meter-fill" style={{ width: `${pct}%` }} />
      </div>
      <span className="meter-text">
        {value}/{max}
      </span>
    </div>
  )
}

export function Empty({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <div className="empty">
      <p className="empty-title">{title}</p>
      {children && <div className="empty-body">{children}</div>}
    </div>
  )
}

export const DIFFICULTY_LABEL = { facil: 'Fácil', medio: 'Medio', dificil: 'Difícil' } as const
export const LEVEL_LABEL = { inicial: 'Inicial', intermedio: 'Intermedio', avanzado: 'Avanzado' } as const
export const CODE_STATUS_LABEL = {
  probado: 'Código compilado y probado en CI',
  revisado: 'Código revisado estáticamente, no compilado',
  ilustrativo: 'Ejemplos ilustrativos, no ejecutados',
  'sin-codigo': 'Sin código',
} as const

export function Badge({ children, tone = 'neutral' }: { children: ReactNode; tone?: 'neutral' | 'ok' | 'warn' | 'bad' | 'accent' }) {
  return <span className={`badge badge-${tone}`}>{children}</span>
}

export function BookmarkButton({ type, id }: { type: NoteTarget | 'recurso'; id: string }) {
  const marked = useLiveQuery(() => db.bookmarks.get(`${type}:${id}`), [type, id])
  return (
    <button type="button" className="btn btn-quiet" aria-pressed={!!marked} onClick={() => void toggleBookmark(type, id)}>
      {marked ? 'Guardado en marcadores' : 'Guardar en marcadores'}
    </button>
  )
}

export function NotesPanel({ type, id, title = 'Mis notas' }: { type: NoteTarget; id: string; title?: string }) {
  const notes = useLiveQuery(() => db.notes.where('[targetType+targetId]').equals([type, id]).toArray(), [type, id]) ?? []
  const [draft, setDraft] = useState('')
  const [editing, setEditing] = useState<number | null>(null)
  const [editText, setEditText] = useState('')

  return (
    <section className="notes" aria-label={title}>
      <h2 className="section-title">{title}</h2>
      {notes.map((n) =>
        editing === n.id ? (
          <div key={n.id} className="note">
            <textarea value={editText} onChange={(e) => setEditText(e.target.value)} rows={4} aria-label="Editar nota" />
            <div className="row">
              <button className="btn" type="button" onClick={() => void saveNote(type, id, editText, n.id).then(() => setEditing(null))}>
                Guardar nota
              </button>
              <button className="btn btn-quiet" type="button" onClick={() => setEditing(null)}>
                Cancelar
              </button>
            </div>
          </div>
        ) : (
          <div key={n.id} className="note">
            <p className="note-text">{n.text}</p>
            <div className="row note-meta">
              <span>{new Date(n.updatedAt).toLocaleString('es-MX', { dateStyle: 'medium', timeStyle: 'short' })}</span>
              <button className="link" type="button" onClick={() => { setEditing(n.id ?? null); setEditText(n.text) }}>
                Editar
              </button>
              <button className="link" type="button" onClick={() => n.id !== undefined && confirm('¿Eliminar esta nota?') && void deleteNote(n.id)}>
                Eliminar
              </button>
            </div>
          </div>
        ),
      )}
      <textarea value={draft} onChange={(e) => setDraft(e.target.value)} rows={3} placeholder="Escribe una nota para ti…" aria-label="Nueva nota" />
      <button className="btn" type="button" disabled={!draft.trim()} onClick={() => void saveNote(type, id, draft.trim()).then(() => setDraft(''))}>
        Guardar nota
      </button>
    </section>
  )
}

export function Reveal({ label, children, onReveal, initiallyOpen = false, confirmText }: { label: string; children: ReactNode; onReveal?: () => void; initiallyOpen?: boolean; confirmText?: string }) {
  const [open, setOpen] = useState(initiallyOpen)
  if (open) return <div className="revealed">{children}</div>
  return (
    <button
      type="button"
      className="btn btn-reveal"
      onClick={() => {
        if (confirmText && !confirm(confirmText)) return
        setOpen(true)
        onReveal?.()
      }}
    >
      {label}
    </button>
  )
}

export function Rubric({ items, onSubmit, submitLabel = 'Registrar autoevaluación' }: { items: string[]; onSubmit: (score: number, checked: boolean[]) => void; submitLabel?: string }) {
  const [checked, setChecked] = useState<boolean[]>(() => items.map(() => false))
  const done = checked.filter(Boolean).length
  return (
    <fieldset className="rubric">
      <legend>Rúbrica de autoevaluación</legend>
      <p className="muted small">Marca solo lo que tu respuesta cumple de verdad. Esto no es una calificación automática.</p>
      {items.map((it, i) => (
        <label key={i} className="check">
          <input type="checkbox" checked={checked[i] ?? false} onChange={(e) => setChecked((c) => c.map((v, j) => (j === i ? e.target.checked : v)))} />
          <span>{it}</span>
        </label>
      ))}
      <button type="button" className="btn" onClick={() => onSubmit(items.length ? done / items.length : 0, checked)}>
        {submitLabel} ({done}/{items.length})
      </button>
    </fieldset>
  )
}

export function scoreToResult(score: number) {
  return score >= 1 ? 'correcto' : score >= 0.5 ? 'parcial' : 'incorrecto'
}

export const RESULT_LABEL = { correcto: 'Correcto', parcial: 'Parcial', incorrecto: 'Incorrecto' } as const
export const RESULT_TONE = { correcto: 'ok', parcial: 'warn', incorrecto: 'bad' } as const

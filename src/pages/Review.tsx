import { useLiveQuery } from 'dexie-react-hooks'
import { useState } from 'react'
import { Markdown } from '../components/Markdown'
import { Badge, Empty, PageHeader } from '../components/ui'
import { content, getChallenge, getExercise, getQuestion } from '../content'
import { removeCard, reviewCard, setDifficult } from '../db/actions'
import { db, type ReviewCard } from '../db/db'
import { GRADES } from '../srs/scheduler'

const cardById = new Map(content.lessons.flatMap((l) => l.cards.map((c) => [c.id, { card: c, lesson: l }] as const)))

const SOURCE_LABEL = { concepto: 'Concepto', ejercicio: 'Ejercicio fallado', reto: 'Reto de código', pregunta: 'Pregunta de entrevista' } as const

/** Prioridad: difíciles, luego fallos, luego por fecha de vencimiento. */
export function orderDue(cards: ReviewCard[]): ReviewCard[] {
  const rank = (c: ReviewCard) => (c.difficult ? 0 : c.reason === 'fallo' ? 1 : 2)
  return [...cards].sort((a, b) => rank(a) - rank(b) || a.dueAt.localeCompare(b.dueAt))
}

function describe(card: ReviewCard): { title: string; front: string; back?: string; href?: string } | null {
  switch (card.source) {
    case 'concepto': {
      const c = cardById.get(card.refId)
      return c ? { title: c.lesson.title, front: c.card.front, back: c.card.back, href: `#/leccion/${c.lesson.id}` } : null
    }
    case 'ejercicio': {
      const e = getExercise(card.refId)
      return e ? { title: e.lesson.title, front: e.exercise.prompt, href: `#/leccion/${e.lesson.id}/${e.exercise.id}` } : null
    }
    case 'reto': {
      const ch = getChallenge(card.refId)
      return ch ? { title: 'Reto de código', front: `**${ch.title}.** ${ch.summary}\n\nResuélvelo de nuevo sin mirar la solución. Patrón: ${ch.patterns.join(', ')}.`, href: `#/reto/${ch.id}` } : null
    }
    case 'pregunta': {
      const q = getQuestion(card.refId)
      return q ? { title: 'Pregunta de entrevista', front: q.question, back: q.answer, href: `#/entrevistas/pregunta/${q.id}` } : null
    }
  }
}

export function ReviewPage() {
  const due = useLiveQuery(() => db.cards.where('dueAt').belowOrEqual(new Date().toISOString()).toArray(), [])
  const total = useLiveQuery(() => db.cards.count(), []) ?? 0
  const upcoming = useLiveQuery(() => db.cards.where('dueAt').above(new Date().toISOString()).sortBy('dueAt'), []) ?? []
  const [shown, setShown] = useState(false)

  if (!due) return <div className="page" aria-busy="true" />
  const queue = orderDue(due)
  const card = queue[0]
  const info = card ? describe(card) : null

  return (
    <div className="page">
      <PageHeader title="Repaso espaciado">
        <p>
          Entran aquí los conceptos de lecciones completadas, los ejercicios y retos fallados, y las preguntas de entrevista incompletas. El intervalo se calcula con FSRS según qué tan bien
          recordaste. Primero aparecen los temas marcados como difíciles y los fallos.
        </p>
      </PageHeader>
      <p className="muted">
        {queue.length} pendiente{queue.length === 1 ? '' : 's'} hoy · {total} tarjeta{total === 1 ? '' : 's'} en total
      </p>

      {!card ? (
        <Empty title={total === 0 ? 'Tu repaso está vacío' : 'Terminaste el repaso de hoy'}>
          {total === 0 ? 'Completa una lección o falla un ejercicio y aparecerá aquí.' : upcoming[0] ? `La siguiente tarjeta vence el ${new Date(upcoming[0].dueAt).toLocaleString('es-MX', { dateStyle: 'medium', timeStyle: 'short' })}.` : null}
        </Empty>
      ) : !info ? (
        <div className="review-card">
          <p>Esta tarjeta apunta a contenido que ya no existe ({card.refId}).</p>
          <button type="button" className="btn" onClick={() => void removeCard(card.id)}>
            Quitar del repaso
          </button>
        </div>
      ) : (
        <article className="review-card" aria-live="polite">
          <div className="row">
            <Badge>{SOURCE_LABEL[card.source]}</Badge>
            {card.difficult && <Badge tone="warn">Difícil</Badge>}
            <span className="muted small">{info.title}</span>
          </div>
          <div className="review-front">
            <Markdown text={info.front} />
          </div>
          {!shown ? (
            <button type="button" className="btn btn-primary" onClick={() => setShown(true)}>
              {info.back ? 'Mostrar respuesta' : 'Ya lo intenté'}
            </button>
          ) : (
            <>
              {info.back && (
                <div className="review-back">
                  <Markdown text={info.back} />
                </div>
              )}
              {!info.back && info.href && (
                <p>
                  <a href={info.href}>Abrir el ejercicio para resolverlo de nuevo</a>
                </p>
              )}
              <p className="field-label">¿Qué tan bien lo recordaste?</p>
              <div className="grades">
                {GRADES.map((g) => (
                  <button
                    key={g.grade}
                    type="button"
                    className="btn grade"
                    onClick={() => {
                      setShown(false)
                      void reviewCard(card, g.grade, info.title)
                    }}
                  >
                    {g.label}
                    <span className="muted small">{g.hint}</span>
                  </button>
                ))}
              </div>
            </>
          )}
          <div className="row review-actions">
            <button type="button" className="link" onClick={() => void setDifficult(card.id, !card.difficult)}>
              {card.difficult ? 'Quitar marca de difícil' : 'Marcar como tema difícil'}
            </button>
            {info.href && <a href={info.href}>Ir al contenido</a>}
          </div>
        </article>
      )}
    </div>
  )
}

import { useLiveQuery } from 'dexie-react-hooks'
import { useState } from 'react'
import { Markdown } from '../components/Markdown'
import { Badge, Empty, PageHeader } from '../components/ui'
import { content, getChallenge, getExercise, getQuestion } from '../content'
import { removeCard, reviewCard, setDifficult } from '../db/actions'
import { db, type ReviewCard } from '../db/db'
import { GRADES } from '../srs/scheduler'

const cardById = new Map(content.lessons.flatMap((l) => l.cards.map((c) => [c.id, { card: c, lesson: l }] as const)))

const SOURCE_LABEL = { concepto: 'Concept', ejercicio: 'Missed exercise', reto: 'Coding challenge', pregunta: 'Interview question' } as const

/** Order: cards marked hard, then misses, then by due date. */
export function orderDue(cards: ReviewCard[]): ReviewCard[] {
  const rank = (c: ReviewCard) => (c.difficult ? 0 : c.reason === 'fallo' ? 1 : 2)
  return [...cards].sort((a, b) => rank(a) - rank(b) || a.dueAt.localeCompare(b.dueAt))
}

function describe(card: ReviewCard): { title: string; front: string; back?: string; href?: string } | null {
  switch (card.source) {
    case 'concepto': {
      const c = cardById.get(card.refId)
      return c ? { title: c.lesson.title, front: c.card.front, back: c.card.back, href: `#/lesson/${c.lesson.id}` } : null
    }
    case 'ejercicio': {
      const e = getExercise(card.refId)
      return e ? { title: e.lesson.title, front: e.exercise.prompt, href: `#/lesson/${e.lesson.id}/${e.exercise.id}` } : null
    }
    case 'reto': {
      const ch = getChallenge(card.refId)
      return ch ? { title: 'Coding challenge', front: `**${ch.title}.** ${ch.summary}\n\nSolve it again without looking at the solution. Pattern: ${ch.patterns.join(', ')}.`, href: `#/challenge/${ch.id}` } : null
    }
    case 'pregunta': {
      const q = getQuestion(card.refId)
      return q ? { title: 'Interview question', front: q.question, back: q.answer, href: `#/interviews/question/${q.id}` } : null
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
      <PageHeader kicker="Practice" title="Spaced review">
        <p>
          Concepts from completed lessons land here, along with missed exercises and challenges and interview questions you didn’t fully answer. FSRS sets the next interval from how well
          you remembered. Cards marked hard and recent misses come first.
        </p>
      </PageHeader>
      <p className="muted">
        {queue.length} due today · {total} card{total === 1 ? '' : 's'} in total
      </p>

      {!card ? (
        <Empty title={total === 0 ? 'Nothing to review yet' : 'You’re done for today'}>
          {total === 0 ? 'Finish a lesson or miss an exercise and it shows up here.' : upcoming[0] ? `The next card is due ${new Date(upcoming[0].dueAt).toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'short' })}.` : null}
        </Empty>
      ) : !info ? (
        <div className="review-card">
          <p>This card points to content that no longer exists ({card.refId}).</p>
          <button type="button" className="btn" onClick={() => void removeCard(card.id)}>
            Remove from review
          </button>
        </div>
      ) : (
        <article className="review-card" aria-live="polite">
          <div className="row">
            <Badge>{SOURCE_LABEL[card.source]}</Badge>
            {card.difficult && <Badge tone="warn">Hard</Badge>}
            <span className="muted small">{info.title}</span>
          </div>
          <div className="review-front">
            <Markdown text={info.front} />
          </div>
          {!shown ? (
            <button type="button" className="btn btn-primary" onClick={() => setShown(true)}>
              {info.back ? 'Show answer' : 'I tried it'}
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
                  <a href={info.href}>Open the exercise and solve it again</a>
                </p>
              )}
              <p className="field-label">How well did you remember it?</p>
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
              {card.difficult ? 'Unmark as hard' : 'Mark as hard'}
            </button>
            {info.href && <a href={info.href}>Go to the content</a>}
          </div>
        </article>
      )}
    </div>
  )
}

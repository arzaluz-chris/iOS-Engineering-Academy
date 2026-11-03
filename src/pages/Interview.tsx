import { useLiveQuery } from 'dexie-react-hooks'
import { useMemo, useState } from 'react'
import { CodeEditor } from '../components/CodeEditor'
import { Markdown } from '../components/Markdown'
import { Badge, DIFFICULTY_LABEL, Empty, NotesPanel, PageHeader, Rubric, scoreToResult } from '../components/ui'
import { content, getChallenge, getLesson, getModule, getQuestion } from '../content'
import type { InterviewCategory, InterviewQuestion } from '../content/schema'
import { recordAttempt, setQuestionStatus } from '../db/actions'
import { db } from '../db/db'
import { latestByRef } from '../db/stats'
import { navigate } from '../router'

export const CATEGORY_LABEL: Record<InterviewCategory, string> = {
  swift: 'Swift',
  memory: 'Memory and ARC',
  uikit: 'UIKit',
  swiftui: 'SwiftUI',
  concurrency: 'Concurrency',
  architecture: 'Architecture and design',
  testing: 'Testing',
  security: 'Security',
  'system-design': 'Mobile system design',
}

export function InterviewPage() {
  const attempts = useLiveQuery(() => db.attempts.where('kind').equals('entrevista').toArray(), []) ?? []
  const states = useLiveQuery(() => db.questions.toArray(), []) ?? []
  const latest = latestByRef(attempts)
  const mastered = new Set(states.filter((s) => s.status === 'dominada').map((s) => s.questionId))
  const [cat, setCat] = useState('all')
  const [dif, setDif] = useState('all')
  const [n, setN] = useState(5)
  const cats = (Object.keys(CATEGORY_LABEL) as InterviewCategory[]).filter((c) => content.questions.some((q) => q.category === c))
  const failed = content.questions.filter((q) => latest.get(q.id) && latest.get(q.id)?.result !== 'correcto')

  return (
    <div className="page">
      <PageHeader kicker="Practice" title="Technical interviews">
        <p>
          Questions the way an iOS interviewer asks them: one at a time. You answer before you see the model answer, then you get follow-ups. You grade yourself against the key points,
          so be strict.
        </p>
      </PageHeader>

      <section className="sim-form" aria-labelledby="sim">
        <h2 id="sim" className="section-title">New mock interview</h2>
        <div className="filters">
          <label>
            Category
            <select value={cat} onChange={(e) => setCat(e.target.value)}>
              <option value="all">All</option>
              {cats.map((c) => (
                <option key={c} value={c}>
                  {CATEGORY_LABEL[c]}
                </option>
              ))}
            </select>
          </label>
          <label>
            Difficulty
            <select value={dif} onChange={(e) => setDif(e.target.value)}>
              <option value="all">All</option>
              <option value="easy">Easy</option>
              <option value="medium">Medium</option>
              <option value="hard">Hard</option>
            </select>
          </label>
          <label>
            Questions
            <select value={n} onChange={(e) => setN(Number(e.target.value))}>
              {[1, 3, 5, 8].map((x) => (
                <option key={x} value={x}>
                  {x}
                </option>
              ))}
            </select>
          </label>
          <button type="button" className="btn btn-primary" onClick={() => navigate(`/interviews/simulation?cat=${cat}&diff=${dif}&n=${n}&s=${Date.now()}`)}>
            Start the interview
          </button>
          <button type="button" className="btn" disabled={failed.length === 0} onClick={() => navigate(`/interviews/simulation?failed=1&n=${failed.length}&s=${Date.now()}`)}>
            Retry missed ({failed.length})
          </button>
        </div>
      </section>

      <section aria-labelledby="by-cat">
        <h2 id="by-cat" className="section-title">Results by category</h2>
        <table className="data-table">
          <thead>
            <tr>
              <th scope="col">Category</th>
              <th scope="col">Questions</th>
              <th scope="col">Answered</th>
              <th scope="col">Correct (latest)</th>
              <th scope="col">Mastered</th>
            </tr>
          </thead>
          <tbody>
            {cats.map((c) => {
              const qs = content.questions.filter((q) => q.category === c)
              return (
                <tr key={c}>
                  <th scope="row">{CATEGORY_LABEL[c]}</th>
                  <td>{qs.length}</td>
                  <td>{qs.filter((q) => latest.has(q.id)).length}</td>
                  <td>{qs.filter((q) => latest.get(q.id)?.result === 'correcto').length}</td>
                  <td>{qs.filter((q) => mastered.has(q.id)).length}</td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </section>

      <section aria-labelledby="bank">
        <h2 id="bank" className="section-title">Question bank</h2>
        {cats.map((c) => (
          <div key={c} className="q-group">
            <h3 className="sub-title">{CATEGORY_LABEL[c]}</h3>
            <ul className="plain-list">
              {content.questions
                .filter((q) => q.category === c)
                .map((q) => (
                  <li key={q.id}>
                    <a href={`#/interviews/question/${q.id}`}>{q.question}</a> <span className="muted small">{DIFFICULTY_LABEL[q.difficulty]}</span>
                    {mastered.has(q.id) && <Badge tone="ok">Mastered</Badge>}
                    {latest.get(q.id) && latest.get(q.id)?.result !== 'correcto' && <Badge tone="warn">To review</Badge>}
                  </li>
                ))}
            </ul>
          </div>
        ))}
      </section>
    </div>
  )
}

function shuffle<T>(arr: T[], seed: number): T[] {
  const a = [...arr]
  let s = seed % 2147483647 || 1
  for (let i = a.length - 1; i > 0; i--) {
    s = (s * 16807) % 2147483647
    const j = s % (i + 1)
    ;[a[i], a[j]] = [a[j] as T, a[i] as T]
  }
  return a
}

export function SimulationPage({ query }: { query: URLSearchParams }) {
  const attempts = useLiveQuery(() => db.attempts.where('kind').equals('entrevista').toArray(), [])
  const seed = Number(query.get('s') ?? 1)
  const questions = useMemo(() => {
    if (!attempts) return null
    const latest = latestByRef(attempts)
    const cat = query.get('cat') ?? 'all'
    const dif = query.get('diff') ?? 'all'
    const pool = query.get('failed')
      ? content.questions.filter((q) => latest.get(q.id) && latest.get(q.id)?.result !== 'correcto')
      : content.questions.filter((q) => (cat === 'all' || q.category === cat) && (dif === 'all' || q.difficulty === dif))
    return shuffle(pool, seed).slice(0, Number(query.get('n') ?? 5))
    // The question set is fixed when the interview starts.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [attempts === undefined, seed])
  const [index, setIndex] = useState(0)
  const [results, setResults] = useState<{ id: string; score: number }[]>([])

  if (!questions) return <div className="page" aria-busy="true" />
  if (questions.length === 0)
    return (
      <div className="page">
        <Empty title="No questions match these filters">
          <a href="#/interviews">Back to interviews</a>
        </Empty>
      </div>
    )

  if (index >= questions.length) {
    const avg = results.reduce((s, r) => s + r.score, 0) / Math.max(1, results.length)
    return (
      <div className="page">
        <PageHeader title="Interview finished">
          <p>Average key points covered: {Math.round(avg * 100)}%.</p>
        </PageHeader>
        <table className="data-table">
          <thead>
            <tr>
              <th scope="col">Question</th>
              <th scope="col">Category</th>
              <th scope="col">Key points covered</th>
            </tr>
          </thead>
          <tbody>
            {results.map((r) => {
              const q = getQuestion(r.id)
              return (
                <tr key={r.id}>
                  <td>
                    <a href={`#/interviews/question/${r.id}`}>{q?.question}</a>
                  </td>
                  <td>{q && CATEGORY_LABEL[q.category]}</td>
                  <td>{Math.round(r.score * 100)}%</td>
                </tr>
              )
            })}
          </tbody>
        </table>
        <p>Anything under 100% went into your review queue.</p>
        <a className="btn" href="#/interviews">
          Back to interviews
        </a>
      </div>
    )
  }

  const q = questions[index] as InterviewQuestion
  return (
    <div className="page">
      <PageHeader kicker={<><a href="#/interviews">Interviews</a> / Mock interview</>} title={`Question ${index + 1} of ${questions.length}`} />
      <QuestionRunner
        key={q.id}
        q={q}
        onDone={(score) => {
          setResults((r) => [...r, { id: q.id, score }])
          setIndex((i) => i + 1)
        }}
        nextLabel={index + 1 < questions.length ? 'Next question' : 'See results'}
      />
    </div>
  )
}

export function QuestionPage({ id }: { id: string }) {
  const q = getQuestion(id)
  const [round, setRound] = useState(0)
  if (!q) return <Empty title="Question not found"><a href="#/interviews">Back</a></Empty>
  return (
    <div className="page">
      <PageHeader kicker={<><a href="#/interviews">Interviews</a> / {CATEGORY_LABEL[q.category]}</>} title="Interview question" />
      <QuestionRunner key={`${q.id}-${round}`} q={q} onDone={() => setRound((r) => r + 1)} nextLabel="Answer again" />
      <NotesPanel type="pregunta" id={q.id} />
    </div>
  )
}

function QuestionRunner({ q, onDone, nextLabel }: { q: InterviewQuestion; onDone: (score: number) => void; nextLabel: string }) {
  const state = useLiveQuery(() => db.questions.get(q.id), [q.id])
  const [answer, setAnswer] = useState('')
  const [phase, setPhase] = useState<'answer' | 'review' | 'followups'>('answer')
  const [score, setScore] = useState<number | null>(null)
  const [follow, setFollow] = useState(0)
  const [followShown, setFollowShown] = useState(false)

  return (
    <div className="q-runner">
      <div className="row">
        <Badge>{CATEGORY_LABEL[q.category]}</Badge>
        <Badge>{DIFFICULTY_LABEL[q.difficulty]}</Badge>
        {state?.status === 'dominada' && <Badge tone="ok">Mastered</Badge>}
      </div>
      <h2 className="q-text">{q.question}</h2>
      {phase === 'answer' && (
        <>
          <p className="muted">Answer the way you would out loud in the room. Writing it down forces you to put your reasoning in order.</p>
          <CodeEditor value={answer} onChange={setAnswer} language={q.writesCode ? 'swift' : 'text'} label="Your answer" minLines={q.writesCode ? 12 : 6} />
          <button type="button" className="btn btn-primary" disabled={!answer.trim()} onClick={() => setPhase('review')}>
            See the model answer
          </button>
          <button type="button" className="btn btn-quiet" onClick={() => confirm('Seeing the answer without answering counts as an attempt with no answer. Continue?') && setPhase('review')}>
            I don’t know
          </button>
        </>
      )}
      {phase !== 'answer' && (
        <>
          {answer.trim() && (
            <details>
              <summary>Your answer</summary>
              <pre className="answer-echo">{answer}</pre>
            </details>
          )}
          <div className="model-answer">
            <h3>Model answer</h3>
            <Markdown text={q.answer} />
          </div>
          {score === null ? (
            <Rubric
              items={q.keyPoints}
              submitLabel="Record points covered"
              onSubmit={(s) => {
                setScore(s)
                void recordAttempt({ kind: 'entrevista', refId: q.id, result: scoreToResult(s), score: s, grading: 'autoevaluacion', answer, label: q.question })
                setPhase('followups')
              }}
            />
          ) : (
            <p className="verdict" role="status">
              You covered {Math.round(score * 100)}% of the key points.
            </p>
          )}
          {phase === 'followups' && q.followUps.length > 0 && (
            <section className="followups" aria-label="Follow-up questions">
              <h3>Interviewer follow-ups</h3>
              {q.followUps.slice(0, follow + 1).map((f, i) => (
                <div key={i} className="followup">
                  <p className="q-follow">{f.question}</p>
                  {i < follow || followShown ? <Markdown text={f.answer} /> : (
                    <button type="button" className="btn btn-quiet" onClick={() => setFollowShown(true)}>
                      Think through your answer, then reveal
                    </button>
                  )}
                </div>
              ))}
              {followShown && follow + 1 < q.followUps.length && (
                <button type="button" className="btn" onClick={() => { setFollow((f) => f + 1); setFollowShown(false) }}>
                  Next follow-up
                </button>
              )}
            </section>
          )}
          {q.related.length > 0 && (
            <p className="muted small">
              Related:{' '}
              {q.related.map((r, i) => (
                <span key={r}>
                  {i > 0 && ', '}
                  <a href={getLesson(r) ? `#/lesson/${r}` : getChallenge(r) ? `#/challenge/${r}` : `#/module/${r}`}>{getLesson(r)?.title ?? getChallenge(r)?.title ?? getModule(r)?.title}</a>
                </span>
              ))}
            </p>
          )}
          {phase === 'followups' && (
            <div className="row">
              <button type="button" className="btn" onClick={() => void setQuestionStatus(q.id, state?.status === 'dominada' ? 'pendiente' : 'dominada')}>
                {state?.status === 'dominada' ? 'Mark as not mastered' : 'Mark as mastered'}
              </button>
              <button type="button" className="btn btn-primary" onClick={() => onDone(score ?? 0)}>
                {nextLabel}
              </button>
            </div>
          )}
        </>
      )}
    </div>
  )
}

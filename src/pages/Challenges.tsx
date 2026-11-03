import { useLiveQuery } from 'dexie-react-hooks'
import { useEffect, useRef, useState } from 'react'
import { CodeEditor } from '../components/CodeEditor'
import { CodeView, Markdown } from '../components/Markdown'
import { Badge, BookmarkButton, CODE_STATUS_LABEL, DIFFICULTY_LABEL, Empty, NotesPanel, PageHeader, RESULT_LABEL, RESULT_TONE, Rubric, scoreToResult } from '../components/ui'
import { content, getChallenge, getLesson, getModule } from '../content'
import type { Challenge } from '../content/parse'
import { recordAttempt, saveDraft, updateChallenge } from '../db/actions'
import { db, type ChallengeState } from '../db/db'
import { latestByRef } from '../db/stats'
import { navigate } from '../router'

const STATUS_LABEL: Record<ChallengeState['status'] | 'nuevo', string> = { nuevo: 'Not started', intentado: 'Attempted', resuelto: 'Solved', dominado: 'Mastered' }
// URL filter values (English) mapped to the stored status values.
const STATUS_FILTER: Record<string, ChallengeState['status'] | 'nuevo'> = { new: 'nuevo', attempted: 'intentado', solved: 'resuelto', mastered: 'dominado' }

export function ChallengesPage({ query }: { query: URLSearchParams }) {
  const diff = query.get('difficulty') ?? 'all'
  const pattern = query.get('pattern') ?? 'all'
  const status = query.get('status') ?? 'all'
  const states = useLiveQuery(() => db.challenges.toArray(), []) ?? []
  const attempts = useLiveQuery(() => db.attempts.where('kind').equals('reto').toArray(), []) ?? []
  const byId = new Map(states.map((s) => [s.challengeId, s]))
  const latest = latestByRef(attempts)
  const patterns = [...new Set(content.challenges.flatMap((c) => c.patterns))].sort((a, b) => a.localeCompare(b, 'en'))

  const set = (k: string, v: string) => {
    const q = new URLSearchParams(query)
    if (v === 'all') q.delete(k)
    else q.set(k, v)
    navigate(`/challenges${q.toString() ? `?${q}` : ''}`)
  }

  const rows = content.challenges.filter((c) => {
    const st = byId.get(c.id)?.status ?? 'nuevo'
    const failed = latest.get(c.id) && latest.get(c.id)?.result !== 'correcto'
    return (
      (diff === 'all' || c.difficulty === diff) &&
      (pattern === 'all' || c.patterns.includes(pattern)) &&
      (status === 'all' || (status === 'failed' ? failed : st === STATUS_FILTER[status]))
    )
  })

  return (
    <div className="page">
      <PageHeader kicker="Practice" title="Coding challenges">
        <p>
          Interview problems, solved in Swift. Try first. Hints, the approach and the solution open one at a time. Every solution lives in the repository’s <code>swift/</code>
          package with its tests, and CI builds and runs them on macOS.
        </p>
      </PageHeader>
      <div className="filters" role="group" aria-label="Filters">
        <label>
          Difficulty
          <select value={diff} onChange={(e) => set('difficulty', e.target.value)}>
            <option value="all">All</option>
            <option value="easy">Easy</option>
            <option value="medium">Medium</option>
            <option value="hard">Hard</option>
          </select>
        </label>
        <label>
          Pattern
          <select value={pattern} onChange={(e) => set('pattern', e.target.value)}>
            <option value="all">All</option>
            {patterns.map((p) => (
              <option key={p}>{p}</option>
            ))}
          </select>
        </label>
        <label>
          Status
          <select value={status} onChange={(e) => set('status', e.target.value)}>
            <option value="all">All</option>
            <option value="new">Not started</option>
            <option value="attempted">Attempted</option>
            <option value="solved">Solved</option>
            <option value="mastered">Mastered</option>
            <option value="failed">Failed (to review)</option>
          </select>
        </label>
      </div>
      {rows.length === 0 ? (
        <Empty title="No challenges match these filters" />
      ) : (
        <table className="data-table">
          <thead>
            <tr>
              <th scope="col">Challenge</th>
              <th scope="col">Difficulty</th>
              <th scope="col">Patterns</th>
              <th scope="col">Status</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((c) => {
              const st = byId.get(c.id)?.status ?? 'nuevo'
              const last = latest.get(c.id)
              return (
                <tr key={c.id}>
                  <td>
                    <a href={`#/challenge/${c.id}`}>{c.title}</a>
                    <p className="muted small">{c.summary}</p>
                  </td>
                  <td>{DIFFICULTY_LABEL[c.difficulty]}</td>
                  <td className="small">{c.patterns.join(', ')}</td>
                  <td>
                    <Badge tone={st === 'dominado' || st === 'resuelto' ? 'ok' : st === 'intentado' ? 'warn' : 'neutral'}>{STATUS_LABEL[st]}</Badge>
                    {last && last.result !== 'correcto' && <span className="muted small"> last: {RESULT_LABEL[last.result].toLowerCase()}</span>}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      )}

      <section aria-labelledby="by-pattern">
        <h2 id="by-pattern" className="section-title">Review by pattern</h2>
        <p className="muted">Spotting the pattern from the problem statement is half the work. Here are the challenges grouped by the technique that cracks them.</p>
        <dl className="patterns">
          {patterns.map((p) => (
            <div key={p}>
              <dt>
                <a href={`#/challenges?pattern=${encodeURIComponent(p)}`}>{p}</a>
              </dt>
              <dd>
                {content.challenges
                  .filter((c) => c.patterns.includes(p))
                  .map((c) => c.title)
                  .join(', ')}
              </dd>
            </div>
          ))}
        </dl>
      </section>
    </div>
  )
}

type Mode = 'guiado' | 'independiente' | 'entrevista'
const MODE_HELP: Record<Mode, string> = {
  guiado: 'Open hints and sections whenever you want, one at a time.',
  independiente: 'Hints unlock once you’ve written an attempt of your own.',
  entrevista: 'No hints until you finish. Think out loud: clarify the problem, propose an approach, work out the complexity and test the edge cases.',
}

const INTERVIEW_RUBRIC = [
  'I asked clarifying questions before writing code',
  'I explained an approach out loud before coding it',
  'I traced at least one example by hand',
  'I considered the edge cases',
  'I stated the correct time and space complexity',
]

export function ChallengePage({ id }: { id: string }) {
  const c = getChallenge(id)
  if (!c) return <Empty title="Challenge not found"><a href="#/challenges">Back to the challenges</a></Empty>
  return <ChallengeView key={c.id} c={c} />
}

function ChallengeView({ c }: { c: Challenge }) {
  const state = useLiveQuery(() => db.challenges.get(c.id), [c.id])
  const draft = useLiveQuery(() => db.drafts.get(`reto:${c.id}`), [c.id])
  const attempts = useLiveQuery(() => db.attempts.where('refId').equals(c.id).sortBy('at'), [c.id]) ?? []
  const [mode, setMode] = useState<Mode>('guiado')
  const [code, setCode] = useState<string | null>(null)
  const [revealed, setRevealed] = useState(0)
  const [finished, setFinished] = useState(false)
  const [timerMin, setTimerMin] = useState(0)
  const [startedAt, setStartedAt] = useState<number | null>(null)
  const [nowTick, setNowTick] = useState(Date.now())
  const saveTimer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)

  useEffect(() => {
    if (!startedAt) return
    const t = setInterval(() => setNowTick(Date.now()), 1000)
    return () => clearInterval(t)
  }, [startedAt])

  const value = code ?? draft?.code ?? c.starter
  const wroteSomething = value.trim() !== c.starter.trim() && value.trim().length > 0
  const steps = [...c.hints.map((h, i) => ({ heading: `Hint ${i + 1}`, body: h, kind: 'hint' as const })), ...c.reveal.map((s) => ({ ...s, kind: 'section' as const }))]
  const locked = (mode === 'independiente' && !wroteSomething) || (mode === 'entrevista' && !finished)
  const last = attempts.at(-1)
  const elapsed = startedAt ? Math.floor((nowTick - startedAt) / 1000) : 0
  const remaining = timerMin ? timerMin * 60 - elapsed : null

  const onChange = (v: string) => {
    setCode(v)
    clearTimeout(saveTimer.current)
    saveTimer.current = setTimeout(() => {
      void saveDraft(`reto:${c.id}`, v)
      if (!state) void updateChallenge(c.id, { status: 'intentado' })
    }, 600)
  }

  const reveal = () => {
    const n = revealed + 1
    setRevealed(n)
    const hintsUsed = Math.min(n, c.hints.length)
    void updateChallenge(c.id, { revealed: n, hintsUsed })
  }

  return (
    <div className="page challenge-page">
      <PageHeader kicker={<><a href="#/challenges">Coding challenges</a> / {DIFFICULTY_LABEL[c.difficulty]}</>} title={c.title}>
        <p>{c.summary}</p>
      </PageHeader>
      <div className="row">
        {c.patterns.map((p) => (
          <Badge key={p}>{p}</Badge>
        ))}
        <Badge tone={c.codeStatus === 'tested' ? 'ok' : 'neutral'}>{CODE_STATUS_LABEL[c.codeStatus]}</Badge>
        {state && <Badge tone={state.status === 'intentado' ? 'warn' : 'ok'}>{STATUS_LABEL[state.status]}</Badge>}
        {last && <Badge tone={RESULT_TONE[last.result]}>Last self-assessment: {RESULT_LABEL[last.result]}</Badge>}
        <BookmarkButton type="reto" id={c.id} />
      </div>

      {c.prerequisites.length > 0 && (
        <p className="prereq">
          Helps to have seen:{' '}
          {c.prerequisites.map((p, i) => (
            <span key={p}>
              {i > 0 && ', '}
              <a href={getLesson(p) ? `#/lesson/${p}` : `#/module/${p}`}>{getLesson(p)?.title ?? `Module ${getModule(p)?.number}. ${getModule(p)?.title}`}</a>
            </span>
          ))}
        </p>
      )}

      <fieldset className="modes">
        <legend>Practice mode</legend>
        {(['guiado', 'independiente', 'entrevista'] as Mode[]).map((m) => (
          <label key={m} className="mode">
            <input type="radio" name="mode" checked={mode === m} onChange={() => { setMode(m); setFinished(false); setRevealed(0) }} />
            <span>
              <strong>{m === 'guiado' ? 'Guided' : m === 'independiente' ? 'On your own' : 'Mock interview'}</strong>
              <span className="muted small">{MODE_HELP[m]}</span>
            </span>
          </label>
        ))}
        {mode === 'entrevista' && (
          <div className="row timer">
            <label>
              Optional timer
              <select value={timerMin} onChange={(e) => setTimerMin(Number(e.target.value))}>
                <option value={0}>No limit</option>
                <option value={20}>20 min</option>
                <option value={35}>35 min</option>
                <option value={45}>45 min</option>
              </select>
            </label>
            {!startedAt ? (
              <button type="button" className="btn" onClick={() => setStartedAt(Date.now())}>
                Start
              </button>
            ) : (
              <span className={`clock ${remaining !== null && remaining < 0 ? 'over' : ''}`} aria-live="off">
                {formatClock(remaining ?? elapsed)}
                {remaining !== null && remaining < 0 && ' over time'}
              </span>
            )}
            {!finished && (
              <button type="button" className="btn btn-quiet" onClick={() => setFinished(true)}>
                End the interview
              </button>
            )}
          </div>
        )}
      </fieldset>

      <section className="statement" aria-labelledby="statement">
        <h2 id="statement" className="section-title">Problem</h2>
        <Markdown text={c.statement} />
        <div className="two-col">
          <div>
            <h3 className="sub-title">Edge cases to consider</h3>
            <ul>
              {c.edgeCases.map((e) => (
                <li key={e}>{e}</li>
              ))}
            </ul>
          </div>
          <div>
            <h3 className="sub-title">Questions worth asking the interviewer</h3>
            <ul>
              {c.askInterviewer.map((e) => (
                <li key={e}>{e}</li>
              ))}
            </ul>
          </div>
        </div>
      </section>

      <section aria-labelledby="attempt">
        <h2 id="attempt" className="section-title">Your solution</h2>
        <CodeEditor value={value} onChange={onChange} label="Your Swift solution" minLines={14} />
        <p className="muted small">
          Saved in this browser. To run it, copy your code into <code>swift/Sources/Challenges/{c.solutionFile}</code> in your clone of the repository and run <code>swift test --filter {c.testFile.replace('.swift', '')}</code>, or paste both files into a new Swift package in Xcode.
        </p>
        <details className="tests">
          <summary>Tests your solution has to pass</summary>
          <CodeView code={c.testCode} label={c.testFile} />
        </details>
      </section>

      <section aria-labelledby="reveal">
        <h2 id="reveal" className="section-title">Hints and solution</h2>
        {locked && (
          <p className="muted">{mode === 'entrevista' ? 'End the interview to open the hints and solution.' : 'Write an attempt of your own in the editor to unlock the hints.'}</p>
        )}
        {steps.slice(0, revealed).map((s, i) => (
          <div key={i} className={s.kind === 'hint' ? 'hint' : 'reveal-section'}>
            {s.kind === 'hint' ? <p className="hint-label">{s.heading}</p> : <h3>{s.heading}</h3>}
            <Markdown text={s.body} />
            {s.kind === 'section' && /^Optimized solution/i.test(s.heading) && (
              <>
                <CodeView code={c.solutionCode} label={`${c.solutionFile} · ${c.codeStatus === 'tested' ? 'tested in CI' : 'not tested yet'}`} />
                <p className="muted small">
                  Complexity: time {c.time}; space {c.space}.
                </p>
              </>
            )}
          </div>
        ))}
        {!locked && revealed < steps.length && (
          <button
            type="button"
            className="btn btn-reveal"
            onClick={() => {
              const nextIsSolution = steps[revealed]?.kind === 'section' && /^(Naive|Optimized) solution/i.test(steps[revealed]?.heading ?? '')
              if (nextIsSolution && !wroteSomething && !confirm('You haven’t written an attempt yet. Show the solution anyway?')) return
              reveal()
            }}
          >
            Reveal: {steps[revealed]?.heading}
          </button>
        )}
        {!locked && revealed >= steps.length && steps.length > 0 && <p className="muted small">Everything is revealed.</p>}
      </section>

      <section aria-labelledby="eval">
        <h2 id="eval" className="section-title">Self-assessment</h2>
        <p className="muted">
          Run the tests before you check the first box. Code that “looks right” doesn’t count.
        </p>
        <Rubric
          key={mode}
          items={mode === 'entrevista' ? ['My solution passes every test in Xcode or with swift test', ...INTERVIEW_RUBRIC, ...c.rubric] : ['My solution passes every test in Xcode or with swift test', ...c.rubric]}
          onSubmit={(score) => {
            const result = scoreToResult(score)
            void recordAttempt({ kind: 'reto', refId: c.id, result, score, grading: 'autoevaluacion', answer: value, label: c.title })
            void updateChallenge(c.id, { status: result === 'correcto' ? (state?.status === 'dominado' ? 'dominado' : 'resuelto') : 'intentado' })
          }}
        />
        {state?.status === 'resuelto' && (
          <button type="button" className="btn btn-quiet" onClick={() => void updateChallenge(c.id, { status: 'dominado' })}>
            I solved it again without help: mark as mastered
          </button>
        )}
      </section>

      <section aria-labelledby="followups">
        <h2 id="followups" className="section-title">Interviewer follow-up questions</h2>
        <ul>
          {c.followUps.map((f) => (
            <li key={f}>
              <Markdown text={f} className="inline-md" />
            </li>
          ))}
        </ul>
      </section>

      <NotesPanel type="reto" id={c.id} />
    </div>
  )
}

function formatClock(totalSeconds: number) {
  const s = Math.abs(totalSeconds)
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`
}

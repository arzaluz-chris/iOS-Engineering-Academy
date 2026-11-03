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

const STATUS_LABEL: Record<ChallengeState['status'] | 'nuevo', string> = { nuevo: 'Sin empezar', intentado: 'Intentado', resuelto: 'Resuelto', dominado: 'Dominado' }

export function ChallengesPage({ query }: { query: URLSearchParams }) {
  const diff = query.get('dificultad') ?? 'todas'
  const pattern = query.get('patron') ?? 'todos'
  const status = query.get('estado') ?? 'todos'
  const states = useLiveQuery(() => db.challenges.toArray(), []) ?? []
  const attempts = useLiveQuery(() => db.attempts.where('kind').equals('reto').toArray(), []) ?? []
  const byId = new Map(states.map((s) => [s.challengeId, s]))
  const latest = latestByRef(attempts)
  const patterns = [...new Set(content.challenges.flatMap((c) => c.patterns))].sort((a, b) => a.localeCompare(b, 'es'))

  const set = (k: string, v: string) => {
    const q = new URLSearchParams(query)
    if (v === 'todos' || v === 'todas') q.delete(k)
    else q.set(k, v)
    navigate(`/retos${q.toString() ? `?${q}` : ''}`)
  }

  const rows = content.challenges.filter((c) => {
    const st = byId.get(c.id)?.status ?? 'nuevo'
    const failed = latest.get(c.id) && latest.get(c.id)?.result !== 'correcto'
    return (
      (diff === 'todas' || c.difficulty === diff) &&
      (pattern === 'todos' || c.patterns.includes(pattern)) &&
      (status === 'todos' || (status === 'fallados' ? failed : st === status))
    )
  })

  return (
    <div className="page">
      <PageHeader title="Retos de código">
        <p>
          Problemas de entrevista resueltos en Swift. Intenta primero; las pistas, el enfoque y la solución se revelan uno a uno. Cada solución vive en el paquete <code>swift/</code> del
          repositorio con sus pruebas, y CI las compila y ejecuta en macOS.
        </p>
      </PageHeader>
      <div className="filters" role="group" aria-label="Filtros">
        <label>
          Dificultad
          <select value={diff} onChange={(e) => set('dificultad', e.target.value)}>
            <option value="todas">Todas</option>
            <option value="facil">Fácil</option>
            <option value="medio">Medio</option>
            <option value="dificil">Difícil</option>
          </select>
        </label>
        <label>
          Patrón
          <select value={pattern} onChange={(e) => set('patron', e.target.value)}>
            <option value="todos">Todos</option>
            {patterns.map((p) => (
              <option key={p}>{p}</option>
            ))}
          </select>
        </label>
        <label>
          Estado
          <select value={status} onChange={(e) => set('estado', e.target.value)}>
            <option value="todos">Todos</option>
            <option value="nuevo">Sin empezar</option>
            <option value="intentado">Intentados</option>
            <option value="resuelto">Resueltos</option>
            <option value="dominado">Dominados</option>
            <option value="fallados">Fallados (para repasar)</option>
          </select>
        </label>
      </div>
      {rows.length === 0 ? (
        <Empty title="Ningún reto coincide con los filtros" />
      ) : (
        <table className="data-table">
          <thead>
            <tr>
              <th scope="col">Reto</th>
              <th scope="col">Dificultad</th>
              <th scope="col">Patrones</th>
              <th scope="col">Estado</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((c) => {
              const st = byId.get(c.id)?.status ?? 'nuevo'
              const last = latest.get(c.id)
              return (
                <tr key={c.id}>
                  <td>
                    <a href={`#/reto/${c.id}`}>{c.title}</a>
                    <p className="muted small">{c.summary}</p>
                  </td>
                  <td>{DIFFICULTY_LABEL[c.difficulty]}</td>
                  <td className="small">{c.patterns.join(', ')}</td>
                  <td>
                    <Badge tone={st === 'dominado' || st === 'resuelto' ? 'ok' : st === 'intentado' ? 'warn' : 'neutral'}>{STATUS_LABEL[st]}</Badge>
                    {last && last.result !== 'correcto' && <span className="muted small"> último: {RESULT_LABEL[last.result].toLowerCase()}</span>}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      )}

      <section aria-labelledby="by-pattern">
        <h2 id="by-pattern" className="section-title">Repaso por patrón</h2>
        <p className="muted">Reconocer el patrón a partir del enunciado es la mitad del trabajo. Repasa los retos agrupados por la técnica que los resuelve.</p>
        <dl className="patterns">
          {patterns.map((p) => (
            <div key={p}>
              <dt>
                <a href={`#/retos?patron=${encodeURIComponent(p)}`}>{p}</a>
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
  guiado: 'Puedes revelar pistas y secciones cuando quieras, una a la vez.',
  independiente: 'Las pistas se desbloquean cuando hayas escrito un intento propio.',
  entrevista: 'Sin pistas hasta terminar. Piensa en voz alta: aclara el problema, propone una solución, analiza complejidad y prueba casos límite.',
}

const INTERVIEW_RUBRIC = [
  'Hice preguntas aclaratorias antes de escribir código',
  'Expliqué en voz alta un enfoque antes de implementarlo',
  'Recorrí al menos un ejemplo a mano',
  'Consideré los casos límite',
  'Di la complejidad temporal y espacial correcta',
]

export function ChallengePage({ id }: { id: string }) {
  const c = getChallenge(id)
  if (!c) return <Empty title="Reto no encontrado"><a href="#/retos">Volver a los retos</a></Empty>
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
  const steps = [...c.hints.map((h, i) => ({ heading: `Pista ${i + 1}`, body: h, kind: 'hint' as const })), ...c.reveal.map((s) => ({ ...s, kind: 'section' as const }))]
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
      <PageHeader kicker={<><a href="#/retos">Retos de código</a> / {DIFFICULTY_LABEL[c.difficulty]}</>} title={c.title}>
        <p>{c.summary}</p>
      </PageHeader>
      <div className="row">
        {c.patterns.map((p) => (
          <Badge key={p}>{p}</Badge>
        ))}
        <Badge tone={c.codeStatus === 'probado' ? 'ok' : 'neutral'}>{CODE_STATUS_LABEL[c.codeStatus]}</Badge>
        {state && <Badge tone={state.status === 'intentado' ? 'warn' : 'ok'}>{STATUS_LABEL[state.status]}</Badge>}
        {last && <Badge tone={RESULT_TONE[last.result]}>Última autoevaluación: {RESULT_LABEL[last.result]}</Badge>}
        <BookmarkButton type="reto" id={c.id} />
      </div>

      {c.prerequisites.length > 0 && (
        <p className="prereq">
          Conviene haber visto:{' '}
          {c.prerequisites.map((p, i) => (
            <span key={p}>
              {i > 0 && ', '}
              <a href={getLesson(p) ? `#/leccion/${p}` : `#/modulo/${p}`}>{getLesson(p)?.title ?? `Módulo ${getModule(p)?.number}. ${getModule(p)?.title}`}</a>
            </span>
          ))}
        </p>
      )}

      <fieldset className="modes">
        <legend>Modo de práctica</legend>
        {(['guiado', 'independiente', 'entrevista'] as Mode[]).map((m) => (
          <label key={m} className="mode">
            <input type="radio" name="mode" checked={mode === m} onChange={() => { setMode(m); setFinished(false); setRevealed(0) }} />
            <span>
              <strong>{m === 'guiado' ? 'Aprendizaje guiado' : m === 'independiente' ? 'Práctica independiente' : 'Simulación de entrevista'}</strong>
              <span className="muted small">{MODE_HELP[m]}</span>
            </span>
          </label>
        ))}
        {mode === 'entrevista' && (
          <div className="row timer">
            <label>
              Cronómetro opcional
              <select value={timerMin} onChange={(e) => setTimerMin(Number(e.target.value))}>
                <option value={0}>Sin límite</option>
                <option value={20}>20 min</option>
                <option value={35}>35 min</option>
                <option value={45}>45 min</option>
              </select>
            </label>
            {!startedAt ? (
              <button type="button" className="btn" onClick={() => setStartedAt(Date.now())}>
                Empezar
              </button>
            ) : (
              <span className={`clock ${remaining !== null && remaining < 0 ? 'over' : ''}`} aria-live="off">
                {formatClock(remaining ?? elapsed)}
                {remaining !== null && remaining < 0 && ' fuera de tiempo'}
              </span>
            )}
            {!finished && (
              <button type="button" className="btn btn-quiet" onClick={() => setFinished(true)}>
                Terminar la entrevista
              </button>
            )}
          </div>
        )}
      </fieldset>

      <section className="statement" aria-labelledby="statement">
        <h2 id="statement" className="section-title">Enunciado</h2>
        <Markdown text={c.statement} />
        <div className="two-col">
          <div>
            <h3 className="sub-title">Casos límite a considerar</h3>
            <ul>
              {c.edgeCases.map((e) => (
                <li key={e}>{e}</li>
              ))}
            </ul>
          </div>
          <div>
            <h3 className="sub-title">Preguntas que conviene hacer al entrevistador</h3>
            <ul>
              {c.askInterviewer.map((e) => (
                <li key={e}>{e}</li>
              ))}
            </ul>
          </div>
        </div>
      </section>

      <section aria-labelledby="attempt">
        <h2 id="attempt" className="section-title">Tu solución</h2>
        <CodeEditor value={value} onChange={onChange} label="Tu solución en Swift" minLines={14} />
        <p className="muted small">
          Se guarda en este navegador. Para ejecutarla: copia tu código a <code>swift/Sources/Challenges/{c.solutionFile}</code> en tu clon del repositorio y corre <code>swift test --filter {c.testFile.replace('.swift', '')}</code>, o pega ambos archivos en un paquete nuevo de Xcode.
        </p>
        <details className="tests">
          <summary>Pruebas que debe pasar tu solución</summary>
          <CodeView code={c.testCode} label={c.testFile} />
        </details>
      </section>

      <section aria-labelledby="reveal">
        <h2 id="reveal" className="section-title">Pistas y solución</h2>
        {locked && (
          <p className="muted">{mode === 'entrevista' ? 'Termina la entrevista para revelar pistas y solución.' : 'Escribe un intento propio en el editor para desbloquear las pistas.'}</p>
        )}
        {steps.slice(0, revealed).map((s, i) => (
          <div key={i} className={s.kind === 'hint' ? 'hint' : 'reveal-section'}>
            {s.kind === 'hint' ? <p className="hint-label">{s.heading}</p> : <h3>{s.heading}</h3>}
            <Markdown text={s.body} />
            {s.kind === 'section' && /^Solución optimizada/i.test(s.heading) && (
              <>
                <CodeView code={c.solutionCode} label={`${c.solutionFile} · ${c.codeStatus === 'probado' ? 'probado en CI' : 'pendiente de prueba'}`} />
                <p className="muted small">
                  Complejidad: tiempo {c.time}; espacio {c.space}.
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
              const nextIsSolution = steps[revealed]?.kind === 'section' && /^Solución/.test(steps[revealed]?.heading ?? '')
              if (nextIsSolution && !wroteSomething && !confirm('Aún no escribes un intento. ¿Revelar la solución de todos modos?')) return
              reveal()
            }}
          >
            Revelar: {steps[revealed]?.heading}
          </button>
        )}
        {!locked && revealed >= steps.length && steps.length > 0 && <p className="muted small">Ya revelaste todo.</p>}
      </section>

      <section aria-labelledby="eval">
        <h2 id="eval" className="section-title">Autoevaluación</h2>
        <p className="muted">
          Corre las pruebas antes de marcar el primer criterio. Que el código "se vea bien" no cuenta.
        </p>
        <Rubric
          key={mode}
          items={mode === 'entrevista' ? ['Mi solución pasa todas las pruebas en Xcode o con swift test', ...INTERVIEW_RUBRIC, ...c.rubric] : ['Mi solución pasa todas las pruebas en Xcode o con swift test', ...c.rubric]}
          onSubmit={(score) => {
            const result = scoreToResult(score)
            void recordAttempt({ kind: 'reto', refId: c.id, result, score, grading: 'autoevaluacion', answer: value, label: c.title })
            void updateChallenge(c.id, { status: result === 'correcto' ? (state?.status === 'dominado' ? 'dominado' : 'resuelto') : 'intentado' })
          }}
        />
        {state?.status === 'resuelto' && (
          <button type="button" className="btn btn-quiet" onClick={() => void updateChallenge(c.id, { status: 'dominado' })}>
            Lo resolví sin ayuda otra vez: marcar como dominado
          </button>
        )}
      </section>

      <section aria-labelledby="followups">
        <h2 id="followups" className="section-title">Preguntas de seguimiento del entrevistador</h2>
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

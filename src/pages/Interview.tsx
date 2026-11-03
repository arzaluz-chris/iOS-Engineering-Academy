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
  memoria: 'Memoria y ARC',
  uikit: 'UIKit',
  swiftui: 'SwiftUI',
  concurrencia: 'Concurrencia',
  arquitectura: 'Arquitectura y diseño',
  testing: 'Testing',
  seguridad: 'Seguridad',
  'system-design': 'Mobile system design',
}

export function InterviewPage() {
  const attempts = useLiveQuery(() => db.attempts.where('kind').equals('entrevista').toArray(), []) ?? []
  const states = useLiveQuery(() => db.questions.toArray(), []) ?? []
  const latest = latestByRef(attempts)
  const mastered = new Set(states.filter((s) => s.status === 'dominada').map((s) => s.questionId))
  const [cat, setCat] = useState('todas')
  const [dif, setDif] = useState('todas')
  const [n, setN] = useState(5)
  const cats = (Object.keys(CATEGORY_LABEL) as InterviewCategory[]).filter((c) => content.questions.some((q) => q.category === c))
  const failed = content.questions.filter((q) => latest.get(q.id) && latest.get(q.id)?.result !== 'correcto')

  return (
    <div className="page">
      <PageHeader title="Entrevistas técnicas">
        <p>
          Preguntas como las de un entrevistador de iOS: una a la vez, respondes antes de ver la respuesta modelo y después enfrentas preguntas de seguimiento. Tú evalúas tu respuesta
          contra los puntos clave; sé estricto.
        </p>
      </PageHeader>

      <section className="sim-form" aria-labelledby="sim">
        <h2 id="sim" className="section-title">Nueva simulación</h2>
        <div className="filters">
          <label>
            Categoría
            <select value={cat} onChange={(e) => setCat(e.target.value)}>
              <option value="todas">Todas</option>
              {cats.map((c) => (
                <option key={c} value={c}>
                  {CATEGORY_LABEL[c]}
                </option>
              ))}
            </select>
          </label>
          <label>
            Dificultad
            <select value={dif} onChange={(e) => setDif(e.target.value)}>
              <option value="todas">Todas</option>
              <option value="facil">Fácil</option>
              <option value="medio">Medio</option>
              <option value="dificil">Difícil</option>
            </select>
          </label>
          <label>
            Preguntas
            <select value={n} onChange={(e) => setN(Number(e.target.value))}>
              {[1, 3, 5, 8].map((x) => (
                <option key={x} value={x}>
                  {x}
                </option>
              ))}
            </select>
          </label>
          <button type="button" className="btn btn-primary" onClick={() => navigate(`/entrevistas/simulacion?cat=${cat}&dif=${dif}&n=${n}&s=${Date.now()}`)}>
            Comenzar simulación
          </button>
          <button type="button" className="btn" disabled={failed.length === 0} onClick={() => navigate(`/entrevistas/simulacion?fallados=1&n=${failed.length}&s=${Date.now()}`)}>
            Repetir falladas ({failed.length})
          </button>
        </div>
      </section>

      <section aria-labelledby="by-cat">
        <h2 id="by-cat" className="section-title">Resultado por categoría</h2>
        <table className="data-table">
          <thead>
            <tr>
              <th scope="col">Categoría</th>
              <th scope="col">Preguntas</th>
              <th scope="col">Respondidas</th>
              <th scope="col">Correctas (último intento)</th>
              <th scope="col">Dominadas</th>
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
        <h2 id="bank" className="section-title">Banco de preguntas</h2>
        {cats.map((c) => (
          <div key={c} className="q-group">
            <h3 className="sub-title">{CATEGORY_LABEL[c]}</h3>
            <ul className="plain-list">
              {content.questions
                .filter((q) => q.category === c)
                .map((q) => (
                  <li key={q.id}>
                    <a href={`#/entrevistas/pregunta/${q.id}`}>{q.question}</a> <span className="muted small">{DIFFICULTY_LABEL[q.difficulty]}</span>
                    {mastered.has(q.id) && <Badge tone="ok">Dominada</Badge>}
                    {latest.get(q.id) && latest.get(q.id)?.result !== 'correcto' && <Badge tone="warn">Por repasar</Badge>}
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
    const cat = query.get('cat') ?? 'todas'
    const dif = query.get('dif') ?? 'todas'
    const pool = query.get('fallados')
      ? content.questions.filter((q) => latest.get(q.id) && latest.get(q.id)?.result !== 'correcto')
      : content.questions.filter((q) => (cat === 'todas' || q.category === cat) && (dif === 'todas' || q.difficulty === dif))
    return shuffle(pool, seed).slice(0, Number(query.get('n') ?? 5))
    // La selección se fija al iniciar la simulación.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [attempts === undefined, seed])
  const [index, setIndex] = useState(0)
  const [results, setResults] = useState<{ id: string; score: number }[]>([])

  if (!questions) return <div className="page" aria-busy="true" />
  if (questions.length === 0)
    return (
      <div className="page">
        <Empty title="No hay preguntas con esos filtros">
          <a href="#/entrevistas">Volver a entrevistas</a>
        </Empty>
      </div>
    )

  if (index >= questions.length) {
    const avg = results.reduce((s, r) => s + r.score, 0) / Math.max(1, results.length)
    return (
      <div className="page">
        <PageHeader title="Simulación terminada">
          <p>Promedio de puntos clave cubiertos: {Math.round(avg * 100)}%.</p>
        </PageHeader>
        <table className="data-table">
          <thead>
            <tr>
              <th scope="col">Pregunta</th>
              <th scope="col">Categoría</th>
              <th scope="col">Puntos clave cubiertos</th>
            </tr>
          </thead>
          <tbody>
            {results.map((r) => {
              const q = getQuestion(r.id)
              return (
                <tr key={r.id}>
                  <td>
                    <a href={`#/entrevistas/pregunta/${r.id}`}>{q?.question}</a>
                  </td>
                  <td>{q && CATEGORY_LABEL[q.category]}</td>
                  <td>{Math.round(r.score * 100)}%</td>
                </tr>
              )
            })}
          </tbody>
        </table>
        <p>Las preguntas con menos del 100% quedaron en tu repaso.</p>
        <a className="btn" href="#/entrevistas">
          Volver a entrevistas
        </a>
      </div>
    )
  }

  const q = questions[index] as InterviewQuestion
  return (
    <div className="page">
      <PageHeader kicker={<><a href="#/entrevistas">Entrevistas</a> / Simulación</>} title={`Pregunta ${index + 1} de ${questions.length}`} />
      <QuestionRunner
        key={q.id}
        q={q}
        onDone={(score) => {
          setResults((r) => [...r, { id: q.id, score }])
          setIndex((i) => i + 1)
        }}
        nextLabel={index + 1 < questions.length ? 'Siguiente pregunta' : 'Ver resultado'}
      />
    </div>
  )
}

export function QuestionPage({ id }: { id: string }) {
  const q = getQuestion(id)
  const [round, setRound] = useState(0)
  if (!q) return <Empty title="Pregunta no encontrada"><a href="#/entrevistas">Volver</a></Empty>
  return (
    <div className="page">
      <PageHeader kicker={<><a href="#/entrevistas">Entrevistas</a> / {CATEGORY_LABEL[q.category]}</>} title="Pregunta de entrevista" />
      <QuestionRunner key={`${q.id}-${round}`} q={q} onDone={() => setRound((r) => r + 1)} nextLabel="Responder de nuevo" />
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
        {state?.status === 'dominada' && <Badge tone="ok">Dominada</Badge>}
      </div>
      <h2 className="q-text">{q.question}</h2>
      {phase === 'answer' && (
        <>
          <p className="muted">Responde como lo harías en voz alta frente al entrevistador. Escribirlo te obliga a ordenar el razonamiento.</p>
          <CodeEditor value={answer} onChange={setAnswer} language={q.writesCode ? 'swift' : 'text'} label="Tu respuesta" minLines={q.writesCode ? 12 : 6} />
          <button type="button" className="btn btn-primary" disabled={!answer.trim()} onClick={() => setPhase('review')}>
            Ver la respuesta modelo
          </button>
          <button type="button" className="btn btn-quiet" onClick={() => confirm('Ver la respuesta sin contestar cuenta como intento sin respuesta. ¿Continuar?') && setPhase('review')}>
            No sé la respuesta
          </button>
        </>
      )}
      {phase !== 'answer' && (
        <>
          {answer.trim() && (
            <details>
              <summary>Tu respuesta</summary>
              <pre className="answer-echo">{answer}</pre>
            </details>
          )}
          <div className="model-answer">
            <h3>Respuesta modelo</h3>
            <Markdown text={q.answer} />
          </div>
          {score === null ? (
            <Rubric
              items={q.keyPoints}
              submitLabel="Registrar puntos cubiertos"
              onSubmit={(s) => {
                setScore(s)
                void recordAttempt({ kind: 'entrevista', refId: q.id, result: scoreToResult(s), score: s, grading: 'autoevaluacion', answer, label: q.question })
                setPhase('followups')
              }}
            />
          ) : (
            <p className="verdict" role="status">
              Cubriste {Math.round(score * 100)}% de los puntos clave.
            </p>
          )}
          {phase === 'followups' && q.followUps.length > 0 && (
            <section className="followups" aria-label="Preguntas de seguimiento">
              <h3>Seguimiento del entrevistador</h3>
              {q.followUps.slice(0, follow + 1).map((f, i) => (
                <div key={i} className="followup">
                  <p className="q-follow">{f.question}</p>
                  {i < follow || followShown ? <Markdown text={f.answer} /> : (
                    <button type="button" className="btn btn-quiet" onClick={() => setFollowShown(true)}>
                      Piensa tu respuesta y después revela
                    </button>
                  )}
                </div>
              ))}
              {followShown && follow + 1 < q.followUps.length && (
                <button type="button" className="btn" onClick={() => { setFollow((f) => f + 1); setFollowShown(false) }}>
                  Siguiente seguimiento
                </button>
              )}
            </section>
          )}
          {q.related.length > 0 && (
            <p className="muted small">
              Relacionado:{' '}
              {q.related.map((r, i) => (
                <span key={r}>
                  {i > 0 && ', '}
                  <a href={getLesson(r) ? `#/leccion/${r}` : getChallenge(r) ? `#/reto/${r}` : `#/modulo/${r}`}>{getLesson(r)?.title ?? getChallenge(r)?.title ?? getModule(r)?.title}</a>
                </span>
              ))}
            </p>
          )}
          {phase === 'followups' && (
            <div className="row">
              <button type="button" className="btn" onClick={() => void setQuestionStatus(q.id, state?.status === 'dominada' ? 'pendiente' : 'dominada')}>
                {state?.status === 'dominada' ? 'Marcar como pendiente' : 'Marcar como dominada'}
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

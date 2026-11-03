import { useLiveQuery } from 'dexie-react-hooks'
import { useEffect, useMemo, useRef, useState } from 'react'
import { CodeEditor } from '../components/CodeEditor'
import { CodeView, Markdown } from '../components/Markdown'
import { Badge, NotesPanel, RESULT_LABEL, RESULT_TONE, Reveal, Rubric, scoreToResult } from '../components/ui'
import type { Exercise } from '../content/schema'
import { AUTO_TYPES } from '../content/schema'
import { recordAttempt, saveDraft } from '../db/actions'
import { db, type AttemptResult } from '../db/db'
import { gradeBlanks, gradeChoices, gradePrediction, splitBlanks } from './grade'

export const TYPE_LABEL: Record<Exercise['type'], string> = {
  comprension: 'Comprensión',
  prediccion: 'Predicción',
  completar: 'Completar código',
  errores: 'Encontrar errores',
  resolver: 'Resolver un problema',
  explicar: 'Explicar una solución',
  refactorizar: 'Refactorización',
  diseno: 'Diseño',
}

const TYPE_LETTER: Record<Exercise['type'], string> = {
  comprension: 'A',
  prediccion: 'B',
  completar: 'C',
  errores: 'D',
  resolver: 'E',
  explicar: 'F',
  refactorizar: 'G',
  diseno: 'H',
}

export function ExerciseBlock({ exercise, label }: { exercise: Exercise; label: string }) {
  const attempts = useLiveQuery(() => db.attempts.where('refId').equals(exercise.id).sortBy('at'), [exercise.id]) ?? []
  const last = attempts.at(-1)
  const auto = AUTO_TYPES.includes(exercise.type)
  const record = (result: AttemptResult, score: number, grading: 'automatica' | 'autoevaluacion', answer?: string) =>
    recordAttempt({ kind: 'ejercicio', refId: exercise.id, result, score, grading, answer, label })

  return (
    <section className="exercise" id={exercise.id} aria-labelledby={`${exercise.id}-t`}>
      <header className="exercise-head">
        <h3 id={`${exercise.id}-t`}>
          <span className="exercise-type">
            Tipo {TYPE_LETTER[exercise.type]} · {TYPE_LABEL[exercise.type]}
          </span>
        </h3>
        <div className="row">
          <Badge tone={auto ? 'accent' : 'neutral'}>{auto ? 'Calificación automática' : 'Autoevaluación con rúbrica'}</Badge>
          {last && <Badge tone={RESULT_TONE[last.result]}>Último intento: {RESULT_LABEL[last.result]}</Badge>}
          {attempts.length > 0 && <span className="muted small">{attempts.length} intento{attempts.length === 1 ? '' : 's'}</span>}
        </div>
      </header>
      <Markdown text={exercise.prompt} />
      <Body exercise={exercise} record={record} attempted={attempts.length > 0} />
      {exercise.hints.length > 0 && <Hints hints={exercise.hints} />}
      <div className="solution">
        <Reveal
          label="Mostrar solución explicada"
          confirmText={attempts.length === 0 ? 'Todavía no registras un intento. ¿Quieres ver la solución de todos modos?' : undefined}
        >
          <h4>Solución</h4>
          <Markdown text={exercise.solution} />
        </Reveal>
      </div>
      <details className="exercise-notes">
        <summary>Notas de este ejercicio</summary>
        <NotesPanel type="ejercicio" id={exercise.id} title="Notas del ejercicio" />
      </details>
    </section>
  )
}

type RecordFn = (result: AttemptResult, score: number, grading: 'automatica' | 'autoevaluacion', answer?: string) => Promise<void>

function Body({ exercise: e, record, attempted }: { exercise: Exercise; record: RecordFn; attempted: boolean }) {
  switch (e.type) {
    case 'comprension':
      return <Choices choices={e.choices} multiple={e.multiple} record={record} />
    case 'prediccion':
      return <Prediction code={e.code} lang={e.lang} output={e.output} accept={e.accept} record={record} />
    case 'completar':
      return <Blanks code={e.code} blanks={e.blanks} record={record} />
    case 'errores':
      return (
        <>
          <CodeView code={e.code} label="Código con problemas" />
          <Choices choices={e.choices} multiple record={record} prompt="Selecciona todos los problemas reales:" />
          <SelfGraded id={e.id} starter={e.code} rubric={e.rubric} record={record} editorLabel="Escribe la versión corregida" attempted={attempted} />
        </>
      )
    case 'resolver':
      return (
        <>
          <SelfGraded id={e.id} starter={e.starter} rubric={e.rubric} record={record} editorLabel="Tu solución en Swift" attempted={attempted} />
          {e.tests && (
            <details className="tests">
              <summary>Pruebas para ejecutar en Xcode o con swift test</summary>
              <CodeView code={e.tests} label="Swift Testing" />
              <p className="muted small">
                El navegador no compila Swift. Copia tu solución y estas pruebas a un Swift Package (por ejemplo en <code>swift/</code> del repositorio) y ejecuta <code>swift test</code>.
              </p>
            </details>
          )}
        </>
      )
    case 'explicar':
      return (
        <>
          <CodeView code={e.code} />
          <SelfGraded id={e.id} starter="" rubric={e.rubric} record={record} editorLabel="Tu explicación" language="text" attempted={attempted} />
        </>
      )
    case 'refactorizar':
      return (
        <>
          <CodeView code={e.code} label="Código original" />
          <SelfGraded id={e.id} starter={e.code} rubric={e.rubric} record={record} editorLabel="Tu versión refactorizada" attempted={attempted} />
        </>
      )
    case 'diseno':
      return <SelfGraded id={e.id} starter="" rubric={e.rubric} record={record} editorLabel="Tu diseño" language="text" attempted={attempted} />
  }
}

function Choices({ choices, multiple, record, prompt }: { choices: { text: string; correct: boolean; why?: string }[]; multiple: boolean; record: RecordFn; prompt?: string }) {
  const [selected, setSelected] = useState<number[]>([])
  const [checked, setChecked] = useState<boolean | null>(null)
  const name = useMemo(() => `c${Math.random().toString(36).slice(2)}`, [])
  const toggle = (i: number) => {
    setChecked(null)
    setSelected((s) => (multiple ? (s.includes(i) ? s.filter((x) => x !== i) : [...s, i]) : [i]))
  }
  return (
    <fieldset className="choices">
      <legend className={prompt ? '' : 'sr-only'}>{prompt ?? 'Opciones'}</legend>
      {choices.map((c, i) => {
        const state = checked === null ? '' : c.correct ? 'is-correct' : selected.includes(i) ? 'is-wrong' : ''
        return (
          <label key={i} className={`choice ${state}`}>
            <input type={multiple ? 'checkbox' : 'radio'} name={name} checked={selected.includes(i)} onChange={() => toggle(i)} />
            <span>
              <Markdown text={c.text} className="inline-md" />
              {checked !== null && c.why && (selected.includes(i) || c.correct) && <span className="why">{c.why}</span>}
            </span>
          </label>
        )
      })}
      <div className="row">
        <button
          type="button"
          className="btn"
          disabled={selected.length === 0}
          onClick={() => {
            const ok = gradeChoices(selected, choices.map((c) => c.correct))
            setChecked(ok)
            void record(ok ? 'correcto' : 'incorrecto', ok ? 1 : 0, 'automatica', JSON.stringify(selected))
          }}
        >
          Comprobar respuesta
        </button>
        {checked !== null && <Verdict ok={checked} />}
      </div>
    </fieldset>
  )
}

function Verdict({ ok }: { ok: boolean }) {
  return (
    <span className={`verdict ${ok ? 'ok' : 'bad'}`} role="status">
      {ok ? 'Correcto.' : 'No es correcto. Revisa las explicaciones e inténtalo de nuevo.'}
    </span>
  )
}

function Prediction({ code, lang, output, accept, record }: { code: string; lang: 'swift' | 'pseudo'; output: string; accept: string[]; record: RecordFn }) {
  const [answer, setAnswer] = useState('')
  const [checked, setChecked] = useState<boolean | null>(null)
  return (
    <div className="prediction">
      <CodeView code={code} lang={lang} />
      <label className="field">
        <span>
          {lang === 'pseudo'
            ? '¿Qué muestra este algoritmo? Escribe la salida exacta, una línea por cada «Muestra».'
            : '¿Qué imprime este programa? Escribe la salida exacta, una línea por cada print.'}
        </span>
        <textarea className="mono" rows={Math.max(3, output.split('\n').length + 1)} value={answer} onChange={(e) => { setAnswer(e.target.value); setChecked(null) }} spellCheck={false} />
      </label>
      <div className="row">
        <button
          type="button"
          className="btn"
          disabled={!answer.trim()}
          onClick={() => {
            const ok = gradePrediction(answer, output, accept)
            setChecked(ok)
            void record(ok ? 'correcto' : 'incorrecto', ok ? 1 : 0, 'automatica', answer)
          }}
        >
          Comprobar salida
        </button>
        {checked !== null && <Verdict ok={checked} />}
      </div>
      {checked === false && (
        <Reveal label="Ver la salida esperada">
          <CodeView code={output} lang="output" label="Salida esperada" />
        </Reveal>
      )}
    </div>
  )
}

function Blanks({ code, blanks, record }: { code: string; blanks: { id: string; answers: string[] }[]; record: RecordFn }) {
  const parts = useMemo(() => splitBlanks(code), [code])
  const [values, setValues] = useState<Record<string, string>>({})
  const [result, setResult] = useState<Record<string, boolean> | null>(null)
  return (
    <div className="blanks">
      <pre className="code-blanks">
        <code>
          {parts.map((p, i) =>
            p.kind === 'text' ? (
              <span key={i}>{p.text}</span>
            ) : (
              <input
                key={i}
                className={`blank ${result ? (result[p.id] ? 'is-correct' : 'is-wrong') : ''}`}
                aria-label={`Hueco ${p.id}`}
                size={Math.max(4, (values[p.id] ?? '').length + 1)}
                value={values[p.id] ?? ''}
                spellCheck={false}
                autoCapitalize="off"
                onChange={(e) => { setValues((v) => ({ ...v, [p.id]: e.target.value })); setResult(null) }}
              />
            ),
          )}
        </code>
      </pre>
      <div className="row">
        <button
          type="button"
          className="btn"
          onClick={() => {
            const r = gradeBlanks(values, blanks)
            setResult(r)
            const ok = Object.values(r).filter(Boolean).length
            const score = ok / blanks.length
            void record(score === 1 ? 'correcto' : score > 0 ? 'parcial' : 'incorrecto', score, 'automatica', JSON.stringify(values))
          }}
        >
          Comprobar huecos
        </button>
        {result && <Verdict ok={Object.values(result).every(Boolean)} />}
      </div>
    </div>
  )
}

function SelfGraded({ id, starter, rubric, record, editorLabel, language = 'swift', attempted }: { id: string; starter: string; rubric: string[]; record: RecordFn; editorLabel: string; language?: 'swift' | 'text'; attempted: boolean }) {
  const draft = useLiveQuery(() => db.drafts.get(id), [id])
  const [code, setCode] = useState<string | null>(null)
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)
  const [graded, setGraded] = useState<number | null>(null)

  useEffect(() => () => clearTimeout(timer.current), [])
  const value = code ?? draft?.code ?? starter

  const onChange = (v: string) => {
    setCode(v)
    clearTimeout(timer.current)
    timer.current = setTimeout(() => void saveDraft(id, v), 500)
  }

  return (
    <div className="self-graded">
      <p className="field-label">{editorLabel}</p>
      <CodeEditor value={value} onChange={onChange} language={language} label={editorLabel} />
      <p className="muted small">
        Se guarda automáticamente en este navegador{draft ? ` (último guardado: ${new Date(draft.updatedAt).toLocaleTimeString('es-MX', { timeStyle: 'short' })})` : ''}.
        {language === 'swift' && ' El navegador no ejecuta Swift: compila y prueba en Xcode.'}
      </p>
      <Rubric
        items={rubric}
        submitLabel={attempted ? 'Registrar nueva autoevaluación' : 'Registrar autoevaluación'}
        onSubmit={(score) => {
          setGraded(score)
          void record(scoreToResult(score), score, 'autoevaluacion', value)
        }}
      />
      {graded !== null && (
        <p className="verdict" role="status">
          Autoevaluación registrada: {Math.round(graded * 100)}% de los criterios. {graded < 1 && 'El ejercicio queda en tu repaso.'}
        </p>
      )}
    </div>
  )
}

function Hints({ hints }: { hints: string[] }) {
  const [shown, setShown] = useState(0)
  return (
    <div className="hints">
      {hints.slice(0, shown).map((h, i) => (
        <div key={i} className="hint">
          <p className="hint-label">Pista {i + 1}</p>
          <Markdown text={h} />
        </div>
      ))}
      {shown < hints.length && (
        <button type="button" className="btn btn-quiet" onClick={() => setShown((n) => n + 1)}>
          {shown === 0 ? 'Ver una pista' : 'Ver otra pista'} ({shown}/{hints.length})
        </button>
      )}
    </div>
  )
}

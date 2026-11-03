import { useLiveQuery } from 'dexie-react-hooks'
import { useEffect, useMemo } from 'react'
import { Markdown, slugify } from '../components/Markdown'
import { Badge, BookmarkButton, CODE_STATUS_LABEL, Empty, LEVEL_LABEL, NotesPanel, PageHeader } from '../components/ui'
import { getLesson, getModule, getResource, neighbors } from '../content'
import { completeLesson, reopenLesson, setLessonAnchor, startLesson } from '../db/actions'
import { db } from '../db/db'
import { latestByRef, lessonMastery } from '../db/stats'
import { ExerciseBlock } from '../exercises/ExerciseBlock'

const RESOURCE_KIND = { oficial: 'Documentación oficial', tutorial: 'Tutorial', articulo: 'Artículo complementario', referencia: 'Referencia' } as const

export function LessonPage({ id, focus }: { id: string; focus?: string }) {
  const lesson = getLesson(id)
  const progress = useLiveQuery(() => db.lessons.get(id), [id])
  const attempts = useLiveQuery(() => db.attempts.where('kind').equals('ejercicio').toArray(), []) ?? []
  const prereqProgress = useLiveQuery(() => db.lessons.bulkGet(lesson?.prerequisites ?? []), [id]) ?? []

  useEffect(() => {
    if (lesson) void startLesson(lesson.id, lesson.title)
  }, [lesson])

  // Ir al ejercicio enlazado (#/leccion/x/ejercicio) o retomar la última sección.
  useEffect(() => {
    if (!lesson) return
    const target = focus || undefined
    const t = setTimeout(() => {
      if (target) document.getElementById(target)?.scrollIntoView({ block: 'start' })
    }, 60)
    return () => clearTimeout(t)
  }, [lesson, focus])

  // Registrar la última sección visible para "continuar donde te quedaste".
  useEffect(() => {
    if (!lesson || typeof IntersectionObserver === 'undefined') return
    const headings = [...document.querySelectorAll<HTMLElement>('.lesson-body h2[id]')]
    const obs = new IntersectionObserver(
      (entries) => {
        const visible = entries.find((e) => e.isIntersecting)
        if (visible) void setLessonAnchor(lesson.id, visible.target.id)
      },
      { rootMargin: '0px 0px -70% 0px' },
    )
    headings.forEach((h) => obs.observe(h))
    return () => obs.disconnect()
  }, [lesson])

  const toc = useMemo(
    () =>
      lesson?.segments
        .flatMap((s) => (s.kind === 'md' ? [...s.text.matchAll(/^## (.+)$/gm)].map((m) => m[1] ?? '') : []))
        .map((h) => ({ text: h.replace(/`/g, ''), id: slugify(h.replace(/`/g, '')) })) ?? [],
    [lesson],
  )

  if (!lesson) return <Empty title="Lección no encontrada"><a href="#/curriculo">Volver al currículo</a></Empty>

  const mod = getModule(lesson.module)
  const latest = latestByRef(attempts)
  const mastery = lessonMastery(lesson, latest)
  const allAttempted = mastery.attempted === mastery.total
  const { prev, next } = neighbors(lesson.id)
  let exerciseCount = 0

  return (
    <div className="page lesson-page">
      <div className="lesson-layout">
        <article className="lesson">
          <PageHeader
            kicker={
              <>
                <a href="#/curriculo">Currículo</a> / <a href={`#/modulo/${lesson.module}`}>Módulo {mod?.number}. {mod?.title}</a> / Lección {lesson.order}
              </>
            }
            title={lesson.title}
          >
            <p>{lesson.description}</p>
          </PageHeader>

          <div className="lesson-meta row">
            <Badge>{LEVEL_LABEL[lesson.level]}</Badge>
            <Badge>{lesson.minutes} min aprox.</Badge>
            {lesson.swiftVersion && <Badge>Swift {lesson.swiftVersion}</Badge>}
            <Badge tone={lesson.codeStatus === 'probado' ? 'ok' : 'neutral'}>{CODE_STATUS_LABEL[lesson.codeStatus]}</Badge>
            {progress?.status === 'completada' && <Badge tone={mastery.mastered ? 'ok' : 'accent'}>{mastery.mastered ? 'Dominada' : 'Completada'}</Badge>}
            <BookmarkButton type="leccion" id={lesson.id} />
          </div>

          <section className="lesson-intro" aria-label="Antes de empezar">
            <div>
              <h2 className="section-title">Objetivos</h2>
              <ul>
                {lesson.objectives.map((o) => (
                  <li key={o}>{o}</li>
                ))}
              </ul>
            </div>
            <div>
              <h2 className="section-title">Prerrequisitos</h2>
              {lesson.prerequisites.length === 0 ? (
                <p className="muted">Ninguno. Esta lección parte de cero.</p>
              ) : (
                <ul>
                  {lesson.prerequisites.map((p, i) => {
                    const pl = getLesson(p)
                    const done = prereqProgress[i]?.status === 'completada'
                    return (
                      <li key={p}>
                        <a href={`#/leccion/${p}`}>{pl?.title ?? p}</a> {done ? <Badge tone="ok">Completada</Badge> : <Badge tone="warn">Pendiente</Badge>}
                      </li>
                    )
                  })}
                </ul>
              )}
            </div>
          </section>

          {lesson.terms.length > 0 && (
            <section aria-labelledby="terms">
              <h2 id="terms" className="section-title">Terminología</h2>
              <dl className="terms">
                {lesson.terms.map((t) => (
                  <div key={t.term}>
                    <dt>{t.term}</dt>
                    <dd>{t.definition}</dd>
                  </div>
                ))}
              </dl>
            </section>
          )}

          <div className="lesson-body">
            {lesson.segments.map((s, i) => {
              if (s.kind === 'md') return <Markdown key={i} text={s.text} />
              exerciseCount++
              return <ExerciseBlock key={s.exercise.id} exercise={s.exercise} label={`${lesson.title} · ejercicio ${exerciseCount}`} />
            })}
          </div>

          <section className="mastery" aria-labelledby="mastery">
            <h2 id="mastery">Lo que debes poder hacer ahora</h2>
            <p className="muted">Comprueba cada punto sin mirar la lección. Si alguno te cuesta, vuelve a la sección correspondiente antes de avanzar.</p>
            <ul className="checklist">
              {lesson.mastery.map((m) => (
                <li key={m}>{m}</li>
              ))}
            </ul>
          </section>

          {lesson.resources.length > 0 && (
            <section aria-labelledby="resources">
              <h2 id="resources" className="section-title">Para profundizar</h2>
              <ul className="resources">
                {lesson.resources.map((rid) => {
                  const r = getResource(rid)
                  if (!r) return null
                  return (
                    <li key={rid}>
                      <a href={r.url} target="_blank" rel="noopener noreferrer">
                        {r.title}
                      </a>
                      <span className="muted small">
                        {' '}
                        {r.source} · {RESOURCE_KIND[r.kind]}
                        {r.status === 'verificado' && r.verifiedAt ? ` · verificado el ${r.verifiedAt}` : ' · enlace pendiente de verificación automática'}
                      </span>
                      <p>{r.why}</p>
                    </li>
                  )
                })}
              </ul>
            </section>
          )}

          <section className="complete" aria-labelledby="complete">
            <h2 id="complete" className="section-title">Cerrar la lección</h2>
            <p>
              Ejercicios intentados: {mastery.attempted}/{mastery.total}. Correctos en el último intento: {mastery.correct}/{mastery.total}.
            </p>
            {progress?.status === 'completada' ? (
              <div className="row">
                <span>Lección completada{progress.completedAt ? ` el ${new Date(progress.completedAt).toLocaleDateString('es-MX', { dateStyle: 'long' })}` : ''}.</span>
                <button type="button" className="btn btn-quiet" onClick={() => void reopenLesson(lesson.id)}>
                  Marcar como en curso
                </button>
              </div>
            ) : (
              <>
                <button type="button" className="btn btn-primary" disabled={!allAttempted} onClick={() => void completeLesson(lesson.id, lesson.title, lesson.cards.map((c) => c.id))}>
                  Marcar lección como completada
                </button>
                {!allAttempted && <p className="muted small">Intenta todos los ejercicios antes de completar la lección. No tienen que estar correctos: los fallados pasan a tu repaso.</p>}
                {lesson.cards.length > 0 && <p className="muted small">Al completarla, {lesson.cards.length} conceptos clave entran a tu repaso espaciado.</p>}
              </>
            )}
          </section>

          <NotesPanel type="leccion" id={lesson.id} />

          <nav className="pager" aria-label="Lecciones">
            {prev ? (
              <a href={`#/leccion/${prev.id}`} rel="prev">
                <span className="muted small">Anterior</span>
                {prev.title}
              </a>
            ) : (
              <span />
            )}
            {next && (
              <a href={`#/leccion/${next.id}`} rel="next" className="pager-next">
                <span className="muted small">Siguiente</span>
                {next.title}
              </a>
            )}
          </nav>
        </article>

        {toc.length > 2 && (
          <nav className="toc" aria-label="En esta lección">
            <p className="nav-heading">En esta lección</p>
            <ol>
              {toc.map((t) => (
                <li key={t.id}>
                  <a href={`#/leccion/${lesson.id}/${t.id}`} aria-current={progress?.lastAnchor === t.id ? 'location' : undefined}>
                    {t.text}
                  </a>
                </li>
              ))}
              <li>
                <a href={`#/leccion/${lesson.id}/mastery`}>Lo que debes poder hacer ahora</a>
              </li>
            </ol>
          </nav>
        )}
      </div>
    </div>
  )
}

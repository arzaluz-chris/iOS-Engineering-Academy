import { useLiveQuery } from 'dexie-react-hooks'
import { Markdown } from '../components/Markdown'
import { Badge, Empty, Meter, NotesPanel, PageHeader } from '../components/ui'
import { content, getModule, getProject } from '../content'
import { startProject, toggleMilestone } from '../db/actions'
import { db } from '../db/db'

export function ProjectsPage() {
  const states = useLiveQuery(() => db.projects.toArray(), []) ?? []
  const byId = new Map(states.map((s) => [s.projectId, s]))
  return (
    <div className="page">
      <PageHeader title="Proyectos">
        <p>Ocho proyectos acumulativos. Cada uno se divide en hitos con los conceptos que necesitas. No hay un proyecto terminado para copiar: hay soluciones de referencia por hito cuando las necesites.</p>
      </PageHeader>
      <ol className="project-list">
        {content.projects.map((p) => {
          const st = byId.get(p.id)
          return (
            <li key={p.id}>
              <a href={`#/proyecto/${p.id}`} className="project-link">
                <span className="module-num">Proyecto {p.number}</span>
                <span className="module-title">{p.title}</span>
                <span className="muted small">{p.summary}</span>
                <span className="module-meta">
                  {st ? <Meter value={st.milestonesDone.length} max={p.milestones.length} label={`Hitos de ${p.title}`} /> : <Badge>Sin iniciar</Badge>}
                </span>
              </a>
            </li>
          )
        })}
      </ol>
    </div>
  )
}

export function ProjectPage({ id }: { id: string }) {
  const p = getProject(id)
  const st = useLiveQuery(() => db.projects.get(id), [id])
  if (!p) return <Empty title="Proyecto no encontrado"><a href="#/proyectos">Volver</a></Empty>
  const done = new Set(st?.milestonesDone ?? [])
  return (
    <div className="page">
      <PageHeader kicker={<><a href="#/proyectos">Proyectos</a> / Proyecto {p.number}</>} title={p.title}>
        <p>{p.summary}</p>
      </PageHeader>
      {p.prerequisites.length > 0 && (
        <p className="prereq">
          Requiere:{' '}
          {p.prerequisites.map((m, i) => (
            <span key={m}>
              {i > 0 && ', '}
              <a href={`#/modulo/${m}`}>
                Módulo {getModule(m)?.number}. {getModule(m)?.title}
              </a>
            </span>
          ))}
        </p>
      )}
      <div className="two-col">
        <section>
          <h2 className="section-title">Objetivos</h2>
          <ul>
            {p.objectives.map((o) => (
              <li key={o}>{o}</li>
            ))}
          </ul>
        </section>
        <section>
          <h2 className="section-title">Requisitos</h2>
          <ul>
            {p.requirements.map((o) => (
              <li key={o}>{o}</li>
            ))}
          </ul>
        </section>
      </div>
      <Markdown text={p.body} />
      <section aria-labelledby="milestones">
        <h2 id="milestones" className="section-title">Hitos</h2>
        {!st && (
          <button type="button" className="btn btn-primary" onClick={() => void startProject(p.id, p.title)}>
            Iniciar el proyecto
          </button>
        )}
        <ol className="milestones">
          {p.milestones.map((m) => (
            <li key={m.id} className={done.has(m.id) ? 'is-done' : ''}>
              <label className="check">
                <input type="checkbox" checked={done.has(m.id)} onChange={() => void toggleMilestone(p.id, m.id, p.title)} />
                <strong>{m.title}</strong>
              </label>
              <ul>
                {m.tasks.map((t) => (
                  <li key={t}>{t}</li>
                ))}
              </ul>
              {m.concepts.length > 0 && <p className="muted small">Conceptos: {m.concepts.join(', ')}</p>}
            </li>
          ))}
        </ol>
      </section>
      <section aria-labelledby="acceptance">
        <h2 id="acceptance" className="section-title">Criterios de aceptación</h2>
        <ul className="checklist">
          {p.acceptance.map((a) => (
            <li key={a}>{a}</li>
          ))}
        </ul>
      </section>
      <NotesPanel type="proyecto" id={p.id} />
    </div>
  )
}

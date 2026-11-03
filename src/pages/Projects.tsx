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
      <PageHeader kicker="Build" title="Projects">
        <p>Eight projects, each building on the last. Every one is split into milestones that list the concepts you’ll need. There’s no finished project to copy, but each milestone has a reference solution when you need it.</p>
      </PageHeader>
      <ol className="project-list">
        {content.projects.map((p) => {
          const st = byId.get(p.id)
          return (
            <li key={p.id}>
              <a href={`#/project/${p.id}`} className="project-link">
                <span className="module-num">Project {p.number}</span>
                <span className="module-title">{p.title}</span>
                <span className="muted small">{p.summary}</span>
                <span className="module-meta">
                  {st ? <Meter value={st.milestonesDone.length} max={p.milestones.length} label={`${p.title} milestones`} /> : <Badge>Not started</Badge>}
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
  if (!p) return <Empty title="Project not found"><a href="#/projects">Back</a></Empty>
  const done = new Set(st?.milestonesDone ?? [])
  return (
    <div className="page">
      <PageHeader kicker={<><a href="#/projects">Projects</a> / Project {p.number}</>} title={p.title}>
        <p>{p.summary}</p>
      </PageHeader>
      {p.prerequisites.length > 0 && (
        <p className="prereq">
          Requiere:{' '}
          {p.prerequisites.map((m, i) => (
            <span key={m}>
              {i > 0 && ', '}
              <a href={`#/module/${m}`}>
                Module {getModule(m)?.number}. {getModule(m)?.title}
              </a>
            </span>
          ))}
        </p>
      )}
      <div className="two-col">
        <section>
          <h2 className="section-title">Goals</h2>
          <ul>
            {p.objectives.map((o) => (
              <li key={o}>{o}</li>
            ))}
          </ul>
        </section>
        <section>
          <h2 className="section-title">Requirements</h2>
          <ul>
            {p.requirements.map((o) => (
              <li key={o}>{o}</li>
            ))}
          </ul>
        </section>
      </div>
      <Markdown text={p.body} />
      <section aria-labelledby="milestones">
        <h2 id="milestones" className="section-title">Milestones</h2>
        {!st && (
          <button type="button" className="btn btn-primary" onClick={() => void startProject(p.id, p.title)}>
            Start the project
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
              {m.concepts.length > 0 && <p className="muted small">Concepts: {m.concepts.join(', ')}</p>}
            </li>
          ))}
        </ol>
      </section>
      <section aria-labelledby="acceptance">
        <h2 id="acceptance" className="section-title">Acceptance criteria</h2>
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

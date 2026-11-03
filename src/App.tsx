import { useLiveQuery } from 'dexie-react-hooks'
import { useEffect, useRef, useState } from 'react'
import { content } from './content'
import { db } from './db/db'
import { ChallengePage, ChallengesPage } from './pages/Challenges'
import { CurriculumPage, ModulePage } from './pages/Curriculum'
import { Dashboard } from './pages/Dashboard'
import { ExercisesPage } from './pages/Exercises'
import { InterviewPage, QuestionPage, SimulationPage } from './pages/Interview'
import { LessonPage } from './pages/Lesson'
import { NotesPage } from './pages/Notes'
import { ProjectPage, ProjectsPage } from './pages/Projects'
import { ReviewPage } from './pages/Review'
import { SearchPage } from './pages/Search'
import { SettingsPage } from './pages/Settings'
import { navigate, useRoute, type Route } from './router'

const NAV: { to: string; label: string; match: string[] }[] = [
  { to: '#/', label: 'Inicio', match: [''] },
  { to: '#/curriculo', label: 'Currículo', match: ['curriculo', 'modulo', 'leccion'] },
  { to: '#/ejercicios', label: 'Ejercicios', match: ['ejercicios'] },
  { to: '#/retos', label: 'Retos de código', match: ['retos', 'reto'] },
  { to: '#/entrevistas', label: 'Entrevistas', match: ['entrevistas'] },
  { to: '#/proyectos', label: 'Proyectos', match: ['proyectos', 'proyecto'] },
  { to: '#/repaso', label: 'Repaso', match: ['repaso'] },
  { to: '#/notas', label: 'Notas y marcadores', match: ['notas'] },
  { to: '#/ajustes', label: 'Ajustes y respaldo', match: ['ajustes'] },
]

function Page({ route }: { route: Route }) {
  const [a = '', b = '', c = ''] = route.path
  switch (a) {
    case '':
      return <Dashboard />
    case 'curriculo':
      return <CurriculumPage />
    case 'modulo':
      return <ModulePage id={b} />
    case 'leccion':
      return <LessonPage id={b} focus={c} />
    case 'ejercicios':
      return <ExercisesPage query={route.query} />
    case 'retos':
      return <ChallengesPage query={route.query} />
    case 'reto':
      return <ChallengePage id={b} />
    case 'entrevistas':
      if (b === 'simulacion') return <SimulationPage query={route.query} />
      if (b === 'pregunta') return <QuestionPage id={c} />
      return <InterviewPage />
    case 'proyectos':
      return <ProjectsPage />
    case 'proyecto':
      return <ProjectPage id={b} />
    case 'repaso':
      return <ReviewPage />
    case 'notas':
      return <NotesPage />
    case 'buscar':
      return <SearchPage q={route.query.get('q') ?? ''} />
    case 'ajustes':
      return <SettingsPage />
    default:
      return (
        <div className="page">
          <h1>Esta página no existe</h1>
          <p>
            La dirección <code>{window.location.hash}</code> no corresponde a ningún contenido. <a href="#/">Vuelve al inicio</a> o usa el buscador.
          </p>
        </div>
      )
  }
}

export function App() {
  const route = useRoute()
  const [menuOpen, setMenuOpen] = useState(false)
  const main = useRef<HTMLElement>(null)
  const due = useLiveQuery(() => db.cards.where('dueAt').belowOrEqual(new Date().toISOString()).count(), [route.path.join('/')]) ?? 0
  const searchRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    setMenuOpen(false)
    // Al cambiar de página: arriba y foco en el contenido, salvo anclas internas.
    if (!(route.path[0] === 'leccion' && route.path[2])) window.scrollTo(0, 0)
    main.current?.focus({ preventScroll: true })
    const title = document.querySelector('main h1')?.textContent
    document.title = title ? `${title} · iOS Engineering Academy` : 'iOS Engineering Academy'
  }, [route.path.join('/')])

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const t = e.target as HTMLElement
      const typing = t.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(t.tagName) || t.closest('.cm-editor')
      if (typing) return
      if (e.key === '/') {
        e.preventDefault()
        searchRef.current?.focus()
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  const section = route.path[0] ?? ''

  return (
    <div className={`shell ${menuOpen ? 'menu-open' : ''}`}>
      <a className="skip" href="#contenido" onClick={(e) => { e.preventDefault(); main.current?.focus() }}>
        Saltar al contenido
      </a>
      <header className="topbar">
        <button type="button" className="btn btn-quiet menu-btn" aria-expanded={menuOpen} aria-controls="sidebar" onClick={() => setMenuOpen((o) => !o)}>
          Menú
        </button>
        <a href="#/" className="brand-small">
          iOS Engineering Academy
        </a>
      </header>
      <aside className="sidebar" id="sidebar">
        <a href="#/" className="brand">
          <span className="brand-mark" aria-hidden="true">
            <svg viewBox="0 0 32 32" width="28" height="28">
              <rect width="32" height="32" rx="7" fill="currentColor" />
              <path d="M9 22 16 9l7 13" stroke="var(--bg)" strokeWidth="3" fill="none" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </span>
          <span>
            iOS Engineering
            <br />
            Academy
          </span>
        </a>
        <form
          className="search-box"
          role="search"
          onSubmit={(e) => {
            e.preventDefault()
            const q = searchRef.current?.value.trim()
            if (q) navigate(`/buscar?q=${encodeURIComponent(q)}`)
          }}
        >
          <label htmlFor="global-search" className="sr-only">
            Buscar en el curso
          </label>
          <input id="global-search" ref={searchRef} type="search" placeholder="Buscar  ( / )" autoComplete="off" />
        </form>
        <nav aria-label="Secciones">
          <ul className="nav">
            {NAV.map((n) => (
              <li key={n.to}>
                <a href={n.to} aria-current={n.match.includes(section) ? 'page' : undefined}>
                  {n.label}
                  {n.to === '#/repaso' && due > 0 && <span className="nav-count">{due}</span>}
                </a>
              </li>
            ))}
          </ul>
        </nav>
        <nav aria-label="Etapas del currículo" className="stage-nav">
          <p className="nav-heading">Etapas</p>
          <ol>
            {content.stages.map((s) => (
              <li key={s.id}>
                <a href={`#/curriculo?etapa=${s.id}`} onClick={(e) => { e.preventDefault(); navigate('/curriculo'); setTimeout(() => document.getElementById(s.id)?.scrollIntoView(), 30) }}>
                  <span className="stage-num">{s.number}</span>
                  {s.title}
                </a>
              </li>
            ))}
          </ol>
        </nav>
      </aside>
      <main id="contenido" ref={main} tabIndex={-1}>
        <Page route={route} />
      </main>
    </div>
  )
}

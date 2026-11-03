import { useLiveQuery } from 'dexie-react-hooks'
import { useEffect, useRef, useState } from 'react'
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
import { applyTheme, readTheme, SettingsPage, type Theme } from './pages/Settings'
import { navigate, useRoute, type Route } from './router'

const NAV: { to: string; label: string; match: string[] }[] = [
  { to: '#/curriculum', label: 'Curriculum', match: ['curriculum', 'module', 'lesson'] },
  { to: '#/exercises', label: 'Exercises', match: ['exercises'] },
  { to: '#/challenges', label: 'Challenges', match: ['challenges', 'challenge'] },
  { to: '#/interviews', label: 'Interviews', match: ['interviews'] },
  { to: '#/projects', label: 'Projects', match: ['projects', 'project'] },
  { to: '#/review', label: 'Review', match: ['review'] },
]

function Page({ route }: { route: Route }) {
  const [a = '', b = '', c = ''] = route.path
  switch (a) {
    case '':
      return <Dashboard />
    case 'curriculum':
      return <CurriculumPage />
    case 'module':
      return <ModulePage id={b} />
    case 'lesson':
      return <LessonPage id={b} focus={c} />
    case 'exercises':
      return <ExercisesPage query={route.query} />
    case 'challenges':
      return <ChallengesPage query={route.query} />
    case 'challenge':
      return <ChallengePage id={b} />
    case 'interviews':
      if (b === 'simulation') return <SimulationPage query={route.query} />
      if (b === 'question') return <QuestionPage id={c} />
      return <InterviewPage />
    case 'projects':
      return <ProjectsPage />
    case 'project':
      return <ProjectPage id={b} />
    case 'review':
      return <ReviewPage />
    case 'notes':
      return <NotesPage />
    case 'search':
      return <SearchPage q={route.query.get('q') ?? ''} />
    case 'settings':
      return <SettingsPage />
    default:
      return (
        <div className="page">
          <h1>Page not found</h1>
          <p>
            Nothing lives at <code>{window.location.hash}</code>. <a href="#/">Go home</a> or try searching.
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
    // On navigation: scroll to top and focus the content, except for in-page anchors.
    if (!(route.path[0] === 'lesson' && route.path[2])) window.scrollTo(0, 0)
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
    <div className={`shell ${menuOpen ? 'menu-open' : ''} ${section === '' ? 'is-home' : ''}`}>
      <a className="skip" href="#content" onClick={(e) => { e.preventDefault(); main.current?.focus() }}>
        Skip to content
      </a>
      <header className="site-nav">
        <div className="site-nav-inner">
          <a href="#/" className="brand" aria-label="iOS Engineering Academy, home">
            <BrandMark />
            <span className="brand-name">iOS Engineering Academy</span>
          </a>
          <button type="button" className="menu-btn" aria-expanded={menuOpen} aria-controls="site-menu" onClick={() => setMenuOpen((o) => !o)}>
            <span className="sr-only">Menu</span>
            <svg viewBox="0 0 20 20" width="20" height="20" aria-hidden="true">
              <path d={menuOpen ? 'M4 4l12 12M16 4L4 16' : 'M3 6h14M3 10h14M3 14h14'} stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
            </svg>
          </button>
          <div className="site-menu" id="site-menu">
            <nav aria-label="Sections">
              <ul className="nav">
                {NAV.map((n) => (
                  <li key={n.to}>
                    <a href={n.to} aria-current={n.match.includes(section) ? 'page' : undefined}>
                      {n.label}
                      {n.to === '#/review' && due > 0 && <span className="nav-count" aria-label={`${due} due`}>{due}</span>}
                    </a>
                  </li>
                ))}
              </ul>
            </nav>
            <span className="nav-divider" aria-hidden="true" />
            <form
              className="search-box"
              role="search"
              onSubmit={(e) => {
                e.preventDefault()
                const q = searchRef.current?.value.trim()
                if (q) navigate(`/search?q=${encodeURIComponent(q)}`)
              }}
            >
              <label htmlFor="global-search" className="sr-only">
                Search the course
              </label>
              <input id="global-search" ref={searchRef} type="search" placeholder="Search" autoComplete="off" />
              <kbd aria-hidden="true">/</kbd>
            </form>
          </div>
        </div>
      </header>
      <main id="content" ref={main} tabIndex={-1}>
        <Page route={route} />
      </main>
      <SiteFooter />
    </div>
  )
}

function BrandMark() {
  return (
    <span className="brand-mark" aria-hidden="true">
      <svg viewBox="0 0 32 32" width="30" height="30">
        <defs>
          <linearGradient id="brand-grad" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stopColor="#ff7f00" />
            <stop offset="1" stopColor="#f05238" />
          </linearGradient>
        </defs>
        <rect width="32" height="32" rx="7.5" fill="url(#brand-grad)" />
        <path d="M8.5 22.5 16 8.5l7.5 14" stroke="#fff" strokeWidth="2.8" fill="none" strokeLinecap="round" strokeLinejoin="round" />
        <path d="M11.6 17.5h8.8" stroke="#fff" strokeWidth="2.4" strokeLinecap="round" />
      </svg>
    </span>
  )
}

const FOOTER: { title: string; links: [string, string][] }[] = [
  { title: 'Learn', links: [['Curriculum', '#/curriculum'], ['Exercises', '#/exercises'], ['Coding challenges', '#/challenges']] },
  { title: 'Practice', links: [['Interview prep', '#/interviews'], ['Projects', '#/projects'], ['Spaced review', '#/review']] },
  { title: 'Yours', links: [['Notes and bookmarks', '#/notes'], ['Settings and backup', '#/settings']] },
]

function SiteFooter() {
  return (
    <footer className="site-footer">
      <div className="site-footer-inner">
        <div className="footer-brand">
          <a href="#/" className="brand">
            <BrandMark />
            <span className="brand-name">iOS Engineering Academy</span>
          </a>
          <p>A personal course from zero to professional iOS engineer. Your progress stays in this browser.</p>
        </div>
        {FOOTER.map((col) => (
          <nav key={col.title} aria-label={col.title} className="footer-col">
            <h2>{col.title}</h2>
            <ul>
              {col.links.map(([label, to]) => (
                <li key={to}>
                  <a href={to}>{label}</a>
                </li>
              ))}
            </ul>
          </nav>
        ))}
        <div className="footer-col">
          <h2>Appearance</h2>
          <ThemeSwitch />
        </div>
      </div>
      <div className="site-footer-legal">
        <p>Swift, Xcode, iPhone and iOS are trademarks of Apple Inc. This academy isn’t affiliated with Apple or the Swift project.</p>
      </div>
    </footer>
  )
}

function ThemeSwitch() {
  const [theme, setTheme] = useState<Theme>(readTheme)
  useEffect(() => applyTheme(theme), [theme])
  const options: [Theme, string][] = [['light', 'Light'], ['dark', 'Dark'], ['system', 'Auto']]
  return (
    <div className="theme-switch" role="radiogroup" aria-label="Color scheme">
      {options.map(([value, label]) => (
        <button key={value} type="button" role="radio" aria-checked={theme === value} onClick={() => setTheme(value)}>
          {label}
        </button>
      ))}
    </div>
  )
}

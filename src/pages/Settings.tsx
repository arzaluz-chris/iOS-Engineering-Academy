import { useEffect, useRef, useState } from 'react'
import { PageHeader } from '../components/ui'
import { contentIssues } from '../content'
import { logActivity } from '../db/actions'
import { downloadJson, exportBackup, importBackup, parseBackup, resetAll } from '../db/backup'

export type Theme = 'system' | 'light' | 'dark'

export function readTheme(): Theme {
  try {
    const t = localStorage.getItem('iea:theme')
    return t === 'light' || t === 'dark' ? t : 'system'
  } catch {
    return 'system'
  }
}

export function applyTheme(t: Theme) {
  if (t === 'system') delete document.documentElement.dataset.theme
  else document.documentElement.dataset.theme = t
  try {
    if (t === 'system') localStorage.removeItem('iea:theme')
    else localStorage.setItem('iea:theme', t)
  } catch {
    /* storage unavailable: the theme only lasts for this session */
  }
}

export function SettingsPage() {
  const [theme, setTheme] = useState<Theme>(readTheme)
  const [message, setMessage] = useState<{ tone: 'ok' | 'bad'; text: string } | null>(null)
  const file = useRef<HTMLInputElement>(null)

  useEffect(() => applyTheme(theme), [theme])

  return (
    <div className="page settings">
      <PageHeader kicker="Yours" title="Settings and backup" />

      <section aria-labelledby="theme">
        <h2 id="theme" className="section-title">Appearance</h2>
        <fieldset className="segmented">
          <legend className="sr-only">Theme</legend>
          {(['system', 'light', 'dark'] as Theme[]).map((t) => (
            <label key={t}>
              <input type="radio" name="theme" checked={theme === t} onChange={() => setTheme(t)} />
              <span>{t === 'system' ? 'Match the system' : t === 'light' ? 'Light' : 'Dark'}</span>
            </label>
          ))}
        </fieldset>
      </section>

      <section aria-labelledby="backup">
        <h2 id="backup" className="section-title">Your progress and how to back it up</h2>
        <p>
          Lessons, attempts, code drafts, notes, bookmarks, challenges, projects and review cards are stored in IndexedDB, inside this browser on this device. Nothing is sent to a
          server. If you clear the site’s data or switch browsers or computers, it’s gone, so export a backup now and then and keep it somewhere safe, like iCloud Drive.
        </p>
        <div className="row">
          <button
            type="button"
            className="btn btn-primary"
            onClick={async () => {
              const b = await exportBackup()
              downloadJson(`ios-academy-backup-${b.exportedAt.slice(0, 10)}.json`, b)
              setMessage({ tone: 'ok', text: 'Backup exported.' })
            }}
          >
            Export backup
          </button>
          <button type="button" className="btn" onClick={() => file.current?.click()}>
            Import backup
          </button>
          <input
            ref={file}
            type="file"
            accept="application/json,.json"
            hidden
            onChange={async (e) => {
              const f = e.target.files?.[0]
              e.target.value = ''
              if (!f) return
              const parsed = parseBackup(await f.text())
              if (!parsed.ok) {
                setMessage({ tone: 'bad', text: parsed.error })
                return
              }
              const n = Object.values(parsed.backup.data).reduce((s, rows) => s + rows.length, 0)
              if (!confirm(`The backup from ${new Date(parsed.backup.exportedAt).toLocaleString('en-US')} has ${n} records. Importing it replaces all your current progress. Continue?`)) return
              await importBackup(parsed.backup)
              await logActivity('importacion', 'respaldo', parsed.backup.exportedAt)
              setMessage({ tone: 'ok', text: `Backup imported: ${n} records.` })
            }}
          />
        </div>
        {message && (
          <p className={`verdict ${message.tone}`} role="status">
            {message.text}
          </p>
        )}
        <details className="danger">
          <summary>Erase all progress</summary>
          <p>Deletes lessons, attempts, notes and review cards from this browser. Export a backup first if you want to keep them.</p>
          <button
            type="button"
            className="btn btn-danger"
            onClick={async () => {
              if (!confirm('This erases all your progress in this browser and can’t be undone. Erase it?')) return
              await resetAll()
              setMessage({ tone: 'ok', text: 'Progress erased.' })
            }}
          >
            Erase progress
          </button>
        </details>
      </section>

      <section aria-labelledby="keys">
        <h2 id="keys" className="section-title">Keyboard shortcuts</h2>
        <dl className="terms">
          <div>
            <dt>
              <kbd>/</kbd>
            </dt>
            <dd>Jump to search</dd>
          </div>
          <div>
            <dt>
              <kbd>Tab</kbd> in the editor
            </dt>
            <dd>Indents. To leave the editor with the keyboard, press <kbd>Esc</kbd> and then <kbd>Tab</kbd>.</dd>
          </div>
        </dl>
      </section>

      <section aria-labelledby="about">
        <h2 id="about" className="section-title">About running Swift</h2>
        <p>
          The browser can’t compile Swift: the official compiler doesn’t run as WebAssembly inside a page. So you write code exercises here, they’re saved, and you run them in Xcode or
          with <code>swift test</code>. No code exercise is ever marked correct by comparing text.
        </p>
        {contentIssues.length > 0 && (
          <p className="verdict bad">
            {contentIssues.length} content problems were found while loading. Run <code>npm run validate</code> in the repository.
          </p>
        )}
      </section>
    </div>
  )
}

import { useEffect, useRef, useState } from 'react'
import { PageHeader } from '../components/ui'
import { contentIssues } from '../content'
import { logActivity } from '../db/actions'
import { downloadJson, exportBackup, importBackup, parseBackup, resetAll } from '../db/backup'

type Theme = 'system' | 'light' | 'dark'

function readTheme(): Theme {
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
    /* almacenamiento no disponible: el tema dura solo esta sesión */
  }
}

export function SettingsPage() {
  const [theme, setTheme] = useState<Theme>(readTheme)
  const [message, setMessage] = useState<{ tone: 'ok' | 'bad'; text: string } | null>(null)
  const file = useRef<HTMLInputElement>(null)

  useEffect(() => applyTheme(theme), [theme])

  return (
    <div className="page settings">
      <PageHeader title="Ajustes y respaldo" />

      <section aria-labelledby="theme">
        <h2 id="theme" className="section-title">Apariencia</h2>
        <fieldset className="segmented">
          <legend className="sr-only">Tema</legend>
          {(['system', 'light', 'dark'] as Theme[]).map((t) => (
            <label key={t}>
              <input type="radio" name="theme" checked={theme === t} onChange={() => setTheme(t)} />
              <span>{t === 'system' ? 'Igual que el sistema' : t === 'light' ? 'Claro' : 'Oscuro'}</span>
            </label>
          ))}
        </fieldset>
      </section>

      <section aria-labelledby="backup">
        <h2 id="backup" className="section-title">Tu progreso y cómo respaldarlo</h2>
        <p>
          Lecciones, intentos, borradores de código, notas, marcadores, retos, proyectos y tarjetas de repaso se guardan en IndexedDB, dentro de este navegador y en este dispositivo. No se
          envían a ningún servidor. Si borras los datos del sitio o cambias de navegador o de equipo, se pierden: exporta un respaldo de vez en cuando y guárdalo, por ejemplo, en iCloud
          Drive.
        </p>
        <div className="row">
          <button
            type="button"
            className="btn btn-primary"
            onClick={async () => {
              const b = await exportBackup()
              downloadJson(`ios-academy-respaldo-${b.exportedAt.slice(0, 10)}.json`, b)
              setMessage({ tone: 'ok', text: 'Respaldo exportado.' })
            }}
          >
            Exportar respaldo
          </button>
          <button type="button" className="btn" onClick={() => file.current?.click()}>
            Importar respaldo
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
              if (!confirm(`El respaldo del ${new Date(parsed.backup.exportedAt).toLocaleString('es-MX')} tiene ${n} registros. Importarlo reemplaza todo tu progreso actual. ¿Continuar?`)) return
              await importBackup(parsed.backup)
              await logActivity('importacion', 'respaldo', parsed.backup.exportedAt)
              setMessage({ tone: 'ok', text: `Respaldo importado: ${n} registros.` })
            }}
          />
        </div>
        {message && (
          <p className={`verdict ${message.tone}`} role="status">
            {message.text}
          </p>
        )}
        <details className="danger">
          <summary>Borrar todo el progreso</summary>
          <p>Elimina lecciones, intentos, notas y repaso de este navegador. Exporta un respaldo antes si lo quieres conservar.</p>
          <button
            type="button"
            className="btn btn-danger"
            onClick={async () => {
              if (!confirm('Esto borra todo tu progreso en este navegador y no se puede deshacer. ¿Borrar?')) return
              await resetAll()
              setMessage({ tone: 'ok', text: 'Progreso borrado.' })
            }}
          >
            Borrar el progreso
          </button>
        </details>
      </section>

      <section aria-labelledby="keys">
        <h2 id="keys" className="section-title">Atajos de teclado</h2>
        <dl className="terms">
          <div>
            <dt>
              <kbd>/</kbd>
            </dt>
            <dd>Ir al buscador</dd>
          </div>
          <div>
            <dt>
              <kbd>Tab</kbd> en el editor
            </dt>
            <dd>Indentar. Para salir del editor con el teclado: <kbd>Esc</kbd> y luego <kbd>Tab</kbd>.</dd>
          </div>
        </dl>
      </section>

      <section aria-labelledby="about">
        <h2 id="about" className="section-title">Sobre la ejecución de Swift</h2>
        <p>
          El navegador no compila Swift: el compilador oficial no corre en WebAssembly dentro de una página. Por eso los ejercicios de código se escriben aquí, se guardan, y se ejecutan en
          Xcode o con <code>swift test</code>. Ningún ejercicio de código se marca como correcto comparando texto.
        </p>
        {contentIssues.length > 0 && (
          <p className="verdict bad">
            Hay {contentIssues.length} problemas de contenido detectados al cargar. Ejecuta <code>npm run validate</code> en el repositorio.
          </p>
        )}
      </section>
    </div>
  )
}

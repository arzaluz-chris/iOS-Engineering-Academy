import hljs from 'highlight.js/lib/core'
import bash from 'highlight.js/lib/languages/bash'
import json from 'highlight.js/lib/languages/json'
import plaintext from 'highlight.js/lib/languages/plaintext'
import swift from 'highlight.js/lib/languages/swift'
import { Marked } from 'marked'
import { memo, useMemo } from 'react'

hljs.registerLanguage('swift', swift)
hljs.registerLanguage('bash', bash)
hljs.registerLanguage('json', json)
hljs.registerLanguage('plaintext', plaintext)

const ALIASES: Record<string, string> = { sh: 'bash', shell: 'bash', zsh: 'bash', pseudo: 'plaintext', text: 'plaintext', output: 'plaintext', salida: 'plaintext' }

export function slugify(text: string) {
  return text
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .replace(/<[^>]+>/g, '')
    .replace(/[^a-z0-9\s-]/g, '')
    .trim()
    .replace(/\s+/g, '-')
}

export function highlight(code: string, lang = 'swift') {
  const l = ALIASES[lang] ?? lang
  if (!hljs.getLanguage(l)) return escapeHtml(code)
  return hljs.highlight(code, { language: l }).value
}

export function escapeHtml(s: string) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
}

const LANG_LABEL: Record<string, string> = { swift: 'Swift', bash: 'Terminal', json: 'JSON', plaintext: 'Texto', pseudo: 'Pseudocódigo', output: 'Salida', salida: 'Salida' }

/**
 * Avisos dentro de blockquotes:
 *   > [!error] Título     → diagnóstico estilo compilador (errores frecuentes)
 *   > [!aviso] ...        → advertencia
 *   > [!nota] ...         → nota
 *   > [!practica] ...     → buena práctica
 *   > [!version] ...      → disponibilidad por versión
 */
const CALLOUTS: Record<string, string> = { error: 'Error frecuente', aviso: 'Advertencia', nota: 'Nota', practica: 'Buena práctica', version: 'Disponibilidad' }

const marked = new Marked({
  gfm: true,
  renderer: {
    code({ text, lang }) {
      const raw = (lang ?? '').trim().split(/\s+/)[0] ?? ''
      const key = raw || 'plaintext'
      const label = LANG_LABEL[key] ?? key
      const html = highlight(text, key)
      return `<figure class="code"><figcaption><span>${escapeHtml(label)}</span><button type="button" class="copy" data-copy>Copiar</button></figcaption><pre><code class="hljs">${html}</code></pre></figure>`
    },
    heading({ tokens, depth }) {
      const inner = this.parser.parseInline(tokens)
      const id = slugify(inner)
      return `<h${depth} id="${id}"><a class="anchor" href="#${id}" data-anchor aria-hidden="true" tabindex="-1">#</a>${inner}</h${depth}>`
    },
    blockquote({ tokens }) {
      const inner = this.parser.parse(tokens)
      const m = /^<p>\[!(\w+)\]\s*([^\n<]*)/.exec(inner)
      if (m && m[1] && CALLOUTS[m[1]]) {
        const kind = m[1]
        const title = m[2]?.trim() || CALLOUTS[kind]
        const rest = inner.replace(/^<p>\[!\w+\][^\n<]*(\n|<br>)?/, '<p>').replace(/^<p><\/p>/, '')
        return `<aside class="callout callout-${kind}" role="note"><p class="callout-title">${title}</p>${rest}</aside>`
      }
      return `<blockquote>${inner}</blockquote>`
    },
    table(token) {
      const header = token.header.map((c) => `<th>${this.parser.parseInline(c.tokens)}</th>`).join('')
      const body = token.rows.map((r) => `<tr>${r.map((c) => `<td>${this.parser.parseInline(c.tokens)}</td>`).join('')}</tr>`).join('')
      return `<div class="table-wrap"><table><thead><tr>${header}</tr></thead><tbody>${body}</tbody></table></div>`
    },
    link({ href, title, tokens }) {
      const text = this.parser.parseInline(tokens)
      const external = /^https?:/.test(href)
      const t = title ? ` title="${escapeHtml(title)}"` : ''
      return external ? `<a href="${href}"${t} target="_blank" rel="noopener noreferrer">${text}</a>` : `<a href="${href}"${t}>${text}</a>`
    },
  },
})

export function renderMarkdown(md: string) {
  return marked.parse(md, { async: false })
}

function onClick(e: React.MouseEvent<HTMLDivElement>) {
  const target = e.target as HTMLElement
  const copy = target.closest<HTMLButtonElement>('[data-copy]')
  if (copy) {
    const code = copy.closest('figure')?.querySelector('code')?.textContent ?? ''
    void navigator.clipboard?.writeText(code).then(() => {
      copy.textContent = 'Copiado'
      setTimeout(() => (copy.textContent = 'Copiar'), 1500)
    })
    return
  }
  const anchor = target.closest<HTMLAnchorElement>('[data-anchor]')
  if (anchor) {
    // Los anclajes no deben cambiar el hash de la ruta.
    e.preventDefault()
    document.getElementById(anchor.getAttribute('href')?.slice(1) ?? '')?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }
}

export const Markdown = memo(function Markdown({ text, className = 'prose' }: { text: string; className?: string }) {
  const html = useMemo(() => renderMarkdown(text), [text])
  return <div className={className} onClick={onClick} dangerouslySetInnerHTML={{ __html: html }} />
})

export function CodeView({ code, lang = 'swift', label }: { code: string; lang?: string; label?: string }) {
  const html = useMemo(() => highlight(code.replace(/\n$/, ''), lang), [code, lang])
  return (
    <figure className="code" onClick={onClick as unknown as React.MouseEventHandler}>
      <figcaption>
        <span>{label ?? LANG_LABEL[lang] ?? lang}</span>
        <button type="button" className="copy" data-copy>
          Copiar
        </button>
      </figcaption>
      <pre>
        <code className="hljs" dangerouslySetInnerHTML={{ __html: html }} />
      </pre>
    </figure>
  )
}

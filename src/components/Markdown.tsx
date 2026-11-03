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

const ALIASES: Record<string, string> = { sh: 'bash', shell: 'bash', zsh: 'bash', pseudo: 'plaintext', text: 'plaintext', output: 'plaintext' }

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
  const html = hljs.highlight(code, { language: l }).value
  return l === 'swift' ? classifyIdentifiers(html) : html
}

const DECLARING = new Set(['let', 'var', 'for', 'case', 'guard', 'inout'])

/**
 * highlight.js leaves plain identifiers unmarked. swift.org's highlighter colors them by role,
 * so this pass does the same on the top-level text: names being declared, argument labels and
 * calls get the "declaration" color, capitalized names the type color, and every other
 * reference the "name" color. Text inside strings and comments is never touched.
 */
export function classifyIdentifiers(html: string): string {
  let out = ''
  let depth = 0
  let keywordOpen = false
  let lastKeyword = ''
  for (const [part] of html.matchAll(/<span[^>]*>|<\/span>|[^<]+/g)) {
    if (part.startsWith('<span')) {
      if (depth === 0) {
        keywordOpen = part.includes('hljs-keyword')
        lastKeyword = ''
      }
      depth++
      out += part
    } else if (part === '</span>') {
      depth--
      out += part
    } else if (depth > 0) {
      if (depth === 1 && keywordOpen) lastKeyword = part
      out += part
    } else {
      out += part.replace(/&#?\w+;|[A-Za-z_][A-Za-z0-9_]*/g, (token, offset: number) => {
        if (token.startsWith('&')) return token
        const before = part.slice(0, offset)
        const after = part.slice(offset + token.length)
        const declared = DECLARING.has(lastKeyword) && /^\s*$/.test(before)
        lastKeyword = ''
        let cls = 'hljs-ident'
        if (declared || /^\s*:(?!:)/.test(after) || /^\(/.test(after)) cls = 'hljs-decl'
        else if (/^[A-Z]/.test(token)) cls = 'hljs-type'
        return `<span class="${cls}">${token}</span>`
      })
      if (part.trim()) lastKeyword = ''
    }
  }
  return out
}

export function escapeHtml(s: string) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
}

/**
 * Code blocks follow swift.org: a plain rounded box with no header, and an icon-only copy
 * button that appears on hover. Code gets the filled box; output and plain text get the
 * bordered white box swift.org uses for file trees and command output. Only output and
 * pseudocode carry a small caption, so a learner can tell them apart from Swift.
 */
const CAPTION: Record<string, string> = { output: 'Output', pseudo: 'Pseudocode' }
const PLAIN = new Set(['output', 'plaintext', 'text'])

const COPY_ICON =
  '<svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor" aria-hidden="true"><path d="M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z"/></svg>'
const CHECK_ICON =
  '<svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor" aria-hidden="true"><path d="M9 16.17 4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>'

export function codeBlockHtml(highlighted: string, lang: string, caption?: string) {
  const cap = caption ?? CAPTION[lang]
  const kind = PLAIN.has(lang) ? 'code-plain' : 'code-filled'
  return (
    `<div class="code-block ${kind}" data-lang="${escapeHtml(lang)}">` +
    (cap ? `<p class="code-caption">${escapeHtml(cap)}</p>` : '') +
    `<div class="highlight"><button type="button" class="copy-button" data-copy aria-label="Copy code">${COPY_ICON}</button>` +
    `<pre><code class="hljs">${highlighted}</code></pre></div></div>`
  )
}

/**
 * Callouts inside blockquotes:
 *   > [!error] Title      → compiler-style diagnostic (common mistakes)
 *   > [!warning] ...      → warning
 *   > [!note] ...         → note
 *   > [!tip] ...          → good practice
 *   > [!version] ...      → availability by version
 */
const CALLOUTS: Record<string, string> = { error: 'Common mistake', warning: 'Warning', note: 'Note', tip: 'Good practice', version: 'Availability' }

const marked = new Marked({
  gfm: true,
  renderer: {
    code({ text, lang }) {
      const raw = (lang ?? '').trim().split(/\s+/)[0] ?? ''
      const key = raw || 'plaintext'
      return codeBlockHtml(highlight(text, key), key)
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
    const code = copy.closest('.highlight')?.querySelector('code')?.textContent ?? ''
    void navigator.clipboard?.writeText(code).then(() => {
      copy.classList.add('copied')
      copy.innerHTML = CHECK_ICON
      copy.setAttribute('aria-label', 'Copied')
      setTimeout(() => {
        copy.classList.remove('copied')
        copy.innerHTML = COPY_ICON
        copy.setAttribute('aria-label', 'Copy code')
      }, 1500)
    })
    return
  }
  const anchor = target.closest<HTMLAnchorElement>('[data-anchor]')
  if (anchor) {
    // Anchor links must not change the route hash.
    e.preventDefault()
    document.getElementById(anchor.getAttribute('href')?.slice(1) ?? '')?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }
}

export const Markdown = memo(function Markdown({ text, className = 'prose' }: { text: string; className?: string }) {
  const html = useMemo(() => renderMarkdown(text), [text])
  return <div className={className} onClick={onClick} dangerouslySetInnerHTML={{ __html: html }} />
})

export function CodeView({ code, lang = 'swift', label }: { code: string; lang?: string; label?: string }) {
  const html = useMemo(() => codeBlockHtml(highlight(code.replace(/\n$/, ''), lang), lang, label), [code, lang, label])
  return <div className="code-view" onClick={onClick as unknown as React.MouseEventHandler} dangerouslySetInnerHTML={{ __html: html }} />
}

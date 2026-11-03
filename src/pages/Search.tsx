import { useMemo, useState } from 'react'
import { Badge, Empty, PageHeader } from '../components/ui'
import { content } from '../content'
import { buildDocs, createIndex, KIND_LABEL, type SearchKind } from '../search'
import { navigate } from '../router'

let index: ReturnType<typeof createIndex> | null = null
const getIndex = () => (index ??= createIndex(buildDocs(content)))

export function SearchPage({ q }: { q: string }) {
  const [kind, setKind] = useState<SearchKind | 'all'>('all')
  const [text, setText] = useState(q)
  const results = useMemo(() => (q.trim() ? getIndex().search(q) : []), [q])
  const filtered = kind === 'all' ? results : results.filter((r) => r.kind === kind)
  const counts = results.reduce<Record<string, number>>((acc, r) => ({ ...acc, [r.kind]: (acc[r.kind] ?? 0) + 1 }), {})

  return (
    <div className="page">
      <PageHeader title="Search" />
      <form
        role="search"
        className="search-page-form"
        onSubmit={(e) => {
          e.preventDefault()
          navigate(`/search?q=${encodeURIComponent(text.trim())}`)
        }}
      >
        <label htmlFor="q" className="sr-only">
          Search terms
        </label>
        <input id="q" type="search" value={text} onChange={(e) => setText(e.target.value)} placeholder="optional, closure, two pointers, compiler…" autoFocus />
        <button className="btn btn-primary" type="submit">
          Search
        </button>
      </form>
      {q && (
        <div className="filters" role="group" aria-label="Result type">
          <button type="button" className="chip" aria-pressed={kind === 'all'} onClick={() => setKind('all')}>
            All ({results.length})
          </button>
          {(Object.keys(KIND_LABEL) as SearchKind[])
            .filter((k) => counts[k])
            .map((k) => (
              <button key={k} type="button" className="chip" aria-pressed={kind === k} onClick={() => setKind(k)}>
                {KIND_LABEL[k]} ({counts[k]})
              </button>
            ))}
        </div>
      )}
      {!q ? (
        <Empty title="Type what you’re looking for">Searches titles, explanations, APIs, concepts, questions, challenges and resources.</Empty>
      ) : filtered.length === 0 ? (
        <Empty title={`No results for “${q}”`}>Try fewer words, or the exact API name.</Empty>
      ) : (
        <ol className="results">
          {filtered.slice(0, 60).map((r) => (
            <li key={r.id}>
              <Badge>{KIND_LABEL[r.kind as SearchKind]}</Badge>{' '}
              <a href={r.href} {...(r.kind === 'recurso' ? { target: '_blank', rel: 'noopener noreferrer' } : {})}>
                {r.title}
              </a>
            </li>
          ))}
        </ol>
      )}
    </div>
  )
}

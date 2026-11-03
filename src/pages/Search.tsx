import { useMemo, useState } from 'react'
import { Badge, Empty, PageHeader } from '../components/ui'
import { content } from '../content'
import { buildDocs, createIndex, KIND_LABEL, type SearchKind } from '../search'
import { navigate } from '../router'

let index: ReturnType<typeof createIndex> | null = null
const getIndex = () => (index ??= createIndex(buildDocs(content)))

export function SearchPage({ q }: { q: string }) {
  const [kind, setKind] = useState<SearchKind | 'todo'>('todo')
  const [text, setText] = useState(q)
  const results = useMemo(() => (q.trim() ? getIndex().search(q) : []), [q])
  const filtered = kind === 'todo' ? results : results.filter((r) => r.kind === kind)
  const counts = results.reduce<Record<string, number>>((acc, r) => ({ ...acc, [r.kind]: (acc[r.kind] ?? 0) + 1 }), {})

  return (
    <div className="page">
      <PageHeader title="Buscar" />
      <form
        role="search"
        className="search-page-form"
        onSubmit={(e) => {
          e.preventDefault()
          navigate(`/buscar?q=${encodeURIComponent(text.trim())}`)
        }}
      >
        <label htmlFor="q" className="sr-only">
          Términos de búsqueda
        </label>
        <input id="q" type="search" value={text} onChange={(e) => setText(e.target.value)} placeholder="optional, closure, two pointers, compilador…" autoFocus />
        <button className="btn btn-primary" type="submit">
          Buscar
        </button>
      </form>
      {q && (
        <div className="filters" role="group" aria-label="Tipo de resultado">
          <button type="button" className="chip" aria-pressed={kind === 'todo'} onClick={() => setKind('todo')}>
            Todo ({results.length})
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
        <Empty title="Escribe qué buscas">Busca en títulos, explicaciones, APIs, conceptos, preguntas, retos y recursos. Los acentos no importan.</Empty>
      ) : filtered.length === 0 ? (
        <Empty title={`Sin resultados para «${q}»`}>Prueba con menos palabras o con el término en inglés (por ejemplo, «closure» en lugar de «cierre»).</Empty>
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

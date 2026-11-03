import MiniSearch from 'minisearch'
import type { Catalog } from '../content/parse'

export type SearchKind = 'leccion' | 'modulo' | 'ejercicio' | 'reto' | 'pregunta' | 'proyecto' | 'recurso'

export interface SearchDoc {
  id: string
  kind: SearchKind
  title: string
  text: string
  tags: string
  href: string
}

export const KIND_LABEL: Record<SearchKind, string> = {
  leccion: 'Lección',
  modulo: 'Módulo',
  ejercicio: 'Ejercicio',
  reto: 'Reto',
  pregunta: 'Entrevista',
  proyecto: 'Proyecto',
  recurso: 'Recurso',
}

export function buildDocs(c: Catalog): SearchDoc[] {
  const docs: SearchDoc[] = []
  for (const m of c.modules)
    docs.push({ id: `modulo:${m.id}`, kind: 'modulo', title: `Módulo ${m.number}. ${m.title}`, text: `${m.summary} ${m.objectives.join(' ')}`, tags: m.topics.join(' '), href: `#/modulo/${m.id}` })
  for (const l of c.lessons) {
    docs.push({ id: `leccion:${l.id}`, kind: 'leccion', title: l.title, text: `${l.description} ${l.plain}`, tags: [...l.terms.map((t) => t.term), ...l.objectives].join(' '), href: `#/leccion/${l.id}` })
    for (const e of l.exercises)
      docs.push({ id: `ejercicio:${e.id}`, kind: 'ejercicio', title: firstLine(e.prompt), text: e.prompt, tags: `${e.type} ${e.concept ?? ''}`, href: `#/leccion/${l.id}/${e.id}` })
  }
  for (const ch of c.challenges)
    docs.push({ id: `reto:${ch.id}`, kind: 'reto', title: ch.title, text: ch.plain, tags: ch.patterns.join(' '), href: `#/reto/${ch.id}` })
  for (const q of c.questions)
    docs.push({ id: `pregunta:${q.id}`, kind: 'pregunta', title: q.question, text: q.keyPoints.join(' '), tags: q.category, href: `#/entrevistas/pregunta/${q.id}` })
  for (const p of c.projects)
    docs.push({ id: `proyecto:${p.id}`, kind: 'proyecto', title: `Proyecto ${p.number}. ${p.title}`, text: `${p.summary} ${p.requirements.join(' ')}`, tags: '', href: `#/proyecto/${p.id}` })
  for (const r of c.resources)
    docs.push({ id: `recurso:${r.id}`, kind: 'recurso', title: r.title, text: `${r.why} ${r.source}`, tags: r.topic, href: r.url })
  return docs
}

function firstLine(md: string) {
  const line = md.split('\n').find((l) => l.trim()) ?? md
  const clean = line.replace(/[`*_#]/g, '').trim()
  return clean.length > 90 ? `${clean.slice(0, 87)}…` : clean
}

/** Quita acentos para que "funcion" encuentre "función". */
const fold = (s: string) => s.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase()

export function createIndex(docs: SearchDoc[]) {
  const index = new MiniSearch<SearchDoc>({
    fields: ['title', 'tags', 'text'],
    storeFields: ['kind', 'title', 'href'],
    processTerm: (t) => fold(t),
    searchOptions: { boost: { title: 3, tags: 2 }, prefix: true, fuzzy: 0.2, combineWith: 'AND' },
  })
  index.addAll(docs)
  return index
}

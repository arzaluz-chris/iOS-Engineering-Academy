import { parse as parseYaml } from 'yaml'
import type { z } from 'zod'
import {
  challengeMetaSchema,
  curriculumSchema,
  exerciseSchema,
  interviewFileSchema,
  lessonMetaSchema,
  projectMetaSchema,
  resourceSchema,
  type ChallengeMeta,
  type Exercise,
  type InterviewQuestion,
  type LessonMeta,
  type Module,
  type ProjectMeta,
  type Resource,
  type Stage,
} from './schema'

/** Archivos de contenido crudos, indexados por ruta relativa a la raíz del repo. */
export interface RawContent {
  curriculum: string
  resources: string
  lessons: Record<string, string>
  challenges: Record<string, string>
  interview: Record<string, string>
  projects: Record<string, string>
  swift: Record<string, string>
}

export type Segment = { kind: 'md'; text: string } | { kind: 'exercise'; exercise: Exercise }

export interface Section {
  heading: string
  body: string
}

export interface Lesson extends LessonMeta {
  path: string
  segments: Segment[]
  exercises: Exercise[]
  /** Texto plano aproximado para el buscador. */
  plain: string
}

export interface Challenge extends ChallengeMeta {
  path: string
  statement: string
  /** Secciones que se revelan una a una, en orden. */
  reveal: Section[]
  solutionCode: string
  testCode: string
  plain: string
}

export interface Project extends ProjectMeta {
  path: string
  body: string
}

export interface Catalog {
  stages: Stage[]
  modules: Module[]
  lessons: Lesson[]
  challenges: Challenge[]
  questions: InterviewQuestion[]
  projects: Project[]
  resources: Resource[]
}

export interface Issue {
  path: string
  message: string
}

const FRONTMATTER = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/

export function splitFrontmatter(raw: string): { data: unknown; body: string } | null {
  const m = FRONTMATTER.exec(raw)
  if (!m) return null
  return { data: parseYaml(m[1] ?? ''), body: m[2] ?? '' }
}

/**
 * Los ejercicios se escriben dentro de la lección como bloques
 * ````exercise (cuatro comillas invertidas) con YAML, para poder incluir
 * bloques de código ``` normales dentro de sus campos.
 */
const EXERCISE_BLOCK = /^````exercise[ \t]*\r?\n([\s\S]*?)\r?\n````[ \t]*$/gm

export function splitSegments(body: string, path: string, issues: Issue[]): Segment[] {
  const segments: Segment[] = []
  let last = 0
  for (const m of body.matchAll(EXERCISE_BLOCK)) {
    const before = body.slice(last, m.index)
    if (before.trim()) segments.push({ kind: 'md', text: before })
    last = (m.index ?? 0) + m[0].length
    let data: unknown
    try {
      data = parseYaml(m[1] ?? '')
    } catch (e) {
      issues.push({ path, message: `YAML inválido en ejercicio: ${(e as Error).message}` })
      continue
    }
    const r = exerciseSchema.safeParse(data)
    if (r.success) segments.push({ kind: 'exercise', exercise: r.data })
    else issues.push({ path, message: `Ejercicio inválido (${describeId(data)}): ${formatZod(r.error)}` })
  }
  const rest = body.slice(last)
  if (rest.trim()) segments.push({ kind: 'md', text: rest })
  return segments
}

export function splitSections(text: string): { intro: string; sections: Section[] } {
  const parts = text.split(/^## /m)
  const intro = parts.shift() ?? ''
  const sections = parts.map((p) => {
    const nl = p.indexOf('\n')
    return nl === -1 ? { heading: p.trim(), body: '' } : { heading: p.slice(0, nl).trim(), body: p.slice(nl + 1).trim() }
  })
  return { intro, sections }
}

export const REVEAL_MARKER = '<!-- revelar -->'

export function toPlain(text: string): string {
  return text
    .replace(/```[\s\S]*?```/g, ' ')
    .replace(/`([^`]*)`/g, '$1')
    .replace(/[#>*_\[\]()|-]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

function describeId(data: unknown): string {
  return typeof data === 'object' && data && 'id' in data ? String((data as { id: unknown }).id) : 'sin id'
}

export function formatZod(err: z.ZodError): string {
  return err.issues.map((i) => `${i.path.join('.') || '(raíz)'}: ${i.message}`).join('; ')
}

function parseDoc<T>(
  path: string,
  raw: string,
  schema: z.ZodType<T>,
  issues: Issue[],
): { meta: T; body: string } | null {
  let fm: ReturnType<typeof splitFrontmatter>
  try {
    fm = splitFrontmatter(raw)
  } catch (e) {
    issues.push({ path, message: `YAML inválido: ${(e as Error).message}` })
    return null
  }
  if (!fm) {
    issues.push({ path, message: 'Falta el bloque de frontmatter (--- ... ---)' })
    return null
  }
  const r = schema.safeParse(fm.data)
  if (!r.success) {
    issues.push({ path, message: formatZod(r.error) })
    return null
  }
  return { meta: r.data, body: fm.body }
}

function basename(p: string): string {
  return p.split('/').pop() ?? p
}

export function buildCatalog(raw: RawContent): { catalog: Catalog; issues: Issue[] } {
  const issues: Issue[] = []

  const cur = curriculumSchema.safeParse(safeYaml(raw.curriculum, 'content/curriculum.yaml', issues))
  if (!cur.success) issues.push({ path: 'content/curriculum.yaml', message: formatZod(cur.error) })

  const resParsed = safeYaml(raw.resources, 'content/resources.yaml', issues) as { resources?: unknown[] } | undefined
  const resources: Resource[] = []
  for (const r of resParsed?.resources ?? []) {
    const p = resourceSchema.safeParse(r)
    if (p.success) resources.push(p.data)
    else issues.push({ path: 'content/resources.yaml', message: `${describeId(r)}: ${formatZod(p.error)}` })
  }

  const lessons: Lesson[] = []
  for (const [path, text] of sortedEntries(raw.lessons)) {
    const doc = parseDoc(path, text, lessonMetaSchema, issues)
    if (!doc) continue
    const segments = splitSegments(doc.body, path, issues)
    const exercises = segments.flatMap((s) => (s.kind === 'exercise' ? [s.exercise] : []))
    const plain = toPlain(segments.map((s) => (s.kind === 'md' ? s.text : s.exercise.prompt)).join(' '))
    lessons.push({ ...doc.meta, path, segments, exercises, plain })
  }

  const swiftByName = new Map<string, string>()
  for (const [path, text] of Object.entries(raw.swift)) swiftByName.set(basename(path), text)

  const challenges: Challenge[] = []
  for (const [path, text] of sortedEntries(raw.challenges)) {
    const doc = parseDoc(path, text, challengeMetaSchema, issues)
    if (!doc) continue
    const markerAt = doc.body.indexOf(REVEAL_MARKER)
    if (markerAt === -1) {
      issues.push({ path, message: `Falta el marcador ${REVEAL_MARKER} que separa el enunciado de lo que se revela` })
      continue
    }
    const statement = doc.body.slice(0, markerAt).trim()
    const { sections } = splitSections(doc.body.slice(markerAt + REVEAL_MARKER.length))
    const solutionCode = swiftByName.get(doc.meta.solutionFile)
    const testCode = swiftByName.get(doc.meta.testFile)
    if (solutionCode === undefined) issues.push({ path, message: `No existe swift/**/${doc.meta.solutionFile}` })
    if (testCode === undefined) issues.push({ path, message: `No existe swift/**/${doc.meta.testFile}` })
    challenges.push({
      ...doc.meta,
      path,
      statement,
      reveal: sections,
      solutionCode: solutionCode ?? '',
      testCode: testCode ?? '',
      plain: toPlain(`${doc.meta.summary} ${statement} ${doc.meta.patterns.join(' ')}`),
    })
  }

  const questions: InterviewQuestion[] = []
  for (const [path, text] of sortedEntries(raw.interview)) {
    const r = interviewFileSchema.safeParse(safeYaml(text, path, issues))
    if (r.success) questions.push(...r.data.questions)
    else issues.push({ path, message: formatZod(r.error) })
  }

  const projects: Project[] = []
  for (const [path, text] of sortedEntries(raw.projects)) {
    const doc = parseDoc(path, text, projectMetaSchema, issues)
    if (doc) projects.push({ ...doc.meta, path, body: doc.body })
  }

  const catalog: Catalog = {
    stages: cur.success ? [...cur.data.stages].sort((a, b) => a.number - b.number) : [],
    modules: cur.success ? [...cur.data.modules].sort((a, b) => a.number - b.number) : [],
    lessons: lessons.sort((a, b) => a.module.localeCompare(b.module) || a.order - b.order),
    challenges: challenges.sort((a, b) => a.order - b.order),
    questions,
    projects: projects.sort((a, b) => a.number - b.number),
    resources,
  }
  return { catalog, issues }
}

function safeYaml(text: string, path: string, issues: Issue[]): unknown {
  try {
    return parseYaml(text)
  } catch (e) {
    issues.push({ path, message: `YAML inválido: ${(e as Error).message}` })
    return undefined
  }
}

function sortedEntries(r: Record<string, string>): [string, string][] {
  return Object.entries(r).sort(([a], [b]) => a.localeCompare(b))
}

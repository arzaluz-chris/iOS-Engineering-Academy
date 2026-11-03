import type { Catalog, Issue } from './parse'

export interface Report {
  errors: Issue[]
  warnings: Issue[]
}

const VIDEO_HOSTS = [/youtube\.com/, /youtu\.be/, /vimeo\.com/, /developer\.apple\.com\/videos/, /twitch\.tv/]

/** Integrity checks across entities. Doesn't depend on the browser or on Node. */
export function validateCatalog(c: Catalog): Report {
  const errors: Issue[] = []
  const warnings: Issue[] = []
  const err = (path: string, message: string) => errors.push({ path, message })

  // IDs are unique across the whole course (progress is stored by ID).
  const seen = new Map<string, string>()
  const claim = (id: string, where: string) => {
    const prev = seen.get(id)
    if (prev) err(where, `Duplicate ID "${id}" (also in ${prev})`)
    else seen.set(id, where)
  }
  c.stages.forEach((s) => claim(s.id, 'curriculum.yaml'))
  c.modules.forEach((m) => claim(m.id, 'curriculum.yaml'))
  c.resources.forEach((r) => claim(r.id, 'resources.yaml'))
  c.lessons.forEach((l) => {
    claim(l.id, l.path)
    l.exercises.forEach((e) => claim(e.id, l.path))
    l.cards.forEach((k) => claim(k.id, l.path))
  })
  c.challenges.forEach((ch) => claim(ch.id, ch.path))
  c.questions.forEach((q) => claim(q.id, 'content/interview'))
  c.projects.forEach((p) => {
    claim(p.id, p.path)
    p.milestones.forEach((m) => claim(m.id, p.path))
  })

  const stageIds = new Set(c.stages.map((s) => s.id))
  const moduleById = new Map(c.modules.map((m) => [m.id, m]))
  const lessonById = new Map(c.lessons.map((l) => [l.id, l]))
  const resourceIds = new Set(c.resources.map((r) => r.id))

  for (const m of c.modules) {
    if (!stageIds.has(m.stage)) err('curriculum.yaml', `Module ${m.id}: unknown stage "${m.stage}"`)
    for (const p of m.prerequisites) {
      const pm = moduleById.get(p)
      if (!pm) err('curriculum.yaml', `Module ${m.id}: unknown prerequisite "${p}"`)
      else if (pm.number >= m.number) err('curriculum.yaml', `Module ${m.id}: prerequisite ${p} must come earlier in the sequence`)
    }
  }
  const numbers = new Set<number>()
  for (const m of c.modules) {
    if (numbers.has(m.number)) err('curriculum.yaml', `Repeated module number: ${m.number}`)
    numbers.add(m.number)
  }

  const orderKey = new Set<string>()
  for (const l of c.lessons) {
    const mod = moduleById.get(l.module)
    if (!mod) {
      err(l.path, `Unknown module "${l.module}"`)
      continue
    }
    const key = `${l.module}#${l.order}`
    if (orderKey.has(key)) err(l.path, `Order ${l.order} repeated within ${l.module}`)
    orderKey.add(key)

    for (const p of l.prerequisites) {
      const pl = lessonById.get(p)
      if (!pl) {
        err(l.path, `Unknown prerequisite "${p}"`)
        continue
      }
      const pmod = moduleById.get(pl.module)
      if (pmod && (pmod.number > mod.number || (pmod.number === mod.number && pl.order >= l.order)))
        err(l.path, `Prerequisite ${p} must come earlier in the sequence`)
    }
    for (const r of l.resources) if (!resourceIds.has(r)) err(l.path, `Unknown resource "${r}"`)
    if (l.exercises.length === 0) err(l.path, 'The lesson has no exercises')

    const fences = l.segments
      .filter((s) => s.kind === 'md')
      .map((s) => (s.kind === 'md' ? s.text : ''))
      .join('\n')
      .match(/^```/gm)
    if (fences && fences.length % 2 !== 0) err(l.path, 'Unclosed code block (odd number of ```)')

    for (const e of l.exercises) {
      const where = `${l.path} › ${e.id}`
      if (e.type === 'comprehension') {
        const correct = e.choices.filter((ch) => ch.correct).length
        if (correct === 0) err(where, 'No option is correct')
        if (!e.multiple && correct !== 1) err(where, 'Single choice with more than one correct answer')
      }
      if (e.type === 'find-errors' && !e.choices.some((ch) => ch.correct)) err(where, 'No option identifies a real problem')
      if (e.type === 'prediction' && e.lang === 'pseudo' && !/^```swift[^\S\n]*$/m.test(e.solution))
        err(where, 'Pseudocode prediction without a Swift translation in the solution (```swift block) to verify the output')
      if (e.type === 'fill-in') {
        const holes = [...e.code.matchAll(/\[\[(\w+)\]\]/g)].map((m) => m[1])
        const declared = e.blanks.map((b) => b.id)
        if (holes.length === 0) err(where, 'The code has no [[n]] blanks')
        for (const h of holes) if (!declared.includes(h ?? '')) err(where, `Blank [[${h}]] has no declared answer`)
        for (const d of declared) if (!holes.includes(d)) err(where, `Answer for a blank that doesn't exist "${d}"`)
      }
    }
  }

  const knownRef = (id: string) => lessonById.has(id) || moduleById.has(id)
  for (const ch of c.challenges) {
    for (const p of ch.prerequisites) if (!knownRef(p)) err(ch.path, `Unknown prerequisite "${p}"`)
    if (ch.reveal.length < 3) err(ch.path, 'Expected at least 3 revealable sections (approach, solution, explanation)')
    if (ch.solutionCode && !/\bfunc\b|\bstruct\b|\bclass\b/.test(ch.solutionCode)) err(ch.path, 'The solution file has no recognizable Swift code')
    if (ch.testCode && !/@Test\b/.test(ch.testCode)) err(ch.path, 'The test file has no @Test')
  }

  for (const q of c.questions)
    for (const r of q.related) if (!knownRef(r) && !c.challenges.some((ch) => ch.id === r)) err('content/interview', `${q.id}: unknown related item "${r}"`)

  for (const p of c.projects) for (const r of p.prerequisites) if (!moduleById.has(r)) err(p.path, `Unknown prerequisite "${r}"`)

  const urls = new Map<string, string>()
  for (const r of c.resources) {
    if (VIDEO_HOSTS.some((h) => h.test(r.url))) err('resources.yaml', `${r.id}: video links aren't allowed`)
    const prev = urls.get(r.url)
    if (prev) err('resources.yaml', `${r.id}: duplicate URL (also in ${prev})`)
    urls.set(r.url, r.id)
    if (r.status === 'broken') warnings.push({ path: 'resources.yaml', message: `${r.id}: marked as broken` })
    if (r.status === 'verified' && !r.verifiedAt) err('resources.yaml', `${r.id}: verified without a date`)
  }

  for (const m of c.modules)
    if (!c.lessons.some((l) => l.module === m.id)) warnings.push({ path: 'curriculum.yaml', message: `Module ${m.number} (${m.id}) has no lessons yet` })

  return { errors, warnings }
}

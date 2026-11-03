import type { Catalog, Issue } from './parse'

export interface Report {
  errors: Issue[]
  warnings: Issue[]
}

const VIDEO_HOSTS = [/youtube\.com/, /youtu\.be/, /vimeo\.com/, /developer\.apple\.com\/videos/, /twitch\.tv/]

/** Comprobaciones de integridad entre entidades. No depende del navegador ni de Node. */
export function validateCatalog(c: Catalog): Report {
  const errors: Issue[] = []
  const warnings: Issue[] = []
  const err = (path: string, message: string) => errors.push({ path, message })

  // IDs únicos en todo el curso (el progreso se guarda por ID).
  const seen = new Map<string, string>()
  const claim = (id: string, where: string) => {
    const prev = seen.get(id)
    if (prev) err(where, `ID duplicado "${id}" (también en ${prev})`)
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
    if (!stageIds.has(m.stage)) err('curriculum.yaml', `Módulo ${m.id}: etapa inexistente "${m.stage}"`)
    for (const p of m.prerequisites) {
      const pm = moduleById.get(p)
      if (!pm) err('curriculum.yaml', `Módulo ${m.id}: prerrequisito inexistente "${p}"`)
      else if (pm.number >= m.number) err('curriculum.yaml', `Módulo ${m.id}: el prerrequisito ${p} debe ir antes en la secuencia`)
    }
  }
  const numbers = new Set<number>()
  for (const m of c.modules) {
    if (numbers.has(m.number)) err('curriculum.yaml', `Número de módulo repetido: ${m.number}`)
    numbers.add(m.number)
  }

  const orderKey = new Set<string>()
  for (const l of c.lessons) {
    const mod = moduleById.get(l.module)
    if (!mod) {
      err(l.path, `Módulo inexistente "${l.module}"`)
      continue
    }
    const key = `${l.module}#${l.order}`
    if (orderKey.has(key)) err(l.path, `Orden ${l.order} repetido dentro de ${l.module}`)
    orderKey.add(key)

    for (const p of l.prerequisites) {
      const pl = lessonById.get(p)
      if (!pl) {
        err(l.path, `Prerrequisito inexistente "${p}"`)
        continue
      }
      const pmod = moduleById.get(pl.module)
      if (pmod && (pmod.number > mod.number || (pmod.number === mod.number && pl.order >= l.order)))
        err(l.path, `El prerrequisito ${p} debe estar antes en la secuencia`)
    }
    for (const r of l.resources) if (!resourceIds.has(r)) err(l.path, `Recurso inexistente "${r}"`)
    if (l.exercises.length === 0) err(l.path, 'La lección no tiene ejercicios')

    const fences = l.segments
      .filter((s) => s.kind === 'md')
      .map((s) => (s.kind === 'md' ? s.text : ''))
      .join('\n')
      .match(/^```/gm)
    if (fences && fences.length % 2 !== 0) err(l.path, 'Bloque de código sin cerrar (número impar de ```)')

    for (const e of l.exercises) {
      const where = `${l.path} › ${e.id}`
      if (e.type === 'comprension') {
        const correct = e.choices.filter((ch) => ch.correct).length
        if (correct === 0) err(where, 'Ninguna opción es correcta')
        if (!e.multiple && correct !== 1) err(where, 'Selección única con más de una respuesta correcta')
      }
      if (e.type === 'errores' && !e.choices.some((ch) => ch.correct)) err(where, 'Ninguna opción identifica un error real')
      if (e.type === 'completar') {
        const holes = [...e.code.matchAll(/\[\[(\w+)\]\]/g)].map((m) => m[1])
        const declared = e.blanks.map((b) => b.id)
        if (holes.length === 0) err(where, 'El código no tiene huecos [[n]]')
        for (const h of holes) if (!declared.includes(h ?? '')) err(where, `Hueco [[${h}]] sin respuesta declarada`)
        for (const d of declared) if (!holes.includes(d)) err(where, `Respuesta para hueco inexistente "${d}"`)
      }
    }
  }

  const knownRef = (id: string) => lessonById.has(id) || moduleById.has(id)
  for (const ch of c.challenges) {
    for (const p of ch.prerequisites) if (!knownRef(p)) err(ch.path, `Prerrequisito inexistente "${p}"`)
    if (ch.reveal.length < 3) err(ch.path, 'Se esperan al menos 3 secciones revelables (enfoque, solución, explicación)')
    if (ch.solutionCode && !/\bfunc\b|\bstruct\b|\bclass\b/.test(ch.solutionCode)) err(ch.path, 'El archivo de solución no contiene código Swift reconocible')
    if (ch.testCode && !/@Test\b/.test(ch.testCode)) err(ch.path, 'El archivo de tests no contiene ningún @Test')
  }

  for (const q of c.questions)
    for (const r of q.related) if (!knownRef(r) && !c.challenges.some((ch) => ch.id === r)) err('content/interview', `${q.id}: relacionado inexistente "${r}"`)

  for (const p of c.projects) for (const r of p.prerequisites) if (!moduleById.has(r)) err(p.path, `Prerrequisito inexistente "${r}"`)

  const urls = new Map<string, string>()
  for (const r of c.resources) {
    if (VIDEO_HOSTS.some((h) => h.test(r.url))) err('resources.yaml', `${r.id}: no se permiten enlaces a videos`)
    const prev = urls.get(r.url)
    if (prev) err('resources.yaml', `${r.id}: URL duplicada (también en ${prev})`)
    urls.set(r.url, r.id)
    if (r.status === 'roto') warnings.push({ path: 'resources.yaml', message: `${r.id}: marcado como roto` })
    if (r.status === 'verificado' && !r.verifiedAt) err('resources.yaml', `${r.id}: verificado sin fecha`)
  }

  for (const m of c.modules)
    if (!c.lessons.some((l) => l.module === m.id)) warnings.push({ path: 'curriculum.yaml', message: `Módulo ${m.number} (${m.id}) sin lecciones todavía` })

  return { errors, warnings }
}

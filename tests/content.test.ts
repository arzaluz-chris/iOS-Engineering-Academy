import { describe, expect, it } from 'vitest'
import { loadFromDisk } from '../scripts/load-content'
import { buildCatalog } from '../src/content/parse'
import { validateCatalog } from '../src/content/validate'

describe('contenido real del curso', () => {
  const { catalog, issues } = loadFromDisk()
  const report = validateCatalog(catalog)

  it('se carga sin errores de esquema', () => {
    expect(issues).toEqual([])
  })

  it('no tiene errores de integridad', () => {
    expect(report.errors).toEqual([])
  })

  it('tiene el mapa completo: 12 a 16 etapas y al menos un módulo por etapa', () => {
    expect(catalog.stages.length).toBeGreaterThanOrEqual(12)
    expect(catalog.stages.length).toBeLessThanOrEqual(16)
    for (const s of catalog.stages) expect(catalog.modules.some((m) => m.stage === s.id)).toBe(true)
  })

  it('incluye un módulo de desarrollo seguro', () => {
    expect(catalog.modules.some((m) => /seguro/i.test(m.title))).toBe(true)
    expect(catalog.questions.some((q) => q.category === 'seguridad')).toBe(true)
  })

  it('cada lección escrita tiene objetivos, ejercicios con solución y sección de dominio', () => {
    for (const l of catalog.lessons) {
      expect(l.objectives.length, l.id).toBeGreaterThan(0)
      expect(l.mastery.length, l.id).toBeGreaterThan(0)
      expect(l.exercises.length, l.id).toBeGreaterThan(0)
      for (const e of l.exercises) expect(e.solution.trim().length, e.id).toBeGreaterThan(20)
    }
  })

  it('cada reto enlaza su solución y sus pruebas Swift reales', () => {
    for (const c of catalog.challenges) {
      expect(c.solutionCode, c.id).toMatch(/public func/)
      expect(c.testCode, c.id).toMatch(/import Testing/)
      expect(c.reveal.map((s) => s.heading)).toContain('Solución optimizada')
    }
  })

  it('no enlaza videos', () => {
    for (const r of catalog.resources) expect(r.url).not.toMatch(/youtube|vimeo|developer\.apple\.com\/videos/)
  })
})

describe('validador', () => {
  const base = {
    curriculum: `stages:\n  - {id: s01, number: 1, title: E, summary: S, outcome: O}\nmodules:\n  - {id: m01, stage: s01, number: 1, title: M, summary: S, objectives: [o], topics: [t]}\n  - {id: m02, stage: s01, number: 2, title: M2, summary: S, objectives: [o], topics: [t], prerequisites: [m03]}\n`,
    resources: 'resources: []\n',
    lessons: {},
    challenges: {},
    interview: {},
    projects: {},
    swift: {},
  }

  it('detecta prerrequisitos inexistentes', () => {
    const { catalog } = buildCatalog(base)
    const r = validateCatalog(catalog)
    expect(r.errors.some((e) => e.message.includes('prerrequisito inexistente "m03"'))).toBe(true)
  })

  it('detecta IDs duplicados y huecos sin respuesta', () => {
    const lesson = (id: string) => `---\nid: ${id}\ntitle: T\ndescription: D\nmodule: m01\norder: ${id === 'a' ? 1 : 2}\nlevel: inicial\nminutes: 10\nobjectives: [o]\nmastery: [m]\ncodeStatus: sin-codigo\n---\n\n\`\`\`\`exercise\nid: e1\ntype: completar\nprompt: P\ncode: "let x = [[1]] + [[2]]"\nblanks:\n  - {id: "1", answers: ["1"]}\nsolution: S\n\`\`\`\`\n`
    const { catalog, issues } = buildCatalog({ ...base, lessons: { 'a.md': lesson('a'), 'b.md': lesson('b') } })
    expect(issues).toEqual([])
    const r = validateCatalog(catalog)
    expect(r.errors.some((e) => e.message.includes('ID duplicado "e1"'))).toBe(true)
    expect(r.errors.some((e) => e.message.includes('Hueco [[2]]'))).toBe(true)
  })

  it('rechaza un ejercicio de opción única con dos respuestas correctas', () => {
    const md = `---\nid: a\ntitle: T\ndescription: D\nmodule: m01\norder: 1\nlevel: inicial\nminutes: 10\nobjectives: [o]\nmastery: [m]\ncodeStatus: sin-codigo\n---\n\`\`\`\`exercise\nid: e1\ntype: comprension\nprompt: P\nchoices:\n  - {text: A, correct: true}\n  - {text: B, correct: true}\nsolution: S\n\`\`\`\`\n`
    const { catalog } = buildCatalog({ ...base, lessons: { 'a.md': md } })
    expect(validateCatalog(catalog).errors.some((e) => e.message.includes('más de una respuesta correcta'))).toBe(true)
  })

  it('exige la traducción a Swift en una predicción en pseudocódigo', () => {
    const md = (solution: string) =>
      `---\nid: a\ntitle: T\ndescription: D\nmodule: m01\norder: 1\nlevel: inicial\nminutes: 10\nobjectives: [o]\nmastery: [m]\ncodeStatus: sin-codigo\n---\n\`\`\`\`exercise\nid: e1\ntype: prediccion\nlang: pseudo\nprompt: P\ncode: |\n  Muestra 1\noutput: |\n  1\nsolution: |\n${solution}\n\`\`\`\`\n`
    const sin = buildCatalog({ ...base, lessons: { 'a.md': md('  Muestra 1 imprime 1.') } })
    expect(sin.issues).toEqual([])
    expect(sin.catalog.lessons[0]?.exercises[0]).toMatchObject({ type: 'prediccion', lang: 'pseudo' })
    expect(validateCatalog(sin.catalog).errors.some((e) => e.message.includes('sin traducción a Swift'))).toBe(true)
    const con = buildCatalog({ ...base, lessons: { 'a.md': md('  Explicación.\n\n  ```swift\n  print(1)\n  ```') } })
    expect(validateCatalog(con.catalog).errors.some((e) => e.message.includes('sin traducción a Swift'))).toBe(false)
  })

  it('una predicción sin lang se considera Swift', () => {
    const md = `---\nid: a\ntitle: T\ndescription: D\nmodule: m01\norder: 1\nlevel: inicial\nminutes: 10\nobjectives: [o]\nmastery: [m]\ncodeStatus: sin-codigo\n---\n\`\`\`\`exercise\nid: e1\ntype: prediccion\nprompt: P\ncode: print(1)\noutput: "1"\nsolution: S\n\`\`\`\`\n`
    expect(buildCatalog({ ...base, lessons: { 'a.md': md } }).catalog.lessons[0]?.exercises[0]).toMatchObject({ lang: 'swift' })
  })

  it('reporta frontmatter inválido sin detenerse', () => {
    const { issues } = buildCatalog({ ...base, lessons: { 'x.md': '---\nid: X Mal\n---\nhola' } })
    expect(issues.length).toBeGreaterThan(0)
  })
})

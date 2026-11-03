import { describe, expect, it } from 'vitest'
import { loadFromDisk } from '../scripts/load-content'
import { buildCatalog } from '../src/content/parse'
import { validateCatalog } from '../src/content/validate'

describe('real course content', () => {
  const { catalog, issues } = loadFromDisk()
  const report = validateCatalog(catalog)

  it('loads without schema errors', () => {
    expect(issues).toEqual([])
  })

  it('has no integrity errors', () => {
    expect(report.errors).toEqual([])
  })

  it('has the full map: 12 to 16 stages and at least one module per stage', () => {
    expect(catalog.stages.length).toBeGreaterThanOrEqual(12)
    expect(catalog.stages.length).toBeLessThanOrEqual(16)
    for (const s of catalog.stages) expect(catalog.modules.some((m) => m.stage === s.id)).toBe(true)
  })

  it('includes a secure development module', () => {
    expect(catalog.modules.some((m) => /secure/i.test(m.title))).toBe(true)
    expect(catalog.questions.some((q) => q.category === 'security')).toBe(true)
  })

  it('every written lesson has objectives, exercises with solutions and a mastery section', () => {
    for (const l of catalog.lessons) {
      expect(l.objectives.length, l.id).toBeGreaterThan(0)
      expect(l.mastery.length, l.id).toBeGreaterThan(0)
      expect(l.exercises.length, l.id).toBeGreaterThan(0)
      for (const e of l.exercises) expect(e.solution.trim().length, e.id).toBeGreaterThan(20)
    }
  })

  it('every challenge links its real Swift solution and tests', () => {
    for (const c of catalog.challenges) {
      expect(c.solutionCode, c.id).toMatch(/public func/)
      expect(c.testCode, c.id).toMatch(/import Testing/)
      expect(c.reveal.map((s) => s.heading)).toContain('Optimized solution')
    }
  })

  it('doesn’t link to videos', () => {
    for (const r of catalog.resources) expect(r.url).not.toMatch(/youtube|vimeo|developer\.apple\.com\/videos/)
  })
})

describe('validator', () => {
  const base = {
    curriculum: `stages:\n  - {id: s01, number: 1, title: E, summary: S, outcome: O}\nmodules:\n  - {id: m01, stage: s01, number: 1, title: M, summary: S, objectives: [o], topics: [t]}\n  - {id: m02, stage: s01, number: 2, title: M2, summary: S, objectives: [o], topics: [t], prerequisites: [m03]}\n`,
    resources: 'resources: []\n',
    lessons: {},
    challenges: {},
    interview: {},
    projects: {},
    swift: {},
  }

  it('catches unknown prerequisites', () => {
    const { catalog } = buildCatalog(base)
    const r = validateCatalog(catalog)
    expect(r.errors.some((e) => e.message.includes('unknown prerequisite "m03"'))).toBe(true)
  })

  it('catches duplicate IDs and blanks without an answer', () => {
    const lesson = (id: string) => `---\nid: ${id}\ntitle: T\ndescription: D\nmodule: m01\norder: ${id === 'a' ? 1 : 2}\nlevel: beginner\nminutes: 10\nobjectives: [o]\nmastery: [m]\ncodeStatus: no-code\n---\n\n\`\`\`\`exercise\nid: e1\ntype: fill-in\nprompt: P\ncode: "let x = [[1]] + [[2]]"\nblanks:\n  - {id: "1", answers: ["1"]}\nsolution: S\n\`\`\`\`\n`
    const { catalog, issues } = buildCatalog({ ...base, lessons: { 'a.md': lesson('a'), 'b.md': lesson('b') } })
    expect(issues).toEqual([])
    const r = validateCatalog(catalog)
    expect(r.errors.some((e) => e.message.includes('Duplicate ID "e1"'))).toBe(true)
    expect(r.errors.some((e) => e.message.includes('Blank [[2]]'))).toBe(true)
  })

  it('rejects a single-choice exercise with two correct answers', () => {
    const md = `---\nid: a\ntitle: T\ndescription: D\nmodule: m01\norder: 1\nlevel: beginner\nminutes: 10\nobjectives: [o]\nmastery: [m]\ncodeStatus: no-code\n---\n\`\`\`\`exercise\nid: e1\ntype: comprehension\nprompt: P\nchoices:\n  - {text: A, correct: true}\n  - {text: B, correct: true}\nsolution: S\n\`\`\`\`\n`
    const { catalog } = buildCatalog({ ...base, lessons: { 'a.md': md } })
    expect(validateCatalog(catalog).errors.some((e) => e.message.includes('more than one correct answer'))).toBe(true)
  })

  it('requires a Swift translation for a pseudocode prediction', () => {
    const md = (solution: string) =>
      `---\nid: a\ntitle: T\ndescription: D\nmodule: m01\norder: 1\nlevel: beginner\nminutes: 10\nobjectives: [o]\nmastery: [m]\ncodeStatus: no-code\n---\n\`\`\`\`exercise\nid: e1\ntype: prediction\nlang: pseudo\nprompt: P\ncode: |\n  Print 1\noutput: |\n  1\nsolution: |\n${solution}\n\`\`\`\`\n`
    const without = buildCatalog({ ...base, lessons: { 'a.md': md('  Print 1 prints 1.') } })
    expect(without.issues).toEqual([])
    expect(without.catalog.lessons[0]?.exercises[0]).toMatchObject({ type: 'prediction', lang: 'pseudo' })
    expect(validateCatalog(without.catalog).errors.some((e) => e.message.includes('without a Swift translation'))).toBe(true)
    const withSwift = buildCatalog({ ...base, lessons: { 'a.md': md('  Explanation.\n\n  ```swift\n  print(1)\n  ```') } })
    expect(validateCatalog(withSwift.catalog).errors.some((e) => e.message.includes('without a Swift translation'))).toBe(false)
  })

  it('a prediction without lang is treated as Swift', () => {
    const md = `---\nid: a\ntitle: T\ndescription: D\nmodule: m01\norder: 1\nlevel: beginner\nminutes: 10\nobjectives: [o]\nmastery: [m]\ncodeStatus: no-code\n---\n\`\`\`\`exercise\nid: e1\ntype: prediction\nprompt: P\ncode: print(1)\noutput: "1"\nsolution: S\n\`\`\`\`\n`
    expect(buildCatalog({ ...base, lessons: { 'a.md': md } }).catalog.lessons[0]?.exercises[0]).toMatchObject({ lang: 'swift' })
  })

  it('reports invalid frontmatter without stopping', () => {
    const { issues } = buildCatalog({ ...base, lessons: { 'x.md': '---\nid: X Bad\n---\nhello' } })
    expect(issues.length).toBeGreaterThan(0)
  })
})

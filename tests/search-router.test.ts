import { describe, expect, it } from 'vitest'
import { loadFromDisk } from '../scripts/load-content'
import { parseHash } from '../src/router'
import { buildDocs, createIndex } from '../src/search'
import { latestByRef, lessonMastery } from '../src/db/stats'

const { catalog } = loadFromDisk()
const index = createIndex(buildDocs(catalog))

describe('buscador', () => {
  it('encuentra sin importar acentos', () => {
    const ids = index.search('compilacion').map((r) => r.id)
    expect(ids).toContain('leccion:m01-l02')
  })

  it('encuentra retos por patrón y preguntas de entrevista', () => {
    expect(index.search('two pointers').some((r) => r.id === 'reto:valid-palindrome')).toBe(true)
    expect(index.search('keychain').some((r) => r.kind === 'pregunta')).toBe(true)
  })

  it('todos los resultados internos apuntan a rutas con hash', () => {
    for (const r of index.search('swift')) if (r.kind !== 'recurso') expect(r.href).toMatch(/^#\//)
  })
})

describe('enrutador', () => {
  it('interpreta ruta y parámetros', () => {
    const r = parseHash('#/leccion/m01-l01/m01-l01-e2?x=1')
    expect(r.path).toEqual(['leccion', 'm01-l01', 'm01-l01-e2'])
    expect(r.query.get('x')).toBe('1')
    expect(parseHash('').path).toEqual([])
  })
})

describe('dominio de una lección', () => {
  it('requiere el último intento correcto en todos los ejercicios', () => {
    const lesson = catalog.lessons[0]!
    const attempts = lesson.exercises.map((e, i) => ({ kind: 'ejercicio' as const, refId: e.id, at: `2026-11-0${i + 1}T00:00:00.000Z`, result: 'correcto' as const, score: 1, grading: 'automatica' as const }))
    expect(lessonMastery(lesson, latestByRef(attempts)).mastered).toBe(true)
    const withFail = [...attempts, { ...attempts[0]!, at: '2026-12-01T00:00:00.000Z', result: 'incorrecto' as const }]
    expect(lessonMastery(lesson, latestByRef(withFail)).mastered).toBe(false)
  })
})

import { beforeEach, describe, expect, it } from 'vitest'
import { completeLesson, ensureCard, recordAttempt, reviewCard, saveNote, setDifficult, startLesson } from '../src/db/actions'
import { exportBackup, importBackup, parseBackup, resetAll } from '../src/db/backup'
import { db, useTestDatabase } from '../src/db/db'
import { orderDue } from '../src/pages/Review'

let n = 0
beforeEach(async () => {
  useTestDatabase(`test-${++n}`)
  await db.open()
})

describe('progreso', () => {
  it('abrir una lección no la completa', async () => {
    await startLesson('m01-l01', 'Lección')
    expect((await db.lessons.get('m01-l01'))?.status).toBe('en-curso')
  })

  it('completar una lección agrega sus tarjetas de concepto al repaso', async () => {
    await completeLesson('m01-l01', 'Lección', ['c1', 'c2'])
    expect((await db.lessons.get('m01-l01'))?.status).toBe('completada')
    expect(await db.cards.count()).toBe(2)
  })

  it('un intento incorrecto agrega el ejercicio al repaso, uno correcto no', async () => {
    await recordAttempt({ kind: 'ejercicio', refId: 'e1', result: 'incorrecto', score: 0, grading: 'automatica', label: 'x' })
    await recordAttempt({ kind: 'ejercicio', refId: 'e2', result: 'correcto', score: 1, grading: 'automatica', label: 'x' })
    expect(await db.cards.get('ejercicio:e1')).toBeDefined()
    expect(await db.cards.get('ejercicio:e2')).toBeUndefined()
  })

  it('repasar una tarjeta la reprograma al futuro y registra el historial', async () => {
    await ensureCard('concepto', 'c1', 'leccion')
    const card = (await db.cards.get('concepto:c1'))!
    await reviewCard(card, 3, 'c1')
    const after = (await db.cards.get('concepto:c1'))!
    expect(after.dueAt > new Date().toISOString()).toBe(true)
    expect(await db.revlog.count()).toBe(1)
  })

  it('el repaso prioriza difíciles y fallos', async () => {
    await ensureCard('concepto', 'a', 'leccion')
    await ensureCard('ejercicio', 'b', 'fallo')
    await ensureCard('concepto', 'c', 'leccion')
    await setDifficult('concepto:c', true)
    const ordered = orderDue(await db.cards.toArray()).map((c) => c.id)
    expect(ordered.slice(0, 2)).toEqual(['concepto:c', 'ejercicio:b'])
  })
})

describe('respaldo', () => {
  it('exporta e importa sin perder datos', async () => {
    await startLesson('m01-l01', 'L')
    await recordAttempt({ kind: 'reto', refId: 'two-sum', result: 'parcial', score: 0.5, grading: 'autoevaluacion', answer: 'func x() {}', label: 'Two Sum' })
    await saveNote('leccion', 'm01-l01', 'Repasar compilador')
    const backup = await exportBackup()
    const json = JSON.stringify(backup)

    await resetAll()
    expect(await db.notes.count()).toBe(0)

    const parsed = parseBackup(json)
    expect(parsed.ok).toBe(true)
    if (!parsed.ok) return
    await importBackup(parsed.backup)
    expect((await db.notes.toArray())[0]?.text).toBe('Repasar compilador')
    expect(await db.attempts.count()).toBe(1)
    expect(await db.cards.get('reto:two-sum')).toBeDefined()
  })

  it('rechaza archivos que no son respaldos válidos', () => {
    expect(parseBackup('no es json').ok).toBe(false)
    expect(parseBackup('{"format":"otra-cosa"}').ok).toBe(false)
    const bad = { format: 'ios-engineering-academy/backup', version: 1, exportedAt: new Date().toISOString(), data: { lessons: [{ lessonId: 'x', status: 'quizas', startedAt: 'ayer' }] } }
    expect(parseBackup(JSON.stringify(bad)).ok).toBe(false)
  })

  it('una importación inválida no toca los datos existentes', async () => {
    await saveNote('leccion', 'a', 'se queda')
    const r = parseBackup('{}')
    expect(r.ok).toBe(false)
    expect(await db.notes.count()).toBe(1)
  })
})

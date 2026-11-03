import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { db, useTestDatabase } from '../src/db/db'
import { ExerciseBlock } from '../src/exercises/ExerciseBlock'
import { Dashboard } from '../src/pages/Dashboard'
import { CurriculumPage } from '../src/pages/Curriculum'
import { getExercise } from '../src/content'

let n = 0
beforeEach(async () => {
  useTestDatabase(`ui-${++n}`)
  await db.open()
})
afterEach(cleanup)

describe('interfaz', () => {
  it('un ejercicio de comprensión registra el intento y muestra el resultado', async () => {
    const ref = getExercise('m04-l01-e1')!
    render(<ExerciseBlock exercise={ref.exercise} label="prueba" />)
    fireEvent.click(screen.getByLabelText(/^`?2`?$/, { selector: 'input' }) ?? screen.getAllByRole('radio')[1]!)
    fireEvent.click(screen.getByRole('button', { name: 'Comprobar respuesta' }))
    expect(await screen.findByRole('status')).toHaveProperty('textContent', 'Correcto.')
    await waitFor(async () => expect(await db.attempts.count()).toBe(1))
    const a = (await db.attempts.toArray())[0]!
    expect(a.result).toBe('correcto')
    expect(a.grading).toBe('automatica')
  })

  it('la solución no se muestra antes de pedirla', () => {
    const ref = getExercise('m04-l01-e2')!
    render(<ExerciseBlock exercise={ref.exercise} label="prueba" />)
    expect(screen.queryByText('Solución')).toBeNull()
    expect(screen.getByRole('button', { name: 'Mostrar solución explicada' })).toBeDefined()
  })

  it('una predicción en pseudocódigo se etiqueta como pseudocódigo y se califica igual', async () => {
    const ref = getExercise('m02-l02-e2')!
    expect(ref.exercise).toMatchObject({ type: 'prediccion', lang: 'pseudo' })
    render(<ExerciseBlock exercise={ref.exercise} label="prueba" />)
    expect(screen.getByText('Pseudocódigo')).toBeDefined()
    expect(screen.getByText(/¿Qué muestra este algoritmo\?/)).toBeDefined()
    fireEvent.change(screen.getByRole('textbox', { name: /¿Qué muestra este algoritmo/ }), { target: { value: '16\n10\n20\n1\n3\n9' } })
    fireEvent.click(screen.getByRole('button', { name: 'Comprobar salida' }))
    await waitFor(async () => expect((await db.attempts.toArray())[0]?.result).toBe('correcto'))
  })

  it('el dashboard sin progreso invita a empezar y no inventa métricas', async () => {
    render(<Dashboard />)
    expect(await screen.findByRole('heading', { name: 'Empieza desde cero' })).toBeDefined()
    expect(screen.getByText(/tiempo de estudio no se registra/i)).toBeDefined()
  })

  it('el currículo lista todas las etapas', () => {
    render(<CurriculumPage />)
    expect(screen.getAllByRole('heading', { level: 2 }).length).toBeGreaterThanOrEqual(12)
  })
})

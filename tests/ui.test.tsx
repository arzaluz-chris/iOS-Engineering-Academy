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

describe('UI', () => {
  it('a comprehension exercise records the attempt and shows the result', async () => {
    const ref = getExercise('m04-l01-e1')!
    render(<ExerciseBlock exercise={ref.exercise} label="test" />)
    fireEvent.click(screen.getByLabelText(/^`?2`?$/, { selector: 'input' }) ?? screen.getAllByRole('radio')[1]!)
    fireEvent.click(screen.getByRole('button', { name: 'Check answer' }))
    expect(await screen.findByRole('status')).toHaveProperty('textContent', 'Correct.')
    await waitFor(async () => expect(await db.attempts.count()).toBe(1))
    const a = (await db.attempts.toArray())[0]!
    expect(a.result).toBe('correcto')
    expect(a.grading).toBe('automatica')
  })

  it('the solution stays hidden until it’s asked for', () => {
    const ref = getExercise('m04-l01-e2')!
    render(<ExerciseBlock exercise={ref.exercise} label="test" />)
    expect(screen.queryByText('Solution')).toBeNull()
    expect(screen.getByRole('button', { name: 'Show the worked solution' })).toBeDefined()
  })

  it('a pseudocode prediction is labeled as pseudocode and graded the same way', async () => {
    const ref = getExercise('m02-l02-e2')!
    expect(ref.exercise).toMatchObject({ type: 'prediction', lang: 'pseudo' })
    render(<ExerciseBlock exercise={ref.exercise} label="test" />)
    expect(screen.getByText('Pseudocode')).toBeDefined()
    expect(screen.getByText(/What does this algorithm print\?/)).toBeDefined()
    fireEvent.change(screen.getByRole('textbox', { name: /What does this algorithm print/ }), { target: { value: '16\n10\n20\n1\n3\n9' } })
    fireEvent.click(screen.getByRole('button', { name: 'Check output' }))
    await waitFor(async () => expect((await db.attempts.toArray())[0]?.result).toBe('correcto'))
  })

  it('the dashboard with no progress invites you to start and doesn’t make up metrics', async () => {
    render(<Dashboard />)
    expect(await screen.findByRole('heading', { name: 'From your first line of code to shipping iOS apps.' })).toBeDefined()
    expect(screen.getByText(/study time isn’t tracked/i)).toBeDefined()
  })

  it('the curriculum lists every stage', () => {
    render(<CurriculumPage />)
    expect(screen.getAllByRole('heading', { level: 2 }).length).toBeGreaterThanOrEqual(12)
  })
})

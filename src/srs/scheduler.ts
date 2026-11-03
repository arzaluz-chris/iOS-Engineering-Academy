import { DefaultScheduler, Rating } from 'ts-fsrs'

/**
 * Repetición espaciada con FSRS (ts-fsrs v6).
 * El modelo se fija explícitamente: si en el futuro se cambia, hay que
 * reprogramar las tarjetas desde el historial (tabla revlog), que se conserva completo.
 */
export const FSRS_MODEL = 'FSRS-7' as const

type Scheduler = Awaited<ReturnType<typeof DefaultScheduler>>
let schedulerPromise: Promise<Scheduler> | null = null

export function scheduler(): Promise<Scheduler> {
  schedulerPromise ??= DefaultScheduler({ version: FSRS_MODEL, desiredRetention: 0.9, enableFuzz: false })
  return schedulerPromise
}

export type Grade = 1 | 2 | 3 | 4
export const GRADES: { grade: Grade; label: string; hint: string }[] = [
  { grade: Rating.Again as Grade, label: 'No lo recordé', hint: 'Vuelve en minutos' },
  { grade: Rating.Hard as Grade, label: 'Con dificultad', hint: 'Intervalo corto' },
  { grade: Rating.Good as Grade, label: 'Lo recordé', hint: 'Intervalo normal' },
  { grade: Rating.Easy as Grade, label: 'Fácil', hint: 'Intervalo largo' },
]

const DATE_KEYS = ['dueAt', 'lastReviewAt'] as const

export function serialize(card: object): Record<string, unknown> {
  return JSON.parse(JSON.stringify(card)) as Record<string, unknown>
}

/** Restaura las fechas de una tarjeta guardada como JSON. */
export function revive(stored: Record<string, unknown>): Record<string, unknown> {
  const c: Record<string, unknown> = { ...stored }
  for (const k of DATE_KEYS) if (typeof c[k] === 'string') c[k] = new Date(c[k] as string)
  return c
}

export async function newCard(now: Date) {
  const s = await scheduler()
  const card = s.newCard({ now })
  return { fsrs: serialize(card), dueAt: new Date(card.dueAt).toISOString() }
}

export async function gradeCard(stored: Record<string, unknown>, grade: Grade, now: Date) {
  const s = await scheduler()
  // La tarjeta viene de la propia biblioteca (serializada); solo se restauran sus fechas.
  const { card } = s.review({ card: revive(stored) as never, grade, now })
  return { fsrs: serialize(card), dueAt: new Date(card.dueAt).toISOString() }
}

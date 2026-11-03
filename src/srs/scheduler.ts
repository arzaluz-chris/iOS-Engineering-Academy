import { DefaultScheduler, Rating } from 'ts-fsrs'

/**
 * Spaced repetition with FSRS (ts-fsrs v6).
 * The model is pinned on purpose: if it ever changes, cards have to be
 * rescheduled from the history (the revlog table), which is kept in full.
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
  { grade: Rating.Again as Grade, label: 'Forgot', hint: 'Back in minutes' },
  { grade: Rating.Hard as Grade, label: 'Hard', hint: 'Short interval' },
  { grade: Rating.Good as Grade, label: 'Remembered', hint: 'Normal interval' },
  { grade: Rating.Easy as Grade, label: 'Easy', hint: 'Long interval' },
]

const DATE_KEYS = ['dueAt', 'lastReviewAt'] as const

export function serialize(card: object): Record<string, unknown> {
  return JSON.parse(JSON.stringify(card)) as Record<string, unknown>
}

/** Restores the dates of a card stored as JSON. */
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
  // The card comes from the library itself (serialized); only its dates need restoring.
  const { card } = s.review({ card: revive(stored) as never, grade, now })
  return { fsrs: serialize(card), dueAt: new Date(card.dueAt).toISOString() }
}

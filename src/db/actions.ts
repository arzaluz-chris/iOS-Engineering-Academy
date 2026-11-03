import { gradeCard, newCard, type Grade } from '../srs/scheduler'
import {
  db,
  now,
  type Activity,
  type AttemptKind,
  type AttemptResult,
  type CardSource,
  type ChallengeStatus,
  type NoteTarget,
  type ReviewCard,
} from './db'

export async function logActivity(type: Activity['type'], refId: string, label: string) {
  await db.activity.add({ at: now(), type, refId, label })
}

// ---------- Lessons ----------

export async function startLesson(lessonId: string, title: string) {
  const existing = await db.lessons.get(lessonId)
  if (existing) return
  await db.lessons.put({ lessonId, status: 'en-curso', startedAt: now() })
  await logActivity('leccion-iniciada', lessonId, title)
}

export async function setLessonAnchor(lessonId: string, anchor: string) {
  await db.lessons.update(lessonId, { lastAnchor: anchor })
}

export async function completeLesson(lessonId: string, title: string, cardIds: string[]) {
  const existing = await db.lessons.get(lessonId)
  await db.lessons.put({ ...(existing ?? { lessonId, startedAt: now() }), status: 'completada', completedAt: now() })
  for (const id of cardIds) await ensureCard('concepto', id, 'leccion')
  await logActivity('leccion-completada', lessonId, title)
}

export async function reopenLesson(lessonId: string) {
  await db.lessons.update(lessonId, { status: 'en-curso', completedAt: undefined })
}

// ---------- Attempts ----------

export async function recordAttempt(params: {
  kind: AttemptKind
  refId: string
  result: AttemptResult
  score: number
  grading: 'automatica' | 'autoevaluacion'
  answer?: string
  label: string
}) {
  const { label, ...attempt } = params
  await db.attempts.add({ ...attempt, at: now() })
  const source: CardSource = params.kind === 'ejercicio' ? 'ejercicio' : params.kind === 'reto' ? 'reto' : 'pregunta'
  if (params.result !== 'correcto') await ensureCard(source, params.refId, 'fallo')
  await logActivity(params.kind === 'ejercicio' ? 'ejercicio' : params.kind === 'reto' ? 'reto' : 'entrevista', params.refId, label)
}

export async function saveDraft(key: string, code: string) {
  await db.drafts.put({ key, code, updatedAt: now() })
}

// ---------- Challenges ----------

export async function updateChallenge(challengeId: string, patch: { status?: ChallengeStatus; revealed?: number; hintsUsed?: number }) {
  const prev = await db.challenges.get(challengeId)
  await db.challenges.put({
    challengeId,
    status: patch.status ?? prev?.status ?? 'intentado',
    revealed: Math.max(patch.revealed ?? 0, prev?.revealed ?? 0),
    hintsUsed: Math.max(patch.hintsUsed ?? 0, prev?.hintsUsed ?? 0),
    updatedAt: now(),
  })
}

// ---------- Interview questions ----------

export async function setQuestionStatus(questionId: string, status: 'pendiente' | 'dominada') {
  await db.questions.put({ questionId, status, updatedAt: now() })
}

// ---------- Projects ----------

export async function toggleMilestone(projectId: string, milestoneId: string, title: string) {
  const prev = await db.projects.get(projectId)
  const done = new Set(prev?.milestonesDone ?? [])
  if (done.has(milestoneId)) done.delete(milestoneId)
  else done.add(milestoneId)
  await db.projects.put({ projectId, startedAt: prev?.startedAt ?? now(), milestonesDone: [...done], updatedAt: now() })
  if (!prev) await logActivity('proyecto', projectId, title)
}

export async function startProject(projectId: string, title: string) {
  if (await db.projects.get(projectId)) return
  await db.projects.put({ projectId, startedAt: now(), milestonesDone: [], updatedAt: now() })
  await logActivity('proyecto', projectId, title)
}

// ---------- Notes and bookmarks ----------

export async function saveNote(targetType: NoteTarget, targetId: string, text: string, id?: number) {
  const t = now()
  if (id !== undefined) {
    await db.notes.update(id, { text, updatedAt: t })
    return id
  }
  const newId = await db.notes.add({ targetType, targetId, text, createdAt: t, updatedAt: t })
  await logActivity('nota', targetId, 'Note added')
  return newId
}

export async function deleteNote(id: number) {
  await db.notes.delete(id)
}

export async function toggleBookmark(targetType: NoteTarget | 'recurso', targetId: string) {
  const key = `${targetType}:${targetId}`
  if (await db.bookmarks.get(key)) await db.bookmarks.delete(key)
  else await db.bookmarks.put({ key, targetType, targetId, createdAt: now() })
}

// ---------- Spaced review ----------

export const cardKey = (source: CardSource, refId: string) => `${source}:${refId}`

export async function ensureCard(source: CardSource, refId: string, reason: ReviewCard['reason']) {
  const id = cardKey(source, refId)
  const existing = await db.cards.get(id)
  if (existing) {
    // A new miss makes the card due today again.
    if (reason === 'fallo' && existing.dueAt > now()) await db.cards.update(id, { dueAt: now(), reason })
    return
  }
  const t = new Date()
  const { fsrs, dueAt } = await newCard(t)
  await db.cards.put({ id, source, refId, fsrs, dueAt, difficult: false, addedAt: t.toISOString(), reason })
}

export async function setDifficult(id: string, difficult: boolean) {
  await db.cards.update(id, { difficult, ...(difficult ? { dueAt: now() } : {}) })
}

export async function reviewCard(card: ReviewCard, grade: Grade, label: string) {
  const t = new Date()
  const { fsrs, dueAt } = await gradeCard(card.fsrs, grade, t)
  await db.transaction('rw', db.cards, db.revlog, db.activity, async () => {
    await db.cards.update(card.id, { fsrs, dueAt })
    await db.revlog.add({ cardId: card.id, rating: grade, at: t.toISOString() })
    await db.activity.add({ at: t.toISOString(), type: 'repaso', refId: card.id, label })
  })
}

export async function removeCard(id: string) {
  await db.cards.delete(id)
}

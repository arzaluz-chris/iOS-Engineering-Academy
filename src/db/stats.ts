import type { Catalog, Lesson } from '../content/parse'
import type { Attempt, ChallengeState, LessonProgress } from './db'

/** Latest attempt per exercise/challenge/question. */
export function latestByRef(attempts: Attempt[]): Map<string, Attempt> {
  const m = new Map<string, Attempt>()
  for (const a of attempts) {
    const prev = m.get(a.refId)
    if (!prev || prev.at <= a.at) m.set(a.refId, a)
  }
  return m
}

export type ExerciseStatus = 'sin-intento' | 'correcto' | 'parcial' | 'incorrecto'

export function exerciseStatus(id: string, latest: Map<string, Attempt>): ExerciseStatus {
  return latest.get(id)?.result ?? 'sin-intento'
}

/**
 * A lesson counts as mastered when it's marked complete and the latest
 * attempt at each of its exercises is correct. Opening it doesn't count.
 */
export function lessonMastery(lesson: Lesson, latest: Map<string, Attempt>) {
  const total = lesson.exercises.length
  const correct = lesson.exercises.filter((e) => latest.get(e.id)?.result === 'correcto').length
  const attempted = lesson.exercises.filter((e) => latest.has(e.id)).length
  return { total, correct, attempted, mastered: total > 0 && correct === total }
}

export interface Overview {
  lessonsTotal: number
  lessonsCompleted: number
  lessonsMastered: number
  exercisesTotal: number
  exercisesCorrect: number
  byStage: { stageId: string; title: string; number: number; lessons: number; completed: number; modulesWithContent: number; modules: number }[]
  pendingExercises: { lessonId: string; exerciseId: string; status: ExerciseStatus }[]
  failedChallenges: string[]
  challengesSolved: number
}

export function overview(c: Catalog, progress: LessonProgress[], attempts: Attempt[], challenges: ChallengeState[]): Overview {
  const done = new Set(progress.filter((p) => p.status === 'completada').map((p) => p.lessonId))
  const started = new Set(progress.map((p) => p.lessonId))
  const latest = latestByRef(attempts)

  const byStage = c.stages.map((s) => {
    const mods = c.modules.filter((m) => m.stage === s.id)
    const ls = c.lessons.filter((l) => mods.some((m) => m.id === l.module))
    return {
      stageId: s.id,
      title: s.title,
      number: s.number,
      lessons: ls.length,
      completed: ls.filter((l) => done.has(l.id)).length,
      modules: mods.length,
      modulesWithContent: mods.filter((m) => c.lessons.some((l) => l.module === m.id)).length,
    }
  })

  const pendingExercises = c.lessons
    .filter((l) => started.has(l.id))
    .flatMap((l) => l.exercises.map((e) => ({ lessonId: l.id, exerciseId: e.id, status: exerciseStatus(e.id, latest) })))
    .filter((x) => x.status !== 'correcto')

  const failedChallenges = c.challenges
    .filter((ch) => {
      const a = latest.get(ch.id)
      return a && a.result !== 'correcto'
    })
    .map((ch) => ch.id)

  return {
    lessonsTotal: c.lessons.length,
    lessonsCompleted: c.lessons.filter((l) => done.has(l.id)).length,
    lessonsMastered: c.lessons.filter((l) => done.has(l.id) && lessonMastery(l, latest).mastered).length,
    exercisesTotal: c.lessons.reduce((n, l) => n + l.exercises.length, 0),
    exercisesCorrect: c.lessons.reduce((n, l) => n + l.exercises.filter((e) => latest.get(e.id)?.result === 'correcto').length, 0),
    byStage,
    pendingExercises,
    failedChallenges,
    challengesSolved: challenges.filter((s) => s.status === 'resuelto' || s.status === 'dominado').length,
  }
}

/** The lesson to study next: the most recent one in progress, or the first one not completed. */
export function currentLesson(sequence: Lesson[], progress: LessonProgress[]): Lesson | undefined {
  const inProgress = progress.filter((p) => p.status === 'en-curso').sort((a, b) => b.startedAt.localeCompare(a.startedAt))[0]
  if (inProgress) return sequence.find((l) => l.id === inProgress.lessonId)
  const done = new Set(progress.filter((p) => p.status === 'completada').map((p) => p.lessonId))
  return sequence.find((l) => !done.has(l.id))
}

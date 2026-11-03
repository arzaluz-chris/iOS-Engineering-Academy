import Dexie, { type EntityTable } from 'dexie'

/**
 * All progress lives in IndexedDB, in this browser. There's no server.
 * GitHub Pages shares the <user>.github.io origin across repositories,
 * so the database name has its own prefix.
 */

export type LessonStatus = 'en-curso' | 'completada'
export interface LessonProgress {
  lessonId: string
  status: LessonStatus
  startedAt: string
  completedAt?: string
  /** Last visible section (heading id), used to resume reading. */
  lastAnchor?: string
}

export type AttemptKind = 'ejercicio' | 'reto' | 'entrevista'
export type AttemptResult = 'correcto' | 'parcial' | 'incorrecto'
export interface Attempt {
  id?: number
  kind: AttemptKind
  refId: string
  at: string
  result: AttemptResult
  /** 0..1. For self-assessed exercises, the fraction of rubric criteria met. */
  score: number
  /** How it was graded: automatica (structured answer) or autoevaluacion (self-assessed with a rubric). */
  grading: 'automatica' | 'autoevaluacion'
  answer?: string
}

export interface Draft {
  key: string
  code: string
  updatedAt: string
}

export type NoteTarget = 'leccion' | 'ejercicio' | 'reto' | 'pregunta' | 'proyecto'
export interface Note {
  id?: number
  targetType: NoteTarget
  targetId: string
  text: string
  createdAt: string
  updatedAt: string
}

export interface Bookmark {
  key: string
  targetType: NoteTarget | 'recurso'
  targetId: string
  createdAt: string
}

export type ChallengeStatus = 'intentado' | 'resuelto' | 'dominado'
export interface ChallengeState {
  challengeId: string
  status: ChallengeStatus
  /** How many hint/solution sections have been revealed. */
  revealed: number
  hintsUsed: number
  updatedAt: string
}

export interface QuestionState {
  questionId: string
  status: 'pendiente' | 'dominada'
  updatedAt: string
}

export interface ProjectState {
  projectId: string
  startedAt: string
  milestonesDone: string[]
  updatedAt: string
}

export type CardSource = 'concepto' | 'ejercicio' | 'reto' | 'pregunta'
export interface ReviewCard {
  /** `${source}:${refId}` */
  id: string
  source: CardSource
  refId: string
  /** Serialized FSRS card (dates as ISO strings). */
  fsrs: Record<string, unknown>
  dueAt: string
  /** Marked by the learner as a hard topic: it gets priority. */
  difficult: boolean
  addedAt: string
  /** Why it entered review: the learner added it, or it came from a miss. */
  reason: 'manual' | 'fallo' | 'leccion'
}

export interface ReviewLog {
  id?: number
  cardId: string
  rating: number
  at: string
}

export interface Activity {
  id?: number
  at: string
  type: 'leccion-iniciada' | 'leccion-completada' | 'ejercicio' | 'reto' | 'entrevista' | 'repaso' | 'nota' | 'proyecto' | 'importacion'
  refId: string
  label: string
}

export class AcademyDB extends Dexie {
  lessons!: EntityTable<LessonProgress, 'lessonId'>
  attempts!: EntityTable<Attempt, 'id'>
  drafts!: EntityTable<Draft, 'key'>
  notes!: EntityTable<Note, 'id'>
  bookmarks!: EntityTable<Bookmark, 'key'>
  challenges!: EntityTable<ChallengeState, 'challengeId'>
  questions!: EntityTable<QuestionState, 'questionId'>
  projects!: EntityTable<ProjectState, 'projectId'>
  cards!: EntityTable<ReviewCard, 'id'>
  revlog!: EntityTable<ReviewLog, 'id'>
  activity!: EntityTable<Activity, 'id'>

  constructor(name = 'iea:ios-engineering-academy') {
    super(name)
    this.version(1).stores({
      lessons: 'lessonId, status',
      attempts: '++id, refId, kind, at, result',
      drafts: 'key',
      notes: '++id, [targetType+targetId], updatedAt',
      bookmarks: 'key, targetType',
      challenges: 'challengeId, status',
      questions: 'questionId, status',
      projects: 'projectId',
      cards: 'id, dueAt, source, refId',
      revlog: '++id, cardId, at',
      activity: '++id, at',
    })
  }
}

export const TABLES = ['lessons', 'attempts', 'drafts', 'notes', 'bookmarks', 'challenges', 'questions', 'projects', 'cards', 'revlog', 'activity'] as const
export type TableName = (typeof TABLES)[number]

export let db = new AcademyDB()

/** Tests only: use an isolated database. */
export function useTestDatabase(name: string) {
  db = new AcademyDB(name)
  return db
}

export const now = () => new Date().toISOString()

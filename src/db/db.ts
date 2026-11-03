import Dexie, { type EntityTable } from 'dexie'

/**
 * Todo el progreso vive en IndexedDB, en este navegador. No hay servidor.
 * GitHub Pages comparte el origen <usuario>.github.io entre repositorios,
 * por eso el nombre de la base lleva prefijo propio.
 */

export type LessonStatus = 'en-curso' | 'completada'
export interface LessonProgress {
  lessonId: string
  status: LessonStatus
  startedAt: string
  completedAt?: string
  /** Última sección visible (id del encabezado) para retomar la lectura. */
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
  /** 0..1. En ejercicios autoevaluados es la fracción de criterios de la rúbrica cumplidos. */
  score: number
  /** Cómo se calificó: automática (respuesta estructurada) o autoevaluación con rúbrica. */
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
  /** Cuántas secciones de pistas/solución se han revelado. */
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
  /** Tarjeta FSRS serializada (fechas como ISO). */
  fsrs: Record<string, unknown>
  dueAt: string
  /** Marcada por el estudiante como tema difícil: se prioriza. */
  difficult: boolean
  addedAt: string
  /** Por qué entró al repaso: lo agregó el estudiante o un fallo. */
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

/** Solo para tests: usar una base aislada. */
export function useTestDatabase(name: string) {
  db = new AcademyDB(name)
  return db
}

export const now = () => new Date().toISOString()

import curriculum from '../../content/curriculum.yaml?raw'
import resources from '../../content/resources.yaml?raw'
import { buildCatalog, type Catalog, type Challenge, type Lesson, type Project } from './parse'
import type { Exercise, InterviewQuestion, Module, Resource, Stage } from './schema'

const glob = (r: Record<string, unknown>) => r as Record<string, string>

const { catalog, issues } = buildCatalog({
  curriculum,
  resources,
  lessons: glob(import.meta.glob('../../content/lessons/**/*.md', { query: '?raw', import: 'default', eager: true })),
  challenges: glob(import.meta.glob('../../content/challenges/*.md', { query: '?raw', import: 'default', eager: true })),
  interview: glob(import.meta.glob('../../content/interview/*.yaml', { query: '?raw', import: 'default', eager: true })),
  projects: glob(import.meta.glob('../../content/projects/*.md', { query: '?raw', import: 'default', eager: true })),
  swift: glob(import.meta.glob('../../swift/{Sources,Tests}/**/*.swift', { query: '?raw', import: 'default', eager: true })),
})

if (issues.length && import.meta.env.DEV) console.warn('Content problems', issues)

export const content: Catalog = catalog
export const contentIssues = issues

export interface ExerciseRef {
  exercise: Exercise
  lesson: Lesson
}

const moduleById = new Map<string, Module>(catalog.modules.map((m) => [m.id, m]))
const stageById = new Map<string, Stage>(catalog.stages.map((s) => [s.id, s]))
const lessonById = new Map<string, Lesson>(catalog.lessons.map((l) => [l.id, l]))
const challengeById = new Map<string, Challenge>(catalog.challenges.map((c) => [c.id, c]))
const projectById = new Map<string, Project>(catalog.projects.map((p) => [p.id, p]))
const resourceById = new Map<string, Resource>(catalog.resources.map((r) => [r.id, r]))
const questionById = new Map<string, InterviewQuestion>(catalog.questions.map((q) => [q.id, q]))
const exerciseById = new Map<string, ExerciseRef>(
  catalog.lessons.flatMap((lesson) => lesson.exercises.map((exercise) => [exercise.id, { exercise, lesson }] as const)),
)

export const getModule = (id: string) => moduleById.get(id)
export const getStage = (id: string) => stageById.get(id)
export const getLesson = (id: string) => lessonById.get(id)
export const getChallenge = (id: string) => challengeById.get(id)
export const getProject = (id: string) => projectById.get(id)
export const getResource = (id: string) => resourceById.get(id)
export const getQuestion = (id: string) => questionById.get(id)
export const getExercise = (id: string) => exerciseById.get(id)

export const modulesOf = (stageId: string) => catalog.modules.filter((m) => m.stage === stageId)
export const lessonsOf = (moduleId: string) => catalog.lessons.filter((l) => l.module === moduleId)

/** Global reading order: by module number, then lesson order. */
export const lessonSequence: Lesson[] = [...catalog.lessons].sort(
  (a, b) => (moduleById.get(a.module)?.number ?? 0) - (moduleById.get(b.module)?.number ?? 0) || a.order - b.order,
)

export function neighbors(lessonId: string): { prev?: Lesson; next?: Lesson } {
  const i = lessonSequence.findIndex((l) => l.id === lessonId)
  return { prev: lessonSequence[i - 1], next: lessonSequence[i + 1] }
}

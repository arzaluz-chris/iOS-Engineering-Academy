import { z } from 'zod'

/**
 * Esquema único del contenido del curso.
 * Lo usan el navegador (al cargar), el script de validación y los tests.
 * Cualquier cambio aquí se refleja en docs/CONTENIDO.md.
 */

const id = z.string().regex(/^[a-z0-9]+(-[a-z0-9]+)*$/, 'ID en kebab-case: minúsculas, números y guiones')
const md = z.string().trim().min(1, 'No puede estar vacío')
const nonEmptyList = <T extends z.ZodType>(t: T) => z.array(t).min(1, 'Debe tener al menos un elemento')

export const level = z.enum(['inicial', 'intermedio', 'avanzado'])
export const difficulty = z.enum(['facil', 'medio', 'dificil'])

/**
 * Qué tan verificado está el código de una pieza de contenido.
 * - probado: compilado y con tests ejecutados en CI (swift test).
 * - revisado: revisado estáticamente, no compilado.
 * - ilustrativo: ejemplo explicativo que no pretende compilar tal cual.
 */
export const codeStatus = z.enum(['probado', 'revisado', 'ilustrativo', 'sin-codigo'])

// ---------- Currículo ----------

export const moduleSchema = z.object({
  id,
  stage: id,
  number: z.number().int().positive(),
  title: md,
  summary: md,
  objectives: nonEmptyList(md),
  topics: nonEmptyList(md),
  prerequisites: z.array(id).default([]),
  optional: z.boolean().default(false),
})

export const stageSchema = z.object({
  id,
  number: z.number().int().positive(),
  title: md,
  summary: md,
  outcome: md,
})

export const curriculumSchema = z.object({
  stages: nonEmptyList(stageSchema),
  modules: nonEmptyList(moduleSchema),
})

// ---------- Recursos ----------

export const resourceSchema = z.object({
  id,
  title: md,
  source: md,
  url: z.url({ protocol: /^https$/ }),
  kind: z.enum(['oficial', 'tutorial', 'articulo', 'referencia']),
  topic: md,
  why: md,
  status: z.enum(['verificado', 'no-verificado', 'roto']),
  verifiedAt: z.iso.date().nullable(),
})

// ---------- Ejercicios ----------

const exerciseBase = {
  id,
  prompt: md,
  hints: z.array(md).default([]),
  solution: md,
  concept: z.string().optional(),
}

const choice = z.object({ text: md, correct: z.boolean(), why: z.string().optional() })

export const exerciseSchema = z.discriminatedUnion('type', [
  z.object({
    ...exerciseBase,
    type: z.literal('comprension'),
    choices: z.array(choice).min(2),
    multiple: z.boolean().default(false),
  }),
  z.object({
    ...exerciseBase,
    type: z.literal('prediccion'),
    code: md,
    /**
     * Lenguaje de `code`. Con `pseudo`, la solución debe incluir la traducción a Swift en un bloque
     * ```swift: las pruebas de swift/ ejecutan esa traducción y comparan su salida con `output`.
     */
    lang: z.enum(['swift', 'pseudo']).default('swift'),
    /** Salida esperada exacta. Se compara línea por línea, ignorando espacios al final. */
    output: z.string(),
    accept: z.array(z.string()).default([]),
  }),
  z.object({
    ...exerciseBase,
    type: z.literal('completar'),
    /** Código con huecos marcados como [[1]], [[2]]... */
    code: md,
    blanks: z.array(z.object({ id: z.string(), answers: nonEmptyList(z.string()) })).min(1),
  }),
  z.object({
    ...exerciseBase,
    type: z.literal('errores'),
    code: md,
    /** El estudiante selecciona los problemas reales entre opciones; la corrección se autoevalúa. */
    choices: z.array(choice).min(2),
    rubric: nonEmptyList(md),
  }),
  z.object({ ...exerciseBase, type: z.literal('resolver'), starter: z.string().default(''), rubric: nonEmptyList(md), tests: z.string().optional() }),
  z.object({ ...exerciseBase, type: z.literal('explicar'), code: md, rubric: nonEmptyList(md) }),
  z.object({ ...exerciseBase, type: z.literal('refactorizar'), code: md, rubric: nonEmptyList(md) }),
  z.object({ ...exerciseBase, type: z.literal('diseno'), rubric: nonEmptyList(md) }),
])

export type Exercise = z.infer<typeof exerciseSchema>
export type ExerciseType = Exercise['type']

export const AUTO_TYPES: ExerciseType[] = ['comprension', 'prediccion', 'completar', 'errores']

// ---------- Lecciones ----------

export const cardSchema = z.object({ id, front: md, back: md })

export const lessonMetaSchema = z.object({
  id,
  title: md,
  description: md,
  module: id,
  order: z.number().int().positive(),
  level,
  minutes: z.number().int().min(5).max(240),
  objectives: nonEmptyList(md),
  prerequisites: z.array(id).default([]),
  terms: z.array(z.object({ term: md, definition: md })).default([]),
  mastery: nonEmptyList(md),
  resources: z.array(id).default([]),
  cards: z.array(cardSchema).default([]),
  swiftVersion: z.string().optional(),
  codeStatus,
})

// ---------- Retos ----------

export const challengeMetaSchema = z.object({
  id,
  title: md,
  difficulty,
  order: z.number().int().positive(),
  patterns: nonEmptyList(md),
  prerequisites: z.array(id).default([]),
  summary: md,
  solutionFile: z.string().regex(/^[A-Za-z0-9]+\.swift$/),
  testFile: z.string().regex(/^[A-Za-z0-9]+Tests\.swift$/),
  /** Firma inicial que ve el estudiante en el editor. */
  starter: md,
  time: md,
  space: md,
  edgeCases: nonEmptyList(md),
  askInterviewer: nonEmptyList(md),
  hints: z.array(md).min(2),
  followUps: nonEmptyList(md),
  rubric: nonEmptyList(md),
  codeStatus,
})

// ---------- Entrevistas ----------

export const interviewCategory = z.enum(['swift', 'uikit', 'swiftui', 'concurrencia', 'arquitectura', 'memoria', 'testing', 'seguridad', 'system-design'])

export const interviewQuestionSchema = z.object({
  id,
  category: interviewCategory,
  difficulty,
  question: md,
  answer: md,
  keyPoints: nonEmptyList(md),
  followUps: z.array(z.object({ question: md, answer: md })).default([]),
  writesCode: z.boolean().default(false),
  related: z.array(id).default([]),
})

export const interviewFileSchema = z.object({ questions: nonEmptyList(interviewQuestionSchema) })

// ---------- Proyectos ----------

export const projectMetaSchema = z.object({
  id,
  number: z.number().int().positive(),
  title: md,
  summary: md,
  prerequisites: z.array(id).default([]),
  objectives: nonEmptyList(md),
  requirements: nonEmptyList(md),
  acceptance: nonEmptyList(md),
  milestones: nonEmptyList(z.object({ id, title: md, tasks: nonEmptyList(md), concepts: z.array(md).default([]) })),
})

export type Stage = z.infer<typeof stageSchema>
export type Module = z.infer<typeof moduleSchema>
export type Resource = z.infer<typeof resourceSchema>
export type LessonMeta = z.infer<typeof lessonMetaSchema>
export type ChallengeMeta = z.infer<typeof challengeMetaSchema>
export type InterviewQuestion = z.infer<typeof interviewQuestionSchema>
export type InterviewCategory = z.infer<typeof interviewCategory>
export type ProjectMeta = z.infer<typeof projectMetaSchema>
export type Card = z.infer<typeof cardSchema>

import { z } from 'zod'

/**
 * The single schema for course content.
 * Used by the browser (on load), the validation script and the tests.
 * Any change here must be reflected in docs/CONTENT.md.
 */

const id = z.string().regex(/^[a-z0-9]+(-[a-z0-9]+)*$/, 'IDs are kebab-case: lowercase letters, digits and hyphens')
const md = z.string().trim().min(1, 'Can\'t be empty')
const nonEmptyList = <T extends z.ZodType>(t: T) => z.array(t).min(1, 'Needs at least one item')

export const level = z.enum(['beginner', 'intermediate', 'advanced'])
export const difficulty = z.enum(['easy', 'medium', 'hard'])

/**
 * How well the code in a piece of content has been checked.
 * - tested: compiled, with tests run in CI (swift test).
 * - reviewed: reviewed by reading it, not compiled.
 * - illustrative: an explanatory example that isn't meant to compile as is.
 * - no-code: the piece has no code.
 */
export const codeStatus = z.enum(['tested', 'reviewed', 'illustrative', 'no-code'])

// ---------- Curriculum ----------

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

// ---------- Resources ----------

export const resourceSchema = z.object({
  id,
  title: md,
  source: md,
  url: z.url({ protocol: /^https$/ }),
  kind: z.enum(['official', 'tutorial', 'article', 'reference']),
  topic: md,
  why: md,
  status: z.enum(['verified', 'unverified', 'broken']),
  verifiedAt: z.iso.date().nullable(),
})

// ---------- Exercises ----------

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
    type: z.literal('comprehension'),
    choices: z.array(choice).min(2),
    multiple: z.boolean().default(false),
  }),
  z.object({
    ...exerciseBase,
    type: z.literal('prediction'),
    code: md,
    /**
     * Language of `code`. With `pseudo`, the solution must include the Swift translation in a
     * ```swift block: the tests in swift/ run that translation and compare its output with `output`.
     */
    lang: z.enum(['swift', 'pseudo']).default('swift'),
    /** Exact expected output. Compared line by line, ignoring trailing spaces. */
    output: z.string(),
    accept: z.array(z.string()).default([]),
  }),
  z.object({
    ...exerciseBase,
    type: z.literal('fill-in'),
    /** Code with blanks marked as [[1]], [[2]]... */
    code: md,
    blanks: z.array(z.object({ id: z.string(), answers: nonEmptyList(z.string()) })).min(1),
  }),
  z.object({
    ...exerciseBase,
    type: z.literal('find-errors'),
    code: md,
    /** The learner picks the real problems from a list of options; the fix is self-assessed. */
    choices: z.array(choice).min(2),
    rubric: nonEmptyList(md),
  }),
  z.object({ ...exerciseBase, type: z.literal('solve'), starter: z.string().default(''), rubric: nonEmptyList(md), tests: z.string().optional() }),
  z.object({ ...exerciseBase, type: z.literal('explain'), code: md, rubric: nonEmptyList(md) }),
  z.object({ ...exerciseBase, type: z.literal('refactor'), code: md, rubric: nonEmptyList(md) }),
  z.object({ ...exerciseBase, type: z.literal('design'), rubric: nonEmptyList(md) }),
])

export type Exercise = z.infer<typeof exerciseSchema>
export type ExerciseType = Exercise['type']

export const AUTO_TYPES: ExerciseType[] = ['comprehension', 'prediction', 'fill-in', 'find-errors']

// ---------- Lessons ----------

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

// ---------- Challenges ----------

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
  /** Starting signature the learner sees in the editor. */
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

// ---------- Interviews ----------

export const interviewCategory = z.enum(['swift', 'uikit', 'swiftui', 'concurrency', 'architecture', 'memory', 'testing', 'security', 'system-design'])

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

// ---------- Projects ----------

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

import { z } from 'zod'
import { db, now, TABLES, type TableName } from './db'

/**
 * Backup format: a single JSON file with every table.
 * It's fully validated before the database is touched; importing replaces
 * the current data inside one transaction (all or nothing).
 */
export const BACKUP_FORMAT = 'ios-engineering-academy/backup'
export const BACKUP_VERSION = 1

const iso = z.iso.datetime()
const str = z.string().min(1)

const rows = {
  lessons: z.object({ lessonId: str, status: z.enum(['en-curso', 'completada']), startedAt: iso, completedAt: iso.optional(), lastAnchor: z.string().optional() }),
  attempts: z.object({
    id: z.number().int().optional(),
    kind: z.enum(['ejercicio', 'reto', 'entrevista']),
    refId: str,
    at: iso,
    result: z.enum(['correcto', 'parcial', 'incorrecto']),
    score: z.number().min(0).max(1),
    grading: z.enum(['automatica', 'autoevaluacion']),
    answer: z.string().optional(),
  }),
  drafts: z.object({ key: str, code: z.string(), updatedAt: iso }),
  notes: z.object({ id: z.number().int().optional(), targetType: z.enum(['leccion', 'ejercicio', 'reto', 'pregunta', 'proyecto']), targetId: str, text: z.string(), createdAt: iso, updatedAt: iso }),
  bookmarks: z.object({ key: str, targetType: z.enum(['leccion', 'ejercicio', 'reto', 'pregunta', 'proyecto', 'recurso']), targetId: str, createdAt: iso }),
  challenges: z.object({ challengeId: str, status: z.enum(['intentado', 'resuelto', 'dominado']), revealed: z.number().int().min(0), hintsUsed: z.number().int().min(0), updatedAt: iso }),
  questions: z.object({ questionId: str, status: z.enum(['pendiente', 'dominada']), updatedAt: iso }),
  projects: z.object({ projectId: str, startedAt: iso, milestonesDone: z.array(str), updatedAt: iso }),
  cards: z.object({
    id: str,
    source: z.enum(['concepto', 'ejercicio', 'reto', 'pregunta']),
    refId: str,
    fsrs: z.record(z.string(), z.unknown()),
    dueAt: iso,
    difficult: z.boolean(),
    addedAt: iso,
    reason: z.enum(['manual', 'fallo', 'leccion']),
  }),
  revlog: z.object({ id: z.number().int().optional(), cardId: str, rating: z.number().int().min(1).max(4), at: iso }),
  activity: z.object({ id: z.number().int().optional(), at: iso, type: str, refId: z.string(), label: z.string() }),
} satisfies Record<TableName, z.ZodType>

export const backupSchema = z.object({
  format: z.literal(BACKUP_FORMAT),
  version: z.literal(BACKUP_VERSION),
  exportedAt: iso,
  data: z.object(Object.fromEntries(TABLES.map((t) => [t, z.array(rows[t])])) as { [K in TableName]: z.ZodArray<(typeof rows)[K]> }),
})

export type Backup = z.infer<typeof backupSchema>

export async function exportBackup(): Promise<Backup> {
  const data = {} as Record<TableName, unknown[]>
  for (const t of TABLES) data[t] = await db.table(t).toArray()
  return { format: BACKUP_FORMAT, version: BACKUP_VERSION, exportedAt: now(), data: data as Backup['data'] }
}

export function parseBackup(text: string): { ok: true; backup: Backup } | { ok: false; error: string } {
  let json: unknown
  try {
    json = JSON.parse(text)
  } catch {
    return { ok: false, error: 'That file isn’t valid JSON.' }
  }
  const r = backupSchema.safeParse(json)
  if (!r.success) {
    const first = r.error.issues.slice(0, 3).map((i) => `${i.path.join('.')}: ${i.message}`)
    return { ok: false, error: `This backup doesn’t have the expected format. ${first.join('; ')}` }
  }
  return { ok: true, backup: r.data }
}

export async function importBackup(backup: Backup) {
  await db.transaction('rw', TABLES.map((t) => db.table(t)), async () => {
    for (const t of TABLES) {
      await db.table(t).clear()
      await db.table(t).bulkAdd(backup.data[t])
    }
  })
}

export async function resetAll() {
  await db.transaction('rw', TABLES.map((t) => db.table(t)), async () => {
    for (const t of TABLES) await db.table(t).clear()
  })
}

export function downloadJson(name: string, value: unknown) {
  const blob = new Blob([JSON.stringify(value, null, 2)], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = name
  a.click()
  setTimeout(() => URL.revokeObjectURL(url), 1000)
}

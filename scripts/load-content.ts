import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join, relative } from 'node:path'
import { buildCatalog } from '../src/content/parse'

export const ROOT = join(import.meta.dirname, '..')

function walk(dir: string, ext: string): string[] {
  const out: string[] = []
  let entries: string[] = []
  try {
    entries = readdirSync(dir)
  } catch {
    return out
  }
  for (const e of entries) {
    const p = join(dir, e)
    if (statSync(p).isDirectory()) out.push(...walk(p, ext))
    else if (p.endsWith(ext)) out.push(p)
  }
  return out
}

function read(dir: string, ext: string): Record<string, string> {
  return Object.fromEntries(walk(join(ROOT, dir), ext).map((p) => [relative(ROOT, p), readFileSync(p, 'utf8')]))
}

/** Loads the content from disk with the same logic the browser uses. */
export function loadFromDisk() {
  return buildCatalog({
    curriculum: readFileSync(join(ROOT, 'content/curriculum.yaml'), 'utf8'),
    resources: readFileSync(join(ROOT, 'content/resources.yaml'), 'utf8'),
    lessons: read('content/lessons', '.md'),
    challenges: read('content/challenges', '.md'),
    interview: read('content/interview', '.yaml'),
    projects: read('content/projects', '.md'),
    swift: { ...read('swift/Sources', '.swift'), ...read('swift/Tests', '.swift') },
  })
}

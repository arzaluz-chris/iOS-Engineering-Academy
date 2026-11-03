/**
 * Automatic grading, ONLY for structured answers.
 * Swift code written by the learner is never graded by comparing text:
 * it's checked by running tests in Xcode or with `swift test`.
 */

export function gradeChoices(selected: number[], correct: boolean[]): boolean {
  const want = correct.flatMap((c, i) => (c ? [i] : []))
  return want.length === selected.length && want.every((i) => selected.includes(i))
}

const normalizeOutput = (s: string) =>
  s
    .replace(/\r\n/g, '\n')
    .split('\n')
    .map((l) => l.replace(/\s+$/, ''))
    .join('\n')
    .replace(/^\n+|\n+$/g, '')

/** Compares the predicted output with the expected one, line by line, ignoring trailing spaces. */
export function gradePrediction(answer: string, expected: string, accept: string[] = []): boolean {
  const a = normalizeOutput(answer)
  return [expected, ...accept].some((e) => normalizeOutput(e) === a)
}

const normalizeToken = (s: string) => s.trim().replace(/\s+/g, ' ')

/** Each blank accepts a closed list of equivalent answers (e.g. `let` or `var`). */
export function gradeBlanks(answers: Record<string, string>, blanks: { id: string; answers: string[] }[]): Record<string, boolean> {
  return Object.fromEntries(blanks.map((b) => [b.id, b.answers.map(normalizeToken).includes(normalizeToken(answers[b.id] ?? ''))]))
}

export type CodePart = { kind: 'text'; text: string } | { kind: 'blank'; id: string }

export function splitBlanks(code: string): CodePart[] {
  const parts: CodePart[] = []
  let last = 0
  for (const m of code.matchAll(/\[\[(\w+)\]\]/g)) {
    if (m.index > last) parts.push({ kind: 'text', text: code.slice(last, m.index) })
    parts.push({ kind: 'blank', id: m[1] ?? '' })
    last = m.index + m[0].length
  }
  if (last < code.length) parts.push({ kind: 'text', text: code.slice(last) })
  return parts
}

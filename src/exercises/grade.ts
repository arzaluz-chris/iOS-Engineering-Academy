/**
 * Calificación automática SOLO para respuestas estructuradas.
 * Nunca se califica código Swift escrito por el estudiante comparando texto:
 * eso se valida ejecutando tests en Xcode o con `swift test`.
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

/** Compara la salida predicha con la esperada, línea por línea e ignorando espacios finales. */
export function gradePrediction(answer: string, expected: string, accept: string[] = []): boolean {
  const a = normalizeOutput(answer)
  return [expected, ...accept].some((e) => normalizeOutput(e) === a)
}

const normalizeToken = (s: string) => s.trim().replace(/\s+/g, ' ')

/** Cada hueco acepta una lista cerrada de respuestas equivalentes (p. ej. `let` o `var`). */
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

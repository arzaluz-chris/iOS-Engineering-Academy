/**
 * Verifica los enlaces de content/resources.yaml.
 * La documentación de Apple es una aplicación JavaScript que puede responder 200
 * para rutas inexistentes; para esas URL se consulta su JSON de datos, que sí da 404.
 * Uso: npm run check-links            (solo informa)
 *      npm run check-links -- --strict (falla si hay enlaces rotos)
 */
import { loadFromDisk } from './load-content'

const { catalog } = loadFromDisk()

function probeUrl(url: string): string {
  const u = new URL(url)
  if (u.hostname === 'developer.apple.com' && u.pathname.startsWith('/documentation/')) {
    return `https://developer.apple.com/tutorials/data${u.pathname.replace(/\/$/, '').toLowerCase()}.json`
  }
  return url
}

async function check(url: string): Promise<number> {
  const target = probeUrl(url)
  for (const method of ['HEAD', 'GET'] as const) {
    try {
      const res = await fetch(target, { method, redirect: 'follow', signal: AbortSignal.timeout(20_000), headers: { 'user-agent': 'ios-engineering-academy-link-check' } })
      if (res.status !== 405 && res.status !== 403) return res.status
    } catch {
      if (method === 'GET') return 0
    }
  }
  return 0
}

const results = await Promise.all(catalog.resources.map(async (r) => ({ r, status: await check(r.url) })))
let broken = 0
for (const { r, status } of results) {
  const ok = status >= 200 && status < 400
  if (!ok) broken++
  console.log(`${ok ? 'ok   ' : 'ROTO '} ${String(status).padStart(3)}  ${r.id}  ${r.url}`)
}
console.log(`\n${results.length - broken}/${results.length} enlaces responden. Fecha: ${new Date().toISOString().slice(0, 10)}`)
if (broken && process.argv.includes('--strict')) process.exit(1)

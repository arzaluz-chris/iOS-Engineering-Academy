/**
 * Checks the links in content/resources.yaml.
 * Apple's documentation is a JavaScript app that can answer 200 for paths
 * that don't exist; for those URLs we request its data JSON, which does return 404.
 * Usage: npm run check-links            (report only)
 *        npm run check-links -- --strict (fail if any link is broken)
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
  console.log(`${ok ? 'ok    ' : 'BROKEN'} ${String(status).padStart(3)}  ${r.id}  ${r.url}`)
}
console.log(`\n${results.length - broken}/${results.length} links respond. Date: ${new Date().toISOString().slice(0, 10)}`)
if (broken && process.argv.includes('--strict')) process.exit(1)

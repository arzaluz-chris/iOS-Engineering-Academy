import { useSyncExternalStore } from 'react'

/**
 * Minimal hash-based router (#/path). GitHub Pages doesn't rewrite paths,
 * so the hash avoids a 404 when any page is reloaded.
 */

function subscribe(cb: () => void) {
  window.addEventListener('hashchange', cb)
  return () => window.removeEventListener('hashchange', cb)
}

const getHash = () => window.location.hash || '#/'

export interface Route {
  path: string[]
  query: URLSearchParams
}

export function parseHash(hash: string): Route {
  const raw = hash.replace(/^#/, '') || '/'
  const [p = '/', q = ''] = raw.split('?')
  return { path: p.split('/').filter(Boolean).map(decodeURIComponent), query: new URLSearchParams(q) }
}

export function useRoute(): Route {
  const hash = useSyncExternalStore(subscribe, getHash, () => '#/')
  return parseHash(hash)
}

export function navigate(to: string) {
  window.location.hash = to.startsWith('#') ? to : `#${to}`
}

export const href = (...parts: string[]) => `#/${parts.map(encodeURIComponent).join('/')}`

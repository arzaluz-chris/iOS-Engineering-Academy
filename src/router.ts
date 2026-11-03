import { useSyncExternalStore } from 'react'

/**
 * Enrutador mínimo basado en el hash (#/ruta). GitHub Pages no reescribe rutas,
 * así que el hash evita 404 al recargar cualquier página.
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

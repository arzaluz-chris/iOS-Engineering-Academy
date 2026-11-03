import { lazy, Suspense } from 'react'

/** CodeMirror loads on demand: only pages with an editor download its code. */
const Impl = lazy(() => import('./CodeEditorImpl'))

export interface CodeEditorProps {
  value: string
  onChange: (value: string) => void
  language?: 'swift' | 'text'
  label: string
  minLines?: number
}

export function CodeEditor(props: CodeEditorProps) {
  return (
    <Suspense fallback={<textarea className="mono" aria-label={props.label} rows={props.minLines ?? 8} value={props.value} readOnly />}>
      <Impl {...props} />
    </Suspense>
  )
}

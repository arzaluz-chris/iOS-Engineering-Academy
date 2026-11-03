import { indentWithTab } from '@codemirror/commands'
import { StreamLanguage } from '@codemirror/language'
import { swift } from '@codemirror/legacy-modes/mode/swift'
import { EditorState } from '@codemirror/state'
import { EditorView, keymap } from '@codemirror/view'
import { basicSetup } from 'codemirror'
import { useEffect, useRef } from 'react'

interface Props {
  value: string
  onChange: (value: string) => void
  /** 'swift' usa resaltado de Swift; 'text' sirve para respuestas en prosa o pseudocódigo. */
  language?: 'swift' | 'text'
  label: string
  minLines?: number
}

/**
 * Editor de código. No ejecuta Swift: en el navegador no hay compilador.
 * El código se guarda localmente y se ejecuta en Xcode o con `swift test`.
 */
export default function CodeEditor({ value, onChange, language = 'swift', label, minLines = 8 }: Props) {
  const host = useRef<HTMLDivElement>(null)
  const view = useRef<EditorView | null>(null)
  const changeRef = useRef(onChange)
  changeRef.current = onChange

  useEffect(() => {
    if (!host.current) return
    const v = new EditorView({
      parent: host.current,
      state: EditorState.create({
        doc: value,
        extensions: [
          basicSetup,
          keymap.of([indentWithTab]),
          ...(language === 'swift' ? [StreamLanguage.define(swift)] : [EditorView.lineWrapping]),
          EditorState.tabSize.of(4),
          EditorView.contentAttributes.of({ 'aria-label': label, spellcheck: language === 'text' ? 'true' : 'false' }),
          EditorView.theme({ '.cm-content': { minHeight: `${minLines * 1.5}em` }, '.cm-scroller': { fontFamily: 'var(--mono)' } }),
          EditorView.updateListener.of((u) => {
            if (u.docChanged) changeRef.current(u.state.doc.toString())
          }),
        ],
      }),
    })
    view.current = v
    return () => v.destroy()
    // El editor se crea una sola vez; los cambios externos se aplican abajo.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [language])

  useEffect(() => {
    const v = view.current
    if (v && v.state.doc.toString() !== value) v.dispatch({ changes: { from: 0, to: v.state.doc.length, insert: value } })
  }, [value])

  return <div className="editor" ref={host} />
}

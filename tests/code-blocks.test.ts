import { describe, expect, it } from 'vitest'
import { classifyIdentifiers, codeBlockHtml, highlight, renderMarkdown } from '../src/components/Markdown'

describe('code blocks follow swift.org', () => {
  it('render as a plain box with an icon-only copy button and no header', () => {
    const html = renderMarkdown('```swift\nlet x = 1\n```')
    expect(html).toContain('class="code-block code-filled"')
    expect(html).toContain('class="copy-button"')
    expect(html).toContain('aria-label="Copy code"')
    expect(html).not.toContain('figcaption')
    expect(html).not.toContain('code-caption')
  })

  it('give output its own bordered style and caption so it reads differently from code', () => {
    const html = codeBlockHtml('Hello', 'output')
    expect(html).toContain('code-plain')
    expect(html).toContain('<p class="code-caption">Output</p>')
  })

  it('color identifiers by role the way swift.org does', () => {
    const html = highlight('let total = price * 2\nprint(total, separator: "-")\nlet t = Greeting()')
    expect(html).toContain('<span class="hljs-decl">total</span> <span class="hljs-operator">=</span> <span class="hljs-ident">price</span>')
    expect(html).toContain('<span class="hljs-decl">separator</span>')
    expect(html).toContain('<span class="hljs-type">Greeting</span>(')
  })

  it('never touches text inside strings, comments or HTML entities', () => {
    const html = classifyIdentifiers('<span class="hljs-string">&quot;hello world&quot;</span> a &lt; b <span class="hljs-comment">// note here</span>')
    expect(html).toContain('<span class="hljs-string">&quot;hello world&quot;</span>')
    expect(html).toContain('<span class="hljs-comment">// note here</span>')
    expect(html).toContain('&lt;')
    expect(html).not.toContain('>quot<')
    expect(html).not.toContain('>lt<')
  })
})

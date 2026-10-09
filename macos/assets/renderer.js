/* Offline context renderer. Model text never becomes executable HTML. */
(function (root) {
  'use strict'
  const md = root.markdownit({ html: false, linkify: true, breaks: true, typographer: false })
  const escape = md.utils.escapeHtml
  const T = source => root.DSHUITranslations?.[source] || source
  md.validateLink = url => /^https?:\/\//i.test(url)
  md.renderer.rules.image = (tokens, index) => '<span class="image-placeholder">[' + escape(T('图片：')) + escape(tokens[index].content || T('未加载')) + ']</span>'
  md.renderer.rules.link_open = (tokens, index, options, env, self) => {
    tokens[index].attrSet('rel', 'noreferrer noopener')
    return self.renderToken(tokens, index, options)
  }
  function math(source, display) {
    try {
      return root.katex.renderToString(source, {
        displayMode: display, throwOnError: true, trust: false,
        maxExpand: 500, maxSize: 20, strict: 'ignore', output: 'htmlAndMathml',
      })
    } catch (_) {
      return '<code class="math-error" title="' + escape(T('公式无法渲染，显示原文')) + '">' + escape(source) + '</code>'
    }
  }
  function isEscaped(source, position) {
    let count = 0
    while (position > 0 && source[--position] === '\\') count++
    return count % 2 === 1
  }
  function closing(source, delimiter, start) {
    let at = source.indexOf(delimiter, start)
    while (at !== -1 && isEscaped(source, at)) at = source.indexOf(delimiter, at + delimiter.length)
    return at
  }
  // Parse before Markdown's backslash escape rule. Code/fences keep their source.
  md.inline.ruler.before('escape', 'dsh_math', (state, silent) => {
    const start = state.pos, src = state.src
    let open, close, display = false
    if (src.startsWith('\\(', start)) { open = '\\('; close = '\\)' }
    else if (src.startsWith('\\[', start)) { open = '\\['; close = '\\]'; display = true }
    else if (src.startsWith('$$', start)) { open = close = '$$'; display = true }
    else if (src[start] === '$') {
      if (/\s/.test(src[start + 1] || ' ') || /\d/.test(src[start - 1] || '')) return false
      open = close = '$'
    } else return false
    const end = closing(src, close, start + open.length)
    if (end < 0 || end === start + open.length) return false
    if (open === '$' && (/\s/.test(src[end - 1]) || /\d/.test(src[end + 1] || ''))) return false
    if (!silent) {
      const token = state.push('dsh_math', '', 0)
      token.content = src.slice(start + open.length, end)
      token.meta = { display }
    }
    state.pos = end + close.length
    return true
  })
  md.renderer.rules.dsh_math = (tokens, index) => math(tokens[index].content, tokens[index].meta.display)
  md.block.ruler.before('fence', 'dsh_math_block', (state, startLine, endLine, silent) => {
    if (state.sCount[startLine] - state.blkIndent >= 4) return false
    const start = state.bMarks[startLine] + state.tShift[startLine]
    const first = state.src.slice(start, state.eMarks[startLine])
    const open = first.startsWith('$$') ? '$$' : first.startsWith('\\[') ? '\\[' : null
    if (!open) return false
    const close = open === '$$' ? '$$' : '\\]'
    let end = closing(state.src, close, start + open.length)
    if (end < 0 || end > state.eMarks[endLine - 1]) return false
    let last = startLine
    while (last + 1 < endLine && state.eMarks[last] < end + close.length) last++
    const logical = state.getLines(startLine, last + 1, state.blkIndent, false).trimStart()
    const logicalEnd = closing(logical, close, open.length)
    if (logicalEnd < 0 || logical.slice(logicalEnd + close.length).trim()) return false
    if (silent) return true
    const token = state.push('dsh_math_block', 'div', 0)
    token.block = true; token.content = logical.slice(open.length, logicalEnd).trim()
    token.map = [startLine, last + 1]
    state.line = last + 1
    return true
  }, { alt: ['paragraph', 'reference', 'blockquote', 'list'] })
  md.renderer.rules.dsh_math_block = (tokens, index) => '<div class="math-block">' + math(tokens[index].content, true) + '</div>\n'
  // Color existing tokens only; escaped code remains inert and selectable.
  md.options.highlight = (source, language) => {
    const json = /^(json|jsonc)$/i.test(language)
    if (!json && !/^(sh|bash|shell|zsh)$/i.test(language)) return escape(source)
    const pattern = json
      ? /"(?:\\[\s\S]|[^"\\])*"|\b(?:true|false|null)\b|-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b/g
      : /'[^']*'|"(?:\\[\s\S]|[^"\\])*"|#[^\n]*|\$\{[^}]*\}|\$[A-Za-z_][A-Za-z0-9_]*|\b(?:if|then|else|fi|for|in|do|done|echo|printf|cd|cat|date|export)\b/g
    let html = '', last = 0
    for (const match of source.matchAll(pattern)) {
      html += escape(source.slice(last, match.index))
      let kind = 'keyword'
      if (match[0][0] === '"' || match[0][0] === "'") kind = json && /^\s*:/.test(source.slice(match.index + match[0].length)) ? 'key' : 'string'
      else if (match[0][0] === '#') kind = 'comment'
      html += '<span class="syntax-' + kind + '">' + escape(match[0]) + '</span>'
      last = match.index + match[0].length
    }
    return html + escape(source.slice(last))
  }
  root.DSHMarkdown = { render: text => md.render(String(text)) }
})(globalThis)

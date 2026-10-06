import { readFileSync } from 'node:fs'
import vm from 'node:vm'
import test from 'node:test'
import assert from 'node:assert/strict'
const root = new URL('../macos/assets/', import.meta.url)
const context = vm.createContext({ console, atob, btoa, TextDecoder, TextEncoder })
for (const file of ['vendor/markdown-it/markdown-it.min.js', 'vendor/katex/katex.min.js', 'renderer.js']) {
  vm.runInContext(readFileSync(new URL(file, root), 'utf8'), context, { filename: file })
}
const render = text => context.DSHMarkdown.render(text)
test('context renders tables, lists, quotes and fenced code', () => {
  const html = render('| 参数 | 值 |\n| --- | --- |\n| **模式** | `safe` |\n\n> 说明\n\n1. 第一步\n2. 第二步\n\n```shell\necho "中文"\n```')
  for (const tag of ['<table>', '<thead>', '<strong>', '<code>', '<blockquote>', '<ol>', '<pre>']) assert(html.includes(tag), tag)
  assert(html.includes('中文'))
})
test('all four common math delimiters render without touching code', () => {
  const html = render(String.raw`行内 $E=mc^2$ 与 \(x_1\)\n\n$$\n\frac{a}{b}\n$$\n\n\[\sum_{i=1}^{n}i\]\n\n\`$untouched$\``.replaceAll('\\n', '\n').replaceAll('\\`', '`'))
  assert.equal((html.match(/class="katex"/g) || []).length, 4)
  assert(html.includes('<math'))
  assert(html.includes('<code>$untouched$</code>'))
})
test('currency and escaped dollars remain text; malformed math keeps its source', () => {
  assert(!render('价格 $5 与 $10，预算 \\$20').includes('class="katex"'))
  const html = render('$\\unknownMacro{<img src=x onerror=evil()>}$')
  assert(html.includes('unknownMacro'))
  assert(!html.includes('<img'))
})
test('untrusted context cannot add HTML, active links or external images', () => {
  const html = render('<script>alert(1)</script>\n\n![tracking](https://example.com/probe)\n\n[x](javascript:alert(1))\n\n[local](file:///tmp/private)\n\n[docs](https://example.com/docs)\n\n$\\includegraphics{https://example.com/probe}$')
  assert(!html.includes('<script>'))
  assert(!html.includes('<img'))
  assert(!html.includes('href="file:'))
  assert(!html.includes('href="javascript:'))
  assert(html.includes('href="https://example.com/docs"'))
  assert(html.includes('tracking'))
})
test('backslash delimiters inside code and code fences stay literal', () => {
  const html = render('`\\(literal\\)`\n\n```json\n{"math":"$literal$"}\n```')
  assert(!html.includes('class="katex"'))
  assert(html.includes('literal'))
})

test('vendored assets match their manifest and every referenced font is packaged', async () => {
  const { createHash } = await import('node:crypto')
  const manifest = JSON.parse(readFileSync(new URL('vendor/manifest.json', root)))
  assert.equal(manifest.packages.length, 2)
  assert.equal(manifest.bundledNotices.length, 5)
  for (const notice of manifest.bundledNotices) assert(manifest.files[notice.file], notice.name)
  for (const [file, sha256] of Object.entries(manifest.files)) {
    assert.equal(createHash('sha256').update(readFileSync(new URL(file, root))).digest('hex'), sha256, file)
  }
  const css = readFileSync(new URL('vendor/katex/katex.min.css', root), 'utf8')
  for (const match of css.matchAll(/url\(([^)]+)\)/g)) {
    assert(readFileSync(new URL('vendor/katex/' + match[1], root)).length > 0, match[1])
  }
})

test('multiline formulas in blockquotes and lists keep their TeX content', () => {
  const quotes = render('> $$\n> x_1\n> $$\n\n> \\[\n> \\frac{a}{b}\n> \\]')
  assert(quotes.includes('encoding="application/x-tex">x_1</annotation>'))
  assert(quotes.includes('encoding="application/x-tex">\\frac{a}{b}</annotation>'))
  assert(!quotes.includes('class="math-error"'))
  assert(render('> 1. $$\n>    x_1\n>    $$').includes('encoding="application/x-tex">x_1</annotation>'))
  const list = render('- 第一步\n\n  $$\n  x_2\n  $$')
  assert(list.includes('encoding="application/x-tex">x_2</annotation>'))
})

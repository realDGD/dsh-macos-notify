'use strict'
window.renderContext = function (items) {
  const root = document.getElementById('context')
  root.replaceChildren()
  for (const item of items) {
    const section = document.createElement('section')
    const role = document.createElement('div')
    role.className = 'role'; role.textContent = item.role === 'user' ? '你的请求' : '助手说明'
    section.append(role)
    const content = document.createElement('div')
    content.innerHTML = DSHMarkdown.render(item.text)
    section.append(content)
    if (item.truncated) {
      const note = document.createElement('p'); note.className = 'truncated'
      note.textContent = '较长内容显示前 20,000 字符，请回到 DSH 阅读全文。'
      section.append(note)
    }
    root.append(section)
  }
  if (!items.length) root.textContent = '此请求没有可用的前置文字上下文。'
}
let heightTimer
function reportHeight() {
  clearTimeout(heightTimer)
  heightTimer = setTimeout(() => {
    window.webkit?.messageHandlers?.contextHeight?.postMessage(document.getElementById('context').getBoundingClientRect().height + 16)
  }, 30)
}
new ResizeObserver(reportHeight).observe(document.getElementById('context'))
document.fonts.ready.then(reportHeight)

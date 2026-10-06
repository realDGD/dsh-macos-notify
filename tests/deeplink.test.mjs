/**
 * 客户端插件（浏览器半边）的回归测试。
 *
 * 为什么需要它：这个插件的每一次线上事故都不是"语法错"，而是**和 DSH 启动时序的交互**——
 *   · 0.1.7 把视图选择从 sessions 服务搬到了 uiWorkspace，旧调用静默失效；
 *   · 插件抢在应用初始导航之前 openSession，会让协调器永远跳过工作区连接
 *     （症状：左栏只有工作区没会话、单击切换失灵、双击才开重命名）；
 *   · 跨工作区跳转不先连接目标工作区，会话视图会引用到不属于当前工作区的会话（黑屏）；
 *   · 激活失败却清掉 ?session= 参数，页面停在"上次浏览的会话"（症状：跳到错的会话）。
 * 这些全都无法靠"重启试一次"稳定验证，只能用桩把时序摆出来。
 *
 * 加载方式：模块顶部是 `window.__ModuleLoader__.load({ factory })`，所以喂一个像样的
 * window 就能在 Node 里拿到 exports。
 */
import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import vm from 'node:vm'

const HERE = dirname(fileURLToPath(import.meta.url))
const SOURCE = readFileSync(join(HERE, '..', 'lib', 'client.js'), 'utf8')

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

test('Desktop 点击请求：跨工作区切换确认后才 ack，确认后不重复跳转', async () => {
  let pending = { requestId: 'click-1', sessionId: 's-target', createdAt: Date.now() }
  const ack = []
  const rpc = { call: async (channel, endpoint, payload) => {
    assert.equal(channel, '/api')
    if (endpoint === 'dsh-macos-notify/pending') return { ok: true, value: pending }
    assert.equal(endpoint, 'dsh-macos-notify/ack')
    ack.push(payload); pending = null; return { ok: true, value: { ok: true } }
  } }
  const { ctx, calls, workspace } = makeCtx({
    ids: ['s-here', 's-target'], rpc,
    workspaces: [{ workspaceId: 'ws-a', sessionIds: ['s-here'] }, { workspaceId: 'ws-b', sessionIds: ['s-target'] }],
  })
  appFinishesBoot(workspace, 's-here')
  const intervals = []
  loadPlugin({ protocol: 'dsh-app:', intervals }).exported.apply(ctx)
  await sleep(40)
  assert.deepEqual(calls, ['openWorkspace:ws-b', 'openSession:s-target'])
  assert.equal(ack[0]?.sessionId, 's-target')
  for (const fn of intervals) fn()
  await sleep(40)
  assert.equal(calls.length, 2)
})

test('Desktop 选中失败时不 ack，也不抢在应用初始导航之前跳转', async () => {
  const ack = []
  const rpc = { call: async (_channel, endpoint, payload) => {
    if (endpoint === 'dsh-macos-notify/pending') return { ok: true, value: { requestId: 'click-1', sessionId: 's-target', createdAt: Date.now() } }
    ack.push(payload); return { ok: true }
  } }
  const { ctx, calls, workspace } = makeCtx({ ids: ['s-here', 's-target'], rpc, activationWorks: false })
  const intervals = []
  loadPlugin({ protocol: 'dsh-app:', intervals }).exported.apply(ctx)
  await sleep(40)
  assert.deepEqual(calls, [])
  appFinishesBoot(workspace, 's-here')
  for (const fn of intervals) fn()
  await sleep(40)
  assert.deepEqual(calls, ['openSession:s-target'])
  assert.deepEqual(ack, [])
})

/** 在 Node 沙箱里加载插件，返回其 exports。 */
function loadPlugin({ search = '', protocol = 'http:', intervals = null } = {}) {
  const replaced = []
  let definition = null
  const windowObj = {
    __ModuleLoader__: { load: (def) => { definition = def } },
    location: {
      href: `http://127.0.0.1:3080/${search}`,
      protocol,
      search,
      pathname: '/',
      hash: '',
    },
    history: { replaceState: (_state, _title, url) => { replaced.push(url) } },
    localStorage: { getItem: () => null, setItem: () => {} },
    // 兜底定时器（30s）只为了让页面别一直等；测试里没必要真的等它，
    // 否则每跑一次测试都得拖满 30 秒才退出。
    setTimeout: (fn, ms) => (ms >= 5000 ? { unref() {} } : setTimeout(fn, ms)),
    clearTimeout,
    setInterval: intervals ? (fn) => { intervals.push(fn); return fn } : setInterval,
    clearInterval,
    addEventListener: () => {},
    removeEventListener: () => {},
    focus: () => {},
  }
  const sandbox = {
    window: windowObj,
    document: { hidden: false, hasFocus: () => true },
    Notification: undefined,
    URL,
    URLSearchParams,
    setTimeout,
    clearTimeout,
    setInterval,
    clearInterval,
    console,
    Date,
    Promise,
    Map,
    Set,
  }
  vm.createContext(sandbox)
  vm.runInContext(SOURCE, sandbox)
  assert.ok(definition !== null, '插件应当通过 window.__ModuleLoader__.load 注册自己')
  const exported = definition.factory(() => { throw new Error('插件不应 require 任何东西') })
  return { exported, replaced }
}

/**
 * 造一个够像的客户端上下文。
 *
 * @param {object} options
 * @param {string[]} options.ids - 会话目录里的会话 id。
 * @param {Array} options.workspaces - `{workspaceId, sessionIds}` 列表。
 * @param {boolean} [options.activationWorks] - openSession 是否真的会改变主视图。
 */
function makeCtx({ ids = ['s1'], workspaces = [{ workspaceId: 'ws-a', sessionIds: ids }], activationWorks = true, rpc = null } = {}) {
  const calls = []
  const listeners = []
  const byId = {}
  for (const id of ids) byId[id] = { id, running: false }

  const list = {
    getSnapshot: () => ({ ids: ids.slice(), byId }),
    subscribe: (fn) => { listeners.push(fn); return () => {} },
  }

  const workspace = {
    mainReference: undefined,
    selection: { getSnapshot: () => ({}) },
    workspaces: { list: { getSnapshot: () => ({ phase: 'ready', items: workspaces }) } },
    openSession(id) {
      calls.push(`openSession:${id}`)
      if (activationWorks) workspace.mainReference = { sessionId: id }
    },
    openWorkspace(workspaceId) {
      calls.push(`openWorkspace:${workspaceId}`)
      return Promise.resolve()
    },
  }

  const ctx = {
    get: (name) => {
      if (name === 'sessions') return { list }
      if (name === 'uiWorkspace') return workspace
      if (name === 'connection') return rpc ? { rpc } : null
      return null
    },
    effect: () => () => {},
  }

  /** 模拟"会话目录发生变化"，触发插件订阅的回调。 */
  const notifyListChanged = () => { for (const fn of listeners) fn() }

  return { ctx, calls, workspace, notifyListChanged }
}

/** 让应用自己完成初始导航（等价于协调器跑完 restoreSelection）。 */
function appFinishesBoot(workspace, sessionId) {
  workspace.mainReference = { sessionId }
}

// ── 核心回归 1：绝不能抢在应用初始导航之前 openSession ────────────────────────

test('应用完成初始导航之前，一次都不调用 openSession', async () => {
  const { ctx, calls, workspace, notifyListChanged } = makeCtx({ ids: ['s1'] })
  const { exported } = loadPlugin({ search: '?session=s1' })
  exported.apply(ctx)

  // 越过 600ms 宽限 + 若干次 400ms 重试，应用仍未完成初始导航。
  await sleep(1400)
  assert.deepEqual(calls, [], '抢跑会让协调器永远跳过工作区连接（左栏只有工作区、点击失灵）')

  // 应用自己选好了 → 这时才允许动手。
  appFinishesBoot(workspace, 's-other')
  notifyListChanged()
  await sleep(120)
  assert.deepEqual(calls, ['openSession:s1'])
})

test('应用完成初始导航后，切换会被复核并用 openSession 落地', async () => {
  const { ctx, calls, workspace, notifyListChanged } = makeCtx({ ids: ['s1'] })
  const { exported, replaced } = loadPlugin({ search: '?session=s1' })
  exported.apply(ctx)

  appFinishesBoot(workspace, 's-other')
  notifyListChanged()
  await sleep(150)

  assert.deepEqual(calls, ['openSession:s1'])
  assert.deepEqual(replaced, ['/'], '确认切过去之后才清掉 ?session= 参数')
})

// ── 核心回归 2：跨工作区必须先连接目标工作区（否则黑屏）────────────────────

test('跨工作区：先 openWorkspace(目标工作区) 再 openSession(会话)', async () => {
  const { ctx, calls, workspace, notifyListChanged } = makeCtx({
    ids: ['s-here', 's-target'],
    workspaces: [
      { workspaceId: 'ws-a', sessionIds: ['s-here'] },
      { workspaceId: 'ws-b', sessionIds: ['s-target'] },
    ],
  })
  const { exported } = loadPlugin({ search: '?session=s-target' })
  exported.apply(ctx)

  appFinishesBoot(workspace, 's-here') // 已连接的是 ws-a，目标在 ws-b
  notifyListChanged()
  await sleep(200)

  assert.deepEqual(calls, ['openWorkspace:ws-b', 'openSession:s-target'], '顺序错了就会黑屏')
})

test('同工作区内：不调用 openWorkspace，直接 openSession', async () => {
  const { ctx, calls, workspace, notifyListChanged } = makeCtx({
    ids: ['s-here', 's-target'],
    workspaces: [{ workspaceId: 'ws-a', sessionIds: ['s-here', 's-target'] }],
  })
  const { exported } = loadPlugin({ search: '?session=s-target' })
  exported.apply(ctx)

  appFinishesBoot(workspace, 's-here')
  notifyListChanged()
  await sleep(200)

  assert.deepEqual(calls, ['openSession:s-target'])
})

// ── 核心回归 3：没确认成功就不许清 URL（否则表现为"跳到错的会话"）──────────

test('切换未被确认时保留 ?session= 参数', async () => {
  const { ctx, workspace, notifyListChanged } = makeCtx({ ids: ['s1'], activationWorks: false })
  const { exported, replaced } = loadPlugin({ search: '?session=s1' })
  exported.apply(ctx)

  appFinishesBoot(workspace, 's-other')
  notifyListChanged()
  await sleep(500)

  assert.deepEqual(replaced, [], '清掉参数就等于假装成功，页面会停在"上次浏览的会话"上')
})

test('本来就在目标会话上：不重复切换，但会清掉参数', async () => {
  const { ctx, calls, workspace, notifyListChanged } = makeCtx({ ids: ['s1'] })
  const { exported, replaced } = loadPlugin({ search: '?session=s1' })
  exported.apply(ctx)

  appFinishesBoot(workspace, 's1') // 启动恢复的正是目标会话
  notifyListChanged()
  await sleep(900)

  assert.deepEqual(calls, [], '已经在目标上了，不该再动一次')
  assert.deepEqual(replaced, ['/'])
})

// ── 无参数时插件必须完全安静 ──────────────────────────────────────────────

test('URL 没有 ?session= 时什么都不做', async () => {
  const { ctx, calls, workspace, notifyListChanged } = makeCtx({ ids: ['s1'] })
  const { exported, replaced } = loadPlugin({ search: '' })
  exported.apply(ctx)
  appFinishesBoot(workspace, 's1')
  notifyListChanged()
  await sleep(900)
  assert.deepEqual(calls, [])
  assert.deepEqual(replaced, [])
})

// ── 目标会话不在目录里时不许乱动 ──────────────────────────────────────────

test('目标会话不在列表里：一直等，不误切换别的会话', async () => {
  const { ctx, calls, workspace, notifyListChanged } = makeCtx({ ids: ['s1'] })
  const { exported, replaced } = loadPlugin({ search: '?session=s-missing' })
  exported.apply(ctx)

  appFinishesBoot(workspace, 's1')
  notifyListChanged()
  await sleep(600)

  assert.deepEqual(calls, [])
  assert.deepEqual(replaced, [])
})

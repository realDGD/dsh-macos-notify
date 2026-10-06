import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import * as hostPlugin from '../lib/index.js'
const { apply } = hostPlugin

test('真实 Cordis 下认证 API 路由在调用插件生命周期内注册和清理', {
  skip: false,
}, async (t) => {
  const { Context, Service } = await import(process.env.DSH_CORDIS_MODULE || '@deepseek-ai/cordis')
  const ctx = new Context()
  const dir = mkdtempSync(join(tmpdir(), 'dsh-notify-cordis-'))
  t.after(async () => { await ctx.fiber.dispose(); rmSync(dir, { recursive: true, force: true }) })
  const routes = new Map()
  await ctx.plugin({ name: 'test-webserver', apply(ctx) {
    ctx.provide('webServer', { register(route) {
      routes.set(route.path, route)
      return () => routes.delete(route.path)
    } })
  } })
  // Match Desktop's HostConnectionService exact Fetch registry, mounted by
  // its existing authenticated /api carrier (no generic-channel registration).
  class Connection extends Service {
    constructor(ctx) { super(ctx, 'connection') }
    get fetch() {
      const owner = this.ctx
      return { register: (route) => owner.effect(() => {
        routes.set(route.path, route)
        return () => routes.delete(route.path)
      }, 'test Connection Fetch') }
    }
  }
  await ctx.plugin({ name: 'test-connection', apply(ctx) { new Connection(ctx) } })
  const fiber = await ctx.plugin(hostPlugin, { stateDir: dir })
  assert.equal(typeof routes.get('/api/dsh-macos-notify/pending')?.fetch, 'function')
  await fiber.dispose()
  assert.equal(routes.size, 0)
})

function host(t) {
  const dir = mkdtempSync(join(tmpdir(), 'dsh-notify-host-'))
  t.after(() => rmSync(dir, { recursive: true, force: true }))
  const routes = new Map()
  const connection = { fetch: { register(route) { routes.set(route.path, route) } } }
  apply({ get: () => connection }, { stateDir: dir })
  assert.equal(routes.size, 9, '宿主应注册已认证的跳转 API 路由')
  const send = async (endpoint, payload, envelope = {}) => {
    const method = 'dsh-macos-notify/' + endpoint
    return routes.get('/api/' + method).fetch(new Request('http://localhost/api/' + method, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ type: 'client-request', rpcId: 'test-rpc', method, payload, ...envelope }),
    }))
  }
  const handler = async (endpoint, payload) => {
    const response = await send(endpoint, payload)
    assert.equal(response.status, 200)
    const body = await response.json()
    assert.equal(body.type, 'server-response')
    assert.equal(body.rpcId, 'test-rpc')
    assert.equal(body.result.ok, true)
    return body.result.value
  }
  const put = (requestId, sessionId, createdAt = Date.now()) => {
    writeFileSync(join(dir, 'open-session.json'), JSON.stringify({ requestId, sessionId, createdAt }))
  }
  return { dir, handler, put, send }
}

test('宿主保留请求直到客户端确认对应会话', async (t) => {
  const { dir, handler, put } = host(t)
  put('click-1', 'session-1')
  assert.equal((await handler('pending', {})).sessionId, 'session-1')
  assert.equal((await handler('ack', { requestId: 'click-1', sessionId: 'wrong' })).ok, false)
  assert.equal((await handler('pending', {})).sessionId, 'session-1')
  assert.equal((await handler('ack', { requestId: 'click-1', sessionId: 'session-1' })).ok, true)
  assert.equal(await handler('pending', {}), null)
  assert.equal(JSON.parse(readFileSync(join(dir, 'jump-result.json'))).sessionId, 'session-1')
})

test('较早点击的确认不能清掉后来点击的请求', async (t) => {
  const { handler, put } = host(t)
  put('click-1', 'session-1')
  put('click-2', 'session-2')
  assert.equal((await handler('ack', { requestId: 'click-1', sessionId: 'session-1' })).ok, false)
  assert.equal((await handler('pending', {})).sessionId, 'session-2')
})

test('陈旧或损坏的请求不触发跳转', async (t) => {
  const { dir, handler, put } = host(t)
  put('old-click', 'session-1', Date.now() - 180_000)
  assert.equal(await handler('pending', {}), null)
  writeFileSync(join(dir, 'open-session.json'), '{broken')
  assert.equal(await handler('pending', {}), null)
})

test('错误 RPC 方法和超长请求拒绝执行', async (t) => {
  const { send, dir, put } = host(t)
  put('click-1', 'session-1')
  assert.equal((await send('ack', { requestId: 'click-1', sessionId: 'session-1' }, { method: 'wrong' })).status, 400)
  assert.equal((await send('ack', { text: 'x'.repeat(5000) })).status, 413)
  assert.throws(() => readFileSync(join(dir, 'jump-result.json')))
})

test('settings RPC persists preferences, rejects unknown secrets and reports only bounded diagnostics', async t => {
  const { send, handler, dir } = host(t)
  const preferences = await handler('settings', {})
  assert.equal(preferences.sound, true)
  assert.equal((await handler('save', { sound: false })).sound, false)
  assert.equal((await send('save', { secret: 'do-not-save' })).status, 400)
  const status = await handler('status', {})
  assert.equal(status.version, JSON.parse(readFileSync(new URL('../package.json', import.meta.url))).version)
  assert.equal(status.helper.running, false)
  assert.equal(JSON.stringify(status).includes(dir), false)
  assert.equal((await handler('test', { sessionId: 'session-safe' })).queued, true)
})

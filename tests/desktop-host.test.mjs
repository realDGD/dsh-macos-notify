import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, writeFileSync, readFileSync, rmSync, renameSync, mkdirSync } from 'node:fs'
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
  await new Promise(resolve => setImmediate(resolve))
  const menu = JSON.parse(readFileSync(join(dir, 'session-menu.json'), 'utf8'))
  assert.equal(menu.availability, 'unavailable')
  assert.equal(menu.enabled, true)
  await fiber.dispose()
  assert.equal(routes.size, 0)
})

function host(t, events = false) {
  const dir = mkdtempSync(join(tmpdir(), 'dsh-notify-host-'))
  const cleanups = [], hooks = new Map()
  t.after(() => { for (const off of cleanups) off?.(); rmSync(dir, { recursive: true, force: true }) })
  const routes = new Map()
  const connection = { fetch: { register(route) { routes.set(route.path, route) } } }
  const ctx = { get: name => name === 'connection' ? connection : null }
  if (events) Object.assign(ctx, { on: (name, fn) => hooks.set(name, fn), effect: fn => cleanups.push(fn()) })
  apply(ctx, { stateDir: dir })
  assert.equal(routes.size, 10, '宿主应注册已认证的跳转 API 路由')
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
  const put = (requestId, sessionId, createdAt = Date.now(), testId) => {
    writeFileSync(join(dir, 'open-session.json'), JSON.stringify({ requestId, sessionId, createdAt, ...(testId ? { testId } : {}) }))
  }
  return { dir, handler, put, send, hooks }
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
test('Host derives cold-child address from its fresh bounded menu tree, not arbitrary incoming routing hints',async t=>{
 const f=host(t);f.put('child-request','grandchild')
 const incoming=JSON.parse(readFileSync(join(f.dir,'open-session.json'),'utf8'))
 writeFileSync(join(f.dir,'open-session.json'),JSON.stringify({...incoming,lineage:['wrong','grandchild'],address:{parentSessionId:'wrong',childSessionId:'grandchild',mode:'unknown'}}))
 const snapshot={version:1,generation:crypto.randomUUID(),updatedAt:Date.now(),nodes:[{id:'root',parentId:null},{id:'child',parentId:'root'},{id:'grandchild',parentId:'child'}]}
 writeFileSync(join(f.dir,'session-menu.json'),JSON.stringify(snapshot))
 const request=await f.handler('pending',{})
 assert.deepEqual(request.lineage,['root','child','grandchild'])
 assert.deepEqual(request.address,{parentSessionId:'child',childSessionId:'grandchild',mode:'unknown'})
 snapshot.updatedAt-=7000;writeFileSync(join(f.dir,'session-menu.json'),JSON.stringify(snapshot))
 assert.equal((await f.handler('pending',{})).address,undefined)
})
test('matching jump receipt remains bounded regardless of routing lineage length',async t=>{
 const f=host(t);f.put('bounded-receipt','node-299')
 const nodes=Array.from({length:300},(_,i)=>({id:'node-'+i,parentId:i?'node-'+(i-1):null}))
 writeFileSync(join(f.dir,'session-menu.json'),JSON.stringify({version:1,updatedAt:Date.now(),nodes}))
 assert.equal((await f.handler('pending',{})).lineage.length,300)
 assert.equal((await f.handler('ack',{requestId:'bounded-receipt',sessionId:'node-299'})).ok,true)
 const receipt=JSON.parse(readFileSync(join(f.dir,'jump-result.json'),'utf8'))
 assert.deepEqual(Object.keys(receipt).sort(),['confirmedAt','createdAt','requestId','sessionId'])
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


test('background windows and delayed presence packets cannot override foreground quiet mode', async t => {
  const f = host(t, true)
  await f.handler('save', { quietCurrentSession: true })
  const presence = (clientId, seq, visible) => f.handler('foreground', { clientId, seq, sessionId: 'session-active', visible })
  await presence('active-window', 1, true)
  await presence('background-window', 1, false)
  const end = turn => f.hooks.get('session/event')({ id: 'session-active', header: {} }, { type: 'turn/end', data: { turn, reason: { kind: 'completed' } } })
  end(1)
  assert.equal((await f.handler('status', {})).notifications.suppressed, 1)
  await presence('active-window', 2, false)
  await presence('active-window', 1, true)
  end(2)
  assert.equal((await f.handler('status', {})).notifications.posted, 1)
})

test('safe test queue failure never returns queued success', async t => {
  const f = host(t)
  renameSync(join(f.dir, 'notifications'), join(f.dir, 'old-queue'))
  writeFileSync(join(f.dir, 'notifications'), 'blocked queue')
  assert.equal((await f.send('test', { sessionId: 'session-safe' })).status, 400)
})

test('safe test status binds delivery and confirmation to this test and session only', async t => {
  const f = host(t)
  assert.equal((await f.handler('status', {})).test?.state, 'none')
  await f.handler('test', { sessionId: 'session-safe' })
  assert.equal((await f.handler('status', {})).test.state, 'waiting-for-helper')
  const test = JSON.parse(readFileSync(join(f.dir, 'last-test.json')))
  const receipts = join(f.dir, 'test-delivery'); mkdirSync(receipts)
  const writeReceipt = (id, state) => writeFileSync(join(receipts, id + '.json'), JSON.stringify({ id, state, updatedAt: Date.now(), secret: 'private diagnostic input' }))
  writeReceipt(crypto.randomUUID(), 'posted')
  assert.equal((await f.handler('status', {})).test.state, 'waiting-for-helper')
  writeReceipt(test.id, 'posted')
  assert.equal((await f.handler('status', {})).test.state, 'waiting-for-click')
  f.put('other-session', 'session-other', Date.now(), test.id)
  await f.handler('ack', { requestId: 'other-session', sessionId: 'session-other' })
  assert.equal((await f.handler('status', {})).test.state, 'waiting-for-click')
  f.put('own-test', 'session-safe', Date.now(), test.id)
  assert.equal((await f.handler('status', {})).test.state, 'opening')
  await f.handler('ack', { requestId: 'own-test', sessionId: 'session-safe' })
  assert.equal((await f.handler('status', {})).test.state, 'confirmed')
  f.put('later-unrelated', 'session-other')
  await f.handler('ack', { requestId: 'later-unrelated', sessionId: 'session-other' })
  const status = await f.handler('status', {})
  assert.equal(status.test.state, 'confirmed')
  for (const secret of [f.dir, test.id, 'session-safe', 'private diagnostic input']) assert(!JSON.stringify(status).includes(secret))
  await f.handler('test', { sessionId: 'session-safe' })
  assert.equal((await f.handler('status', {})).test.state, 'waiting-for-helper')
})

test('helper status never exposes arbitrary file content as a version', async t => {
  const f = host(t)
  writeFileSync(join(f.dir, 'helper-status.json'), JSON.stringify({ updatedAt: Date.now(), version: 'private diagnostic secret', permission: 'authorized' }))
  const status = await f.handler('status', {})
  assert.equal(status.helper.version, null)
  assert.equal(JSON.stringify(status).includes('private diagnostic secret'), false)
})

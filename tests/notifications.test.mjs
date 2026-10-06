import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, readdirSync, readFileSync, statSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { createNotifications } from '../lib/notifications.js'

function fixture(t, preferences = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'dsh-notify-test-'))
  t.after(() => rmSync(dir, { recursive: true, force: true }))
  let clock = 100000
  const service = createNotifications({ stateDir: dir, now: () => clock, preferences: () => preferences })
  const records = () => readdirSync(join(dir, 'notifications')).map(f => JSON.parse(readFileSync(join(dir, 'notifications', f))))
  return { service, records, dir, advance: () => clock += 1000 }
}
const root = { id: 'session-root', title: 'Example task', header: {} }
const child = { id: 'session-child', header: { parentSession: root.id, origin: 'subagent' } }
const event = (type, turn = 1, reason = 'completed') => ({ type, seq: turn * 10, data: { turn, reason: { kind: reason } } })

test('one private completion record per root turn, with no replay or duplicate terminal event', t => {
  const f = fixture(t)
  f.service.observe(root, event('turn/start'))
  f.service.observe(root, event('assistant/message'))
  f.service.observe(root, event('turn/end'))
  f.service.observe(root, event('turn/end'))
  f.service.error({ agent: { session: root }, turn: 1, error: new Error('late duplicate') })
  assert.equal(f.records().length, 1)
  assert.equal(f.records()[0].title, '任务完成')
  assert.equal(f.records()[0].sessionId, root.id)
  assert.equal(statSync(join(f.dir, 'notifications')).mode & 0o777, 0o700)
  assert.equal(statSync(join(f.dir, 'notifications', readdirSync(join(f.dir, 'notifications'))[0])).mode & 0o777, 0o600)
})
test('aborted, interrupted, and blocked turns are silent', t => {
  const f = fixture(t)
  for (const reason of ['aborted', 'interrupted', 'blocked']) {
    f.advance(); f.service.observe(root, event('turn/end', f.records().length + reason.length, reason))
  }
  assert.deepEqual(f.records(), [])
})
test('root completion waits for nested live children without child notifications', t => {
  const f = fixture(t)
  const grandchild = { id: 'session-grandchild', header: { parentSession: child.id, origin: 'subagent' } }
  f.service.observe(root, event('turn/start'))
  f.service.observe(child, event('turn/start'))
  f.service.observe(grandchild, event('turn/start'))
  f.service.observe(root, event('turn/end'))
  assert.equal(f.records().length, 0)
  f.service.observe(child, event('turn/end'))
  assert.equal(f.records().length, 0)
  f.service.observe(grandchild, event('turn/end'))
  assert.deepEqual(f.records().map(n => n.sessionId), [root.id])
})
test('a new root turn cancels the older held completion', t => {
  const f = fixture(t)
  f.service.observe(root, event('turn/start'))
  f.service.observe(child, event('turn/start'))
  f.service.observe(root, event('turn/end'))
  f.service.observe(root, event('turn/start', 2))
  f.service.observe(child, event('turn/end'))
  assert.equal(f.records().length, 0)
  f.service.observe(root, event('turn/end', 2))
  assert.equal(f.records().length, 1)
})
test('errors are immediate, bounded and deduplicated, never raw logs', t => {
  const f = fixture(t)
  f.service.error({ agent: { session: root }, turn: 2, error: new Error('private error content') })
  f.service.observe(root, event('turn/end', 2, 'error'))
  assert.equal(f.records().length, 1)
  assert.equal(f.records()[0].title, '任务出错')
  assert.equal(JSON.stringify(f.service.status()).includes('private error content'), false)
})
test('notification preferences suppress reminders without consuming Host answers', t => {
  const prefs = { completed: false, error: true }
  const f = fixture(t, prefs)
  f.service.observe(root, event('turn/end'))
  assert.equal(f.records().length, 0)
  f.service.observe(root, event('turn/end', 2, 'error'))
  assert.equal(f.records().length, 1)
  assert.equal(f.service.status().suppressed, 1)
})

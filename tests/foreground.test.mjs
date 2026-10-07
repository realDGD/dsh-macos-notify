import test from 'node:test'
import assert from 'node:assert/strict'
import { createForeground } from '../lib/foreground.js'
test('foreground leases expire without allowing delayed older packets to revive focus', () => {
  let now = 10000
  const f = createForeground({ now: () => now })
  const put = (clientId, seq, visible, sessionId = 'session-active') => f.update({ clientId, seq, visible, sessionId })
  put('one', 1, true); now += 1; put('two', 1, true)
  assert.equal(f.current().sessionId, 'session-active')
  put('two', 2, false)
  assert.equal(f.current().updatedAt, 10000)
  now += 5000; assert.equal(f.current(), null)
  put('one', 1, true); assert.equal(f.current(), null)
  put('one', 2, true); assert.equal(f.current().updatedAt, now)
  put('one', 3, false, null); assert.equal(f.current(), null)
})
test('bounded presence history preserves active client amid inactive arrivals and supports legacy clients', () => {
  const f = createForeground({ maxClients: 2, now: () => 10000 })
  f.update({ clientId: 'active', seq: 1, visible: true, sessionId: 'session-active' })
  for (let i = 0; i < 200; i++) f.update({ clientId: 'idle-' + i, seq: 1, visible: false, sessionId: null })
  assert.equal(f.current().sessionId, 'session-active')
  assert.throws(() => f.update({ clientId: '../bad', seq: 1, visible: true, sessionId: 'session-active' }))
  assert.throws(() => f.update({ clientId: 'ok', seq: NaN, visible: true, sessionId: 'session-active' }))
  assert.throws(() => f.update({ visible: true, sessionId: '../bad' }))
  f.update({ visible: true, sessionId: 'session-legacy' })
  assert.equal(f.current()?.visible, true)
})

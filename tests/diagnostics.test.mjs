import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { readTestStatus } from '../lib/diagnostics.js'
import { randomUUID } from 'node:crypto'
test('safe test diagnostics reject malformed, oversized, stale and future receipts; report real failure and timeout', t => {
  const dir = mkdtempSync(join(tmpdir(), 'dsh-diagnostic-')); t.after(() => rmSync(dir, { recursive: true, force: true }))
  const now = 100000000, id = randomUUID(), sessionId = 'session-example'
  const write = (name, value) => writeFileSync(join(dir, name), JSON.stringify(value))
  const state = (time = now) => readTestStatus(dir, time).state
  const current = { id, sessionId, createdAt: now - 1000 }
  write('last-test.json', { ...current, createdAt: now + 10001 }); assert.equal(state(), 'none')
  write('last-test.json', { ...current, createdAt: now - 86400001 }); assert.equal(state(), 'none')
  writeFileSync(join(dir, 'last-test.json'), '{broken'); assert.equal(state(), 'none')
  writeFileSync(join(dir, 'last-test.json'), ' '.repeat(5000)); assert.equal(state(), 'none')
  write('last-test.json', { ...current, queueFailed: true }); assert.equal(state(), 'queue-failed')
  write('last-test.json', current); assert.equal(state(), 'waiting-for-helper'); assert.equal(state(now + 120000), 'expired')
  mkdirSync(join(dir, 'test-delivery'))
  write('test-delivery/' + id + '.json', { id, state: 'posted', updatedAt: now + 10001 }); assert.equal(state(), 'waiting-for-helper')
  write('test-delivery/' + id + '.json', { id, state: 'failed', updatedAt: now }); assert.equal(state(), 'system-rejected')
  const request = { testId: id, sessionId, requestId: 'click-id', createdAt: now }
  write('open-session.json', request); assert.equal(state(), 'opening'); assert.equal(state(now + 15001), 'timed-out')
  write('jump-result.json', { ...request, createdAt: now - 1, confirmedAt: now }); assert.equal(state(), 'opening')
  write('jump-result.json', { ...request, confirmedAt: now - 1 }); assert.equal(state(), 'opening')
  write('jump-result.json', { ...request, confirmedAt: now }); assert.equal(state(), 'confirmed')
})

import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, writeFileSync, statSync, rmSync } from 'node:fs'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import { createSettings } from '../lib/settings.js'
function make(t) {
  const dir = mkdtempSync(join(tmpdir(), 'notify-settings-'))
  t.after(() => rmSync(dir, { recursive: true, force: true }))
  return { dir, settings: createSettings(dir) }
}
test('preferences persist privately and survive a new Host generation', t => {
  const { dir, settings } = make(t)
  assert.equal(settings.get().sound, true)
  settings.save({ sound: false, quietCurrentSession: true })
  assert.equal(createSettings(dir).get().sound, false)
  assert.equal(createSettings(dir).get().quietCurrentSession, true)
  assert.equal(statSync(join(dir, 'settings.json')).mode & 0o777, 0o600)
})
test('wrong types, unknown keys and malformed saved JSON cannot corrupt preferences', t => {
  const { dir, settings } = make(t)
  assert.throws(() => settings.save({ sound: 'false' }))
  assert.throws(() => settings.save({ token: 'private' }))
  assert.equal(settings.get().sound, true)
  writeFileSync(join(dir, 'settings.json'), '{broken')
  assert.equal(createSettings(dir).get().sound, true)
})

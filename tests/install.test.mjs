import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, readdirSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { execFileSync } from 'node:child_process'
const script = new URL('../scripts/install.mjs', import.meta.url)
function fixture(t) {
  const home = mkdtempSync(join(tmpdir(), 'notify-install-'))
  t.after(() => rmSync(home, { recursive: true, force: true }))
  const app = join(home, 'source.app')
  mkdirSync(join(app, 'Contents/MacOS'), { recursive: true })
  writeFileSync(join(app, 'Contents/MacOS/DSHNotify'), 'v1')
  writeFileSync(join(app, 'Contents/Info.plist'), '<plist><dict><key>CFBundleIdentifier</key><string>com.dgd.dsh-jump-notifier</string></dict></plist>')
  return { home, app, run: (...args) => execFileSync(process.execPath, [script.pathname, '--home', home, '--app', app, '--no-start', ...args], { encoding: 'utf8', stdio: 'pipe' }) }
}
test('fresh install configures private startup without touching another profile', t => {
  const f = fixture(t); f.run()
  assert.equal(readFileSync(join(f.home, 'Applications/DSH Notify.app/Contents/MacOS/DSHNotify'), 'utf8'), 'v1')
  assert.equal(existsSync(join(f.home, 'Library/LaunchAgents/com.dgd.dsh-jump-notifier.plist')), true)
  assert.equal(existsSync(join(f.home, '.dsh/dsh-jump/install.json')), true)
})
test('upgrade backs up previous app, preserves settings and supports safe removal', t => {
  const f = fixture(t); f.run()
  writeFileSync(join(f.home, '.dsh/dsh-jump/settings.json'), '{"sound":false}')
  writeFileSync(join(f.app, 'Contents/MacOS/DSHNotify'), 'v2'); f.run()
  const backups = readdirSync(join(f.home, '.dsh/dsh-jump/backups'))
  assert.equal(backups.length, 1)
  assert.equal(readFileSync(join(f.home, '.dsh/dsh-jump/backups', backups[0], 'Contents/MacOS/DSHNotify'), 'utf8'), 'v1')
  assert.equal(readFileSync(join(f.home, '.dsh/dsh-jump/settings.json'), 'utf8'), '{"sound":false}')
  f.run('--uninstall')
  assert.equal(existsSync(join(f.home, 'Applications/DSH Notify.app')), false)
  assert.equal(existsSync(join(f.home, '.dsh/dsh-jump/settings.json')), true)
})
test('an unknown existing startup file or application is never overwritten', t => {
  const f = fixture(t)
  mkdirSync(join(f.home, 'Library/LaunchAgents'), { recursive: true })
  writeFileSync(join(f.home, 'Library/LaunchAgents/com.dgd.dsh-jump-notifier.plist'), 'unrelated')
  assert.throws(() => f.run())
  assert.equal(existsSync(join(f.home, 'Applications/DSH Notify.app')), false)
})

test('upgrade refuses an open native panel and preserves the current app', t => {
  const f = fixture(t); f.run()
  writeFileSync(join(f.home, '.dsh/dsh-jump/open-panels.json'), JSON.stringify({ updatedAt: Date.now(), ids: ['draft-panel'] }))
  writeFileSync(join(f.app, 'Contents/MacOS/DSHNotify'), 'v2')
  assert.throws(() => f.run(), /Close native/)
  assert.equal(readFileSync(join(f.home, 'Applications/DSH Notify.app/Contents/MacOS/DSHNotify'), 'utf8'), 'v1')
})

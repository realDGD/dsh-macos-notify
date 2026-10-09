import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync, readdirSync, rmSync, chmodSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { execFileSync, spawnSync, spawn } from 'node:child_process'
import { once } from 'node:events'
const script = new URL('../scripts/install.mjs', import.meta.url)
function fixture(t) {
  const home = mkdtempSync(join(tmpdir(), 'notify-install-'))
  t.after(() => rmSync(home, { recursive: true, force: true }))
  const app = join(home, 'source.app')
  mkdirSync(join(app, 'Contents/MacOS'), { recursive: true })
  writeFileSync(join(app, 'Contents/MacOS/DSHNotify'), 'v1')
  writeFileSync(join(app, 'Contents/Info.plist'), '<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>com.dgd.dsh-jump-notifier</string><key>CFBundleExecutable</key><string>DSHNotify</string><key>CFBundlePackageType</key><string>APPL</string></dict></plist>')
  return { home, app, run: (...args) => execFileSync(process.execPath, [script.pathname, '--home', home, '--app', app, '--no-start', ...args], { encoding: 'utf8', stdio: 'pipe' }) }
}
test('fresh install follows Desktop without creating a login agent', t => {
  const f = fixture(t); f.run()
  assert.equal(readFileSync(join(f.home, 'Applications/DSH Notify.app/Contents/MacOS/DSHNotify'), 'utf8'), 'v1')
  assert.equal(existsSync(join(f.home, 'Library/LaunchAgents/com.dgd.dsh-jump-notifier.plist')), false)
  assert.equal(existsSync(join(f.home, '.dsh/dsh-jump/install.json')), true)
  assert.equal(JSON.parse(readFileSync(join(f.home, '.dsh/dsh-jump/install.json'))).startup, 'desktop')
})
test('upgrade retires only the managed login agent and retains its backup', t => {
  const f = fixture(t); f.run()
  const agent = join(f.home, 'Library/LaunchAgents/com.dgd.dsh-jump-notifier.plist')
  mkdirSync(join(f.home, 'Library/LaunchAgents'), { recursive: true })
  const original = '<!-- dsh-macos-notify managed -->old startup'
  writeFileSync(agent, original)
  f.run()
  assert.equal(existsSync(agent), false)
  const backups = join(f.home, '.dsh/dsh-jump/backups')
  assert.ok(readdirSync(backups).some(name => name.endsWith('.plist') && readFileSync(join(backups,name),'utf8') === original))
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

test('package postinstall installs the native helper through the owned installer', t => {
  const f = fixture(t)
  const result = spawnSync('npm', ['run', 'postinstall', '--', '--home', f.home, '--app', f.app, '--no-start'],
    { cwd: new URL('..', import.meta.url), encoding: 'utf8' })
  assert.equal(result.status, 0, result.stdout + result.stderr)
  assert.equal(readFileSync(join(f.home, 'Applications/DSH Notify.app/Contents/MacOS/DSHNotify'), 'utf8'), 'v1')
  assert.equal(JSON.parse(readFileSync(join(f.home, '.dsh/dsh-jump/install.json'))).startup, 'desktop')
})

test('automatic repeat install reuses an intact matching helper, even with an open draft', t => {
  const f = fixture(t); f.run('--automatic')
  const state = join(f.home, '.dsh/dsh-jump')
  const manifest = readFileSync(join(state, 'install.json'), 'utf8')
  writeFileSync(join(state, 'open-panels.json'), JSON.stringify({ updatedAt: Date.now(), ids: ['draft-panel'] }))
  assert.doesNotThrow(() => f.run('--automatic'))
  assert.equal(readFileSync(join(state, 'install.json'), 'utf8'), manifest)
  assert.equal(readdirSync(join(state, 'backups')).length, 0)
})

test('automatic upgrade installs changed inputs and retains the previous helper and settings', t => {
  const f = fixture(t); f.run('--automatic')
  const state = join(f.home, '.dsh/dsh-jump')
  writeFileSync(join(state, 'settings.json'), '{"sound":false}')
  writeFileSync(join(f.app, 'Contents/MacOS/DSHNotify'), 'v2'); f.run('--automatic')
  const backups = readdirSync(join(state, 'backups'))
  assert.equal(backups.length, 1)
  assert.equal(readFileSync(join(state, 'backups', backups[0], 'Contents/MacOS/DSHNotify'), 'utf8'), 'v1')
  assert.equal(readFileSync(join(f.home, 'Applications/DSH Notify.app/Contents/MacOS/DSHNotify'), 'utf8'), 'v2')
  assert.equal(readFileSync(join(state, 'settings.json'), 'utf8'), '{"sound":false}')
})

test('automatic reuse detects modified installed resources and repairs from the requested source', t => {
  const f = fixture(t); f.run('--automatic')
  const installed = join(f.home, 'Applications/DSH Notify.app/Contents/MacOS/DSHNotify')
  writeFileSync(installed, 'modified')
  f.run('--automatic')
  assert.equal(readFileSync(installed, 'utf8'), 'v1')
  const state = join(f.home, '.dsh/dsh-jump')
  const backups = readdirSync(join(state, 'backups'))
  assert.equal(readFileSync(join(state, 'backups', backups[0], 'Contents/MacOS/DSHNotify'), 'utf8'), 'modified')
})

test('failed automatic compilation preserves the installed app and ownership record', t => {
  const f = fixture(t); f.run('--automatic')
  const manifest = join(f.home, '.dsh/dsh-jump/install.json')
  const record = readFileSync(manifest, 'utf8')
  const bin = join(f.home, 'bin'); mkdirSync(bin)
  writeFileSync(join(bin, 'xcrun'), '#!/bin/sh\nexit 1\n'); chmodSync(join(bin, 'xcrun'), 0o755)
  const result = spawnSync(process.execPath, [script.pathname, '--automatic', '--home', f.home, '--no-start'],
    { encoding: 'utf8', env: { ...process.env, PATH: bin + ':' + process.env.PATH } })
  assert.notEqual(result.status, 0)
  assert.match(result.stderr, /xcode-select --install/)
  assert.equal(readFileSync(join(f.home, 'Applications/DSH Notify.app/Contents/MacOS/DSHNotify'), 'utf8'), 'v1')
  assert.equal(readFileSync(manifest, 'utf8'), record)
  assert.equal(readdirSync(join(f.home, '.dsh/dsh-jump/backups')).length, 0)
  assert.deepEqual(readdirSync(join(f.home, 'Applications')), ['DSH Notify.app'])
})

test('automatic opt-out leaves the helper and settings untouched', t => {
  const f = fixture(t); f.run('--automatic')
  const record = readFileSync(join(f.home, '.dsh/dsh-jump/install.json'), 'utf8')
  writeFileSync(join(f.app, 'Contents/MacOS/DSHNotify'), 'v2')
  const result = spawnSync(process.execPath, [script.pathname, '--automatic', '--home', f.home, '--app', f.app, '--no-start'],
    { encoding: 'utf8', env: { ...process.env, DSH_NOTIFY_SKIP_NATIVE_INSTALL: '1' } })
  assert.equal(result.status, 0, result.stderr)
  assert.equal(readFileSync(join(f.home, 'Applications/DSH Notify.app/Contents/MacOS/DSHNotify'), 'utf8'), 'v1')
  assert.equal(readFileSync(join(f.home, '.dsh/dsh-jump/install.json'), 'utf8'), record)
})

test('concurrent native installation refuses to replace an app owned by another installer', t => {
  const f = fixture(t); f.run('--automatic')
  const lock = join(f.home, 'Applications/.DSH Notify.install.lock')
  const owner = JSON.stringify({ pid: process.pid })
  writeFileSync(lock, owner)
  writeFileSync(join(f.app, 'Contents/MacOS/DSHNotify'), 'v2')
  assert.throws(() => f.run('--automatic'), /native installation.*active/)
  assert.equal(readFileSync(join(f.home, 'Applications/DSH Notify.app/Contents/MacOS/DSHNotify'), 'utf8'), 'v1')
  assert.equal(readFileSync(lock, 'utf8'), owner)
  assert.equal(readdirSync(join(f.home, '.dsh/dsh-jump/backups')).length, 0)
})

test('another state directory cannot replace a running helper with an open draft', async t => {
  if (process.platform !== 'darwin') { t.skip('Requires a signed macOS no-UI process fixture'); return }
  const f = fixture(t)
  execFileSync('xcrun', ['clang', '-x', 'c', '-', '-o', join(f.app, 'Contents/MacOS/DSHNotify')],
    { input: '#include <unistd.h>\nint main(void) { for (;;) pause(); }\n', stdio: ['pipe','pipe','pipe'] })
  execFileSync('codesign', ['--force', '--deep', '--sign', '-', f.app], { stdio: 'pipe' })
  f.run('--automatic')
  const original = join(f.home, 'Original State'); mkdirSync(original)
  let helper = spawn(join(f.home, 'Applications/DSH Notify.app/Contents/MacOS/DSHNotify'), ['--state-dir', original], { stdio: 'ignore' })
  await once(helper, 'spawn')
  t.after(async () => { if (helper.exitCode === null && helper.signalCode === null) { helper.kill('SIGTERM'); await once(helper, 'exit') } })
  writeFileSync(join(original, 'open-panels.json'), JSON.stringify({ updatedAt: Date.now(), ids: ['live-draft'] }))
  const result = spawnSync(process.execPath, [script.pathname, '--automatic', '--defer-start', '--home', f.home,
    '--dsh-home', join(f.home, 'Different State'), '--app', f.app], { encoding: 'utf8' })
  assert.notEqual(result.status, 0, 'Upgrade incorrectly stopped the helper using another state directory')
  assert.match(result.stderr, /Close native/)
  assert.doesNotThrow(() => process.kill(helper.pid, 0), 'The original helper was terminated with a draft')
  assert.equal(existsSync(join(f.home, 'Different State/dsh-jump/install.json')), false)
  helper.kill('SIGTERM'); await once(helper, 'exit')
  helper = spawn(join(f.home, 'Applications/DSH Notify.app/Contents/MacOS/DSHNotify'), [], { stdio: 'ignore' })
  await once(helper, 'spawn')
  const unknown = spawnSync(process.execPath, [script.pathname, '--automatic', '--defer-start', '--home', f.home,
    '--dsh-home', join(f.home, 'Different State'), '--app', f.app], { encoding: 'utf8' })
  assert.notEqual(unknown.status, 0)
  assert.match(unknown.stderr, /Cannot verify the running helper state directory/)
  assert.doesNotThrow(() => process.kill(helper.pid, 0), 'A helper with unknown state was terminated')
})

test('failed ownership-record replacement restores the previous app and cleans staging', t => {
  const f = fixture(t); f.run('--automatic')
  const state = join(f.home, '.dsh/dsh-jump')
  writeFileSync(join(state, 'settings.json'), '{"sound":false}')
  rmSync(join(state, 'install.json')); mkdirSync(join(state, 'install.json'))
  writeFileSync(join(f.app, 'Contents/MacOS/DSHNotify'), 'v2')
  assert.throws(() => f.run('--automatic'))
  assert.equal(readFileSync(join(f.home, 'Applications/DSH Notify.app/Contents/MacOS/DSHNotify'), 'utf8'), 'v1')
  assert.equal(readFileSync(join(state, 'settings.json'), 'utf8'), '{"sound":false}')
  assert.equal(readdirSync(join(state, 'backups')).length, 0)
  assert.deepEqual(readdirSync(join(f.home, 'Applications')), ['DSH Notify.app'])
  assert.equal(readdirSync(state).some(name => name.startsWith('.install-')), false)
})

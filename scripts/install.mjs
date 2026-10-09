import { existsSync, mkdirSync, readFileSync, writeFileSync, renameSync, rmSync, cpSync, readdirSync, lstatSync, openSync, closeSync } from 'node:fs'
import { homedir } from 'node:os'
import { join, resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { execFileSync } from 'node:child_process'
import { randomUUID, createHash } from 'node:crypto'
const args = process.argv.slice(2)
const option = name => { const i = args.indexOf(name); if (i < 0) return null; if (!args[i + 1] || args[i + 1].startsWith('--')) throw new Error(`Missing ${name} value`); return args[i + 1] }
const automatic = args.includes('--automatic'), deferStart = args.includes('--defer-start')
const homeOverride = option('--home') || process.env.DSH_NOTIFY_INSTALL_HOME
const home = resolve(homeOverride || homedir()), dry = args.includes('--no-start')
if (automatic && process.env.DSH_NOTIFY_SKIP_NATIVE_INSTALL === '1') {
  console.log('Native helper installation skipped explicitly. Run bash macos/install.sh before using native notifications.')
  process.exit(0)
}
if (automatic && process.platform !== 'darwin' && !dry) {
  console.log('DSH Notify native helper requires macOS 13 or later; no application was installed on this platform.')
  process.exit(0)
}
if (automatic && process.platform === 'darwin' && !dry) {
  const release = execFileSync('/usr/bin/sw_vers', ['-productVersion'], { encoding: 'utf8' }).trim()
  if (!/^\d+(?:\.\d+)*$/.test(release) || Number(release.split('.')[0]) < 13) throw new Error('DSH Notify requires macOS 13 or later.')
}
const dir = resolve(option('--dsh-home') || (homeOverride ? join(home, '.dsh') : process.env.DSH_HOME || join(home, '.dsh')), 'dsh-jump')
const target = join(home, 'Applications/DSH Notify.app'), legacy = join(home, 'Applications/DSH Jump.app')
const label = 'com.dgd.dsh-jump-notifier'
const agent = join(home, 'Library/LaunchAgents', label + '.plist'), manifest = join(dir, 'install.json')
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const fingerprint = (folder, include = () => true) => {
  const hash = createHash('sha256')
  const walk = relative => {
    for (const entry of readdirSync(join(folder, relative), { withFileTypes: true }).sort((a,b) => a.name.localeCompare(b.name, 'en'))) {
      const path = join(relative, entry.name)
      if (entry.isSymbolicLink()) throw new Error('Native installation inputs must not contain symbolic links.')
      if (entry.isDirectory()) { walk(path); continue }
      if (!entry.isFile() || !include(path)) continue
      hash.update(path); hash.update('\0'); hash.update(String(lstatSync(join(folder,path)).mode & 0o777)); hash.update('\0'); hash.update(readFileSync(join(folder,path))); hash.update('\0')
    }
  }
  walk(''); return hash.digest('hex')
}
const owned = app => { try { return readFileSync(join(app, 'Contents/Info.plist'), 'utf8').includes('<string>' + label + '</string>') } catch { return false } }
const agentOwned = () => { try { return readFileSync(agent, 'utf8').includes('<!-- dsh-macos-notify managed -->') } catch { return false } }
const checkPanels = directory => {
  try {
    const lease = JSON.parse(readFileSync(join(directory, 'open-panels.json'), 'utf8'))
    if (Date.now() - lease.updatedAt < 5000 && (lease.ids?.length || lease.draftIds?.length)) throw new Error('Close native panels and resolve unsent question drafts before upgrading. Closing a question window keeps its draft; quitting the helper discards it.')
  } catch (error) { if (error.message.startsWith('Close native')) throw error }
}
const stop = () => {
  checkPanels(dir)
  if (dry) return
  const lines = execFileSync('ps', ['-axww', '-o', 'pid=,command='], { encoding: 'utf8' }).split('\n')
  const pids = []
  for (const line of lines) {
    const match = line.trim().match(/^(\d+)\s+(.+)$/)
    if (!match) continue
    const command = match[2]
    const executable = [join(target, 'Contents/MacOS/DSHNotify'), join(legacy, 'Contents/MacOS/DSHJumpNotify')]
      .find(path => command === path || command.startsWith(path + ' '))
    if (!executable) continue
    const activeState = command.slice(executable.length).match(/^ --state-dir (\/.+)$/)?.[1]
    if (!activeState || !existsSync(activeState) || !lstatSync(activeState).isDirectory()) {
      throw new Error('Cannot verify the running helper state directory. Close DSH Desktop and the helper before upgrading so drafts are preserved.')
    }
    checkPanels(activeState)
    pids.push(Number(match[1]))
  }
  // All running instances must pass draft checks before any is stopped.
  if (agentOwned()) { try { execFileSync('launchctl', ['bootout', `gui/${process.getuid()}/${label}`], { stdio: 'pipe' }) } catch {} }
  for (const pid of pids) {
      try { process.kill(pid, 'SIGTERM') } catch (error) { if (error.code !== 'ESRCH') throw error; continue }
      let exited = false
      for (let n = 0; n < 100; n++) {
        try { process.kill(pid, 0) } catch (error) { if (error.code === 'ESRCH') { exited = true; break } throw error }
        Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 50)
      }
      if (!exited) throw new Error('Previous helper has not exited; keeping the existing application.')
  }
}
if (existsSync(agent) && !agentOwned()) throw new Error('Existing startup item is not owned by this installer; preserve it and resolve the conflict first.')
if (existsSync(target) && !owned(target)) throw new Error('Existing destination is not this helper; refusing to overwrite it.')
function install() {
if (args.includes('--uninstall')) {
  if (!existsSync(manifest)) throw new Error('No installer ownership record; refusing to remove files.')
  const record = JSON.parse(readFileSync(manifest, 'utf8'))
  if (record.app !== target || record.label !== label) throw new Error('Installation ownership mismatch')
  stop()
  if (existsSync(target)) rmSync(target, { recursive: true })
  if (agentOwned()) rmSync(agent)
  rmSync(manifest)
  console.log('Removed helper and login startup. Settings and backups are preserved. Remove the DSH plugin in Plugins separately.')
} else {
  if (process.platform !== 'darwin' && !dry) throw new Error('macOS required')
  mkdirSync(dir, { recursive: true, mode: 0o700 })
  mkdirSync(dirname(target), { recursive: true })
  const staging = join(dirname(target), `.DSH Notify.stage-${randomUUID()}.app`)
  const supplied = option('--app')
  const sourceFingerprint = supplied ? fingerprint(resolve(supplied)) : createHash('sha256')
    .update(process.arch).update('\0').update(fingerprint(join(root,'macos'), path => path.endsWith('.swift') || path === 'Info.plist' || path.endsWith('.sh') || path.startsWith('assets/'))).digest('hex')
  if (automatic && existsSync(target) && owned(target)) {
    try {
      const record = JSON.parse(readFileSync(manifest, 'utf8'))
      if (record.app === target && record.label === label && record.sourceFingerprint === sourceFingerprint && record.appFingerprint === fingerprint(target)) {
        if (!dry) execFileSync('codesign', ['--verify', '--deep', '--strict', target], { stdio: 'pipe' })
        console.log('Matching DSH Notify.app is already installed; retained without interrupting open drafts.')
        return
      }
    } catch { /* Missing or invalid provenance/signature requires a verified rebuild. */ }
  }
  try {
    if (supplied) {
      if (!owned(resolve(supplied))) throw new Error('Source application bundle identity mismatch')
      cpSync(resolve(supplied), staging, { recursive: true })
    } else execFileSync('bash', [join(root, 'macos/build.sh'), staging], { stdio: 'inherit' })
    if (!dry) execFileSync('codesign', ['--verify', '--deep', '--strict', staging], { stdio: 'inherit' })
    stop()
    const backupDir = join(dir, 'backups'); mkdirSync(backupDir, { recursive: true, mode: 0o700 })
    if (agentOwned()) {
      renameSync(agent, join(backupDir, `${new Date().toISOString().replace(/[:.]/g, '-')}-${randomUUID()}.plist`))
      console.log('Previous login startup retired and retained as backup.')
    }
    const previousApps = [], temporaryManifest = join(dir, `.install-${randomUUID()}.json`)
    let replaced = false
    try {
      // Compute provenance before replacing the installed bundle.
      const record = { version: 3, app: target, label, startup: 'desktop', sourceFingerprint, appFingerprint: fingerprint(staging) }
      writeFileSync(temporaryManifest, JSON.stringify(record) + '\n', { mode: 0o600 })
      for (const previous of [target, legacy]) if (existsSync(previous) && owned(previous)) {
        const backup = join(backupDir, `${new Date().toISOString().replace(/[:.]/g, '-')}-${randomUUID()}.app`)
        renameSync(previous, backup); previousApps.push({ previous, backup })
        console.log('Previous helper retained as backup.')
      }
      renameSync(staging, target); replaced = true
      renameSync(temporaryManifest, manifest)
    } catch (error) {
      if (replaced) rmSync(target, { recursive: true })
      for (const { previous, backup } of previousApps.reverse()) renameSync(backup, previous)
      throw error
    } finally { if (existsSync(temporaryManifest)) rmSync(temporaryManifest) }
    if (!dry && !deferStart) {
      execFileSync('/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister', ['-f', target])
      execFileSync('/usr/bin/open', ['-g', '-j', '-a', target, '--args', '--state-dir', dir])
    }
    console.log('Installed DSH Notify.app. It follows DSH Desktop instead of login startup; restart Desktop once to load the plugin lifecycle.')
  } finally { if (existsSync(staging)) rmSync(staging, { recursive: true }) }
}
}
// Different DSH profiles can install concurrently into the same Applications directory.
mkdirSync(dirname(target), { recursive: true })
const lock = join(dirname(target), '.DSH Notify.install.lock')
let handle
try { handle = openSync(lock, 'wx', 0o600) }
catch (error) {
  if (error.code !== 'EEXIST') throw error
  throw new Error('Another native installation may be active. Retry after it finishes. If it crashed, confirm the PID in the installer lock has exited before removing the lock: ' + lock)
}
const release = () => { if (handle !== undefined) { closeSync(handle); handle = undefined; rmSync(lock, { force: true }) } }
process.once('exit', release)
try { writeFileSync(handle, JSON.stringify({ pid: process.pid }) + '\n'); install() }
finally { release() }

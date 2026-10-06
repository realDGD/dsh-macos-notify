import { existsSync, mkdirSync, readFileSync, writeFileSync, renameSync, rmSync, cpSync } from 'node:fs'
import { homedir } from 'node:os'
import { join, resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { execFileSync } from 'node:child_process'
import { randomUUID } from 'node:crypto'
const args = process.argv.slice(2)
const option = name => { const i = args.indexOf(name); if (i < 0) return null; if (!args[i + 1] || args[i + 1].startsWith('--')) throw new Error(`Missing ${name} value`); return args[i + 1] }
const home = resolve(option('--home') || homedir()), dry = args.includes('--no-start')
const dir = resolve(option('--dsh-home') || (option('--home') ? join(home, '.dsh') : process.env.DSH_HOME || join(home, '.dsh')), 'dsh-jump')
const target = join(home, 'Applications/DSH Notify.app'), legacy = join(home, 'Applications/DSH Jump.app')
const label = 'com.dgd.dsh-jump-notifier'
const agent = join(home, 'Library/LaunchAgents', label + '.plist'), manifest = join(dir, 'install.json')
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const owned = app => { try { return readFileSync(join(app, 'Contents/Info.plist'), 'utf8').includes('<string>' + label + '</string>') } catch { return false } }
const xml = s => s.replace(/[<>&"']/g, c => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&apos;' }[c]))
const agentOwned = () => { try { return readFileSync(agent, 'utf8').includes('<!-- dsh-macos-notify managed -->') } catch { return false } }
const stop = () => {
  try {
    const lease = JSON.parse(readFileSync(join(dir, 'open-panels.json'), 'utf8'))
    if (Date.now() - lease.updatedAt < 5000 && lease.ids?.length) throw new Error('Close native question/approval panels before upgrading so drafts are preserved.')
  } catch (error) { if (error.message.startsWith('Close native')) throw error }
  if (dry) return
  try { execFileSync('launchctl', ['bootout', `gui/${process.getuid()}/${label}`], { stdio: 'pipe' }) } catch {}
  const lines = execFileSync('ps', ['-axo', 'pid=,command='], { encoding: 'utf8' }).split('\n')
  for (const line of lines) {
    const match = line.trim().match(/^(\d+)\s+(.+)$/)
    if (!match) continue
    const command = match[2]
    const matches = [join(target, 'Contents/MacOS/DSHNotify'), join(legacy, 'Contents/MacOS/DSHJumpNotify')]
      .some(path => command === path || command.startsWith(path + ' '))
    if (matches) {
      const pid = Number(match[1])
      try { process.kill(pid, 'SIGTERM') } catch (error) { if (error.code !== 'ESRCH') throw error; continue }
      let exited = false
      for (let n = 0; n < 100; n++) {
        try { process.kill(pid, 0) } catch (error) { if (error.code === 'ESRCH') { exited = true; break } throw error }
        Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 50)
      }
      if (!exited) throw new Error('Previous helper has not exited; keeping the existing application.')
    }
  }
}
if (existsSync(agent) && !agentOwned()) throw new Error('Existing startup item is not owned by this installer; preserve it and resolve the conflict first.')
if (existsSync(target) && !owned(target)) throw new Error('Existing destination is not this helper; refusing to overwrite it.')
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
  mkdirSync(dirname(agent), { recursive: true })
  const staging = join(dirname(target), `.DSH Notify.stage-${randomUUID()}.app`)
  const supplied = option('--app')
  try {
    if (supplied) {
      if (!owned(resolve(supplied))) throw new Error('Source application bundle identity mismatch')
      cpSync(resolve(supplied), staging, { recursive: true })
    } else execFileSync('bash', [join(root, 'macos/build.sh'), staging], { stdio: 'inherit' })
    if (!dry) execFileSync('codesign', ['--verify', '--deep', '--strict', staging], { stdio: 'inherit' })
    stop()
    const backupDir = join(dir, 'backups'); mkdirSync(backupDir, { recursive: true, mode: 0o700 })
    for (const previous of [target, legacy]) if (existsSync(previous) && owned(previous)) {
      const backup = join(backupDir, `${new Date().toISOString().replace(/[:.]/g, '-')}-${randomUUID()}.app`)
      renameSync(previous, backup)
      console.log('Previous helper retained as backup.')
    }
    renameSync(staging, target)
    const plist = `<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<!-- dsh-macos-notify managed -->\n<plist version="1.0"><dict><key>Label</key><string>${label}</string><key>ProgramArguments</key><array><string>${xml(join(target, 'Contents/MacOS/DSHNotify'))}</string></array><key>EnvironmentVariables</key><dict><key>DSH_HOME</key><string>${xml(dirname(dir))}</string></dict><key>RunAtLoad</key><true/><key>KeepAlive</key><true/><key>ThrottleInterval</key><integer>10</integer></dict></plist>\n`
    writeFileSync(agent, plist, { mode: 0o600 })
    writeFileSync(manifest, JSON.stringify({ version: 1, app: target, label }) + '\n', { mode: 0o600 })
    if (!dry) {
      execFileSync('/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister', ['-f', target])
      execFileSync('launchctl', ['bootstrap', `gui/${process.getuid()}`, agent])
      execFileSync('launchctl', ['kickstart', `gui/${process.getuid()}/${label}`])
    }
    console.log('Installed DSH Notify.app and login startup. Add dsh-macos-notify in DSH Desktop Plugins, then restart Desktop once.')
  } finally { if (existsSync(staging)) rmSync(staging, { recursive: true }) }
}

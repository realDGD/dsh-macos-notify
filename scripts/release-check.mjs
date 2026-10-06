import { readFileSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import assert from 'node:assert/strict'
const pkg = JSON.parse(readFileSync(new URL('../package.json', import.meta.url)))
const packed = JSON.parse(execFileSync('npm', ['pack', '--dry-run', '--json'], { encoding: 'utf8' }))[0]
const files = new Set(packed.files.map(f => f.path))
for (const file of ['lib/index.js','lib/interactions.js','lib/notifications.js','lib/settings.js','lib/client.js','macos/main.swift','macos/Interactions.swift','macos/Info.plist','macos/build.sh','macos/install.sh','macos/uninstall.sh','scripts/install.mjs','LICENSE','README.md','cordis.patch.yml']) assert(files.has(file), `Missing package file: ${file}`)
assert.equal(pkg.name, 'dsh-macos-notify')
const plist = readFileSync(new URL('../macos/Info.plist', import.meta.url), 'utf8')
assert(plist.includes(`<string>${pkg.version}</string>`), 'Native/plugin versions disagree')
assert(plist.includes('<string>DSH Notify</string>'))
const paths = execFileSync('git', ['ls-files','--cached','--others','--exclude-standard'], { encoding: 'utf8' }).trim().split('\n').filter(Boolean)
const forbidden = [/\/Users\/[A-Za-z0-9_.-]+\//, /session-[0-9a-f]{8}-[0-9a-f]{4}-/i, /(?:ghp_|gho_|github_pat_)[A-Za-z0-9_]{20,}/, /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/]
for (const path of paths) {
  assert(!/(?:\.app\/|\.local\/|desktop-jump-status|native-actions-ledger|legacy-applet)/.test(path), `Private/legacy artifact staged: ${path}`)
  const content = readFileSync(path, 'utf8')
  for (const pattern of forbidden) assert(!pattern.test(content), `Private material in ${path}`)
}
for (const path of files) assert(!/(?:\.app\/|\.local\/|desktop-jump-status|native-actions-ledger|legacy-applet)/.test(path), `Private package artifact: ${path}`)
console.log(`Release checks passed: ${paths.length} source files, ${files.size} package files, no forbidden private artifacts.`)

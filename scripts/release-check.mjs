import { readFileSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import assert from 'node:assert/strict'
const pkg = JSON.parse(readFileSync(new URL('../package.json', import.meta.url)))
const packed = JSON.parse(execFileSync('npm', ['pack', '--dry-run', '--json'], { encoding: 'utf8' }))[0]
const files = new Set(packed.files.map(f => f.path))
for (const file of ['lib/index.js','lib/foreground.js','lib/diagnostics.js','lib/interactions.js','lib/notifications.js','lib/settings.js','lib/client.js','macos/main.swift','macos/NotificationPayload.swift','macos/Diagnostics.swift','macos/Interactions.swift','macos/MarkdownContext.swift','macos/assets/context.html','macos/assets/context.css','macos/assets/context.js','macos/assets/renderer.js','macos/assets/vendor/manifest.json','macos/assets/vendor/markdown-it/LICENSE','macos/assets/vendor/katex/LICENSE','THIRD_PARTY.md','CHANGELOG.md','macos/Info.plist','macos/build.sh','macos/install.sh','macos/uninstall.sh','scripts/install.mjs','LICENSE','README.md','cordis.patch.yml']) assert(files.has(file), `Missing package file: ${file}`)
for (const file of ['lib/menu-model.js','lib/menu-source.js','lib/menu-host.js','lib/menu-control.js','macos/SessionMenuModel.swift','macos/SessionMenuControl.swift','macos/MenuSessionList.swift','macos/SessionMenuView.swift','macos/SessionMenu.swift','docs/compatibility.md']) assert(files.has(file), `Missing menu package file: ${file}`)
assert.equal(pkg.name, 'dsh-macos-notify')
assert(files.has('npm-shrinkwrap.json'), 'Source archive needs its install lockfile')
assert.deepEqual(JSON.parse(readFileSync(new URL('../npm-shrinkwrap.json', import.meta.url))), JSON.parse(readFileSync(new URL('../package-lock.json', import.meta.url))), 'Install/archive lockfiles disagree')
const plist = readFileSync(new URL('../macos/Info.plist', import.meta.url), 'utf8')
assert(plist.includes(`<string>${pkg.version}</string>`), 'Native/plugin versions disagree')
assert(plist.includes('<string>DSH Notify</string>'))
const paths = execFileSync('git', ['ls-files','--cached','--others','--exclude-standard'], { encoding: 'utf8' }).trim().split('\n').filter(Boolean)
const forbidden = [/\/Users\/[A-Za-z0-9_.-]+\//, /session-[0-9a-f]{8}-[0-9a-f]{4}-/i, /(?:ghp_|gho_|github_pat_)[A-Za-z0-9_]{20,}/, /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/]
for (const path of paths) {
  assert(!/(?:\.app(?:\/|$)|\.icns$|\.local\/|desktop-jump-status|native-actions-ledger|legacy-applet|(?:^|\/)(?:session-menu\.json|menu-commands|menu-results)(?:\/|$))/.test(path), `Private/legacy artifact staged: ${path}`)
  const content = readFileSync(path, 'utf8')
  for (const pattern of forbidden) assert(!pattern.test(content), `Private material in ${path}`)
}
for (const path of files) assert(!/(?:\.app(?:\/|$)|\.icns$|\.local\/|desktop-jump-status|native-actions-ledger|legacy-applet|(?:^|\/)(?:session-menu\.json|menu-commands|menu-results)(?:\/|$))/.test(path), `Private package artifact: ${path}`)
console.log(`Release checks passed: ${paths.length} source files, ${files.size} package files, no forbidden private artifacts.`)

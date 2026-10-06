import { mkdirSync, chmodSync, readFileSync, writeFileSync, renameSync, statSync } from 'node:fs'
import { join } from 'node:path'
export const defaults = Object.freeze({ completed: true, error: true, approval: true, questions: true,
  sound: true, includeSubagents: false, waitForChildren: true, quietCurrentSession: false })
export function createSettings(stateDir) {
  mkdirSync(stateDir, { recursive: true, mode: 0o700 }); chmodSync(stateDir, 0o700)
  const file = join(stateDir, 'settings.json')
  const validate = patch => {
    if (!patch || typeof patch !== 'object' || Array.isArray(patch)) throw new Error('Expected preferences object')
    for (const [key, value] of Object.entries(patch)) if (!(Object.hasOwn(defaults, key)) || typeof value !== 'boolean') throw new Error('Invalid preference')
    return patch
  }
  const get = () => {
    try { if (statSync(file).size > 4096) return { ...defaults }; return { ...defaults, ...validate(JSON.parse(readFileSync(file, 'utf8'))) } }
    catch { return { ...defaults } }
  }
  return { get, save(patch) {
    validate(patch)
    const value = { ...get(), ...patch }, temp = `${file}.tmp-${process.pid}`
    writeFileSync(temp, JSON.stringify(value) + '\n', { mode: 0o600 }); renameSync(temp, file)
    return value
  } }
}

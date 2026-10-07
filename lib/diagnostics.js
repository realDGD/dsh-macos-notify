import { readFileSync, statSync } from 'node:fs'
import { join } from 'node:path'
export const testIdValid = id => typeof id === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)
export function readDiagnostic(path) {
  try { if (statSync(path).size > 4096) return null; return JSON.parse(readFileSync(path, 'utf8')) } catch { return null }
}
export function readTestStatus(stateDir, now = Date.now()) {
  const test = readDiagnostic(join(stateDir, 'last-test.json'))
  if (!testIdValid(test?.id) || typeof test.sessionId !== 'string' || !Number.isFinite(test.createdAt) || test.createdAt > now + 10000 || now - test.createdAt > 86400000) return { state: 'none' }
  const result = state => ({ state, startedAt: test.createdAt })
  if (test.queueFailed === true) return result('queue-failed')
  const timeValid = value => Number.isFinite(value) && value >= test.createdAt && value <= now + 10000
  const requestValid = value => value?.testId === test.id && value.sessionId === test.sessionId && typeof value.requestId === 'string' && /^[A-Za-z0-9-]{1,128}$/.test(value.requestId) && timeValid(value.createdAt)
  const confirmed = value => requestValid(value) && timeValid(value.confirmedAt) && value.confirmedAt >= value.createdAt
  const saved = readDiagnostic(join(stateDir, 'test-result.json'))
  if (confirmed(saved)) return { ...result('confirmed'), confirmedAt: saved.confirmedAt }
  const request = readDiagnostic(join(stateDir, 'open-session.json'))
  if (requestValid(request)) {
    const ack = readDiagnostic(join(stateDir, 'jump-result.json'))
    if (confirmed(ack) && ack.requestId === request.requestId && ack.createdAt === request.createdAt) return { ...result('confirmed'), confirmedAt: ack.confirmedAt }
    return result(now - request.createdAt > 15000 ? 'timed-out' : 'opening')
  }
  const delivery = readDiagnostic(join(stateDir, 'test-delivery', test.id + '.json'))
  if (delivery?.id === test.id && timeValid(delivery.updatedAt)) {
    if (delivery.state === 'posted') return result('waiting-for-click')
    if (delivery.state === 'failed') return result('system-rejected')
  }
  return result(now - test.createdAt > 120000 ? 'expired' : 'waiting-for-helper')
}

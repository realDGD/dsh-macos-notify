import { mkdirSync, chmodSync, writeFileSync, renameSync } from 'node:fs'
import { join, basename } from 'node:path'
import { randomUUID } from 'node:crypto'

// Pure event ownership: only explicit terminal events, never idle snapshots.
export function createNotifications({ stateDir, now = Date.now, preferences = () => ({}), foreground = () => null }) {
  const queue = join(stateDir, 'notifications')
  mkdirSync(queue, { recursive: true, mode: 0o700 }); chmodSync(queue, 0o700)
  const sessions = new Map(), running = new Set(), held = new Map(), seen = new Set(), latestTurns = new Map()
  const counts = { posted: 0, suppressed: 0, failed: 0 }
  const prefs = () => preferences() ?? {}
  const key = (session, turn) => `${session.id}:${turn ?? 'unknown'}`
  const remember = value => {
    if (seen.has(value)) return false
    seen.add(value)
    if (seen.size > 1024) seen.delete(seen.values().next().value)
    return true
  }
  const childOf = (id, ancestor) => {
    const visited = new Set()
    while (id && !visited.has(id)) {
      visited.add(id)
      id = sessions.get(id)?.header?.parentSession
      if (id === ancestor) return true
    }
    return false
  }
  const hasChildren = id => [...running].some(child => child !== id && childOf(child, id))
  const write = (session, kind, body) => {
    const settings = prefs()
    const visible = foreground()
    if (settings[kind] === false || (kind !== 'test' && settings.quietCurrentSession === true
      && visible?.sessionId === session.id && visible.visible === true && now() - visible.updatedAt < 5000)) {
      counts.suppressed++; return
    }
    const id = randomUUID()
    const title = kind === 'completed' ? '任务完成' : kind === 'error' ? '任务出错' : 'DSH Notify · 安全测试'
    const record = { version: 1, id, kind, sessionId: session.id, createdAt: now(),
      title, subtitle: session.title || session.header?.title || basename(session.header?.cwd || '') || 'DSH',
      body: body || (kind === 'completed' ? '任务已完成，点击回到对应会话。' : kind === 'error' ? '任务遇到错误，点击回到 DSH 查看详情。' : '这是通知测试，不会执行命令或发送模型消息。'),
      url: `http://127.0.0.1:3080/?session=${encodeURIComponent(session.id)}` }
    const target = join(queue, `${id}.json`), temp = `${target}.tmp`
    try {
      if (kind === 'test') {
        const metadata = join(stateDir, 'last-test.json'), temporary = metadata + '.tmp'
        writeFileSync(temporary, JSON.stringify({ id, sessionId: session.id, createdAt: record.createdAt }) + '\n', { mode: 0o600 }); renameSync(temporary, metadata)
      }
      writeFileSync(temp, JSON.stringify(record) + '\n', { mode: 0o600 }); renameSync(temp, target); counts.posted++; return record
    }
    catch {
      counts.failed++
      if (kind === 'test') try {
        const metadata = join(stateDir, 'last-test.json'), temporary = metadata + '.tmp'
        writeFileSync(temporary, JSON.stringify({ id, sessionId: session.id, createdAt: record.createdAt, queueFailed: true }) + '\n', { mode: 0o600 }); renameSync(temporary, metadata)
      } catch {}
      return null
    }
  }
  const flush = () => {
    for (const [id, record] of held) if (!hasChildren(id)) { held.delete(id); write(record.session, 'completed') }
  }
  return {
    observe(session, event) {
      if (!session?.id || !event?.type) return
      sessions.set(session.id, session)
      // Keep idle session metadata bounded while preserving active ancestry.
      if (sessions.size > 1024) for (const id of sessions.keys()) {
        if (sessions.size <= 1024) break
        if (!running.has(id) && !held.has(id) && !hasChildren(id)) { sessions.delete(id); latestTurns.delete(id) }
      }
      const latest = latestTurns.get(session.id)
      if (Number.isFinite(latest) && Number.isFinite(event.data?.turn) && event.data.turn < latest) return
      if (event.type === 'turn/start') {
        if (seen.has(key(session, event.data?.turn))) return
        held.delete(session.id); running.add(session.id); latestTurns.set(session.id, event.data?.turn); return
      }
      if (event.type !== 'turn/end') return
      if (latestTurns.get(session.id) !== undefined && event.data?.turn !== undefined && event.data.turn !== latestTurns.get(session.id)) return
      running.delete(session.id)
      const reason = event.data?.reason?.kind
      const isChild = session.header?.origin === 'subagent' || Boolean(session.header?.parentSession)
      const terminal = key(session, event.data?.turn)
      if (remember(terminal) && (!isChild || prefs().includeSubagents === true)) {
        if (reason === 'completed') {
          if (prefs().waitForChildren !== false && hasChildren(session.id)) held.set(session.id, { session, terminal })
          else write(session, 'completed')
        } else if (['error', 'max-tokens'].includes(reason)) { held.delete(session.id); write(session, 'error') }
      }
      flush()
    },
    error(payload) {
      const session = payload?.agent?.session
      if (!session?.id || !remember(key(session, payload.turn))) return
      if (Number.isFinite(latestTurns.get(session.id)) && Number.isFinite(payload.turn) && payload.turn < latestTurns.get(session.id)) return
      held.delete(session.id)
      if (!(session.header?.origin === 'subagent' || session.header?.parentSession) || prefs().includeSubagents === true) write(session, 'error')
    },
    test(sessionId) {
      if (typeof sessionId !== 'string' || !/^[A-Za-z0-9][A-Za-z0-9._-]{0,199}$/.test(sessionId)) throw new Error('Invalid session')
      if (!write({ id: sessionId, title: 'DSH Notify' }, 'test')) throw new Error('Test notification queue unavailable')
      return { queued: true }
    },
    status: () => ({ ...counts, waitingForChildren: held.size }),
  }
}

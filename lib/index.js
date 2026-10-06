// Desktop notification clicks enter through a local file written by DSH Jump.
// The existing Connection service owns authentication and the Host/Origin fence.
import { readFileSync, statSync, mkdirSync, writeFileSync, renameSync } from 'node:fs'
import { homedir } from 'node:os'
import { join } from 'node:path'
import { installInteractions } from './interactions.js'
import { createSettings } from './settings.js'
import { createNotifications } from './notifications.js'
const version = JSON.parse(readFileSync(new URL('../package.json', import.meta.url))).version

export const name = 'dsh-macos-notify'

export const inject = ['connection']

export function apply(ctx, config = {}) {
  const dir = config.stateDir ?? join(process.env.DSH_HOME || join(homedir(), '.dsh'), 'dsh-jump')
  const settings = createSettings(dir)
  let foreground = null
  const notices = createNotifications({ stateDir: dir, preferences: settings.get, foreground: () => foreground })
  if (typeof ctx.on === 'function' && typeof ctx.effect === 'function') {
    installInteractions(ctx, { stateDir: dir, preferences: settings.get, foreground: () => foreground })
    ctx.on('session/event', (session, event) => {
      try {
        const title = ctx.get('sessionTitle')?.get(session)?.title
        notices.observe(title ? { id: session.id, header: session.header, title } : session, event)
      } catch { /* Reminder failures never break the Host. */ }
    })
    ctx.on('agent/error', payload => { try { notices.error(payload) } catch {} })
  }
  const pendingPath = join(dir, 'open-session.json')
  const resultPath = join(dir, 'jump-result.json')
  const read = (path) => {
    try {
      if (statSync(path).size > 4096) return null
      return JSON.parse(readFileSync(path, 'utf8'))
    } catch { return null }
  }
  const pending = () => {
    const request = read(pendingPath)
    if (!request || typeof request.requestId !== 'string' || request.requestId.length > 128
      || request.requestId === '' || typeof request.sessionId !== 'string'
      || !/^[A-Za-z0-9][A-Za-z0-9._-]{0,199}$/.test(request.sessionId)
      || !Number.isFinite(request.createdAt) || Date.now() - request.createdAt > 120_000
      || request.createdAt - Date.now() > 10_000) return null
    const result = read(resultPath)
    return result?.requestId === request.requestId && result?.sessionId === request.sessionId ? null : request
  }
  const handle = (endpoint, payload) => {
    const request = pending()
    if (endpoint === 'settings') return settings.get()
    if (endpoint === 'save') return settings.save(payload)
    if (endpoint === 'foreground') {
      if (typeof payload?.visible !== 'boolean' || (payload.sessionId !== null && (typeof payload.sessionId !== 'string' || !/^[A-Za-z0-9][A-Za-z0-9._-]{0,199}$/.test(payload.sessionId)))) throw new Error('Invalid foreground')
      foreground = { sessionId: payload.sessionId, visible: payload.visible, updatedAt: Date.now() }
      return { ok: true }
    }
    if (endpoint === 'test') return notices.test(payload?.sessionId)
    if (endpoint === 'status') {
      const helper = read(join(dir, 'helper-status.json'))
      const running = helper?.updatedAt <= Date.now() + 10000 && Date.now() - helper.updatedAt < 5000
      return { version, host: { connected: true }, helper: { running: Boolean(running),
        version: running && typeof helper.version === 'string' ? helper.version.slice(0, 40) : null,
        permission: running && ['authorized', 'denied', 'notDetermined', 'provisional'].includes(helper.permission) ? helper.permission : 'unknown' },
        notifications: notices.status() }
    }
    if (endpoint === 'pending') return request
    if (endpoint !== 'ack') throw new Error('Unknown notification navigation endpoint')
    if (!request || payload?.requestId !== request.requestId || payload?.sessionId !== request.sessionId) return { ok: false }
    mkdirSync(dir, { recursive: true, mode: 0o700 })
    const temp = `${resultPath}.tmp-${process.pid}`
    writeFileSync(temp, JSON.stringify({ ...request, confirmedAt: Date.now() }) + '\n', { mode: 0o600 })
    renameSync(temp, resultPath)
    // Retaining the input file avoids deleting a newer click racing this ack.
    return { ok: true }
  }
  // Exact Fetch routes use Connection's existing authenticated /api carrier.
  // Generic rpc.handle() in Desktop 0.2.0-rc.2 resolves webServer against the
  // Connection provider's scope, where it is unavailable, and fails to mount.
  const connection = ctx.get('connection')
  for (const method of [...['pending', 'ack', 'settings', 'save', 'foreground', 'test', 'status'].map(endpoint => `dsh-macos-notify/${endpoint}`), ...['pending', 'ack'].map(endpoint => `dsh-notify-web/${endpoint}`)]) {
    const endpoint = method.split('/')[1]
    connection.fetch.register({
      path: `/api/${method}`, methods: ['POST'], requestBody: 'buffered',
      async fetch(request) {
        if (request.headers.get('content-type')?.split(';', 1)[0]?.trim() !== 'application/json') {
          return new Response('Expected JSON', { status: 415 })
        }
        const text = await request.text()
        if (text.length > 4096) return new Response('Request too large', { status: 413 })
        let message
        try { message = JSON.parse(text) } catch { return new Response('Invalid JSON', { status: 400 }) }
        if (message?.type !== 'client-request' || typeof message.rpcId !== 'string'
          || message.rpcId.length > 128 || message.method !== method) {
          return new Response('Invalid RPC request', { status: 400 })
        }
        try {
          return Response.json({ type: 'server-response', rpcId: message.rpcId,
            result: { ok: true, value: handle(endpoint, message.payload) } })
        } catch { return new Response('Invalid request payload', { status: 400 }) }
      },
    })
  }
}

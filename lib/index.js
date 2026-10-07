// Desktop notification clicks enter through a local file written by DSH Notify.
// The existing Connection service owns authentication and the Host/Origin fence.
import { readFileSync, statSync, mkdirSync, writeFileSync, renameSync } from 'node:fs'
import { homedir } from 'node:os'
import { join } from 'node:path'
import { installInteractions } from './interactions.js'
import { createSettings } from './settings.js'
import { createNotifications } from './notifications.js'
import { createForeground } from './foreground.js'
import { readDiagnostic, readTestStatus, testIdValid } from './diagnostics.js'
import { installSessionMenu } from './menu-host.js'
const version = JSON.parse(readFileSync(new URL('../package.json', import.meta.url))).version

export const name = 'dsh-macos-notify'

export const inject = ['connection']

export function apply(ctx, config = {}) {
  const dir = config.stateDir ?? join(process.env.DSH_HOME || join(homedir(), '.dsh'), 'dsh-jump')
  const settings = createSettings(dir)
  const foreground = createForeground()
  const notices = createNotifications({ stateDir: dir, preferences: settings.get, foreground: foreground.current })
  if (typeof ctx.on === 'function' && typeof ctx.effect === 'function') {
    const interactions = installInteractions(ctx, { stateDir: dir, preferences: settings.get, foreground: foreground.current })
    installSessionMenu(ctx, { stateDir: dir, settings, pendingStates: interactions.pendingStates })
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
    return result?.requestId === request.requestId && result?.sessionId === request.sessionId && result?.createdAt === request.createdAt ? null : request
  }
  const handle = (endpoint, payload) => {
    const request = pending()
    if (endpoint === 'settings') return settings.get()
    if (endpoint === 'save') return settings.save(payload)
    if (endpoint === 'foreground') return foreground.update(payload)
    if (endpoint === 'test') return notices.test(payload?.sessionId)
    if (endpoint === 'status') {
      const helper = read(join(dir, 'helper-status.json'))
      const running = helper?.updatedAt <= Date.now() + 10000 && Date.now() - helper.updatedAt < 5000
      const helperVersion = running && typeof helper.version === 'string' && helper.version.length <= 40 && /^\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?$/.test(helper.version) ? helper.version : null
      return { version, host: { connected: true }, helper: { running: Boolean(running),
        version: helperVersion,
        permission: running && ['authorized', 'denied', 'notDetermined', 'provisional'].includes(helper.permission) ? helper.permission : 'unknown' },
        notifications: notices.status(), test: readTestStatus(dir),
        versionMismatch: Boolean(helperVersion && helperVersion !== version) }
    }
    if (endpoint === 'pending') return request
    if (endpoint !== 'ack') throw new Error('Unknown notification navigation endpoint')
    if (!request || payload?.requestId !== request.requestId || payload?.sessionId !== request.sessionId) return { ok: false }
    mkdirSync(dir, { recursive: true, mode: 0o700 })
    const temp = `${resultPath}.tmp-${process.pid}`
    writeFileSync(temp, JSON.stringify({ ...request, confirmedAt: Date.now() }) + '\n', { mode: 0o600 })
    renameSync(temp, resultPath)
    const test = readDiagnostic(join(dir, 'last-test.json'))
    if (testIdValid(request.testId) && test?.id === request.testId && test.sessionId === request.sessionId && request.createdAt >= test.createdAt) {
      // Diagnostic persistence cannot block the already accepted navigation.
      try {
        const path = join(dir, 'test-result.json'), temporary = path + '.tmp'
        writeFileSync(temporary, JSON.stringify({ ...request, confirmedAt: Date.now() }) + '\n', { mode: 0o600 }); renameSync(temporary, path)
      } catch {}
    }
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

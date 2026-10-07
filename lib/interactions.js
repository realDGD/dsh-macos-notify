// The Host remains the only decision owner. The helper is a same-user peer,
// exchanging atomic files in a private directory, never an unauthenticated API.
import { randomUUID } from 'node:crypto'
import { mkdirSync, chmodSync, readFileSync, writeFileSync, renameSync, readdirSync, unlinkSync, statSync } from 'node:fs'
import { join, basename } from 'node:path'

function atomic(path, value) {
  const temp = `${path}.tmp-${process.pid}`
  writeFileSync(temp, JSON.stringify(value) + '\n', { mode: 0o600 })
  chmodSync(temp, 0o600)
  renameSync(temp, path)
}

function validBatch(questions, answer) {
  if (!Array.isArray(answer?.answers) || answer.answers.length !== questions.length) return false
  const ids = new Set()
  return answer.answers.every(item => {
    const question = questions.find(question => question.id === item?.id)
    if (!question || ids.has(item.id) || !Array.isArray(item.selected)
      || item.selected.some(label => typeof label !== 'string' || !(question.options ?? []).some(option => option.label === label))
      || new Set(item.selected).size !== item.selected.length
      || (!question.multiSelect && item.selected.length > 1)
      || (item.custom !== undefined && (typeof item.custom !== 'string' || item.custom.length > 20000))
      || (!item.selected.length && !item.custom?.trim())) return false
    ids.add(item.id)
    return true
  })
}

// Read the official projected history: never raw log entries, reasoning blocks,
// tool results, or a different call's command. A request can outlive later chat.
function presentation(ctx, session, callId) {
  let title, messages = []
  try { title = ctx.get('sessionTitle')?.get(session)?.title } catch {}
  title ||= session.title || session.header?.title || basename(session.header?.cwd || '') || '未命名会话'
  try { messages = session.deriveMessages?.() ?? [] } catch {}
  let end = messages.length - 1, call
  if (callId) {
    end = messages.findLastIndex(message => message.role === 'assistant'
      && message.content?.some(block => block.type === 'tool-call' && block.id === callId))
    call = messages[end]?.content.find(block => block.type === 'tool-call' && block.id === callId)
  }
  const textOf = message => (message.content ?? []).filter(block => block.type === 'text' && typeof block.text === 'string').map(block => block.text).join('\n')
  const context = []
  if (end >= 0) {
    const user = messages.slice(0, end + 1).findLastIndex(message => message.role === 'user')
    const assistant = messages.slice(Math.max(0, user + 1), end + 1).findLast(message => message.role === 'assistant' && textOf(message))
    for (const message of [messages[user], assistant]) {
      if (!message) continue
      const text = textOf(message)
      if (text) {
        const characters = Array.from(text)
        context.push({ role: message.role, text: characters.slice(0, 20000).join(''), ...(characters.length > 20000 ? { truncated: true } : {}) })
      }
    }
  }
  return { sessionTitle: title, subtitle: title, cwd: session.header?.cwd, context, call }
}

function approvalDetails(request, call) {
  const details = { toolName: request.toolName || '操作', reason: request.reason, callId: request.callId }
  if (call && call.name === request.toolName && typeof call.arguments === 'string') {
    details.arguments = call.arguments
    try {
      const args = JSON.parse(call.arguments)
      if (typeof args.command === 'string') details.command = args.command
    } catch { /* Keep the exact original argument string even if not JSON. */ }
  }
  return details
}

export function installInteractions(ctx, { stateDir, preferences = () => ({}), foreground = () => null }) {
  const active = new Map()
  const suspended = new Map()
  const clones = new WeakSet()
  const commands = join(stateDir, 'commands')
  const results = join(stateDir, 'results')
  for (const dir of [stateDir, commands, results]) { mkdirSync(dir, { recursive: true, mode: 0o700 }); chmodSync(dir, 0o700) }
  let disposed = false
  const snapshot = () => {
    try {
      atomic(join(stateDir, 'interactions.json'), {
        version: 1, updatedAt: Date.now(), pid: process.pid, preferences: preferences(),
        quietSessionId: preferences().quietCurrentSession && foreground()?.visible && Date.now() - foreground().updatedAt < 5000 ? foreground().sessionId : null,
        requests: [...active.values()].map(entry => ({ ...entry.notice, phase: entry.mode ?? 'foreground' })),
      })
    } catch { /* Transport failure must never prevent an official answer. */ }
  }
  const remove = entry => { active.delete(entry.notice.id); snapshot() }
  const userQuestions = () => { try { return ctx.get('userQuestions') } catch { return null } }
  const queued = entry => {
    const matches = message => message?.source?.kind === 'user-question-reply' && message.source.callId === entry.callId
    return [entry.agent?.inbox?.nextTurn, entry.agent?.inbox?.nextStep].some(list => list?.some(matches))
  }
  const continued = entry => {
    try { return userQuestions()?.continued(entry.agent)?.some(question => question.callId === entry.callId) } catch { return false }
  }

  for (const [event, kind] of [['approval/request', 'approval'], ['user-questions/request', 'questions']]) {
    ctx.on(event, function(request, next) {
      if (clones.has(request) || !request.agent?.session?.id || disposed) return next()
      if (request.signal?.aborted) return next()
      const child = new AbortController()
      const clone = { ...request, signal: request.signal ? AbortSignal.any([request.signal, child.signal]) : child.signal }
      clones.add(clone)
      const session = request.agent.session
      const { call, ...display } = presentation(ctx, session, request.callId ?? request.wait?.callId)
      const entry = {
        agent: request.agent, signal: request.signal, callId: request.wait?.callId,
        notice: {
          id: randomUUID(), kind, sessionId: session.id,
          title: kind === 'approval' ? '请求批准' : `需要回答 ${request.questions.length} 个问题`,
          ...display,
          body: kind === 'approval' ? `${request.toolName || '操作'}${request.reason ? '\n' + request.reason : ''}` : request.questions[0]?.question || '',
          ...(kind === 'questions' ? { questions: request.questions } : {}),
          ...(kind === 'approval' ? { approval: approvalDetails(request, call) } : {}),
          createdAt: Date.now(),
        },
      }
      return new Promise((resolve, reject) => {
        let settled = false
        entry.finish = (value, error, source) => {
          if (settled) return false
          settled = true
          request.signal?.removeEventListener('abort', abort)
          entry.uiWait?.abort()
          // Abort only the cloned delivery: original tool signal remains live.
          child.abort(new Error('Request answered or withdrawn'))
          if (kind === 'questions' && entry.callId && !disposed && error?.code === 'ASK_TIMED_OUT') {
            // Continue can arrive as a Client rejection before askTimed closes
            // its signal. Keep the same visible form until projection catches up.
            entry.mode = 'transitioning'
            entry.until = Date.now() + 10000
            suspended.set(entry.notice.id, entry)
            snapshot()
          } else remove(entry)
          if (error) reject(error); else resolve(value)
          return true
        }
        const abort = () => entry.finish(undefined, request.signal.reason || new Error('Request aborted'), 'abort')
        active.set(entry.notice.id, entry)
        snapshot()
        request.signal?.addEventListener('abort', abort, { once: true })
        if (request.signal?.aborted) { abort(); return }
        // Cordis next() cannot replace arguments. Re-dispatch the cloned
        // request in the same carrier scope, skipping this middleware once.
        const fallback = () => {
          if (kind === 'approval') return 'unavailable'
          throw Object.assign(new Error('No official question answerer'), { code: 'NO_PROVIDER' })
        }
        Promise.resolve().then(() => ctx.waterfall(this, event, clone, fallback)).then(
          value => {
            // A missing answerer should leave the native peer available.
            if (kind === 'approval' && value === 'unavailable') return
            entry.finish(value, undefined, 'official')
          }, error => {
            if (!settled && error?.code !== 'NO_PROVIDER') entry.finish(undefined, error, 'official')
          },
        )
      })
    }, true)
  }

  const processCommands = () => {
    for (const file of readdirSync(commands)) {
      if (!/^[A-Za-z0-9-]{1,128}\.json$/.test(file)) continue
      const path = join(commands, file)
      let command
      try {
        // Each question accepts 20,000 characters; a complete UTF-8 batch
        // can exceed 128 KiB even with only three questions.
        if (statSync(path).size > 4 * 1024 * 1024) { unlinkSync(path); continue }
        command = JSON.parse(readFileSync(path, 'utf8'))
      } catch { try { unlinkSync(path) } catch {}; continue }
      try { unlinkSync(path) } catch { continue }
      const commandId = file.slice(0, -5)
      if (command.commandId !== commandId) continue
      const entry = active.get(command.requestId)
      let status = entry?.mode === 'transitioning' ? 'waiting' : 'stale'
      if (entry && entry.mode !== 'transitioning' && (!entry.signal?.aborted || entry.mode === 'continued')) {
        if (entry.notice.kind === 'approval'
          ? !['allowed-once', 'rejected'].includes(command.answer)
          : !validBatch(entry.notice.questions, command.answer)) status = 'invalid'
        else if (entry.mode === 'continued') {
          try {
            status = userQuestions()?.answer(entry.agent, entry.callId, command.answer) === true ? 'accepted' : 'stale'
          } catch (error) { status = error?.code === 'REPLY_QUEUED' ? 'stale' : 'failed' }
          if (status === 'accepted' || status === 'stale') remove(entry)
        } else status = entry.finish(command.answer, undefined, 'native') ? 'accepted' : 'stale'
      }
      atomic(join(results, file), { commandId, requestId: command.requestId, status, completedAt: Date.now() })
    }
  }
  const timer = setInterval(() => {
    try {
      let openPanels = new Set()
      try {
        const path = join(stateDir, 'open-panels.json')
        if (statSync(path).size <= 65536) {
          const lease = JSON.parse(readFileSync(path, 'utf8'))
          if (Math.abs(Date.now() - lease.updatedAt) < 5000 && Array.isArray(lease.ids)) openPanels = new Set(lease.ids)
        }
      } catch {}
      for (const [id, entry] of suspended) {
        if (continued(entry) && !queued(entry)) {
          suspended.delete(id)
          entry.mode = 'continued'
          active.set(id, entry)
        } else if (Date.now() > entry.until || queued(entry)) { suspended.delete(id); active.delete(id) }
      }
      // A fresh plugin/Host generation may inherit persisted continued calls.
      // Rebuild reminders from official live roots, never revive old UUIDs.
      let roots = []
      try { roots = ctx.get('agents')?.roots() ?? [] } catch {}
      for (const agent of roots) {
        for (const question of userQuestions()?.continued(agent) ?? []) {
          const exists = [...active.values()].some(entry => entry.agent === agent && entry.callId === question.callId)
          const entry = { agent, callId: question.callId, mode: 'continued' }
          if (exists || queued(entry)) continue
          const { call, ...display } = presentation(ctx, agent.session, question.callId)
          entry.notice = {
            id: randomUUID(), kind: 'questions', sessionId: agent.session.id,
            title: `需要回答 ${question.questions.length} 个问题`,
            ...display,
            body: question.questions[0]?.question || '', questions: question.questions, createdAt: Date.now(),
          }
          active.set(entry.notice.id, entry)
        }
      }
      for (const entry of active.values()) {
        if (entry.mode === 'continued' && (!continued(entry) || queued(entry))) active.delete(entry.notice.id)
        if (entry.mode !== 'continued' && entry.callId && entry.notice.kind === 'questions') {
          if (!openPanels.has(entry.notice.id)) { entry.uiWait?.abort(); entry.uiWait = undefined }
          else if (!entry.uiWait && typeof userQuestions()?.attachWait === 'function') {
            const hold = entry.uiWait = new AbortController()
            // The official stream owns/relinquishes the timed-wait claim.
            // Never pause unattended questions just because a helper exists.
            ;(async () => {
              try { for await (const frame of userQuestions().attachWait(entry.agent, entry.callId, hold.signal)) { if (hold.signal.aborted) break } }
              catch {}
            })()
          }
        }
      }
      processCommands()
      snapshot()
      // Results only need to cover the helper's short polling window.
      for (const file of readdirSync(results)) {
        if (/^[A-Za-z0-9-]{1,128}\.json$/.test(file) && Date.now() - statSync(join(results, file)).mtimeMs > 600000) unlinkSync(join(results, file))
      }
    } catch (error) { ctx.logger?.warn?.('Native interaction transport: %s', error.message) }
  }, 250)
  timer.unref?.()
  ctx.effect(() => () => {
    disposed = true
    clearInterval(timer)
    suspended.clear()
    for (const entry of active.values()) {
      if (entry.mode !== 'continued') entry.finish(undefined, new Error('Notification plugin disposed'), 'dispose')
    }
    active.clear()
    snapshot()
  })
  snapshot()
  return { pendingStates() {
    const states = new Map()
    if (disposed) return states
    for (const entry of active.values()) {
      const state = states.get(entry.notice.sessionId) ?? { questions: false, approval: false }
      state[entry.notice.kind] = true
      states.set(entry.notice.sessionId, state)
    }
    return states
  } }
}

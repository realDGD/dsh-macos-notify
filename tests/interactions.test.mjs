import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { installInteractions } from '../lib/interactions.js'

const runtime = process.env.DSH_CORDIS_MODULE || '@deepseek-ai/cordis'
const check = {}
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms))
const deferred = () => { let resolve, reject; const promise = new Promise((a, b) => { resolve = a; reject = b }); return { promise, resolve, reject } }

async function fixture(t, event = 'user-questions/request', service, setup) {
  const { Context } = await import(runtime)
  const ctx = new Context()
  const dir = mkdtempSync(join(tmpdir(), 'dsh-native-actions-'))
  const official = deferred()
  if (service) ctx.provide('userQuestions', service)
  let child, accessor
  ctx.on(event, request => { child = request; return official.promise })
  await ctx.plugin({ name: 'native-test', apply(ctx) { accessor = installInteractions(ctx, { stateDir: dir }) } })
  t.after(async () => { await ctx.fiber.dispose(); rmSync(dir, { recursive: true, force: true }) })
  const signal = new AbortController()
  const request = {
    agent: { id: 'agent-1', session: { id: 'session-1', header: { title: 'Test', cwd: '/Test' } } },
    signal: signal.signal,
    ...(event === 'approval/request' ? { toolName: 'bash', reason: 'Run owned test', callId: 'tool-1' } : {
      wait: { callId: 'tool-1', timed: true },
      questions: [
        { id: 'q1', question: 'First?', options: [{ label: 'A', description: 'Choice A' }, { label: 'B' }] },
        { id: 'q2', question: 'Second?', options: [{ label: 'C' }, { label: 'D' }], multiSelect: true },
        { id: 'q3', question: 'Third?' },
      ],
    }),
  }
  setup?.(ctx, request)
  const pending = ctx.waterfall(event, request, () => { throw new Error('no answerer') })
  const state = () => JSON.parse(readFileSync(join(dir, 'interactions.json')))
  const command = async (id, answer, commandId = crypto.randomUUID()) => {
    mkdirSync(join(dir, 'commands'), { recursive: true })
    writeFileSync(join(dir, 'commands', commandId + '.json'), JSON.stringify({ commandId, requestId: id, answer }))
    for (let i = 0; i < 40; i++) {
      try { return JSON.parse(readFileSync(join(dir, 'results', commandId + '.json'))) } catch { await sleep(25) }
    }
    throw new Error('command was not answered')
  }
  return { ctx, dir, official, request, pending, signal, state, command, child: () => child, accessor }
}

test('pending_accessor_first_wins: read-only states follow original acceptance and cloned values cannot corrupt requests', check, async t => {
  const f=await fixture(t)
  const states=f.accessor.pendingStates()
  assert.equal(states.get('session-1').questions,true)
  states.get('session-1').questions=false
  assert.equal(f.accessor.pendingStates().get('session-1').questions,true)
  f.official.resolve(answer)
  await f.pending
  assert.equal(f.accessor.pendingStates().size,0)
})

const answer = { answers: [
  { id: 'q1', selected: ['A'], custom: 'Extra detail' },
  { id: 'q2', selected: ['C', 'D'], custom: 'Second detail' },
  { id: 'q3', selected: [], custom: 'Third answer' },
] }

test('untitled approval fallback uses Host language without changing request data', check, async t => {
  const f = await fixture(t, 'approval/request', undefined, (_, request) => {
    request.agent.session.header = {}
    delete request.toolName
    request.reason = '用户原文 {0}'
  })
  f.pending.catch(() => {})
  const [notice] = f.state().requests
  assert.equal(notice?.sessionTitle, 'Untitled')
  assert.equal(notice?.approval.toolName, 'Action')
  assert.equal(notice?.approval.reason, '用户原文 {0}')
  f.official.resolve('rejected')
  assert.equal(await f.pending, 'rejected')
})

test('approval details use the exact call and its preceding context, not a later command or message', check, async t => {
  const f = await fixture(t, 'approval/request', undefined, (ctx, request) => {
    ctx.provide('sessionTitle', { get: () => ({ title: '真实会话名称' }) })
    request.agent.session.deriveMessages = () => [
      { role: 'user', content: [{ type: 'text', text: '请检查权限。' }] },
      { role: 'assistant', content: [{ type: 'reasoning', text: 'private reasoning' }, { type: 'text', text: '需要确认这条命令。' },
        { type: 'tool-call', id: 'tool-1', name: 'bash', arguments: '{"command":"printf \'中文\\n\'","sandbox_mode":"danger-full-access"}' }] },
      { role: 'tool', content: [{ type: 'text', text: 'unrelated output' }] },
      { role: 'user', content: [{ type: 'text', text: '另一条消息' }] },
      { role: 'assistant', content: [{ type: 'tool-call', id: 'tool-2', name: 'bash', arguments: '{"command":"wrong command"}' }] },
    ]
  })
  const [notice] = f.state().requests
  assert.equal(notice.sessionTitle, '真实会话名称')
  assert.equal(notice.subtitle, '真实会话名称')
  assert.equal(notice.cwd, '/Test')
  assert.deepEqual(notice.context, [{ role: 'user', text: '请检查权限。' }, { role: 'assistant', text: '需要确认这条命令。' }])
  assert.equal(notice.approval.command, "printf '中文\n'")
  assert.equal(notice.approval.arguments, '{"command":"printf \'中文\\n\'","sandbox_mode":"danger-full-access"}')
  assert.equal(notice.approval.reason, 'Run owned test')
  f.official.resolve('rejected')
  assert.equal(await f.pending, 'rejected')
})

test('an unmatched approval call never borrows another command or unrelated conversation', check, async t => {
  const f = await fixture(t, 'approval/request', undefined, (ctx, request) => {
    request.agent.session.deriveMessages = () => [{ role: 'assistant', content: [
      { type: 'tool-call', id: 'other', name: 'bash', arguments: '{"command":"unrelated"}' },
    ] }]
  })
  const [notice] = f.state().requests
  assert.equal(notice.approval.command, undefined)
  assert.equal(notice.approval.arguments, undefined)
  assert.deepEqual(notice.context, [])
  f.official.resolve('rejected')
  await f.pending
})

test('question context follows its call and a long Unicode excerpt never splits an emoji', check, async t => {
  const f = await fixture(t, 'user-questions/request', undefined, (ctx, request) => {
    request.agent.session.deriveMessages = () => [
      { role: 'user', content: [{ type: 'text', text: '文'.repeat(19999) + '😀剩余' }] },
      { role: 'assistant', content: [{ type: 'text', text: '请回答这组问题。' }, { type: 'tool-call', id: 'tool-1', name: 'user_questions', arguments: '{}' }] },
      { role: 'user', content: [{ type: 'text', text: '后来的消息' }] },
    ]
  })
  f.pending.catch(() => {})
  const [notice] = f.state().requests
  assert.equal(notice.context.length, 2)
  assert.equal(notice.context[0].role, 'user')
  assert.equal(notice.context[0].text.endsWith('😀'), true)
  assert.equal(Array.from(notice.context[0].text).length, 20000)
  assert.equal(notice.context[0].truncated, true)
  assert.deepEqual(notice.context[1], { role: 'assistant', text: '请回答这组问题。' })
  f.official.resolve(answer)
  await f.pending
})

test('native multi-question batch settles once and cancels the official delivery without mutating the original signal', check, async t => {
  const f = await fixture(t)
  await sleep(10)
  const [notice] = f.state().requests
  assert.equal(notice.questions.length, 3)
  assert.equal(f.child().signal.aborted, false)
  assert.equal((await f.command(notice.id, answer)).status, 'accepted')
  assert.deepEqual(await f.pending, answer)
  assert.equal(f.child().signal.aborted, true)
  assert.equal(f.request.signal.aborted, false)
  assert.equal(f.state().requests.length, 0)
  assert.equal((await f.command(notice.id, answer)).status, 'stale')
})

test('Desktop answer withdraws the request and rejects a later native answer', check, async t => {
  const f = await fixture(t)
  const [notice] = f.state().requests
  f.official.resolve(answer)
  assert.deepEqual(await f.pending, answer)
  assert.equal(f.state().requests.length, 0)
  assert.equal((await f.command(notice.id, answer)).status, 'stale')
})

test('cancelled questions or a terminated turn withdraw the request before a native answer', check, async t => {
  const f = await fixture(t)
  const [notice] = f.state().requests
  const rejected = assert.rejects(f.pending, /question cancelled or turn terminated/)
  f.signal.abort(new Error('question cancelled or turn terminated'))
  await rejected
  assert.equal(f.state().requests.length, 0)
  assert.equal(f.accessor.pendingStates().size, 0)
  assert.equal((await f.command(notice.id, answer)).status, 'stale')
})

test('a batch of three valid long Chinese answers survives UTF-8 transport without truncation', check, async t => {
  const f = await fixture(t)
  f.pending.catch(() => {})
  const [notice] = f.state().requests
  const batch = { answers: answer.answers.map(item => ({ ...item, custom: '中文回答'.repeat(5000) })) }
  assert.ok(Buffer.byteLength(JSON.stringify(batch)) > 131072)
  assert.equal((await f.command(notice.id, batch)).status, 'accepted')
  assert.deepEqual(await f.pending, batch)
})

test('aborted requests cannot be approved by stale notification buttons', check, async t => {
  const f = await fixture(t, 'approval/request')
  const [notice] = f.state().requests
  const rejected = assert.rejects(f.pending)
  f.signal.abort(new Error('tool cancelled'))
  await rejected
  assert.equal(f.state().requests.length, 0)
  assert.equal((await f.command(notice.id, 'allowed-once')).status, 'stale')
})

test('approval returns the official string vocabulary and two concurrent requests keep independent identity', check, async t => {
  const f = await fixture(t, 'approval/request')
  const second = f.ctx.waterfall('approval/request', { ...f.request, callId: 'tool-2' }, () => 'unavailable')
  const notices = f.state().requests
  assert.equal(notices.length, 2)
  assert.notEqual(notices[0].id, notices[1].id)
  assert.equal((await f.command(notices[0].id, 'allowed-once')).status, 'accepted')
  assert.equal(await f.pending, 'allowed-once')
  assert.equal(f.state().requests.length, 1)
  assert.equal((await f.command(notices[1].id, 'rejected')).status, 'accepted')
  assert.equal(await second, 'rejected')
})

test('incomplete, duplicate, unknown-option and excess single selections never settle a batch', check, async t => {
  const f = await fixture(t)
  const [notice] = f.state().requests
  for (const bad of [
    { answers: answer.answers.slice(0, 2) },
    { answers: [answer.answers[0], answer.answers[0], answer.answers[2]] },
    { answers: [{ id: 'q1', selected: ['UNKNOWN'] }, ...answer.answers.slice(1)] },
    { answers: [{ id: 'q1', selected: ['A', 'B'] }, ...answer.answers.slice(1)] },
    { answers: [answer.answers[0], answer.answers[1], { id: 'q3', selected: [], custom: '  ' }] },
  ]) {
    assert.equal((await f.command(notice.id, bad)).status, 'invalid')
    assert.equal(f.state().requests.length, 1)
  }
  assert.equal((await f.command(notice.id, answer)).status, 'accepted')
  assert.deepEqual(await f.pending, answer)
})

test('timed questions remain answerable through the official continued method and queued Desktop replies withdraw them', check, async t => {
  let continued = []
  let received
  const service = {
    continued: () => continued,
    answer(agent, callId, batch) {
      received = { agentId: agent.id, callId, batch }
      agent.inbox.nextTurn.push({ source: { kind: 'user-question-reply', callId } })
      return true
    },
  }
  const f = await fixture(t, 'user-questions/request', service)
  f.request.agent.inbox = { nextTurn: [], nextStep: [] }
  const [notice] = f.state().requests
  const rejected = assert.rejects(f.pending)
  f.signal.abort(Object.assign(new Error('unattended timeout'), { code: 'ASK_TIMED_OUT' }))
  continued = [{ callId: 'tool-1' }]
  await rejected
  await sleep(300)
  assert.equal(f.state().requests[0].id, notice.id)
  assert.equal((await f.command(notice.id, answer)).status, 'accepted')
  assert.deepEqual(received, { agentId: 'agent-1', callId: 'tool-1', batch: answer })
  assert.equal((await f.command(notice.id, answer)).status, 'stale')
})

test('a queued Desktop continued answer closes the native request before another command arrives', check, async t => {
  const f = await fixture(t, 'user-questions/request', { continued: () => [{ callId: 'tool-1' }] })
  f.request.agent.inbox = { nextTurn: [], nextStep: [] }
  const [notice] = f.state().requests
  const rejected = assert.rejects(f.pending)
  f.signal.abort(Object.assign(new Error('timeout'), { code: 'ASK_TIMED_OUT' }))
  await rejected
  await sleep(300)
  f.request.agent.inbox.nextTurn.push({ source: { kind: 'user-question-reply', callId: 'tool-1' } })
  await sleep(300)
  assert.equal(f.state().requests.length, 0)
  assert.equal((await f.command(notice.id, answer)).status, 'stale')
})

test('Desktop Continue timeout keeps one visible request throughout the foreground-to-continued transition', check, async t => {
  let continued = []
  const f = await fixture(t, 'user-questions/request', {
    continued: () => continued,
    answer: () => true,
  })
  const [notice] = f.state().requests
  const rejected = assert.rejects(f.pending)
  f.official.reject(Object.assign(new Error('Continue'), { code: 'ASK_TIMED_OUT' }))
  await rejected
  assert.equal(f.state().requests[0]?.id, notice.id, 'transition must not publish an empty snapshot and terminalize the native form')
  assert.equal(f.state().requests[0].phase, 'transitioning')
  assert.equal(f.accessor.pendingStates().get('session-1').questions, true)
  assert.equal((await f.command(notice.id, answer)).status, 'waiting')
  continued = [{ callId: 'tool-1' }]
  await sleep(300)
  assert.equal(f.state().requests[0].id, notice.id)
  assert.equal(f.accessor.pendingStates().get('session-1').questions, true)
  assert.equal((await f.command(notice.id, answer)).status, 'accepted')
  assert.equal(f.accessor.pendingStates().size, 0)
})

test('snapshot write failure cannot prevent an official approval from settling or cancelling the losing delivery', check, async t => {
  const f = await fixture(t, 'approval/request')
  await sleep(10)
  const path = join(f.dir, 'interactions.json')
  rmSync(path)
  mkdirSync(path)
  f.official.resolve('allowed-once')
  assert.equal(await Promise.race([f.pending, sleep(100).then(() => 'HUNG')]), 'allowed-once')
  assert.equal(f.child().signal.aborted, true)
  rmSync(path, { recursive: true })
})

test('existing live-root continued questions are rediscovered after coordinator startup with fresh identities', check, async t => {
  let received
  const service = { continued: () => [{ callId: 'cold-call', questions: [{ id: 'cold', question: 'Recovered question?' }] }],
    answer(agent, callId, batch) { received = { callId, batch }; agent.inbox.nextTurn.push({ source: { kind: 'user-question-reply', callId } }); return true } }
  const f = await fixture(t, 'user-questions/request', service)
  f.request.agent.inbox = { nextTurn: [], nextStep: [] }
  f.ctx.provide('agents', { roots: () => [f.request.agent] })
  await sleep(300)
  const notice = f.state().requests.find(item => item.questions?.[0]?.id === 'cold')
  assert.ok(notice, 'continued root question should regain a native reminder')
  const batch = { answers: [{ id: 'cold', selected: [], custom: 'Recovered answer' }] }
  assert.equal((await f.command(notice.id, batch)).status, 'accepted')
  assert.deepEqual(received, { callId: 'cold-call', batch })
  await sleep(300)
  assert.equal(f.state().requests.some(item => item.id === notice.id), false)
  assert.equal((await f.command(notice.id, batch)).status, 'stale')
  f.official.resolve(answer)
  await f.pending
})

test('an open native panel holds the official timed wait and closing the panel releases its claim', check, async t => {
  let held = false
  const service = {
    async *attachWait(agent, callId, signal) {
      assert.equal(agent.id, 'agent-1')
      assert.equal(callId, 'tool-1')
      held = true
      yield { remainingMs: 30000 }
      await new Promise(resolve => signal.addEventListener('abort', resolve, { once: true }))
      held = false
    },
  }
  const f = await fixture(t, 'user-questions/request', service)
  const [notice] = f.state().requests
  writeFileSync(join(f.dir, 'open-panels.json'), JSON.stringify({ updatedAt: Date.now(), ids: [notice.id] }))
  await sleep(300)
  assert.equal(held, true)
  writeFileSync(join(f.dir, 'open-panels.json'), JSON.stringify({ updatedAt: Date.now(), ids: [], draftIds: [notice.id] }))
  await sleep(300)
  assert.equal(held, false, 'hidden drafts must not hold the official timed wait')
  f.official.resolve(answer)
  await f.pending
})

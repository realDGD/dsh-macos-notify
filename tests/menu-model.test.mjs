import test from 'node:test'
import assert from 'node:assert/strict'
import { buildMenuRows, singleLinePreview, todoProgress } from '../lib/menu-model.js'
const fact = (id, extra = {}) => ({ id, parentId:null, origin:null, workspaceTitle:'工作区', sessionTitle:id,
  pinIndex:null, archived:false, blank:false, running:false, turn:1,
  terminal:{turn:1,kind:'completed',time:1}, userText:'用户问题', taskText:'', answerText:'正式回答',
  answerTurn:1, todos:null, waiting:{questions:false,approval:false}, updatedAt:1, ...extra })
test('priority_and_history: official pins and attention precede runs, five roots exclude children/archives', () => {
  const rows = buildMenuRows([
    ...Array.from({length:7}, (_,i)=>fact('history-'+i,{updatedAt:i+10,terminal:{turn:1,kind:'completed',time:i+10}})),
    fact('pin-old',{pinIndex:1}), fact('pin-new',{pinIndex:0}),
    fact('run',{running:true,updatedAt:50}), fact('wait',{waiting:{approval:true},updatedAt:2}),
    fact('error',{terminal:{turn:1,kind:'error',time:3}}),
    fact('child',{parentId:'run',origin:'subagent'}), fact('blank',{blank:true}),fact('archive',{archived:true})
  ])
  assert.deepEqual(rows.activeIds,['pin-new','pin-old','error','wait','run'])
  assert.deepEqual(rows.historyIds,['history-6','history-5','history-4','history-3','history-2'])
  assert.deepEqual(rows.nodes.find(n=>n.id==='run').childIds,['child'])
  assert.ok(!rows.nodes.some(n=>['archive','blank'].includes(n.id)))
})
test('promote_waiting_grandchild preserves completed ancestor actual state and badge', () => {
  const rows=buildMenuRows([fact('parent'),fact('child',{parentId:'parent',origin:'subagent'}),
    fact('grandchild',{parentId:'child',origin:'subagent',waiting:{questions:true}}),fact('run',{running:true})])
  assert.deepEqual(rows.activeIds,['parent','run'])
  assert.equal(rows.nodes.find(n=>n.id==='parent').state,'completed')
  assert.equal(rows.nodes.find(n=>n.id==='parent').descendantBadge,'waiting-questions')
  assert.deepEqual(rows.historyIds,[])
})
test('ordinary user forks remain independent roots in the five history slots', () => {
  const rows=buildMenuRows([fact('parent'),fact('fork',{parentId:'parent',origin:null,updatedAt:5,terminal:{turn:1,kind:'completed',time:5}})])
  assert.deepEqual(rows.historyIds,['fork','parent'])
  assert.equal(rows.nodes.find(n=>n.id==='fork').parentId,null)
  assert.deepEqual(rows.nodes.find(n=>n.id==='parent').childIds,[])
})
test('orphan_and_cycle: missing/cyclic parents never enter root history or recur forever', () => {
  const rows=buildMenuRows([fact('orphan',{parentId:'missing',origin:'subagent',running:true}),
    fact('a',{parentId:'b',origin:'subagent',running:true}),fact('b',{parentId:'a',origin:'subagent'}),fact('a'),fact('/invalid')])
  assert.equal(rows.historyIds.length,0)
  assert.equal(rows.nodes.length,3)
  assert.equal(new Set(rows.nodes.map(n=>n.id)).size,3)
  assert.ok(rows.orphanIds.includes('orphan'))
  for(const node of rows.nodes) {
    const seen=new Set(); let current=node
    while(current) { assert.ok(!seen.has(current.id)); seen.add(current.id); current=rows.nodes.find(n=>n.id===current.parentId) }
  }
})
test('real_progress uses node own valid todos only', () => {
  assert.deepEqual(todoProgress([{status:'completed'},{status:'completed'},{status:'completed'},{status:'in_progress'},{status:'pending'}]),{completed:3,total:5})
  assert.equal(todoProgress([]),null); assert.equal(todoProgress(null),null)
  assert.equal(todoProgress([{status:'unknown'}]),null)
})
test('current_turn_preview and state never use older answer/end; retries stay running', () => {
  const rows=buildMenuRows([fact('new',{turn:2,answerTurn:1}),fact('stop',{terminal:{turn:1,kind:'aborted',cause:'user',time:3}}),
    fact('retry',{running:true,terminal:{turn:1,kind:'error',time:2}}),fact('task',{running:true,userText:'',taskText:'子代理任务'})])
  assert.equal(rows.nodes.find(n=>n.id==='new').state,'unknown')
  assert.equal(rows.nodes.find(n=>n.id==='new').preview,'用户问题')
  assert.equal(rows.nodes.find(n=>n.id==='stop').state,'stopped')
  assert.equal(rows.nodes.find(n=>n.id==='retry').state,'running')
  assert.equal(rows.nodes.find(n=>n.id==='task').previewKind,'task')
  assert.equal(rows.nodes.find(n=>n.id==='task').preview,'子代理任务')
})
test('unicode_and_budget: display only truncation, explicit node omissions, byte cap', () => {
  assert.ok([...singleLinePreview('题目🙂'.repeat(300))].length<=240)
  const facts=Array.from({length:2001},(_,i)=>fact('node-'+i,{pinIndex:i,userText:'题🙂'.repeat(1000),workspaceTitle:'区'.repeat(300),sessionTitle:'会'.repeat(300)}))
  const rows=buildMenuRows(facts)
  assert.equal(rows.nodes.length,2000); assert.equal(rows.omittedCount,1)
  for(const n of rows.nodes) assert.ok([...`${n.workspaceTitle} · ${n.sessionTitle}`].length<=200)
  const small=buildMenuRows(facts,{maxBytes:4096})
  assert.ok(Buffer.byteLength(JSON.stringify(small))<=4096)
  assert.equal(small.omittedCount,2001-small.nodes.length)
  assert.equal(facts[0].sessionTitle.length,300)
})
test('deep tree fits iterative graph traversal and ancestor closure when bounded', () => {
  const rows=buildMenuRows(Array.from({length:10000},(_,i)=>fact('deep-'+i,{parentId:i?'deep-'+(i-1):null,origin:i?'subagent':null,running:true})))
  assert.ok(rows.nodes.length<=2000); assert.equal(rows.omittedCount,10000-rows.nodes.length)
  const ids=new Set(rows.nodes.map(n=>n.id))
  for(const n of rows.nodes) assert.ok(!n.parentId || ids.has(n.parentId))
})
test('markdown_plain_preview: safe one line text without image/html behavior', () => {
  assert.equal(singleLinePreview('## 标题\n**重点** [链接](https://example.invalid)\n`代码`'),'标题 重点 链接 代码')
  assert.equal(singleLinePreview('![图片](https://example.invalid/image.png)'),'无文字输入')
  const rows=buildMenuRows([fact('untitled',{sessionTitle:'',running:true})])
  assert.equal(rows.nodes[0].sessionTitle,'未命名会话')
})

// Regressions: a historical error is not activity; causes are not all user stops.
test('activity_membership keeps observed endings and excludes untouched old failures and pins',()=>{
 const rows=buildMenuRows([fact('old-error',{terminal:{turn:1,kind:'error',time:9}}),fact('old-pin',{pinIndex:0}),
  fact('finished-now',{terminal:{turn:1,kind:'completed',time:10}}),fact('parent'),
  fact('child-now',{parentId:'parent',origin:'subagent',terminal:{turn:1,kind:'error',time:11}})],
  {activityIds:new Set(['finished-now','child-now'])})
 assert.deepEqual(rows.activeIds,['parent','finished-now'])
 assert.deepEqual(rows.historyIds,['old-error','old-pin'])
})
test('cancellation causes preserve user intent and do not invent abnormal crashes',()=>{
 const causes=['user','parent','hook','disposed','legacy',undefined]
 const rows=buildMenuRows(causes.map((cause,i)=>fact('cancel-'+i,{pinIndex:i,terminal:{turn:1,kind:'aborted',cause,time:10-i}})),
  {activityIds:new Set(causes.map((_,i)=>'cancel-'+i))})
 assert.deepEqual(causes.map((_,i)=>rows.nodes.find(n=>n.id==='cancel-'+i).state),
  ['stopped','parent-stopped','hook-stopped','environment-stopped','cancelled','cancelled'])
})

test('synthetic empty previews remain distinct from literal matching user content',()=>{
 const rows=buildMenuRows([fact('image',{running:true,userText:'![image](https://example.invalid/x)'}),fact('literal',{running:true,userText:'无文字输入'})])
 assert.equal(rows.nodes.find(n=>n.id==='image').previewKind,'empty')
 assert.equal(rows.nodes.find(n=>n.id==='literal').previewKind,'user')
 assert.equal(rows.nodes.find(n=>n.id==='literal').preview,'无文字输入')
})

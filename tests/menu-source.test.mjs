import test from 'node:test'
import assert from 'node:assert/strict'
import { createMenuSource } from '../lib/menu-source.js'
const event=(seq,type,data,time=seq+100)=>({seq,type,data,time,...(['user/message','assistant/message'].includes(type)?{surfaceOp:'append'}:{})})
const user=(text,kind='user')=>({role:'user',source:{kind},content:[{type:'text',text}]})
const assistant=text=>({role:'assistant',source:{kind:'model'},content:[{type:'reasoning',text:'SECRET'}, {type:'text',text}]})
function session(id,events,extra={}) {
 return {id,header:{id,version:4,createdAt:50,cwd:'/example/workspace',isSeeded:false,...extra},inheritedEventCount:0,
  get seq(){return events.length},snapshotEvents:()=>events,
  surface:{nodes:events.filter(e=>e.surfaceOp).map(e=>e.seq),contentGeneration:0},eventAt:seq=>events[seq],
  deriveEventMessage:e=>e.type==='user/message'?e.data:e.data.message}
}
function fixture(live=[],cold=[]) {
 const metrics={observations:0,disposals:0,surfaceReads:0,active:0,peak:0}, todos=new Map(), running=new Set(), errors=new Set()
 const query={listSessions:async()=>[...live,...cold].map(s=>({header:s.header,live:live.includes(s),persisted:true})),
  async observeSession(id,{signal,projectionMode}) {
   assert.equal(projectionMode,'all');signal?.throwIfAborted();metrics.active++;metrics.peak=Math.max(metrics.peak,metrics.active)
   await new Promise(r=>setTimeout(r,2));metrics.active--
   if(errors.has(id))throw new Error('owned read failure')
   const s=[...live,...cold].find(s=>s.id===id);metrics.observations++
   let closed=false
   return {header:s.header,cursor:s.seq-1,revision:services.sessionPersistence? (await services.sessionPersistence.stat(id)).revision :{size:s.seq,mtimeMs:100},inheritedEventCount:s.inheritedEventCount,
    events:s.snapshotEvents(),projections:{asOfSeq:s.seq-1,values:{todos:todos.get(id)??null,title:'冷会话名称'}},
    [Symbol.dispose](){assert.equal(closed,false);closed=true;metrics.disposals++}}
  },
  async readSurface(id){metrics.surfaceReads++;const s=[...live,...cold].find(s=>s.id===id);return {session:s.header,inheritedEventCount:s.inheritedEventCount,capturedThroughSeq:s.seq-1,events:s.surface.nodes.map(seq=>s.eventAt(seq))}}
 }
 const services={workspaceRegistry:{list:()=>[{id:'workspace-1',path:'/example/workspace',title:'工作区名称',sessionIds:[...live,...cold].filter(s=>!s.header.parentSession).map(s=>s.id)}],pinnedSessionIds:['session-2','session-1'],archivedSessionIds:[]},
 sessions:{list:()=>live,get:id=>live.find(s=>s.id===id)}, agents:{get:id=>running.has(id)?{status:'running'}:undefined},
 sessionTitle:{get:()=>({title:'真实会话名'})},sessionProjections:{snapshot:s=>({asOfSeq:s.seq-1,values:{todos:todos.get(s.id)??null}})},sessionQuery:query}
 return {ctx:{get:name=>services[name]},services,query,metrics,todos,running,errors,live}
}
test('live_titles_pins_todos: official names/pins and parent workspace, numeric end time',()=>{
 const s=session('session-1',[event(0,'turn/start',{turn:1}),event(1,'user/message',user('最新提问')),event(2,'assistant/message',{turn:1,message:assistant('正式答案')}),event(3,'turn/end',{turn:1,reason:{kind:'completed'}},1234)])
 const child=session('child',[],{parentSession:'session-1',origin:'subagent',cwd:'/different/child'})
 const f=fixture([s,child]);f.todos.set(s.id,[{status:'completed'}]);const source=createMenuSource(f.ctx)
 const rows=source.liveFacts();source.dispose()
 assert.equal(rows[0].workspaceTitle,'工作区名称');assert.equal(rows[0].sessionTitle,'真实会话名');assert.equal(rows[0].pinIndex,1)
 assert.equal(rows[0].terminal.time,1234);assert.equal(rows[0].answerText,'正式答案');assert.equal(rows[0].answerTurn,1)
 assert.deepEqual(rows[0].todos,[{status:'completed'}]);assert.equal(rows[1].workspaceTitle,'工作区名称')
})
test('fork_and_turn_boundaries: inherited input/answer and old todo do not become child current facts',()=>{
 const events=[event(0,'turn/start',{turn:1}),event(1,'user/message',user('父问题')),event(2,'assistant/message',{turn:1,message:assistant('父答案')}),event(3,'turn/end',{turn:1,reason:{kind:'completed'}}),event(4,'turn/start',{turn:2}),event(5,'user/message',user('新的任务','agent-message'))]
 const s=session('child',events,{parentSession:'parent',origin:'subagent',isSeeded:true});s.inheritedEventCount=4
 const f=fixture([s]);const source=createMenuSource(f.ctx);const row=source.liveFacts()[0];source.dispose()
 assert.equal(row.userText,'');assert.equal(row.taskText,'新的任务');assert.equal(row.answerTurn,null);assert.equal(row.terminal,null);assert.equal(row.todos,null)
})
test('ordinary fork lineage resolves workspace without classifying it as a subagent',()=>{
 const parent=session('parent',[]),fork=session('fork',[event(0,'turn/start',{turn:1}),event(1,'user/message',user('独立分支提问'))],{parentSession:'parent',isSeeded:true,cwd:'/different/fork'})
 const f=fixture([parent,fork]),source=createMenuSource(f.ctx),row=source.liveFacts().find(f=>f.id==='fork')
 assert.equal(row.workspaceTitle,'工作区名称');assert.equal(row.parentId,null);assert.equal(row.origin,null)
 assert.equal(row.userText,'独立分支提问');source.dispose()
})
test('human_vs_task_preview ignores injected instructions and superseded message nodes',()=>{
 const s=session('child',[event(0,'turn/start',{turn:1}),event(1,'user/message',user('任务','agent-message')),event(2,'user/message',user('真人输入')),event(3,'user/message',user('后面的注入指令','agent-instructions'))],{origin:'subagent'})
 const f=fixture([s]);const source=createMenuSource(f.ctx)
 assert.equal(source.liveFacts()[0].userText,'真人输入')
 s.surface.nodes=[1,3];s.surface.contentGeneration++
 assert.equal(source.liveFacts()[0].userText,'');assert.equal(source.liveFacts()[0].taskText,'任务');source.dispose()
})
test('latest image-only human input does not resurrect an older text question or child task',()=>{
 const s=session('child',[event(0,'turn/start',{turn:1}),event(1,'user/message',user('任务','agent-message')),event(2,'user/message',user('旧问题')),
   event(3,'user/message',{role:'user',source:{kind:'user'},content:[{type:'image',image:'owned-placeholder'}]})],{origin:'subagent'})
 const f=fixture([s]),source=createMenuSource(f.ctx)
 assert.equal(source.liveFacts()[0].userText,'无文字输入');source.dispose()
})
test('cold_failures_and_revision_cache: release every lease, bounded workers, unchanged log not refolded',async()=>{
 const f=fixture([],Array.from({length:12},(_,i)=>session('cold-'+i,[event(0,'turn/start',{turn:1}),event(1,'turn/end',{turn:1,reason:{kind:'interrupted'}})])))
 f.errors.add('cold-3');const source=createMenuSource(f.ctx)
 const rows=await source.discover();assert.equal(rows.length,11);assert.equal(rows[0].sessionTitle,'冷会话名称')
 const reads=f.metrics.surfaceReads;await source.discover();assert.equal(f.metrics.surfaceReads,reads);assert.equal(reads,0)
 assert.ok(f.metrics.peak<=4);assert.equal(f.metrics.observations,f.metrics.disposals);source.dispose()
})
test('lease_cleanup: cancellation and surface failure release and prevent delayed cache writes',async()=>{
 const s=session('cold',[]),f=fixture([], [s]);const controller=new AbortController()
 const observe=f.query.observeSession;f.query.observeSession=async(...args)=>{const lease=await observe(...args);controller.abort();return lease}
 const source=createMenuSource(f.ctx);const rows=await source.discover(controller.signal)
 assert.deepEqual(rows,[]);assert.equal(f.metrics.disposals,1);source.dispose();assert.deepEqual(source.liveFacts(),[])
})
test('delayed cold observation cannot overwrite newer attached live turn',async()=>{
 const old=session('session-1',[event(0,'turn/start',{turn:1}),event(1,'turn/end',{turn:1,reason:{kind:'completed'}})])
 const f=fixture([], [old]),original=f.query.observeSession;let release
 f.query.observeSession=async(...args)=>{await new Promise(r=>release=r);return original(...args)}
 const source=createMenuSource(f.ctx);const promise=source.discover()
 while(!release)await new Promise(r=>setTimeout(r,1))
 const current=session('session-1',[event(0,'turn/start',{turn:1}),event(1,'turn/end',{turn:1,reason:{kind:'completed'}}),event(2,'turn/start',{turn:2}),event(3,'user/message',user('当前问题'))])
 f.live.push(current);f.running.add(current.id);source.invalidate(current.id);source.liveFacts();release()
 const rows=await promise
 assert.equal(rows[0].turn,2);assert.equal(rows[0].userText,'当前问题');assert.equal(rows[0].running,true);assert.equal(f.metrics.disposals,1);source.dispose()
})
test('lightweight revision cache avoids observing unchanged cold logs beyond five SDK cache entries',async()=>{
 const f=fixture([],Array.from({length:12},(_,i)=>session('revision-'+i,[]))),identity=Symbol('persistence')
 const revisions=new Map();f.services.sessionPersistence={identity,stat:async id=>({revision:revisions.get(id)??'v1'})}
 const source=createMenuSource(f.ctx);await source.discover();const reads=f.metrics.observations
 await source.discover();assert.equal(f.metrics.observations,reads)
 revisions.set('revision-2','v2');await source.discover();assert.equal(f.metrics.observations,reads+1)
 source.invalidate('revision-3');await source.discover();assert.equal(f.metrics.observations,reads+2)
 f.services.sessionPersistence={...f.services.sessionPersistence,identity:Symbol('replacement')};await source.discover();assert.equal(f.metrics.observations,reads+14);source.dispose()
})
test('dispose releases the retained observation before any blocked secondary surface read',async()=>{
 const f=fixture([], [session('blocked',[])]),source=createMenuSource(f.ctx);let release,finished=false
 f.query.readSurface=async()=>{await new Promise(r=>release=r);return {capturedThroughSeq:-1,events:[]}}
 const work=source.discover().finally(()=>finished=true)
 while(!release&&!finished)await new Promise(r=>setTimeout(r,1))
 source.dispose();const released=f.metrics.disposals;release?.();await work
 assert.equal(released,1);assert.equal(f.metrics.surfaceReads,0)
})

test('unregistered cwd is ungrouped instead of a temporary directory workspace',()=>{
 const f=fixture([session('unregistered',[],{cwd:'/tmp/e2e-project-random'})])
 f.services.workspaceRegistry.list=()=>[]
 const source=createMenuSource(f.ctx)
 assert.equal(source.liveFacts()[0].workspaceTitle,'未分组');source.dispose()
})

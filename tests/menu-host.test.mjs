import test from 'node:test'
import assert from 'node:assert/strict'
import {mkdtempSync,readFileSync,statSync,rmSync} from 'node:fs'
import {join} from 'node:path'
import {tmpdir} from 'node:os'
import {createSettings} from '../lib/settings.js'
import {installSessionMenu} from '../lib/menu-host.js'
const settle=()=>new Promise(r=>setImmediate(r))
async function fixture(t,{missing=false,blocked=false}={}) {
 const {Context}=await import(process.env.DSH_CORDIS_MODULE||'@deepseek-ai/cordis'),ctx=new Context()
 const dir=mkdtempSync(join(tmpdir(),'notify-menu-host-')),settings=createSettings(dir),states=new Map(),queries={count:0},clock={value:10000}
 const running=new Set(['session-test']),events=[],s={id:'session-test',header:{id:'session-test',version:4,createdAt:100,cwd:'/fixture',isSeeded:false},inheritedEventCount:0,
  get seq(){return events.length},snapshotEvents:start=>events.slice(start??0),surface:{nodes:[],contentGeneration:0},eventAt:seq=>events[seq],deriveEventMessage:e=>e.data.message??e.data}
 let release
 if(!missing){ctx.provide('sessions',{list:()=>[s],get:id=>id===s.id?s:undefined});ctx.provide('agents',{get:id=>running.has(id)?{status:'running'}:undefined})
  ctx.provide('sessionQuery',{listSessions:async signal=>{queries.count++;if(blocked)await new Promise(r=>release=r);return [{header:s.header,live:true,persisted:true}]},observeSession:async()=>{throw new Error('live requires no lease')},readSurface:async()=>{throw new Error('live requires no cold read')}})
 }
 let menu
 const fiber=await ctx.plugin({name:'menu-fixture',apply:owner=>{menu=installSessionMenu(owner,{stateDir:dir,settings,pendingStates:()=>states,now:()=>clock.value})}})
 t.after(async()=>{release?.();await ctx.fiber.dispose();rmSync(dir,{recursive:true,force:true})})
 const read=()=>JSON.parse(readFileSync(join(dir,'session-menu.json'),'utf8'))
 const advance=async ms=>{clock.value+=ms;menu.refresh();await settle();menu.refresh()}
 return {ctx,fiber,dir,settings,states,clock,menu,queries,read,advance,running,s,events,release:()=>release?.()}
}
test('baseline_loading_to_ready and private_snapshot use whole bounded envelopes',async t=>{
 const f=await fixture(t);assert.equal(f.read().availability,'loading');await f.advance(1000)
 const snapshot=f.read();assert.equal(snapshot.availability,'ready');assert.equal(snapshot.version,1)
 assert.deepEqual(snapshot.activeIds,['session-test']);assert.equal(snapshot.nodes[0].state,'running')
 assert.ok(Buffer.byteLength(readFileSync(join(f.dir,'session-menu.json')))<=4*1024*1024)
 assert.ok(snapshot.nodes.length<=2000);assert.equal(statSync(f.dir).mode&0o777,0o700);assert.equal(statSync(join(f.dir,'session-menu.json')).mode&0o777,0o600)
})
test('lifecycle_and_coalescing: pending changes coalesce, heartbeat survives and discovery waits thirty seconds',async t=>{
 const f=await fixture(t);await f.advance(1000);const before=f.read()
 f.states.set('session-test',{questions:true,approval:false});await f.advance(100)
 assert.equal(f.read().revision,before.revision)
 await f.advance(900);assert.equal(f.read().nodes[0].state,'waiting-questions');const changed=f.read()
 await f.advance(1000);assert.equal(f.read().revision,changed.revision)
 await f.advance(1000);assert.ok(f.read().revision>changed.revision);assert.equal(f.queries.count,1)
 await f.advance(26000);assert.equal(f.queries.count,2)
})
test('disable_reenable: only extra menu collection stops and pending request state stays owned',async t=>{
 const f=await fixture(t);await f.advance(1000);const generation=f.read().generation
 f.states.set('session-test',{approval:true});f.settings.save({menuBarEnabled:false});await f.advance(1000)
 assert.equal(f.read().enabled,false);assert.deepEqual(f.read().nodes,[]);assert.equal(f.states.get('session-test').approval,true)
 const count=f.queries.count;await f.advance(60000);assert.equal(f.queries.count,count)
 f.settings.save({menuBarEnabled:true});await f.advance(1000)
 assert.equal(f.read().enabled,true);assert.equal(f.read().generation,generation);assert.equal(f.read().nodes[0].state,'waiting-approval');assert.equal(f.queries.count,count+1)
})
test('late_read_after_dispose cannot write and generations differ across activation',async t=>{
 const f=await fixture(t,{blocked:true}),before=readFileSync(join(f.dir,'session-menu.json'),'utf8')
 await f.fiber.dispose();f.release();await settle();f.clock.value+=5000;f.menu.refresh()
 assert.equal(readFileSync(join(f.dir,'session-menu.json'),'utf8'),before)
 const second=await fixture(t);assert.notEqual(second.read().generation,JSON.parse(before).generation)
})
test('service_absence is unavailable without fabricated completion or prevented lifecycle',async t=>{
 const f=await fixture(t,{missing:true});assert.equal(f.read().availability,'unavailable');assert.deepEqual(f.read().nodes,[])
 await f.advance(2000);assert.equal(f.read().availability,'unavailable')
})

test('activity retains completion only for runs observed during the current connection',async t=>{
 const f=await fixture(t);await f.advance(1000)
 f.running.clear()
 f.events.push({seq:0,time:12000,type:'turn/end',data:{turn:1,reason:{kind:'completed'}}})
 f.ctx.emit('session/event',f.s,f.events[0]);await f.advance(1000)
 assert.deepEqual(f.read().activeIds,['session-test'])
 assert.equal(f.read().nodes[0].state,'completed')
})
test('old error at baseline is history while a quick start/end after connection is activity',async t=>{
 const f=await fixture(t);f.running.clear()
 // Re-activate to establish a new connection with an idle historical failure.
 await f.fiber.dispose()
 f.events.push({seq:0,time:1,type:'turn/end',data:{turn:1,reason:{kind:'error'}}})
 let next
 await f.ctx.plugin({name:'menu-reconnect',apply:owner=>{next=installSessionMenu(owner,{stateDir:f.dir,settings:f.settings,now:()=>f.clock.value})}})
 f.clock.value+=1000;next.refresh();await settle();next.refresh()
 assert.deepEqual(f.read().activeIds,[])
 const start={seq:1,time:12000,type:'turn/start',data:{turn:2}}
 f.events.push(start);f.ctx.emit('session/event',f.s,start)
 const end={seq:2,time:12001,type:'turn/end',data:{turn:2,reason:{kind:'completed'}}}
 f.events.push(end);f.ctx.emit('session/event',f.s,end)
 f.clock.value+=1000;next.refresh()
 assert.deepEqual(f.read().activeIds,['session-test'])
})

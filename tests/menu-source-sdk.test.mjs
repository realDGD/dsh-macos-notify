import test from 'node:test'
import assert from 'node:assert/strict'
import { Context } from '@deepseek-ai/cordis'
import { Session } from '@deepseek-ai/dsh-session'
import { currentSessionMessageProjections } from '@deepseek-ai/dsh-session-format-catalog/message-projections'
import { SessionQueryEngine } from '@deepseek-ai/dsh-session-query'
const {createMenuSource}=await import(process.env.DSH_MENU_SOURCE_MODULE||'../lib/menu-source.js')
async function sdkFixture(t,{count=12,blocked=false}={}) {
 const ctx=new Context(),records=Array.from({length:count},(_,i)=>({header:{id:'cold-'+i,version:4,createdAt:i,cwd:'/fixture',isSeeded:false},revision:'v1'})),metrics={reads:0,closed:0,active:0}
 let release
 const persistence={identity:Symbol('persistence'),stat:async id=>records.find(r=>r.header.id===id),list:async()=>records,
  open:async(id,access)=>{assert.equal(access,'read');const record=records.find(r=>r.header.id===id);return {header:record.header,inheritedEventCount:0,
   read:async(_start,_end,{signal}={})=>{metrics.reads++;metrics.active++;try{if(blocked)await new Promise((resolve,reject)=>{release=resolve;signal.addEventListener('abort',()=>reject(signal.reason),{once:true})});return {events:record.events??[],eventState:'owned'}}finally{metrics.active--}},
   close:async()=>{metrics.closed++}}}}
 ctx.provide('sessions',{list:()=>[],get:()=>undefined,prepare:(id,o)=>Session.create(id,o.seed,o.meta,o.inheritedEventCount,currentSessionMessageProjections)})
 ctx.provide('sessionPersistence',persistence)
 await ctx.plugin({name:'official-query-fixture',apply:owner=>{new SessionQueryEngine(owner)}})
 const source=createMenuSource(ctx);t.after(async()=>{source.dispose();release?.();await ctx.fiber.dispose()})
 return {source,metrics,records,release:()=>release?.()}
}
test('official five-entry prepared cache: twelve unchanged cold logs are not reread',async t=>{
 const f=await sdkFixture(t);assert.equal((await f.source.discover()).length,12);assert.equal(f.metrics.reads,12)
 await f.source.discover();assert.equal(f.metrics.reads,12)
 f.records[2].revision='v2';await f.source.discover();assert.equal(f.metrics.reads,13)
 assert.equal(f.metrics.closed,f.metrics.reads)
})
test('official pending read cancels and closes before unblock; no second surface read',async t=>{
 const f=await sdkFixture(t,{count:1,blocked:true}),work=f.source.discover()
 while(!f.metrics.active)await new Promise(r=>setTimeout(r,1))
 f.source.dispose();await work
 assert.equal(f.metrics.active,0);assert.equal(f.metrics.closed,1);f.release()
})

test('official retained cold observation supplies current formal answer and human input',async t=>{
 const f=await sdkFixture(t,{count:1}),record=f.records[0],s=Session.create(record.header.id,undefined,record.header,0,currentSessionMessageProjections)
 s.append('turn/start',{turn:1})
 s.append('user/message',{id:'user-1',role:'user',source:{kind:'user'},content:[{type:'text',text:'当前提问'}]},{surfaceOp:'append'})
 s.append('assistant/message',{turn:1,step:1,stream:[],message:{id:'answer-1',role:'assistant',source:{kind:'model',provider:'fixture',model:'fixture'},content:[{type:'text',text:'正式回答'}]}},{surfaceOp:'append'})
 s.append('turn/end',{turn:1,reason:{kind:'completed'}})
 record.events=s.snapshotEvents()
 const rows=await f.source.discover();assert.equal(rows.length,1);assert.equal(rows[0].userText,'当前提问');assert.equal(rows[0].answerText,'正式回答');assert.equal(rows[0].terminal.kind,'completed')
 assert.equal(f.metrics.reads,1);assert.equal(f.metrics.closed,1)
})

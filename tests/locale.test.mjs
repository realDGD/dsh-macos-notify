import test from 'node:test'
import assert from 'node:assert/strict'
import {mkdtempSync,readFileSync,writeFileSync,rmSync,readdirSync} from 'node:fs'
import {tmpdir} from 'node:os'
import {join} from 'node:path'
import vm from 'node:vm'
import {apply} from '../lib/index.js'
import {createNotifications} from '../lib/notifications.js'
import {readUILanguage,uiText} from '../lib/locale.js'

test('authenticated language updates reject invalid values and stale per-view sequences',async t=>{
 const dir=mkdtempSync(join(tmpdir(),'dsh-language-'));t.after(()=>rmSync(dir,{recursive:true,force:true}))
 const routes=new Map();apply({get:k=>k==='connection'?{fetch:{register:r=>routes.set(r.path,r)}}:null},{stateDir:dir})
 const route=routes.get('/api/dsh-macos-notify/locale');assert.ok(route,'language route must be registered')
 const send=async payload=>route.fetch(new Request('http://localhost/api/dsh-macos-notify/locale',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({type:'client-request',rpcId:'language',method:'dsh-macos-notify/locale',payload})}))
 assert.equal((await send({locale:'en',clientId:'view-one',seq:2})).status,200)
 assert.equal(JSON.parse(readFileSync(join(dir,'ui-language.json'))).locale,'en')
 assert.equal((await send({locale:'zh',clientId:'view-one',seq:1})).status,200)
 assert.equal(JSON.parse(readFileSync(join(dir,'ui-language.json'))).locale,'en')
 assert.equal((await send({locale:'zh',clientId:'view-one',seq:3})).status,200)
 assert.equal(JSON.parse(readFileSync(join(dir,'ui-language.json'))).locale,'zh')
 assert.equal((await send({locale:'../../etc',clientId:'view-one',seq:4})).status,400)
})
test('new notification copy follows language while user titles and error contents remain exact',t=>{
 const dir=mkdtempSync(join(tmpdir(),'dsh-language-notice-'));t.after(()=>rmSync(dir,{recursive:true,force:true}))
 writeFileSync(join(dir,'ui-language.json'),JSON.stringify({version:1,locale:'en'}))
 const notices=createNotifications({stateDir:dir});notices.test('session-opaque');const n=JSON.parse(readFileSync(join(dir,'notifications',readdirSync(join(dir,'notifications'))[0])))
 assert.equal(n.title,'DSH Notify · Notification test');assert.match(n.body,/does not run commands/)
 writeFileSync(join(dir,'ui-language.json'),JSON.stringify({version:1,locale:'zh'}))
 notices.test('session-opaque');assert.ok(readdirSync(join(dir,'notifications')).some(f=>JSON.parse(readFileSync(join(dir,'notifications',f))).title==='DSH Notify · 安全测试'))
 const session={id:'literal',title:'任务完成 {0}',header:{}}
 notices.observe(session,{type:'turn/start',data:{turn:1}})
 notices.observe(session,{type:'turn/end',data:{turn:1,reason:{kind:'error'}}})
 const error=readdirSync(join(dir,'notifications')).map(f=>JSON.parse(readFileSync(join(dir,'notifications',f)))).find(n=>n.kind==='error')
 assert.equal(error.subtitle,'任务完成 {0}');assert.equal(error.title,'任务出错')
 writeFileSync(join(dir,'ui-language.json'),JSON.stringify({version:1,locale:'en'}))
 assert.equal(error.title,'任务出错','already queued content must remain unchanged')
})
test('language state rejects malformed and oversized records; parameters are literal',t=>{
 const dir=mkdtempSync(join(tmpdir(),'dsh-language-state-'));t.after(()=>rmSync(dir,{recursive:true,force:true}))
 for(const text of ['{partial',JSON.stringify({version:'1',locale:'zh'}),JSON.stringify({version:1,locale:'../../'}),' '.repeat(1025)]) {
  writeFileSync(join(dir,'ui-language.json'),text);assert.equal(readUILanguage(dir),'en')
 }
 assert.equal(uiText('问题 {0}{1}',dir,{0:'{1}',1:'用户原文'}),'Question {1}用户原文')
})
test('client subscribes to official DSH locale, resends after reset, and disposes listeners',async()=>{
 let definition;let active='en',revision=1;const listeners=new Set(),cleanups=[],events=new Map(),packets=[]
 const locale={getSnapshot:()=>({active,revision}),subscribe:f=>(listeners.add(f),()=>listeners.delete(f))}
 const window={__ModuleLoader__:{load:d=>definition=d},location:{protocol:'dsh-app:',search:'',href:'http://127.0.0.1/'},setInterval:()=>0,clearInterval(){},setTimeout:()=>0,clearTimeout(){},addEventListener(){},removeEventListener(){}}
 vm.runInNewContext(readFileSync(new URL('../lib/client.js',import.meta.url),'utf8'),{window,document:{hidden:false,hasFocus:()=>true},URL,URLSearchParams,console,Date,Promise,Map,Set,setTimeout,clearTimeout})
 const connection={rpc:{call:async(_,method,payload)=>{if(method.endsWith('/locale'))packets.push(payload);return {ok:true,value:null}}}}
 const ctx={get:k=>({locale,connection,sessions:{list:{getSnapshot:()=>({ids:[],byId:{}}),subscribe:()=>()=>{}}}}[k]),on:(name,fn)=>{events.set(name,fn);return ()=>events.delete(name)},effect:f=>cleanups.push(f())}
 definition.factory(()=>{throw Error('not available')}).apply(ctx)
 await new Promise(r=>setImmediate(r));assert.equal(packets.at(-1)?.locale,'en')
 active='zh';revision++;for(const f of listeners)f();await new Promise(r=>setImmediate(r));assert.equal(packets.at(-1)?.locale,'zh')
 const before=packets.length;events.get('connection/reset')?.();await new Promise(r=>setImmediate(r));assert.ok(packets.length>before)
 for(const f of cleanups)f?.();assert.equal(listeners.size,0)
})

test('locale changes coalesce during delayed RPC, retry after failure, and cancel before disposal',async()=>{
 async function harness(disposeImmediately=false) {
  let definition,active='en';const listeners=new Set(),cleanups=[],packets=[],timers=new Map(),pending=[];let id=0
  const locale={getSnapshot:()=>({active}),subscribe:f=>(listeners.add(f),()=>listeners.delete(f))}
  const window={__ModuleLoader__:{load:d=>definition=d},location:{protocol:'dsh-app:',search:'',href:'http://127.0.0.1/'},setInterval:f=>(timers.set(++id,f),id),clearInterval:i=>timers.delete(i),setTimeout:()=>0,clearTimeout(){},addEventListener(){},removeEventListener(){}}
  vm.runInNewContext(readFileSync(new URL('../lib/client.js',import.meta.url),'utf8'),{window,document:{},URL,URLSearchParams,console:{warn(){},log(){}},Date,Promise,Map,Set,setTimeout,clearTimeout})
  const connection={rpc:{call:(_,method,payload)=>{assert.equal(method,'dsh-macos-notify/locale');packets.push(payload);return new Promise((resolve,reject)=>pending.push({resolve,reject}))}}}
  const ctx={get:k=>({locale,connection}[k]),on:()=>()=>{},effect:f=>cleanups.push(f())}
  definition.factory(()=>{throw Error('not available')}).apply(ctx)
  const close=()=>cleanups.forEach(f=>f?.())
  if(disposeImmediately)close()
  await new Promise(r=>setImmediate(r))
  return {packets,pending,timers,close,set:value=>{active=value;listeners.forEach(f=>f())},tick:()=>timers.forEach(f=>f()),settle:()=>new Promise(r=>setImmediate(r))}
 }
 const h=await harness();assert.equal(h.packets.length,1)
 h.set('zh');h.set('en');h.set('zh');assert.equal(h.packets.length,1,'no overlapping language RPC')
 h.pending.shift().resolve({});await h.settle();h.tick();await h.settle()
 assert.equal(h.packets.at(-1).locale,'zh');assert.equal(h.packets.at(-1).seq,2)
 h.pending.shift().reject(Error('temporary disconnect'));await h.settle();h.tick();await h.settle();assert.equal(h.packets.length,3)
 h.pending.shift().resolve({});await h.settle();h.set('fr');await h.settle();assert.equal(h.packets.at(-1).locale,'en')
 h.close();assert.equal(h.timers.size,0)
 const disposed=await harness(true);assert.equal(disposed.packets.length,0,'disposed view must not send scheduled RPC')
})

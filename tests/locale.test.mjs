import test from 'node:test'
import assert from 'node:assert/strict'
import {mkdtempSync,readFileSync,writeFileSync,rmSync,readdirSync} from 'node:fs'
import {tmpdir} from 'node:os'
import {join} from 'node:path'
import vm from 'node:vm'
import {apply} from '../lib/index.js'
import {createNotifications} from '../lib/notifications.js'
import {readUILanguage,uiText,uiStrings,supportedUILanguages} from '../lib/locale.js'

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
 for(const text of ['{partial',JSON.stringify({version:'1',locale:'zh'}),JSON.stringify({version:1,locale:'../../'}),JSON.stringify({version:1,locale:'it'}),JSON.stringify({version:1,locale:'toString'}),' '.repeat(1025)]) {
  writeFileSync(join(dir,'ui-language.json'),text);assert.equal(readUILanguage(dir),'en')
 }
 assert.equal(uiText('问题 {0}{1}',dir,{0:'{1}',1:'用户原文'}),'Question {1}用户原文')
})
test('client subscribes to official DSH locale, resends after reset, and disposes listeners',async()=>{
 let definition,Settings;let active='en',revision=1;const listeners=new Set(),cleanups=[],events=new Map(),packets=[]
 const React={useState:value=>[value,()=>{}],useEffect(){},createElement:(tag,props,...children)=>({tag,children})}
 const slots={inject:(_,f)=>f(),register:(_,component)=>{Settings=component}}
 const locale={getSnapshot:()=>({active,revision}),subscribe:f=>(listeners.add(f),()=>listeners.delete(f))}
 const window={__ModuleLoader__:{load:d=>definition=d},location:{protocol:'dsh-app:',search:'',href:'http://127.0.0.1/'},setInterval:()=>0,clearInterval(){},setTimeout:()=>0,clearTimeout(){},addEventListener(){},removeEventListener(){}}
 vm.runInNewContext(readFileSync(new URL('../lib/client.js',import.meta.url),'utf8'),{window,document:{hidden:false,hasFocus:()=>true,addEventListener(){},removeEventListener(){}},URL,URLSearchParams,console,Date,Promise,Map,Set,setTimeout,clearTimeout})
 const connection={rpc:{call:async(_,method,payload)=>{if(method.endsWith('/locale'))packets.push(payload);return {ok:true,value:null}}}}
 const ctx={get:k=>({locale,connection,slots,sessions:{list:{getSnapshot:()=>({ids:[],byId:{}}),subscribe:()=>()=>{}}}}[k]),on:(name,fn)=>{events.set(name,fn);return ()=>events.delete(name)},effect:f=>cleanups.push(f())}
 definition.factory(name=>{if(name==='react')return React;throw Error('not available')}).apply(ctx)
 await new Promise(r=>setImmediate(r));assert.equal(packets.at(-1)?.locale,'en')
 for(const value of ['zh','ja-JP','es-ES','fr-CA','de-DE','ru-RU','pt-BR','pt_PT','EN-us','zh-Hans','it','constructor',null]) {
  active=value;revision++;for(const f of listeners)f();await new Promise(r=>setImmediate(r));assert.equal(packets.at(-1)?.locale,({ 'ja-JP':'ja','es-ES':'es','fr-CA':'fr','de-DE':'de','ru-RU':'ru','pt-BR':'pt','pt_PT':'pt','EN-us':'en','zh-Hans':'zh',it:'en',constructor:'en',null:'en' })[value]??value)
  const resolved=packets.at(-1).locale,source='发送安全测试通知'
  assert.ok(JSON.stringify(Settings()).includes(resolved==='zh'?source:uiStrings[resolved][source]),'Settings must render the active language: '+value)
 }
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
 h.pending.shift().resolve({});await h.settle();h.set('fr');await h.settle();assert.equal(h.packets.at(-1).locale,'fr')
 h.close();assert.equal(h.timers.size,0)
 const disposed=await harness(true);assert.equal(disposed.packets.length,0,'disposed view must not send scheduled RPC')
})

test('every DSH language has complete copy and literal placeholders across state, RPC and notifications',async t=>{
 assert.deepEqual([...supportedUILanguages].sort(),['de','en','es','fr','ja','pt','ru','zh'])
 const dir=mkdtempSync(join(tmpdir(),'dsh-language-all-'));t.after(()=>rmSync(dir,{recursive:true,force:true}))
 const routes=new Map();apply({get:k=>k==='connection'?{fetch:{register:r=>routes.set(r.path,r)}}:null},{stateDir:dir})
 const notices=createNotifications({stateDir:dir}),keys=Object.keys(uiStrings.en).sort()
 const titles={en:'Task completed',ja:'タスク完了',es:'Tarea completada',fr:'Tâche terminée',de:'Aufgabe abgeschlossen',ru:'Задача завершена',pt:'Tarefa concluída',zh:'任务完成'}
 for(const [index,locale] of supportedUILanguages.entries()) {
  const response=await routes.get('/api/dsh-macos-notify/locale').fetch(new Request('http://localhost/api/dsh-macos-notify/locale',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({type:'client-request',rpcId:'locale',method:'dsh-macos-notify/locale',payload:{locale,clientId:'view-all',seq:index+1}})}))
  assert.equal(response.status,200);assert.equal(readUILanguage(dir),locale);assert.equal(uiText('任务完成',dir),titles[locale])
  if(locale!=='zh') {
   assert.deepEqual(Object.keys(uiStrings[locale]).sort(),keys)
   for(const key of keys) {
    assert.ok(uiStrings[locale][key]);assert.deepEqual(uiStrings[locale][key].match(/\{\d+\}/g)?.sort()??[],key.match(/\{\d+\}/g)?.sort()??[],locale+' / '+key)
   }
  }
  assert.ok(uiText('问题 {0}{1}',dir,{0:'{1}',1:'原文'}).includes('{1}原文'))
  notices.test('literal-'+locale)
  assert.ok(readdirSync(join(dir,'notifications')).map(f=>JSON.parse(readFileSync(join(dir,'notifications',f)))).some(n=>n.title===uiText('DSH Notify · 安全测试',dir)))
 }
})

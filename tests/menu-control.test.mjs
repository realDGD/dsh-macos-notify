import test from 'node:test'
import assert from 'node:assert/strict'
import {mkdtempSync,readFileSync,writeFileSync,statSync,existsSync,rmSync} from 'node:fs'
import {tmpdir} from 'node:os'
import {join} from 'node:path'
import {randomUUID} from 'node:crypto'
import {createSettings} from '../lib/settings.js'
import {installMenuControl} from '../lib/menu-control.js'
const sleep=ms=>new Promise(r=>setTimeout(r,ms))
function fixture(t) {
 const dir=mkdtempSync(join(tmpdir(),'menu-control-')),settings=createSettings(dir),disposals=[],clock={now:10000}
 t.after(()=>{disposals.forEach(fn=>fn());rmSync(dir,{recursive:true,force:true})})
 installMenuControl({effect:fn=>disposals.push(fn())},{stateDir:dir,settings,now:()=>clock.now})
 const put=(patch={},id=randomUUID(),raw)=>{const command={version:1,commandId:id,kind:'set-menu-enabled',createdAt:clock.now,enabled:false,...patch};writeFileSync(join(dir,'menu-commands',id+'.json'),raw??JSON.stringify(command));return id}
 const result=async id=>{for(let i=0;i<150;i++){try{return JSON.parse(readFileSync(join(dir,'menu-results',id+'.json'),'utf8'))}catch{await sleep(10)}}throw new Error('menu result timeout')}
 return {dir,settings,put,result,clock}
}
test('boolean-only validated command persists privately while display is disabled, duplicate IDs cannot reapply',async t=>{
 const f=fixture(t);const id=f.put();const result=await f.result(id)
 assert.equal(result.status,'accepted');assert.equal(result.commandId,id);assert.equal(result.enabled,false)
 assert.equal(f.settings.get().menuBarEnabled,false)
 assert.equal(statSync(join(f.dir,'menu-commands')).mode&0o777,0o700)
 assert.equal(statSync(join(f.dir,'menu-results',id+'.json')).mode&0o777,0o600)
 f.put({enabled:true},id);await sleep(300)
 assert.equal(f.settings.get().menuBarEnabled,false);assert.equal((await f.result(id)).completedAt,result.completedAt)
 const enable=f.put({enabled:true});assert.equal((await f.result(enable)).enabled,true);assert.equal(f.settings.get().menuBarEnabled,true)
})
test('UUID/time/kind/size/malformed binding reject without changing original preferences',async t=>{
 const f=fixture(t)
 const ids=[f.put({enabled:'false'}),f.put({kind:'approve-command'}),f.put({commandId:randomUUID()}),f.put({createdAt:-110001}),f.put({createdAt:20001}),f.put({method:'arbitrary'}),f.put({},randomUUID(),'{bad'),f.put({},randomUUID(),' '.repeat(4097))]
 const results=await Promise.all(ids.map(f.result))
 assert.deepEqual(results.map(r=>r.status),['invalid','invalid','invalid','stale','stale','invalid','invalid','invalid'])
 assert.equal(f.settings.get().menuBarEnabled,true)
 const unknown=join(f.dir,'menu-commands','not-ours.txt');writeFileSync(unknown,'preserve');await sleep(300);assert.ok(existsSync(unknown))
})
test('only bounded recognized results are cleaned; unrelated files survive',async t=>{
 const f=fixture(t),dir=join(f.dir,'menu-results');writeFileSync(join(dir,'other.txt'),'preserve')
 for(let i=0;i<140;i++){const id=randomUUID();writeFileSync(join(dir,id+'.json'),JSON.stringify({commandId:id,kind:'set-menu-enabled',status:'accepted',enabled:false,completedAt:i}))}
 await sleep(300)
 const {readdirSync}=await import('node:fs');assert.ok(readdirSync(dir).filter(n=>n.endsWith('.json')).length<=128);assert.ok(existsSync(join(dir,'other.txt')))
 f.clock.now=700000;await sleep(300);assert.equal(readdirSync(dir).filter(n=>n.endsWith('.json')).length,0)
})

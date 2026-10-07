import {randomUUID} from 'node:crypto'
import {mkdirSync,chmodSync,writeFileSync,renameSync} from 'node:fs'
import {join} from 'node:path'
import {buildMenuRows} from './menu-model.js'
import {createMenuSource} from './menu-source.js'
const services=['workspaceRegistry','sessions','agents','sessionTitle','sessionProjections','sessionQuery','sessionPersistence']
const get=(ctx,key)=>{try{return ctx.get(key)}catch{return undefined}}

/** Timers, leases and late asynchronous completions belong to this Host fiber. */
export function installSessionMenu(ctx,{stateDir,settings,pendingStates=()=>new Map(),now=Date.now}) {
  const generation=randomUUID(),file=join(stateDir,'session-menu.json')
  let disposed=false,enabled,source,abort,epoch=0,revision=0,history=[],availability='loading',pending=false,
    lastDiscovery=-Infinity,lastWrite=-Infinity,lastBody=''
  const capable=()=>typeof get(ctx,'sessions')?.list==='function'&&typeof get(ctx,'sessionQuery')?.listSessions==='function'
  const reset=()=>{
    epoch++;source?.dispose();abort?.abort();source=null;history=[];pending=false;lastDiscovery=-Infinity
    availability=enabled?(capable()?'loading':'unavailable'):'ready'
    if(enabled&&capable()){source=createMenuSource(ctx,{now});abort=new AbortController()}
  }
  const refresh=()=>{
    if(disposed)return
    try {
      const preference=settings.get().menuBarEnabled!==false
      if(preference!==enabled){enabled=preference;reset()}
      if(enabled&&source&&!pending&&now()-lastDiscovery>=30000) {
        pending=true;lastDiscovery=now();const cut=epoch,owner=source,signal=abort.signal
        owner.discover(signal).then(facts=>{
          if(disposed||epoch!==cut||signal.aborted)return
          history=facts;availability='ready';pending=false;refresh()
        },()=>{
          if(disposed||epoch!==cut||signal.aborted)return
          availability='unavailable';pending=false;refresh()
        })
      }
      const facts=new Map(enabled?history.map(f=>[f.id,f]):[])
      if(enabled&&source)for(const fact of source.liveFacts())facts.set(fact.id,fact)
      const waiting=pendingStates()
      const input=[...facts.values()].map(f=>({...f,waiting:waiting.get(f.id)??{questions:false,approval:false}}))
      const envelope={version:1,generation,revision:revision+1,updatedAt:now(),enabled,availability}
      const rows=buildMenuRows(input,{maxBytes:4194304-Buffer.byteLength(JSON.stringify(envelope))-2})
      const body=JSON.stringify({enabled,availability,...rows})
      const changed=body!==lastBody
      if((changed&&now()-lastWrite>=1000)||now()-lastWrite>=2000) {
        const bytes=JSON.stringify({...envelope,...rows})+'\n'
        if(Buffer.byteLength(bytes)>4194304)throw new Error('Menu snapshot bounds')
        mkdirSync(stateDir,{recursive:true,mode:0o700});chmodSync(stateDir,0o700)
        const temp=file+'.tmp-'+process.pid
        writeFileSync(temp,bytes,{mode:0o600});chmodSync(temp,0o600);renameSync(temp,file)
        revision++;lastWrite=now();lastBody=body
      }
    } catch { /* Menu failures must not change official notifications/answers. */ }
  }
  ctx.on?.('session/event',(session)=>{source?.invalidate(session.id);refresh()})
  ctx.on?.('internal/service',(name)=>{if(services.includes(name)&&enabled!==undefined){reset();refresh()}})
  const timer=setInterval(refresh,250);timer.unref?.()
  ctx.effect(()=>()=>{disposed=true;clearInterval(timer);epoch++;source?.dispose();abort?.abort();history=[]})
  refresh()
  return {refresh}
}

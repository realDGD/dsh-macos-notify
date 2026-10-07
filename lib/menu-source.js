import { basename } from 'node:path'
import { foldSurface, deriveEventMessage } from '@deepseek-ai/dsh-session'
import { currentSessionMessageProjections } from '@deepseek-ai/dsh-session-format-catalog/message-projections'
import { menuIdValid, singleLinePreview } from './menu-model.js'
const textOf = message => Array.isArray(message?.content)?message.content.filter(b=>b?.type==='text'&&typeof b.text==='string').map(b=>b.text).join(' '):''
const safeGet = (ctx,name) => { try{return ctx.get(name)}catch{return undefined} }

/** Official read-only cuts; never attach/activate a Session or retain full logs. */
export function createMenuSource(ctx,{now=Date.now,maxReadConcurrency=4}={}) {
  const cache=new Map(),headers=new Map(),invalidations=new Map(),lifetime=new AbortController()
  let disposed=false
  const service=name=>safeGet(ctx,name)
  const metadata=fact=>{
    const registry=service('workspaceRegistry'),workspaces=registry?.list?.()??[]
    let id=fact.id,workspace,seen=new Set()
    while(id&&!seen.has(id)) {
      seen.add(id);workspace=workspaces.find(w=>w.sessionIds?.includes(id))
      if(workspace)break;id=headers.get(id)?.parentSession
    }
    workspace??=workspaces.find(w=>w.path===headers.get(fact.id)?.cwd)
    const pins=registry?.pinnedSessionIds??[],pinIndex=pins.indexOf(fact.id)
    return {...fact,workspaceTitle:workspace?.title||basename(workspace?.path||headers.get(fact.id)?.cwd||'未命名工作区'),
      pinIndex:pinIndex<0?null:pinIndex,archived:(registry?.archivedSessionIds??[]).includes(fact.id),
      running:service('agents')?.get?.(fact.id)?.status==='running'}
  }
  const remember=(id,entry)=>{cache.delete(id);cache.set(id,entry);while(cache.size>2000)cache.delete(cache.keys().next().value)}
  const fold=(header,events,inherited,surface,project,todos,previous)=>{
    const fact=previous?{...previous}:{id:header.id,parentId:header.origin==='subagent'?(header.parentSession??null):null,origin:header.origin??null,
      workspaceTitle:'',sessionTitle:'',pinIndex:null,archived:false,blank:true,running:false,turn:null,terminal:null,
      userText:'',taskText:'',answerText:'',answerTurn:null,todos:null,waiting:{questions:false,approval:false},updatedAt:header.createdAt??0}
    for(const e of events) {
      if(e.seq<inherited)continue
      if(Number.isFinite(e.time))fact.updatedAt=Math.max(fact.updatedAt,e.time)
      if(e.type==='turn/start'&&Number.isSafeInteger(e.data?.turn)&&e.data.turn>=(fact.turn??0)) {
        fact.turn=e.data.turn;fact.terminal=null;fact.answerText='';fact.answerTurn=null
      }
      if(e.type==='turn/end'&&Number.isSafeInteger(e.data?.turn)&&e.data.turn>=(fact.turn??0)) {
        fact.turn=e.data.turn;fact.terminal={turn:e.data.turn,kind:e.data.reason?.kind,cause:e.data.reason?.reason?.kind,time:e.time}
      }
      if(e.type==='session/title'&&typeof e.data?.title==='string')fact.sessionTitle=e.data.title
    }
    fact.userText='';fact.taskText='';fact.answerText='';fact.answerTurn=null;fact.blank=true
    for(let i=surface.length-1;i>=0;i--) {
      const e=surface[i];if(e.seq<inherited)continue
      if(e.type!=='user/message'&&e.type!=='assistant/message')continue
      const message=project(e)
      if(!message)continue
      fact.blank=false
      const text=textOf(message)
      if(e.type==='user/message'&&message.source?.kind==='user'&&!fact.userText)fact.userText=singleLinePreview(text)
      if(e.type==='user/message'&&header.origin==='subagent'&&message.source?.kind==='agent-message'&&!fact.taskText&&text)fact.taskText=singleLinePreview(text)
      if(e.type==='assistant/message'&&e.data.turn===fact.turn&&!e.data.interrupted&&fact.answerTurn===null&&text) {
        fact.answerText=singleLinePreview(text);fact.answerTurn=e.data.turn
      }
    }
    fact.sessionTitle=singleLinePreview(fact.sessionTitle||'未命名会话',200)
    fact.todos=Array.isArray(todos)?todos.map(t=>({status:t?.status})):null
    return fact
  }
  const liveFacts=()=>{
    if(disposed)return []
    const sessions=service('sessions')?.list?.()??[]
    for(const s of sessions)headers.set(s.id,s.header)
    return sessions.filter(s=>menuIdValid(s.id)).map(s=>{
      const old=cache.get(s.id),key=`live:${s.seq}:${s.surface?.contentGeneration??0}:${invalidations.get(s.id)??0}`
      if(old?.key===key)return metadata(old.fact)
      const canAdvance=old?.source==='live'&&old.cursor<=s.seq-1
      const events=s.snapshotEvents(canAdvance?old.cursor+1:0)
      const surface=(s.surface?.nodes??[]).map(seq=>s.eventAt(seq)).filter(Boolean)
      const projection=service('sessionProjections')?.snapshot?.(s,['todos'])
      const fact=fold(s.header,events,s.inheritedEventCount??0,surface,e=>s.deriveEventMessage(e),projection?.values?.todos,canAdvance?old.fact:null)
      fact.sessionTitle=service('sessionTitle')?.get?.(s)?.title||fact.sessionTitle
      remember(s.id,{key,fact,cursor:s.seq-1,source:'live'})
      return metadata(fact)
    })
  }
  const discover=async externalSignal=>{
    if(disposed)return []
    const signal=externalSignal?AbortSignal.any([externalSignal,lifetime.signal]):lifetime.signal
    const query=service('sessionQuery')
    if(!query?.listSessions||!query?.observeSession)throw new Error('Session query unavailable')
    const records=await query.listSessions(signal)
    if(signal.aborted||disposed)return []
    for(const record of records)if(menuIdValid(record.header?.id))headers.set(record.header.id,record.header)
    const validIds=new Set(records.map(r=>r.header.id))
    for(const id of cache.keys())if(!validIds.has(id))cache.delete(id)
    for(const id of headers.keys())if(!validIds.has(id))headers.delete(id)
    const result=new Map(liveFacts().map(f=>[f.id,f])),cold=records.filter(r=>!result.has(r.header.id)&&menuIdValid(r.header.id))
    let position=0
    const worker=async()=>{
      while(!disposed&&!signal.aborted&&position<cold.length) {
        const id=cold[position++].header.id,epoch=invalidations.get(id)??0
        let observation
        try {
          const persistence=service('sessionPersistence'),identity=persistence?.identity
          const stat=await persistence?.stat?.(id,{signal}),old=cache.get(id)
          if(disposed||signal.aborted)continue
          if(stat&&old?.source==='cold'&&old.identity===identity&&old.revision===stat.revision&&old.epoch===epoch) {
            result.set(id,metadata(old.fact));continue
          }
          observation=await query.observeSession(id,{signal,projectionMode:'all'})
          if(disposed||signal.aborted)continue
          const key=`cold:${JSON.stringify(observation.revision??null)}:${observation.cursor}:${epoch}`
          let fact
          if(old?.key===key&&old.identity===identity)fact=old.fact
          else {
            const surface=foldSurface(observation.events,currentSessionMessageProjections)
            fact=fold(observation.header,observation.events,observation.inheritedEventCount,surface.nodes.map(seq=>observation.events[seq]),
              e=>deriveEventMessage(e,surface.projectedMessages),observation.projections?.values?.todos)
            fact.sessionTitle=observation.projections?.values?.title||fact.sessionTitle
          }
          if((invalidations.get(id)??0)!==epoch||service('sessions')?.get?.(id)||service('sessionPersistence')?.identity!==identity)continue
          remember(id,{key,fact,cursor:observation.cursor,source:'cold',identity,revision:observation.revision??stat?.revision,epoch});result.set(id,metadata(fact))
        } catch { /* Isolate corrupt/unavailable histories; never invent an end. */ }
        finally { observation?.[Symbol.dispose]?.() }
      }
    }
    await Promise.all(Array.from({length:Math.min(4,maxReadConcurrency,cold.length)},worker))
    if(disposed||signal.aborted)return []
    for(const fact of liveFacts())result.set(fact.id,fact)
    return [...result.values()]
  }
  return {liveFacts,discover,invalidate(id){invalidations.set(id,(invalidations.get(id)??0)+1)},
    dispose(){disposed=true;lifetime.abort();cache.clear();headers.clear();invalidations.clear()}}
}

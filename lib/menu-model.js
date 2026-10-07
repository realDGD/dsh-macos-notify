/** @typedef {{id:string,parentId:string|null,origin:string|null,workspaceTitle:string,sessionTitle:string,pinIndex:number|null,archived:boolean,blank:boolean,running:boolean,turn:number|null,terminal:{turn:number,kind:string,cause?:string,time:number}|null,userText:string,taskText:string,answerText:string,answerTurn:number|null,todos:Array<{status:string}>|null,waiting:{questions:boolean,approval:boolean},updatedAt:number}} MenuFact */
/** @typedef {{id:string,parentId:string|null,workspaceTitle:string,sessionTitle:string,state:string,preview:string,previewKind:string,pinned:boolean,pinIndex:number|null,progress:{completed:number,total:number}|null,childIds:string[],descendantBadge:string|null,updatedAt:number}} MenuNode */
/** @typedef {{nodes:MenuNode[],activeIds:string[],orphanIds:string[],historyIds:string[],omittedCount:number}} MenuRows */
export const menuIdValid = id => typeof id === 'string' && /^[A-Za-z0-9][A-Za-z0-9._-]{0,199}$/.test(id)
const clip = (text, limit) => { const chars=Array.from(text); return chars.length<=limit?text:chars.slice(0,Math.max(0,limit-1)).join('')+'…' }
export function singleLinePreview(text, limit=240) {
  if(typeof text!=='string') return '无文字输入'
  const plain=text.replace(/!\[[^\]]*\]\([^)]*\)/g,'').replace(/\[([^\]]+)\]\([^)]*\)/g,'$1')
    .replace(/<[^>]*>/g,'').replace(/^\s{0,3}(?:#{1,6}\s+|>\s*|[-*+]\s+|\d+\.\s+)/gm,'')
    .replace(/^\s*```[^\n]*$/gm,'').replace(/[`*_~]/g,'').replace(/\s+/gu,' ').trim()
  return clip(plain || '无文字输入',limit)
}
export function todoProgress(todos) {
  if(!Array.isArray(todos)||!todos.length||todos.some(t=>!['pending','in_progress','completed'].includes(t?.status))) return null
  return {completed:todos.filter(t=>t.status==='completed').length,total:todos.length}
}
function stateOf(f) {
  if(f.waiting?.questions) return 'waiting-questions'
  if(f.waiting?.approval) return 'waiting-approval'
  if(f.running) return 'running'
  const end=f.terminal?.turn===f.turn?f.terminal:null
  if(end?.kind==='aborted') return ({user:'stopped',parent:'parent-stopped',hook:'hook-stopped',disposed:'environment-stopped'})[end.cause]??'cancelled'
  return ({completed:'completed',error:'error',interrupted:'interrupted','max-tokens':'max-tokens',blocked:'paused'})[end?.kind]??'unknown'
}
const rankOf = state => ['waiting-questions','waiting-approval','error','interrupted','max-tokens'].includes(state)?1:state==='running'?2:3
const finiteTime = value => Number.isFinite(value)&&value>=0?value:0
/** Build display-only facts. No input fact or original message is modified. */
export function buildMenuRows(facts,{maxNodes=2000,maxBytes=4194304,activityIds=null}={}) {
  const map=new Map()
  for(const f of facts) {
    if(!menuIdValid(f?.id)||map.has(f.id)||f.archived) continue
    const state=stateOf(f), pinned=Number.isSafeInteger(f.pinIndex)&&f.pinIndex>=0
    const workspaceTitle=clip(singleLinePreview(f.workspaceTitle||'未分组'),100)
    const sessionTitle=clip(singleLinePreview(f.sessionTitle||'未命名会话'),197-Array.from(workspaceTitle).length)
    const answer=state==='completed'&&f.answerTurn===f.turn&&f.answerText
    const user=f.userText||f.taskText, previewKind=answer?'answer':f.userText?'user':f.taskText?'task':'empty'
    const terminal=f.terminal?.turn===f.turn&&!f.running&&!f.waiting?.questions&&!f.waiting?.approval?f.terminal:null
    const child=f.origin==='subagent'
    const node={id:f.id,parentId:child&&menuIdValid(f.parentId)?f.parentId:null,workspaceTitle,sessionTitle,state,
      preview:singleLinePreview(answer||user),previewKind,pinned,pinIndex:pinned?f.pinIndex:null,
      progress:todoProgress(f.todos),childIds:[],descendantBadge:null,
      activityToken:Number.isSafeInteger(f.turn)?'turn:'+f.turn:null,
      updatedAt:finiteTime(terminal?.time??f.updatedAt)}
    map.set(f.id,{node,child,blank:!!f.blank,
      active:(activityIds?.has(f.id)??false)||f.running||!!f.waiting?.questions||!!f.waiting?.approval,
      rank:pinned?0:rankOf(state),pin:pinned?f.pinIndex:Infinity,badge:null})
  }
  // Break cycles deterministically, without recursive walks or lost descendants.
  const done=new Set()
  for(const start of [...map.keys()].sort()) {
    if(done.has(start)) continue
    const path=[],local=new Set(); let id=start
    while(map.has(id)&&!done.has(id)) {
      if(local.has(id)) { map.get(id).node.parentId=null; break }
      local.add(id);path.push(id);id=map.get(id).node.parentId
    }
    for(const value of path) done.add(value)
  }
  const roots=[]
  for(const entry of map.values()) {
    const parent=map.get(entry.node.parentId)
    if(parent) parent.node.childIds.push(entry.node.id)
    else { entry.node.parentId=null; roots.push(entry) }
  }
  // Postorder once: descendants promote branch ordering while own states stay true.
  const ordered=[],stack=roots.map(e=>e.node.id)
  while(stack.length) { const id=stack.pop(),e=map.get(id);ordered.push(id);stack.push(...e.node.childIds) }
  for(let i=ordered.length-1;i>=0;i--) {
    const e=map.get(ordered[i])
    for(const childId of e.node.childIds) {
      const child=map.get(childId)
      e.active ||= child.active
      if(child.rank<e.rank||child.rank===0&&child.pin<e.pin) {
        e.rank=child.rank;e.pin=child.pin;e.badge=child.badge||child.node.state
      }
    }
    e.node.descendantBadge=e.badge
  }
  const compare=(a,b)=>a.rank-b.rank||(a.rank===0?a.pin-b.pin:0)||b.node.updatedAt-a.node.updatedAt||a.node.id.localeCompare(b.node.id)
  for(const e of map.values()) e.node.childIds.sort((a,b)=>compare(map.get(a),map.get(b)))
  const isActive=e=>activityIds===null?e.rank<3:e.active
  const active=roots.filter(e=>!e.child&&isActive(e)).sort(compare)
  const orphans=roots.filter(e=>e.child&&isActive(e)).sort(compare)
  const history=roots.filter(e=>!e.child&&!e.blank&&!isActive(e)).sort((a,b)=>b.node.updatedAt-a.node.updatedAt||a.node.id.localeCompare(b.node.id)).slice(0,5)
  const candidate=[]
  for(const root of [...active,...orphans,...history]) {
    const visit=[root.node.id]
    while(visit.length) { const id=visit.pop(),e=map.get(id);candidate.push(e.node);for(let i=e.node.childIds.length-1;i>=0;i--)visit.push(e.node.childIds[i]) }
  }
  const total=candidate.length
  let selected=candidate.slice(0,Math.max(0,Math.min(2000,maxNodes)))
  const make=()=>{
    const ids=new Set(selected.map(n=>n.id))
    return {nodes:selected.map(n=>({...n,childIds:n.childIds.filter(id=>ids.has(id))})),
      activeIds:active.map(e=>e.node.id).filter(id=>ids.has(id)),orphanIds:orphans.map(e=>e.node.id).filter(id=>ids.has(id)),
      historyIds:history.map(e=>e.node.id).filter(id=>ids.has(id)),omittedCount:total-selected.length}
  }
  let result=make(),bytes=Buffer.byteLength(JSON.stringify(result))
  while(bytes>maxBytes&&selected.length) {
    const drop=Math.max(1,Math.ceil((bytes-maxBytes)/(bytes/selected.length)))
    selected=selected.slice(0,Math.max(0,selected.length-drop));result=make();bytes=Buffer.byteLength(JSON.stringify(result))
  }
  return result
}

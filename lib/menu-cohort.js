// Track run boundaries before disk snapshots are coalesced. Never infer a new
// run from an old terminal fact, nor let a user cancellation color the icon.
export function createMenuCohort() {
  let id=0,revision=0,last=''
  const members=new Map(),ended=new Map()
  const key=turn=>Number.isSafeInteger(turn)?'turn:'+turn:'baseline'
  const running=()=>[...members.values()].some(m=>m.state==='running')
  const start=(sessionId,turn,state='running')=>{
    const token=key(turn),old=members.get(sessionId)
    if(old?.token===token){old.state=state;return}
    if(![...members.values()].some(m=>['running','waiting-questions','waiting-approval'].includes(m.state))){id++;members.clear()}
    members.set(sessionId,{token,state});ended.delete(sessionId)
    while(members.size>2000)members.delete(members.keys().next().value)
  }
  const terminalState=reason=>reason?.kind==='aborted'
    ? ({user:'stopped',parent:'parent-stopped',hook:'hook-stopped',disposed:'environment-stopped'})[reason.reason?.kind]??'cancelled'
    : ({completed:'completed',error:'error',interrupted:'interrupted','max-tokens':'max-tokens',blocked:'paused'})[reason?.kind]??'unknown'
  const finish=(sessionId,turn,reason)=>{
    const old=members.get(sessionId),token=key(turn)
    if(old && (old.token===token || old.token==='baseline')){
      old.token=token;old.state=terminalState(reason);ended.set(sessionId,token)
      while(ended.size>2000)ended.delete(ended.keys().next().value)
    }
  }
  const observe=facts=>{
    for(const f of facts){
      if(f.archived)continue
      const token=key(f.turn),terminal=f.terminal?.turn===f.turn?f.terminal:null
      const state=f.waiting?.questions?'waiting-questions':f.waiting?.approval?'waiting-approval':terminal
        ? terminalState({kind:terminal.kind,reason:{kind:terminal.cause}}):f.running?'running':'unknown'
      const old=members.get(f.id)
      if(old?.token===token){
        // Agent disposal can lag the authoritative turn/end event.
        if(!(state==='running' && ended.get(f.id)===token))old.state=state
      } else if(['running','waiting-questions','waiting-approval'].includes(state))start(f.id,f.turn,state)
      else if(old?.token==='baseline' && terminal)finish(f.id,f.turn,{kind:terminal.kind,reason:{kind:terminal.cause}})
    }
  }
  const snapshot=()=>{
    const states=[...members.values()].map(m=>m.state)
    const tone=states.some(s=>['waiting-questions','waiting-approval'].includes(s))?'yellow'
      :states.some(s=>['error','interrupted','max-tokens','environment-stopped','paused','cancelled'].includes(s))?'red'
      :states.includes('completed')?'green':'white'
    const digest=JSON.stringify([id,[...members],tone])
    if(digest!==last){revision++;last=digest}
    return {id,revision,running:running(),tone}
  }
  return {start,finish,observe,snapshot}
}

import {mkdirSync,chmodSync,readdirSync,lstatSync,readFileSync,writeFileSync,renameSync,unlinkSync} from 'node:fs'
import {join} from 'node:path'
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const ownFile=name=>name.endsWith('.json')&&uuid.test(name.slice(0,-5))
const read=path=>{try{const info=lstatSync(path);if(!info.isFile()||info.size>4096)return null;return JSON.parse(readFileSync(path,'utf8'))}catch{return null}}
const atomic=(file,value)=>{const temp=file+'.tmp-'+process.pid;writeFileSync(temp,JSON.stringify(value)+'\n',{mode:0o600});chmodSync(temp,0o600);renameSync(temp,file)}
export function installMenuControl(ctx,{stateDir,settings,now=Date.now}) {
  const commands=join(stateDir,'menu-commands'),results=join(stateDir,'menu-results')
  for(const dir of [commands,results]){mkdirSync(dir,{recursive:true,mode:0o700});chmodSync(dir,0o700)}
  let disposed=false
  const poll=()=>{
    if(disposed)return
    try {
      for(const name of readdirSync(commands)) {
        if(!ownFile(name))continue
        const file=join(commands,name)
        if(!lstatSync(file).isFile())continue
        const command=read(file),id=name.slice(0,-5)
        unlinkSync(file)
        const prior=read(join(results,name))
        if(prior?.commandId===id&&prior.kind==='set-menu-enabled')continue
        let status='invalid',enabled=settings.get().menuBarEnabled!==false
        if(command&&command.version===1&&command.commandId===id&&command.kind==='set-menu-enabled'
          &&typeof command.enabled==='boolean'&&Number.isFinite(command.createdAt)
          &&Object.keys(command).every(k=>['version','commandId','kind','enabled','createdAt'].includes(k))) {
          if(now()-command.createdAt>120000||command.createdAt-now()>10000)status='stale'
          else {try{enabled=settings.save({menuBarEnabled:command.enabled}).menuBarEnabled;status='accepted'}catch{status='failed'}}
        }
        atomic(join(results,name),{commandId:id,kind:'set-menu-enabled',enabled,status,completedAt:now()})
      }
      const retained=[]
      for(const name of readdirSync(results)) {
        if(!ownFile(name))continue
        const result=read(join(results,name))
        if(result?.commandId!==name.slice(0,-5)||result.kind!=='set-menu-enabled'||!Number.isFinite(result.completedAt))continue
        if(now()-result.completedAt>600000)unlinkSync(join(results,name))
        else retained.push({name,time:result.completedAt})
      }
      retained.sort((a,b)=>b.time-a.time||a.name.localeCompare(b.name))
      for(const entry of retained.slice(128))unlinkSync(join(results,entry.name))
    } catch { /* A settings transport failure never answers a tool request. */ }
  }
  const timer=setInterval(poll,250);timer.unref?.();ctx.effect(()=>()=>{disposed=true;clearInterval(timer)})
}

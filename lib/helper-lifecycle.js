import { readFileSync,statSync,existsSync } from 'node:fs'
import { homedir } from 'node:os'
import { join,resolve } from 'node:path'
import { spawn } from 'node:child_process'

// Only the official Desktop Host owns automatic helper startup. CLI profiles
// must not repeatedly launch a GUI helper when Desktop is absent.
export function installHelperLifecycle(ctx,{stateDir,home=homedir(),platform=process.platform,argv=process.argv,
 now=Date.now,launch=spawn,schedule=setInterval,cancel=clearInterval}) {
 if(platform!=='darwin' || !argv.some(arg=>typeof arg==='string' && /[/\\]@deepseek-ai[/\\]dsh-desktop-host[/\\]/.test(arg)) || typeof ctx.effect!=='function')return
 const app=join(home,'Applications/DSH Notify.app'),info=join(app,'Contents/Info.plist'),status=join(stateDir,'helper-status.json')
 ctx.effect(()=>{
  let disposed=false
  const ensure=()=>{
   if(disposed)return
   try {
    if(statSync(info).size>65536 || !readFileSync(info,'utf8').includes('<string>com.dgd.dsh-jump-notifier</string>') || !existsSync(join(app,'Contents/MacOS/DSHNotify')))return
    try {
     if(statSync(status).size<=4096) {
      const value=JSON.parse(readFileSync(status,'utf8'))
      if(Number.isSafeInteger(value.pid) && value.pid>0 && Number.isFinite(value.updatedAt) && Math.abs(now()-value.updatedAt)<5000)return
     }
    } catch {}
    // LaunchServices reuses an existing application instead of spawning copies.
    const child=launch('/usr/bin/open',['-g','-j','-a',app,'--args','--state-dir',resolve(stateDir)],{stdio:'ignore'})
    child.on('error',()=>{});child.unref()
   } catch { /* Helper installation/launch failure never breaks the Host. */ }
  }
  ensure();const timer=schedule(ensure,10000);timer.unref?.()
  return()=>{disposed=true;cancel(timer)}
 })
}

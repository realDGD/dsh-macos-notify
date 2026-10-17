import { readFileSync,statSync,existsSync } from 'node:fs'
import { homedir } from 'node:os'
import { join,resolve } from 'node:path'
import { spawn } from 'node:child_process'

// Our helper runs as this user, so a signal-0 probe is the same authority the
// Host already holds: it answers whether the recorded pid is still alive. Any
// failure (ESRCH, or a reused pid this user cannot signal) means "not our helper".
function pidAlive(pid) {
 try { process.kill(pid, 0); return true } catch { return false }
}

// A restart can leave the previous helper's status file looking fresh for a few
// seconds after that process exits, so the activation-time check may skip a
// launch that is about to become necessary. Probe a few times early instead of
// waiting a whole watchdog interval; LaunchServices never duplicates a running
// application, and every probe still honours the freshness+alive gate.
const RECOVERY_PROBES_MS = [1000, 2500, 5000]
const WATCHDOG_MS = 10000

// Only the official Desktop Host owns automatic helper startup. CLI profiles
// must not repeatedly launch a GUI helper when Desktop is absent.
export function installHelperLifecycle(ctx,{stateDir,home=homedir(),platform=process.platform,argv=process.argv,
 now=Date.now,launch=spawn,schedule=setInterval,cancel=clearInterval,defer=setTimeout,cancelDefer=clearTimeout,alive=pidAlive}) {
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
      if(Number.isSafeInteger(value.pid) && value.pid>0 && Number.isFinite(value.updatedAt) && Math.abs(now()-value.updatedAt)<5000 && alive(value.pid))return
     }
    } catch {}
    // LaunchServices reuses an existing application instead of spawning copies.
    const child=launch('/usr/bin/open',['-g','-j','-a',app,'--args','--state-dir',resolve(stateDir)],{stdio:'ignore'})
    child.on('error',()=>{});child.unref()
   } catch { /* Helper installation/launch failure never breaks the Host. */ }
  }
  ensure()
  const probes=RECOVERY_PROBES_MS.map(ms=>{const timer=defer(ensure,ms);timer.unref?.();return timer})
  const watchdog=schedule(ensure,WATCHDOG_MS);watchdog.unref?.()
  return()=>{disposed=true;cancel(watchdog);for(const timer of probes)cancelDefer(timer)}
 })
}

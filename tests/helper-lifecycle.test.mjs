import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync,mkdirSync,writeFileSync,rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { installHelperLifecycle } from '../lib/helper-lifecycle.js'
function fixture(t, overrides={}, {status,legacy=false}={}) {
 const home=mkdtempSync(join(tmpdir(),'notify-lifecycle-')),stateDir=join(home,'.dsh/dsh-jump'),applicationsDir=join(home,'Shared Applications')
 const app=join(legacy ? join(home,'Applications'):applicationsDir,'DSH Notify.app')
 mkdirSync(stateDir,{recursive:true});mkdirSync(join(app,'Contents/MacOS'),{recursive:true})
 writeFileSync(join(app,'Contents/Info.plist'),'<key>CFBundleIdentifier</key><string>com.dgd.dsh-jump-notifier</string>')
 writeFileSync(join(app,'Contents/MacOS/DSHNotify'),'fixture')
 if(status!==undefined)writeFileSync(join(stateDir,'helper-status.json'),JSON.stringify(status))
 const launches=[],cleanups=[],deferred=[];let tick,stopped=false,cancelled=0
 const options={stateDir,home,applicationsDir,platform:'darwin',argv:['desktop','/app/dsh/node_modules/@deepseek-ai/dsh-desktop-host/lib/index.js'],now:()=>10000,
  alive:()=>true,
  launch:(file,args)=>{launches.push({file,args});return {on(){return this},unref(){}}},
  schedule:fn=>{tick=fn;return {unref(){}}},cancel:()=>{stopped=true},
  defer:(fn,ms)=>{deferred.push({fn,ms});return {unref(){}}},cancelDefer:()=>{cancelled++},
  ...overrides}
 installHelperLifecycle({effect:fn=>cleanups.push(fn())},options)
 t.after(()=>{cleanups.forEach(fn=>fn());rmSync(home,{recursive:true,force:true})})
 return {home,stateDir,app,applicationsDir,launches,deferred,tick:()=>tick?.(),runProbe:()=>deferred.shift()?.fn(),
  dispose:()=>cleanups.forEach(fn=>fn()),stopped:()=>stopped,cancelled:()=>cancelled}
}
test('Desktop launches the helper quietly, skips a fresh live helper, retries a stale one and disposes its watchdog',t=>{
 const f=fixture(t);assert.equal(f.launches.length,1)
 assert.deepEqual(f.launches[0],{file:'/usr/bin/open',args:['-g','-j','-a',f.app,'--args','--state-dir',f.stateDir]})
 assert.deepEqual(f.deferred.map(p=>p.ms),[1000,2500,5000])
 writeFileSync(join(f.stateDir,'helper-status.json'),JSON.stringify({pid:123,updatedAt:9999}))
 f.tick();assert.equal(f.launches.length,1)
 f.runProbe();assert.equal(f.launches.length,1)
 writeFileSync(join(f.stateDir,'helper-status.json'),JSON.stringify({pid:123,updatedAt:1}))
 f.tick();assert.equal(f.launches.length,2)
 f.dispose();f.tick();assert.equal(f.launches.length,2);assert.equal(f.stopped(),true);assert.equal(f.cancelled(),3)
})
test('a helper status whose pid is gone is relaunched at activation, not after the watchdog',t=>{
 const dead=fixture(t,{alive:pid=>pid!==777},{status:{pid:777,updatedAt:9999}})
 assert.equal(dead.launches.length,1)
 const live=fixture(t,{alive:()=>true},{status:{pid:777,updatedAt:9999}})
 assert.equal(live.launches.length,0)
})
test('recovery probes relaunch after a restart race and stay silent after disposal',t=>{
 const f=fixture(t);assert.equal(f.launches.length,1)
 writeFileSync(join(f.stateDir,'helper-status.json'),JSON.stringify({pid:123,updatedAt:1}))
 f.runProbe();assert.equal(f.launches.length,2)
 const remaining=f.deferred.shift();f.dispose();remaining.fn();assert.equal(f.launches.length,2)
})
test('CLI, other platforms and uninstalled apps do not launch helpers',t=>{
 assert.equal(fixture(t,{argv:['node','/dsh/cli.js']}).launches.length,0)
 assert.equal(fixture(t,{platform:'linux'}).launches.length,0)
 assert.equal(fixture(t,{home:join(tmpdir(),'uninstalled-helper-fixture'),applicationsDir:join(tmpdir(),'uninstalled-applications-fixture')}).launches.length,0)
})

test('Desktop can start the legacy user app until migration, then prefers the shared app',t=>{
 const f=fixture(t,{}, {legacy:true})
 assert.equal(f.launches[0].args[3],f.app)
 const shared=join(f.applicationsDir,'DSH Notify.app')
 mkdirSync(join(shared,'Contents/MacOS'),{recursive:true})
 writeFileSync(join(shared,'Contents/Info.plist'),'<string>com.dgd.dsh-jump-notifier</string>')
 writeFileSync(join(shared,'Contents/MacOS/DSHNotify'),'fixture')
 f.tick()
 assert.equal(f.launches[1].args[3],shared)
})

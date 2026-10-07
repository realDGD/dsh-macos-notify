import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync,mkdirSync,writeFileSync,rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { installHelperLifecycle } from '../lib/helper-lifecycle.js'
function fixture(t, overrides={}) {
 const home=mkdtempSync(join(tmpdir(),'notify-lifecycle-')),stateDir=join(home,'.dsh/dsh-jump'),app=join(home,'Applications/DSH Notify.app')
 mkdirSync(stateDir,{recursive:true});mkdirSync(join(app,'Contents/MacOS'),{recursive:true})
 writeFileSync(join(app,'Contents/Info.plist'),'<key>CFBundleIdentifier</key><string>com.dgd.dsh-jump-notifier</string>')
 writeFileSync(join(app,'Contents/MacOS/DSHNotify'),'fixture')
 const launches=[],cleanups=[];let tick,stopped=false
 const options={stateDir,home,platform:'darwin',argv:['desktop','/app/dsh/node_modules/@deepseek-ai/dsh-desktop-host/lib/index.js'],now:()=>10000,
  launch:(file,args)=>{launches.push({file,args});return {on(){return this},unref(){}}},
  schedule:fn=>{tick=fn;return {unref(){}}},cancel:()=>{stopped=true},...overrides}
 installHelperLifecycle({effect:fn=>cleanups.push(fn())},options)
 t.after(()=>{cleanups.forEach(fn=>fn());rmSync(home,{recursive:true,force:true})})
 return {home,stateDir,app,launches,tick:()=>tick?.(),dispose:()=>cleanups.forEach(fn=>fn()),stopped:()=>stopped}
}
test('Desktop launches the helper quietly, retries stale helpers and disposes its watchdog',t=>{
 const f=fixture(t);assert.equal(f.launches.length,1)
 assert.deepEqual(f.launches[0],{file:'/usr/bin/open',args:['-g','-j','-a',f.app,'--args','--state-dir',f.stateDir]})
 writeFileSync(join(f.stateDir,'helper-status.json'),JSON.stringify({pid:123,updatedAt:9999}))
 f.tick();assert.equal(f.launches.length,1)
 writeFileSync(join(f.stateDir,'helper-status.json'),JSON.stringify({pid:123,updatedAt:1}))
 f.tick();assert.equal(f.launches.length,2)
 f.dispose();f.tick();assert.equal(f.launches.length,2);assert.equal(f.stopped(),true)
})
test('CLI, other platforms and uninstalled apps do not launch helpers',t=>{
 assert.equal(fixture(t,{argv:['node','/dsh/cli.js']}).launches.length,0)
 assert.equal(fixture(t,{platform:'linux'}).launches.length,0)
 assert.equal(fixture(t,{home:join(tmpdir(),'uninstalled-helper-fixture')}).launches.length,0)
})

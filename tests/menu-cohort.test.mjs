import test from 'node:test'
import assert from 'node:assert/strict'
import {createMenuCohort} from '../lib/menu-cohort.js'
test('overlapping runs retain priority while another fish keeps running',()=>{
 const c=createMenuCohort();c.start('A',1);c.start('B',1);c.start('C',1)
 const id=c.snapshot().id;c.finish('A',1,{kind:'completed'})
 assert.deepEqual({...c.snapshot(),revision:0},{id,revision:0,running:true,tone:'green'})
 c.finish('B',1,{kind:'error'});assert.equal(c.snapshot().tone,'red');assert.equal(c.snapshot().running,true)
 c.observe([{id:'C',turn:1,waiting:{approval:true},running:true}])
 assert.equal(c.snapshot().tone,'yellow');assert.equal(c.snapshot().running,false)
 c.observe([{id:'C',turn:1,running:true}]);assert.equal(c.snapshot().id,id);assert.equal(c.snapshot().running,true)
 c.finish('C',1,{kind:'completed'});assert.equal(c.snapshot().tone,'red');assert.equal(c.snapshot().running,false)
})
test('new B/C cohort excludes completed A, and user stops never color it',()=>{
 const c=createMenuCohort();c.start('A',1);c.finish('A',1,{kind:'completed'})
 const old=c.snapshot().id;c.start('B',1);c.start('C',1)
 assert.equal(c.snapshot().id,old+1);assert.equal(c.snapshot().tone,'white')
 c.finish('B',1,{kind:'aborted',reason:{kind:'user'}});assert.equal(c.snapshot().tone,'white')
 c.finish('C',1,{kind:'completed'});assert.equal(c.snapshot().tone,'green')
 c.start('only',1);c.finish('only',1,{kind:'aborted',reason:{kind:'user'}})
 assert.equal(c.snapshot().tone,'white');assert.equal(c.snapshot().running,false)
})
test('historical terminal facts and stale end events cannot fabricate a new run',()=>{
 const c=createMenuCohort();c.observe([{id:'old',turn:1,terminal:{turn:1,kind:'error'}}]);assert.equal(c.snapshot().tone,'white')
 c.start('A',2);c.finish('A',1,{kind:'error'});assert.equal(c.snapshot().running,true)
 c.finish('A',2,{kind:'completed'});c.observe([{id:'A',turn:2,running:true}]);assert.equal(c.snapshot().running,false)
 const before=c.snapshot();assert.deepEqual(c.snapshot(),before)
})

test('an unanswered approval remains in the batch when another task starts',()=>{
 const c=createMenuCohort();c.start('A',1);c.observe([{id:'A',turn:1,running:true,waiting:{approval:true}}])
 const before=c.snapshot();assert.equal(before.running,false)
 c.start('B',1);assert.equal(c.snapshot().id,before.id);assert.equal(c.snapshot().tone,'yellow');assert.equal(c.snapshot().running,true)
})

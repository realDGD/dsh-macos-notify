import {readFileSync,statSync,mkdirSync,writeFileSync,renameSync,chmodSync} from 'node:fs'
import {join} from 'node:path'
export const uiStrings=JSON.parse(readFileSync(new URL('../macos/assets/ui-strings.json',import.meta.url),'utf8'))
export function readUILanguage(stateDir) {
 try {const p=join(stateDir,'ui-language.json');if(statSync(p).size>1024)return 'en';const v=JSON.parse(readFileSync(p,'utf8'));return v.version===1&&['zh','en'].includes(v.locale)?v.locale:'en'}catch{return 'en'}
}
export function uiText(source,stateDir,params={}) {
 const text=readUILanguage(stateDir)==='zh'?source:uiStrings[source]??source
 return text.replace(/\{(\d+)\}/g,(m,k)=>Object.hasOwn(params,k)?String(params[k]):m)
}
export function createUILanguage(stateDir) {
 const sequences=new Map()
 return {get:()=>readUILanguage(stateDir),save(payload){
  if(!payload||!['en','zh'].includes(payload.locale)||typeof payload.clientId!=='string'||!/^view-[A-Za-z0-9-]{1,110}$/.test(payload.clientId)||!Number.isSafeInteger(payload.seq)||payload.seq<1)throw Error('Invalid UI language')
  if((sequences.get(payload.clientId)??0)>=payload.seq)return {locale:readUILanguage(stateDir)}
  mkdirSync(stateDir,{recursive:true,mode:0o700});chmodSync(stateDir,0o700)
  const target=join(stateDir,'ui-language.json'),tmp=target+'.tmp-'+process.pid
  writeFileSync(tmp,JSON.stringify({version:1,locale:payload.locale,updatedAt:Date.now()})+'\n',{mode:0o600});renameSync(tmp,target)
  sequences.delete(payload.clientId);sequences.set(payload.clientId,payload.seq)
  while(sequences.size>64)sequences.delete(sequences.keys().next().value)
  return {locale:payload.locale}
 }}
}

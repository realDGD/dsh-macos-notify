import Foundation
enum MenuSessionState:String,Codable,CaseIterable {
 case waitingQuestions="waiting-questions",waitingApproval="waiting-approval",error,interrupted,maxTokens="max-tokens",running,completed,stopped,paused,unknown
 var label:String {switch self {
 case .waitingQuestions:return "等待回答";case .waitingApproval:return "等待审批";case .error:return "出错"
 case .interrupted:return "异常中断";case .maxTokens:return "输出上限";case .running:return "运行中"
 case .completed:return "已完成";case .stopped:return "已停止";case .paused:return "已暂停";case .unknown:return "状态未知"
 }}
}
struct MenuProgress:Codable {let completed:Int;let total:Int}
struct MenuNode:Codable {
 let id:String;let parentId:String?;let workspaceTitle:String;let sessionTitle:String;let state:MenuSessionState
 let preview:String;let previewKind:String;let pinned:Bool;let pinIndex:Int?;let progress:MenuProgress?
 let childIds:[String];let descendantBadge:String?;let updatedAt:Double
 var title:String {workspaceTitle+" · "+sessionTitle}
 var accessibleLabel:String {
  var result=title+"，"+state.label
  if pinned {result+="，已固定"}
  if let progress=progress {result+="，任务 \(progress.completed)/\(progress.total)"}
  if let badge=descendantBadge,let status=MenuSessionState(rawValue:badge){result+="，子代理"+status.label}
  return result+"，"+preview
 }
}
struct MenuSnapshot:Codable {
 let version:Int;let generation:String;let revision:Int;let updatedAt:Double;let enabled:Bool;let availability:String
 let nodes:[MenuNode];let activeIds:[String];let orphanIds:[String];let historyIds:[String];let omittedCount:Int
}
func menuSessionIdValid(_ id:String)->Bool {
 id.range(of:#"^[A-Za-z0-9][A-Za-z0-9._-]{0,199}$"#,options:.regularExpression) != nil
}
final class SessionMenuStore {
 private(set) var snapshot:MenuSnapshot?
 private var invalid=false
 @discardableResult func ingest(_ data:Data,at now:Double)->Bool {
  guard data.count<=4194304,let value=try? JSONDecoder().decode(MenuSnapshot.self,from:data),valid(value,at:now) else {invalid=true;return false}
  invalid=false
  if let old=snapshot {
   if value.generation==old.generation && value.revision<=old.revision {return false}
   if value.generation != old.generation && value.updatedAt<old.updatedAt {return false}
  }
  snapshot=value;return true
 }
 func unavailable(){invalid=true}
 func isStale(at now:Double)->Bool {guard let value=snapshot else{return true};return now-value.updatedAt>6000}
 func status(at now:Double)->String {
  guard let value=snapshot else{return "等待 DSH 连接"}
  if isStale(at:now){return "DSH 未连接，内容可能过期"}
  if invalid || value.availability=="unavailable" {return "会话数据暂不可用，显示上次有效内容"}
  return value.availability=="loading" ? "正在加载会话…":"DSH 已连接"
 }
 private func valid(_ value:MenuSnapshot,at now:Double)->Bool {
  guard value.version==1,UUID(uuidString:value.generation) != nil,value.revision>=0,value.revision<=9007199254740991,
        value.updatedAt.isFinite,value.updatedAt>=0,value.updatedAt<=now+10000,["ready","loading","unavailable"].contains(value.availability),
        value.nodes.count<=2000,value.historyIds.count<=5,value.omittedCount>=0 else{return false}
  var byId:[String:MenuNode]=[:]
  for node in value.nodes {
   guard menuSessionIdValid(node.id),byId[node.id]==nil,node.title.unicodeScalars.count<=200,node.preview.unicodeScalars.count<=240,
         !node.preview.contains(where:{$0.isNewline}),["user","task","answer","empty"].contains(node.previewKind),
         node.childIds.count<=2000,Set(node.childIds).count==node.childIds.count,node.updatedAt.isFinite,node.updatedAt>=0,
         node.pinIndex==nil || node.pinIndex!>=0,node.descendantBadge==nil || MenuSessionState(rawValue:node.descendantBadge!) != nil else{return false}
   if let progress=node.progress {guard progress.total>0,progress.completed>=0,progress.completed<=progress.total else{return false}}
   byId[node.id]=node
  }
  let roots=value.activeIds+value.orphanIds+value.historyIds
  guard Set(roots).count==roots.count,roots.allSatisfy({byId[$0]?.parentId==nil && byId[$0] != nil}) else{return false}
  for node in value.nodes {
   if let parent=node.parentId {guard byId[parent]?.childIds.contains(node.id)==true else{return false}}
   else if !roots.contains(node.id) {return false}
   for child in node.childIds {guard byId[child]?.parentId==node.id else{return false}}
  }
  var done=Set<String>()
  for node in value.nodes {
   var local=Set<String>(),current:String?=node.id
   while let id=current,!done.contains(id) {
    if !local.insert(id).inserted{return false};current=byId[id]?.parentId
   }
   done.formUnion(local)
  }
  return true
 }
}

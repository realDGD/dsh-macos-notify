import Foundation
enum MenuInteractionAction:String {
 case allow,deny,details,answer
 var title:String {switch self{case .allow:return L("允许一次");case .deny:return L("拒绝");case .details:return L("查看详情");case .answer:return L("打开完整问答")}}
}
struct MenuInteraction:Equatable {
 let requestId:String,sessionId:String,kind:String,title:String
 let canSubmit:Bool
 var actions:[MenuInteractionAction] {kind=="approval" ? [.allow,.deny]:kind=="questions" ? [.answer]:[]}
 func enabled(_ action:MenuInteractionAction)->Bool {canSubmit || action == .details || action == .answer}
}
enum MenuSessionState:String,Codable,CaseIterable {
 case waitingQuestions="waiting-questions",waitingApproval="waiting-approval",error,interrupted,maxTokens="max-tokens",running,completed,stopped,paused,unknown
 case parentStopped="parent-stopped",hookStopped="hook-stopped",environmentStopped="environment-stopped",cancelled
 var label:String {switch self {
 case .waitingQuestions:return L("等待回答");case .waitingApproval:return L("等待审批");case .error:return L("出错")
 case .interrupted:return L("异常中断");case .maxTokens:return L("输出上限");case .running:return L("进行中")
 case .completed:return L("已完成");case .stopped:return L("用户停止");case .paused:return L("已暂停");case .unknown:return L("状态未知")
 case .parentStopped:return L("随主会话停止");case .hookStopped:return L("规则取消");case .environmentStopped:return L("运行环境停止");case .cancelled:return L("停止原因未知")
 }}
 var isLive:Bool {self == .running || self == .waitingQuestions || self == .waitingApproval}
 var isFailure:Bool {self == .error || self == .interrupted || self == .maxTokens}
}
struct MenuProgress:Codable,Equatable {let completed:Int;let total:Int}
struct MenuNode:Codable,Equatable {
 let id:String;let parentId:String?;let workspaceTitle:String;let sessionTitle:String;let state:MenuSessionState
 let preview:String;let previewKind:String;let pinned:Bool;let pinIndex:Int?;let progress:MenuProgress?
 let childIds:[String];let descendantBadge:String?;let updatedAt:Double
 let activityToken:String?
 var workspaceUnassigned:Bool? = nil
 var sessionUntitled:Bool? = nil
 var displaySessionTitle:String {sessionUntitled == true ? L("未命名"):sessionTitle}
 var title:String {(workspaceUnassigned == true ? L("未分组"):workspaceTitle)+" · "+displaySessionTitle}
 var displayPreview:String {previewKind == "empty" ? L("无文字输入"):preview}
 var accessibleLabel:String {
  var result=title+"，"+state.label
  if pinned {result+=L("，已置顶")}
  if let progress=progress {result+=L("，任务 {0}/{1}", ["0": String(describing: progress.completed), "1": String(describing: progress.total)])}
  if let badge=descendantBadge,let status=MenuSessionState(rawValue:badge){result+=L("，子智能体")+status.label}
  return result+"，"+displayPreview
 }
}
struct MenuSnapshot:Codable {
 let version:Int;let generation:String;let revision:Int;let updatedAt:Double;let enabled:Bool;let availability:String
 let cohort:MenuCohort?
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
  guard let value=snapshot else{return L("等待 DSH 连接")}
  if isStale(at:now){return L("DSH 未连接，内容可能过期")}
  if invalid || value.availability=="unavailable" {return L("会话数据暂不可用，显示上次有效内容")}
  return value.availability=="loading" ? L("正在加载会话…"):L("DSH 已连接")
 }
 private func valid(_ value:MenuSnapshot,at now:Double)->Bool {
  guard value.version==1,UUID(uuidString:value.generation) != nil,value.revision>=0,value.revision<=9007199254740991,
        value.updatedAt.isFinite,value.updatedAt>=0,value.updatedAt<=now+10000,["ready","loading","unavailable"].contains(value.availability),
        value.nodes.count<=2000,value.historyIds.count<=5,value.omittedCount>=0 else{return false}
  if let cohort=value.cohort {guard cohort.id>=0,cohort.revision>=0,["white","yellow","red","green"].contains(cohort.tone) else{return false}}
  var byId:[String:MenuNode]=[:]
  for node in value.nodes {
   guard menuSessionIdValid(node.id),byId[node.id]==nil,(node.workspaceTitle+" · "+node.sessionTitle).unicodeScalars.count<=200,node.preview.unicodeScalars.count<=240,
         !node.preview.contains(where:{$0.isNewline}),["user","task","answer","empty"].contains(node.previewKind),
         node.activityToken==nil || node.activityToken!.utf8.count<=100,
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

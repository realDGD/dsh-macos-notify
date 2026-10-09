import Cocoa
import UserNotifications
let stateDir=NSTemporaryDirectory()
func logLine(_ message:String) {}
@main @MainActor struct NativeMenuInteractionTests {
 static func descendants(_ view:NSView)->[NSView]{[view]+view.subviews.flatMap(descendants)}
 static func main() throws {
  UILocalization.set("zh")
  NSApplication.shared.setActivationPolicy(.prohibited)
  func check(_ value:Bool,_ message:String){if !value{print("FAIL "+message);exit(1)}}
  let directory=FileManager.default.temporaryDirectory.appendingPathComponent("native-menu-actions-"+UUID().uuidString)
  try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
  defer{try? FileManager.default.removeItem(at:directory)}
  let interactions=NotificationInteractions(directory:directory.path,center:nil)
  var approval=NativeRequest(id:"approval-1",kind:"approval",sessionId:"parent",title:"安全测试",subtitle:"测试",body:"审批一",questions:nil,phase:"foreground")
  var other=NativeRequest(id:"approval-2",kind:"approval",sessionId:"parent",title:"安全测试二",subtitle:"测试",body:"审批二",questions:nil,phase:"foreground")
  approval.approval=NativeApproval(toolName:"shell",reason:"读取一",callId:"call-1",arguments:nil,command:"echo FIRST")
  other.approval=NativeApproval(toolName:"shell",reason:"读取二",callId:"call-2",arguments:nil,command:"echo SECOND")
  let question=NativeRequest(id:"questions-1",kind:"questions",sessionId:"child",title:"三题测试",subtitle:"三题测试",body:"",questions:(1...3).map{NativeQuestion(id:"q\($0)",question:"选择并补充文字",header:nil,detail:nil,options:[NativeOption(label:"选项 A",description:nil)],multiSelect:$0 == 2)},phase:"foreground")
  func write(_ requests:[NativeRequest],aged:Bool=false) throws {
   let snapshot=NativeSnapshot(version:1,updatedAt:Date().timeIntervalSince1970*1000-(aged ? 10000:0),requests:requests,preferences:["approval":false,"questions":false])
   try JSONEncoder().encode(snapshot).write(to:directory.appendingPathComponent("interactions.json"),options:.atomic)
  }
  func commands()->[[String:Any]] {
   let folder=directory.appendingPathComponent("commands")
   return ((try? FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil)) ?? []).compactMap{try? JSONSerialization.jsonObject(with:Data(contentsOf:$0)) as? [String:Any]}
  }
  try write([approval,other,question]);interactions.poll()
  let items=interactions.menuInteractions()
  check(items.count==3 && items.filter{$0.sessionId=="parent"}.count==2,"pending menu requests lost or session association wrong")
  let first=items.first{$0.requestId==approval.id}!,second=items.first{$0.requestId==other.id}!,questions=items.first{$0.requestId==question.id}!
  check(first.title.contains("FIRST") && second.title.contains("SECOND") && first.title != second.title,"same-tool approvals have indistinguishable menu descriptions")
  check(first.actions==[.allow,.deny] && questions.actions==[.answer],"wrong actions for request kind")
  let generation=UUID().uuidString,now=Date().timeIntervalSince1970*1000
  let raw:[String:Any]=["version":1,"generation":generation,"revision":1,"updatedAt":now,"enabled":true,"availability":"ready","activeIds":["parent"],"orphanIds":[],"historyIds":[],"omittedCount":0,"nodes":[
   ["id":"parent","parentId":NSNull(),"workspaceTitle":"工作区","sessionTitle":"主会话","state":"waiting-approval","preview":"最后一次输入","previewKind":"user","pinned":false,"childIds":["child"],"updatedAt":now],
   ["id":"child","parentId":"parent","workspaceTitle":"工作区","sessionTitle":"子代理","state":"waiting-questions","preview":"子代理输入","previewKind":"user","pinned":false,"childIds":[],"updatedAt":now]]]
  let snapshot=try JSONDecoder().decode(MenuSnapshot.self,from:JSONSerialization.data(withJSONObject:raw))
  let node=snapshot.nodes[0]
  var calls:[String]=[]
  var fixtureWindows:[NSWindow]=[]
  func layout(_ row:NSView,width:CGFloat) {
   let host=NSView(frame:NSRect(x:0,y:0,width:width,height:64))
   let window=NSWindow(contentRect:host.frame,styleMask:[],backing:.buffered,defer:false)
   row.translatesAutoresizingMaskIntoConstraints=false;host.addSubview(row);window.contentView=host
   NSLayoutConstraint.activate([row.leadingAnchor.constraint(equalTo:host.leadingAnchor),row.trailingAnchor.constraint(equalTo:host.trailingAnchor),row.topAnchor.constraint(equalTo:host.topAnchor),row.bottomAnchor.constraint(equalTo:host.bottomAnchor)])
   host.layoutSubtreeIfNeeded();fixtureWindows.append(window)
  }
  let row=SessionMenuRowView(node:node,depth:0,expanded:false,stale:false,interactions:[first],onDisclosure:{}){item,action in calls.append(item.requestId+":"+action.rawValue)}
  layout(row,width:400)
  for _ in 0..<4 {row.needsLayout=true;row.layoutSubtreeIfNeeded()}
  let allow=descendants(row).compactMap{$0 as? NSButton}.first{$0.title=="允许一次"}!
  let deny=descendants(row).compactMap{$0 as? NSButton}.first{$0.title=="拒绝"}!
  let allowRect=allow.convert(allow.bounds,to:row),denyRect=deny.convert(deny.bounds,to:row)
  check(allowRect.size==NSSize(width:76,height:22) && denyRect.size==NSSize(width:76,height:22),"custom approval frames include native bezel alignment margins: \(allowRect) \(denyRect)")
  check(abs(allowRect.midX-denyRect.midX)<1 && abs(allowRect.midY-denyRect.midY)>18,"approval buttons are not vertically stacked")
  check(!descendants(row).compactMap{$0 as? NSButton}.contains{$0.title=="查看详情"},"menu retains redundant details button")
  check(!allowRect.intersects(row.title.frame) && !denyRect.intersects(row.preview.frame),"stacked approvals cover session text: \(allowRect) \(denyRect) vs \(row.title.frame) \(row.preview.frame)")
  check(allow.bezelColor == MenuStatusPalette.green && deny.bezelColor == MenuStatusPalette.red,"approval button colors missing")
  allow.performClick(nil);check(calls==["approval-1:allow"],"row Allow targeted another request or navigated")
  let disabled=SessionMenuRowView(node:node,depth:0,expanded:false,stale:true,interactions:[first],onDisclosure:{}){_,_ in calls.append("stale")}
  layout(disabled,width:400)
  check(descendants(disabled).compactMap{$0 as? NSButton}.filter{["允许一次","拒绝","查看详情","处理请求"].contains($0.title)}.allSatisfy{!$0.isEnabled},"stale row allows mutation")
  let grouped=SessionMenuRowView(node:node,depth:8,expanded:false,stale:false,interactions:[first,second],onDisclosure:{}){item,action in calls.append(item.requestId+":"+action.rawValue)}
  layout(grouped,width:280)
  let picker=descendants(grouped).compactMap{$0 as? NSPopUpButton}.first!
  let entries=picker.menu!.items.filter{$0.submenu != nil}
  check(Set(entries.map{$0.title}).count==2,"approval entries lack stable disambiguators")
  let pickerRect=picker.convert(picker.bounds,to:grouped)
  check(grouped.bounds.width<=280,"action controls expanded the fixed row width")
  check(!picker.isHidden && pickerRect.minX>=0 && pickerRect.maxX<=grouped.bounds.width,"multi-request/narrow controls clipped")
  let rejectSecond=picker.menu!.items.last!.submenu!.items.first{$0.title=="拒绝"}!
  _=rejectSecond.target?.perform(rejectSecond.action,with:rejectSecond)
  check(calls.last=="approval-2:deny","multi-request action ambiguously targets first approval")
  // A tracking menu can outlive its table cell during a timed refresh.
  let detached:NSMenu=autoreleasepool {
   let twin=MenuInteraction(requestId:second.requestId,sessionId:second.sessionId,kind:second.kind,title:first.title,canSubmit:true)
   let temporary=SessionMenuRowView(node:node,depth:0,expanded:false,stale:false,interactions:[first,twin],onDisclosure:{}){item,action in calls.append(item.requestId+":"+action.rawValue)}
   let menu=descendants(temporary).compactMap{$0 as? NSPopUpButton}.first!.menu!
   check(Set(menu.items.filter{$0.submenu != nil}.map{$0.title}).count==2,"identical commands lack request ordinal labels")
   return menu
  }
  calls.append("detached")
  let detachedDeny=detached.items.last!.submenu!.items.first{$0.title=="拒绝"}!
  _=detachedDeny.target?.perform(detachedDeny.action,with:detachedDeny)
  check(calls.last=="approval-2:deny","refresh destroyed a tracking menu action target")
  let content=SessionMenuViewController(availableSize:NSSize(width:420,height:600))
  content.update(snapshot:snapshot,status:"已连接",stale:false,error:nil,interactions:items)
  content.toggle("parent");content.view.layoutSubtreeIfNeeded()
  let childRow=content.table.view(atColumn:0,row:1,makeIfNecessary:true) as! SessionMenuRowView
  check(descendants(childRow).compactMap{$0 as? NSButton}.contains{$0.title=="打开完整问答"},"nested question row missing form entry")
  try JSONSerialization.data(withJSONObject:raw).write(to:directory.appendingPathComponent("session-menu.json"))
  let controller=SessionMenuController(directory:directory.path,openSession:{_,_ in calls.append("unexpected navigation")},openDesktop:{false},interactions:{interactions.menuInteractions()},performInteraction:{interactions.handleMenuInteraction($0,action:$1)})
  controller.poll(at:now);controller.act(first,action:.allow,at:now)
  check(commands().count==1 && commands()[0]["requestId"] as? String==approval.id && commands()[0]["answer"] as? String=="allowed-once","Allow command binding or payload wrong")
  _=interactions.handleMenuInteraction(first,action:.deny)
  check(commands().count==1 && interactions.menuInteractions().first{$0.requestId==approval.id}?.canSubmit==false,"duplicate approval command emitted")
  check(interactions.handleMenuInteraction(first,action:.details)==nil,"approval details unavailable during submission")
  let approvalForm=NSApplication.shared.windows.first{$0.title.contains("审批详情")}!
  let approvalButtons=descendants(approvalForm.contentView!).compactMap{$0 as? NSButton}.filter{["允许一次","拒绝"].contains($0.title)}
  check(approvalButtons.count==2 && approvalButtons.allSatisfy{!$0.isEnabled},"details reopened mutable controls while approval is submitting")
  let resultDir=directory.appendingPathComponent("results");try FileManager.default.createDirectory(at:resultDir,withIntermediateDirectories:true)
  let commandId=commands()[0]["commandId"] as! String
  try Data("{\"status\":\"accepted\"}".utf8).write(to:resultDir.appendingPathComponent(commandId+".json"))
  interactions.poll()
  check(!interactions.menuInteractions().contains{$0.requestId==approval.id},"accepted approval reappears while Host snapshot lags")
  _=interactions.handleMenuInteraction(first,action:.allow)
  check(commands().count==1,"accepted approval submitted twice before Host withdrawal")
  approvalForm.performClose(nil)
  check(interactions.handleMenuInteraction(second,action:.deny)==nil,"valid menu Deny rejected")
  check(commands().contains{$0["requestId"] as? String==other.id && $0["answer"] as? String=="rejected"},"Deny approval result wrong")
  try write([question]);check(interactions.handleMenuInteraction(first,action:.allow) != nil && commands().count==2,"DSH-settled request accepted again from menu")
  let wrong=MenuInteraction(requestId:question.id,sessionId:"parent",kind:"questions",title:"错位",canSubmit:true)
  check(interactions.handleMenuInteraction(wrong,action:.answer) != nil,"cross-session request mismatch accepted")
  check(interactions.handleMenuInteraction(questions,action:.answer)==nil,"full question entry failed")
  let form=NSApplication.shared.windows.first{$0.title.contains("三题测试")}!
  let editors=descendants(form.contentView!).compactMap{$0 as? NSTextView}.filter{$0.isEditable}
  check(editors.count==3,"menu form loses independent question inputs")
  editors.first!.string="未提交草稿"
  _=interactions.handleMenuInteraction(questions,action:.answer)
  check(editors.first!.string=="未提交草稿" && NSApplication.shared.windows.filter{$0.title.contains("三题测试")}.count==1,"menu reentry replaces form draft")
  let draftTexts=["第一题\n保留换行", "第二题独立补充", "第三题 ✨"]
  for (editor,text) in zip(editors,draftTexts) {editor.string=text}
  let choices=descendants(form.contentView!).compactMap{$0 as? NSButton}.filter{$0.title.isEmpty && $0.tag==0}
  check(choices.count==3,"test needs each question's original choice control")
  choices.forEach{$0.performClick(nil)}
  form.performClose(nil)
  check(interactions.handleMenuInteraction(questions,action:.answer)==nil,"closed question cannot reopen")
  let reopened=NSApplication.shared.windows.first{$0.title.contains("三题测试") && $0.isVisible}!
  let restored=descendants(reopened.contentView!).compactMap{$0 as? NSTextView}.filter{$0.isEditable}
  check(restored.map{$0.string}==draftTexts,"closing the question window discards independent drafts")
  check(descendants(reopened.contentView!).compactMap{$0 as? NSButton}.filter{$0.title.isEmpty && $0.tag==0}.allSatisfy{$0.state == .on},"closing the question window loses single/multi-select choices")
  let clear=descendants(reopened.contentView!).compactMap{$0 as? NSButton}.first{$0.title=="清空回答"}
  check(clear != nil && clear!.isEnabled,"question form has no enabled Clear answers button for a draft")
  let submit=descendants(reopened.contentView!).compactMap{$0 as? NSButton}.first{$0.title=="提交全部回答"}!
  clear!.performClick(nil)
  check(restored.allSatisfy{$0.string.isEmpty},"Clear answers leaves question text behind")
  check(choices.allSatisfy{$0.state == .off},"Clear answers leaves radio/checkbox choices selected")
  check(!clear!.isEnabled && !submit.isEnabled && commands().count==2,"Clear answers submits/cancels the request or leaves invalid controls enabled")
  check(descendants(reopened.contentView!).compactMap{$0 as? NSTextField}.contains{$0.stringValue.hasPrefix("已回答 0 / 3")},"Clear answers does not reset the answer count")
  for (editor,text) in zip(restored,draftTexts) {editor.string=text}
  choices.forEach{$0.performClick(nil)}
  reopened.performClose(nil)
  func leaseIds()->[String] {
   let data=try! Data(contentsOf:directory.appendingPathComponent("open-panels.json"))
   let lease=try! JSONSerialization.jsonObject(with:data) as! [String:Any]
   return (lease["ids"] as! [String]) + (lease["draftIds"] as? [String] ?? [])
  }
  check(leaseIds().contains(question.id),"closed unsent drafts are unprotected during upgrade")
  let closedLease=try JSONSerialization.jsonObject(with:Data(contentsOf:directory.appendingPathComponent("open-panels.json"))) as! [String:Any]
  check((closedLease["ids"] as! [String]).isEmpty,"a hidden draft holds the official question wait open")
  try write([question],aged:true);interactions.poll()
  check(leaseIds().contains(question.id),"disconnect drops protection for a closed draft")
  interactions.handle(id:question.id,action:NotificationInteractions.answer);interactions.poll()
  check(leaseIds().contains(question.id),"notification reentry during disconnect discards a closed draft")
  try write([question]);check(interactions.handleMenuInteraction(questions,action:.answer)==nil,"reconnected question cannot reopen")
  let reconnected=NSApplication.shared.windows.first{$0.title.contains("三题测试") && $0.isVisible}!
  check(reconnected === reopened,"reconnect replaces the original form")
  check(descendants(reconnected.contentView!).compactMap{$0 as? NSTextView}.filter{$0.isEditable}.map{$0.string}==draftTexts,"reconnect discards closed drafts")
  reconnected.performClose(nil)
  try write([]);interactions.poll()
  check(leaseIds().isEmpty,"withdrawn request retains a draft lease")
  check(restored.allSatisfy{$0.string.isEmpty} && choices.allSatisfy{$0.state == .off},"Host withdrawal leaves obsolete answers in the retained controller")
  check(!clear!.isEnabled,"withdrawn request allows clearing or editing")
  try write([question]);_ = interactions.handleMenuInteraction(questions,action:.answer)
  let fresh=NSApplication.shared.windows.first{$0.title.contains("三题测试") && $0.isVisible}!
  let freshEditors=descendants(fresh.contentView!).compactMap{$0 as? NSTextView}.filter{$0.isEditable}
  check(freshEditors.allSatisfy{$0.string.isEmpty},"withdrawn request resurrects its old drafts")
  check(descendants(fresh.contentView!).compactMap{$0 as? NSButton}.filter{$0.title.isEmpty && $0.tag==0}.allSatisfy{$0.state == .off},"withdrawn request resurrects choices")
  fresh.performClose(nil)
  check(leaseIds().isEmpty,"closing an empty form should not block upgrades")
  for resultStatus in ["accepted","stale"] {
   let request=NativeRequest(id:"question-"+resultStatus,kind:"questions",sessionId:"child",title:resultStatus,subtitle:resultStatus,body:"",questions:question.questions,phase:"foreground")
   try write([request]);interactions.poll()
   let item=interactions.menuInteractions().first{$0.requestId==request.id}!
   check(interactions.handleMenuInteraction(item,action:.answer)==nil,"result fixture cannot open")
   let window=NSApplication.shared.windows.first{$0.title=="DSH · "+resultStatus+" · 问答" && $0.isVisible}!
   let fields=descendants(window.contentView!).compactMap{$0 as? NSTextView}.filter{$0.isEditable}
   fields.forEach{$0.string="pending "+resultStatus}
   descendants(window.contentView!).compactMap{$0 as? NSButton}.filter{$0.title.isEmpty && $0.tag==0}.forEach{$0.performClick(nil)}
   let reset=descendants(window.contentView!).compactMap{$0 as? NSButton}.first{$0.title=="清空回答"}!
   let send=descendants(window.contentView!).compactMap{$0 as? NSButton}.first{$0.title=="提交全部回答"}!
   send.performClick(nil)
   check(!reset.isEnabled && fields.allSatisfy{!$0.isEditable},"submitting form can clear or alter its in-flight answers")
   window.performClose(nil)
   let command=commands().first{$0["requestId"] as? String==request.id}!
   try JSONSerialization.data(withJSONObject:["status":resultStatus]).write(to:resultDir.appendingPathComponent((command["commandId"] as! String)+".json"))
   interactions.poll()
   check(fields.allSatisfy{$0.string.isEmpty} && !reset.isEnabled && leaseIds().isEmpty,"settled native result retains its old answers or upgrade lease")
   check(interactions.handleMenuInteraction(item,action:.answer) != nil,"settled request reopens mutable answers while Host snapshot lags")
  }
  let unknown=NativeRequest(id:"question-timeout",kind:"questions",sessionId:"child",title:"unknown",subtitle:"unknown",body:"",questions:question.questions,phase:"foreground")
  try write([unknown]);interactions.poll()
  let unknownItem=interactions.menuInteractions().first{$0.requestId==unknown.id}!
  _=interactions.handleMenuInteraction(unknownItem,action:.answer)
  let unknownWindow=NSApplication.shared.windows.first{$0.title=="DSH · unknown · 问答" && $0.isVisible}!
  let unknownFields=descendants(unknownWindow.contentView!).compactMap{$0 as? NSTextView}.filter{$0.isEditable}
  unknownFields.forEach{$0.string="verify in DSH before retry"}
  descendants(unknownWindow.contentView!).compactMap{$0 as? NSButton}.filter{$0.title.isEmpty && $0.tag==0}.forEach{$0.performClick(nil)}
  descendants(unknownWindow.contentView!).compactMap{$0 as? NSButton}.first{$0.title=="提交全部回答"}!.performClick(nil)
  Thread.sleep(forTimeInterval:15.1);interactions.poll()
  check(unknownFields.allSatisfy{$0.string=="verify in DSH before retry" && !$0.isEditable},"unknown result must retain read-only answers for verification")
  try write([]);interactions.poll()
  check(unknownFields.allSatisfy{$0.string.isEmpty},"authoritative withdrawal after an unknown result leaves obsolete drafts")
  unknownWindow.performClose(nil)
  let beforeStale=commands().count
  controller.act(second,action:.deny,at:now+7000)
  check(commands().count==beforeStale,"stale session menu allowed a submission")
  try write([question],aged:true);check(interactions.handleMenuInteraction(questions,action:.answer) != nil,"aged snapshot still permits menu action")
  let blocked=directory.appendingPathComponent("blocked");try FileManager.default.createDirectory(at:blocked,withIntermediateDirectories:true)
  try Data("not a directory".utf8).write(to:blocked.appendingPathComponent("commands"))
  let payload=NativeSnapshot(version:1,updatedAt:Date().timeIntervalSince1970*1000,requests:[approval])
  try JSONEncoder().encode(payload).write(to:blocked.appendingPathComponent("interactions.json"))
  let failing=NotificationInteractions(directory:blocked.path,center:nil);failing.poll()
  check(failing.handleMenuInteraction(failing.menuInteractions()[0],action:.allow) != nil,"queue write failure returned success to menu")
  print("PASS native menu request binding, stale/duplicate protection, three-question close/reopen drafts, Clear answers, settled cleanup, disconnect and upgrade protection")
 }
}

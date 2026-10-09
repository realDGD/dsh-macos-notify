import Cocoa
import UserNotifications
let stateDir=NSTemporaryDirectory()
func logLine(_ text:String) {}
@main @MainActor struct NativeLocalizationTests {
 static func descendants(_ v:NSView)->[NSView] {[v]+v.subviews.flatMap(descendants)}
 static func main() {
  NSApplication.shared.setActivationPolicy(.prohibited)
  UILocalization.set("zh")
  let question=NativeQuestion(id:"opaque",question:"保持原文",header:"部署",detail:nil,options:[NativeOption(label:"允许本次",description:"原始选项")],multiSelect:false)
  let editor=QuestionEditor(question,number:1);editor.input.string="草稿 {0} $(echo private)"
  descendants(editor.view).compactMap{$0 as? NSButton}.first!.performClick(nil)
  let request=NativeRequest(id:"localization",kind:"questions",sessionId:"demo-session",title:"等待回答",subtitle:"测试会话",body:"",questions:[question],phase:nil)
  let controller=QuestionWindow(request);let root=controller.window!.contentView!
  let windowInput=descendants(root).compactMap{$0 as? NSTextView}.first!
  windowInput.string="窗口草稿 {0}"
  let windowOption=descendants(root).compactMap{$0 as? NSButton}.first{$0.accessibilityLabel()=="允许本次"}!
  windowOption.performClick(nil)
  let oldInput=editor.input
  UILocalization.set("en")
  let buttons=descendants(root).compactMap{$0 as? NSButton}.map{$0.title}
  precondition(buttons.contains("Submit all answers"),"Question window must switch to English")
  precondition(buttons.contains("View related context and session information"),"Context toggle must switch")
  precondition(editor.input === oldInput && editor.input.string=="草稿 {0} $(echo private)","Draft and input identity must survive switching")
  precondition(editor.answer["selected"] as? [String]==["允许本次"],"Original option labels must survive switching")
  precondition(descendants(editor.view).compactMap{$0 as? NSTextField}.contains{$0.stringValue=="保持原文"},"Question content must not be translated")
  precondition(controller.window!.title.hasSuffix(" · Questions"),"Window title must switch")
  precondition(descendants(root).contains{$0 === windowInput} && windowInput.string=="窗口草稿 {0}" && windowOption.state == .on,"Open window input and selection must survive")
  controller.window!.setContentSize(NSSize(width:460,height:400))
  controller.failed(L("此请求已在 DSH 回答、取消或失效，无需再次提交。"))
  root.layoutSubtreeIfNeeded()
  let status=descendants(root).compactMap{$0 as? NSTextField}.first{$0.stringValue.hasPrefix("This request has been answered")}!
  let measured=status.cell!.cellSize(forBounds:NSRect(x:0,y:0,width:status.frame.width,height:10000)).height
  fputs("English status frame=\(status.frame), measured=\(measured), root=\(root.bounds)\n",stderr)
  precondition(status.frame.height+1>=measured && status.frame.minX>=0 && status.frame.maxX<=root.bounds.width,"English status must wrap within narrow window")
  for button in descendants(root).compactMap({$0 as? NSButton}).filter({["Open in DSH","Submit all answers"].contains($0.title)}) {
   let bounds=button.convert(button.bounds,to:root)
   precondition(bounds.minX>=0 && bounds.maxX<=root.bounds.width && bounds.minY>=0,"English footer must fit narrow window")
  }
  let first=NotificationInteractions.content(request)
  precondition(first.categoryIdentifier=="DSH_QUESTIONS.en" && first.title=="Questions to answer: 1","New notification must follow active language")
  UILocalization.set("zh")
  precondition(first.categoryIdentifier=="DSH_QUESTIONS.en","Delivered content language must remain unchanged")
  let categories=NotificationInteractions.categories()
  precondition(categories.first{$0.identifier=="DSH_APPROVAL.en"}!.actions.first!.title=="Allow once","Old English notification action remains English")
  precondition(categories.first{$0.identifier=="DSH_APPROVAL.zh"}!.actions.first!.title=="允许一次","Chinese actions exist simultaneously")
  precondition(categories.first{$0.identifier=="DSH_APPROVAL.en"}!.actions[1].title=="Reject","Official English approval term")
  precondition(categories.first{$0.identifier=="DSH_APPROVAL"}!.actions.first!.title=="允许本次 (Allow)","Legacy delivered notification wording stays stable")
  UILocalization.set("en")
  var unnamed=NativeRequest(id:"unnamed",kind:"approval",sessionId:"opaque",title:"",subtitle:"未命名会话",body:"",questions:nil,phase:nil,approval:NativeApproval(toolName:"操作",reason:"原因 {0}",callId:nil,arguments:"{\"command\":\"echo 中文\"}",command:"echo 中文",toolUnnamed:true),sessionUntitled:true)
  let approval=QuestionWindow(unnamed)
  approval.window!.setContentSize(NSSize(width:460,height:400));approval.window!.contentView!.layoutSubtreeIfNeeded()
  precondition(approval.window!.title.contains("Untitled"),"Synthetic names must translate")
  UILocalization.set("zh")
  precondition(approval.window!.title.contains("未命名"),"Synthetic names must switch live")
  precondition(descendants(approval.window!.contentView!).compactMap{$0 as? NSTextView}.contains{$0.string=="echo 中文"},"Approval command must remain literal")
  unnamed.sessionUntitled=false
  precondition(unnamed.displayTitle=="未命名会话","Actual title equal to fallback stays literal")
  approval.close()
  UILocalization.set("zh")
  precondition(descendants(root).compactMap{$0 as? NSButton}.contains{$0.title=="提交全部回答"},"Switch back must work")
  controller.close()
  print("Native localization, literal content, notification categories, narrow English layout and open-window draft identity passed")
 }
}

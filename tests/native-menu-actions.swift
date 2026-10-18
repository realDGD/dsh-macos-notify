import Cocoa
@MainActor private final class MenuTrackingProbe:NSObject {
 let controller:SessionMenuController
 var menu:NSMenu?,usedStatusItemMenu=false,firstItemVisible=false
 init(_ controller:SessionMenuController){self.controller=controller}
 @objc func began(_ note:Notification) {
  guard let shown=note.object as? NSMenu else{return}
  menu=shown;usedStatusItemMenu=controller.statusItem?.menu===shown
 }
 @objc func cancel(_ timer:Timer){
  if let frame=menu?.items.first?.accessibilityFrame(),frame.width>0,frame.height>0 {
   firstItemVisible=NSScreen.screens.contains{
    let screen=$0.visibleFrame
    return frame.midX>=screen.minX && frame.midX<=screen.maxX && frame.minY>=screen.minY-0.5 && frame.maxY<=screen.maxY+0.5
   }
   if !firstItemVisible{print("Menu geometry: item=\(frame), screens=\(NSScreen.screens.map{$0.visibleFrame})")}
  }
  menu?.cancelTrackingWithoutAnimation()
 }
}
@main @MainActor struct NativeMenuActionTests {
 static func main() throws {
  UILocalization.set("zh");NSApplication.shared.setActivationPolicy(.accessory);NSApp.finishLaunching()
  func check(_ value:Bool,_ message:String){if !value{print("FAIL "+message);exit(1)}}
  func descendants(_ view:NSView)->[NSView]{[view]+view.subviews.flatMap(descendants)}
  let manager=FileManager.default,directory=manager.temporaryDirectory.appendingPathComponent("native-menu-actions-"+UUID().uuidString)
  try manager.createDirectory(at:directory,withIntermediateDirectories:true)
  defer{try? manager.removeItem(at:directory)}
  let generation=UUID().uuidString
  var revision=0,opens=0,quits=0,allowQuit=false,warnings:[MenuQuitWarning]=[]
  func snapshot(_ state:String,updated:Double=Date().timeIntervalSince1970*1000,omitted:Int=0) throws {
   revision+=1
   let node:[String:Any]=["id":"task","parentId":NSNull(),"workspaceTitle":"测试","sessionTitle":"任务","state":state,"preview":"","previewKind":"empty","pinned":false,"childIds":[],"updatedAt":updated]
   try JSONSerialization.data(withJSONObject:["version":1,"generation":generation,"revision":revision,"updatedAt":updated,"enabled":true,"availability":"ready","nodes":[node],"activeIds":["task"],"orphanIds":[],"historyIds":[],"omittedCount":omitted]).write(to:directory.appendingPathComponent("session-menu.json"))
  }
  let controller=SessionMenuController(directory:directory.path,openSession:{_,_ in},openDesktop:{opens+=1;return true},quitDesktop:{quits+=1;return true},confirmQuit:{warnings.append($0);return allowQuit})
  try snapshot("completed");controller.poll()
  let menu=controller.statusMenu()
  func activate(_ title:String) {
   guard let item=menu.items.first(where:{$0.title==title}),let action=item.action else{check(false,"missing action: "+title);return}
   check(NSApp.sendAction(action,to:item.target,from:item),"menu action is not wired: "+title)
  }
  activate("打开 DSH");check(opens==1,"open DSH does not activate Desktop")
  activate("退出 DSH");check(quits==1 && warnings.isEmpty,"idle DSH needs an unnecessary confirmation")
  for state in ["running","waiting-approval","waiting-questions"] {
   try snapshot(state);activate("退出 DSH")
   check(quits==1 && warnings.last == .running,"live work quits before confirmation")
  }
  allowQuit=true;activate("退出 DSH");check(quits==2,"confirmed quit does not terminate Desktop")
  allowQuit=false
  try snapshot("completed",updated:Date().timeIntervalSince1970*1000-7000);activate("退出 DSH")
  check(warnings.last == .unknown && quits==2,"stale state permits an unconfirmed quit")
  try snapshot("completed",omitted:1);activate("退出 DSH")
  check(warnings.last == .unknown && quits==2,"truncated state permits an unconfirmed quit")
  try snapshot("completed");controller.poll()
  try Data("{broken".utf8).write(to:directory.appendingPathComponent("session-menu.json"))
  let beforeInvalid=warnings.count;activate("退出 DSH")
  check(warnings.count==beforeInvalid+1 && warnings.last == .unknown && quits==2,"an invalid update permits an unconfirmed quit using old idle state")
  try snapshot("unknown");let beforeUnknown=warnings.count;activate("退出 DSH")
  check(warnings.count==beforeUnknown+1 && warnings.last == .unknown && quits==2,"unknown task state permits an unconfirmed quit")
  try snapshot("completed");controller.poll()
  let statusButton=controller.statusItem!.button!
  let deadline=Date(timeIntervalSinceNow:2)
  while statusButton.window?.frame.height==0 && Date()<deadline {RunLoop.current.run(until:Date(timeIntervalSinceNow:0.01))}
  let tracking=MenuTrackingProbe(controller)
  NotificationCenter.default.addObserver(tracking,selector:#selector(MenuTrackingProbe.began),name:NSMenu.didBeginTrackingNotification,object:nil)
  let cancel=Timer(timeInterval:0.05,target:tracking,selector:#selector(MenuTrackingProbe.cancel),userInfo:nil,repeats:true)
  RunLoop.main.add(cancel,forMode:.eventTracking)
  controller.showStatusMenu()
  cancel.invalidate();NotificationCenter.default.removeObserver(tracking)
  check(tracking.usedStatusItemMenu,"context menu bypasses native status-bar placement")
  check(tracking.firstItemVisible,"context menu opens with its first item vertically clipped by the screen edge")
  check(controller.statusItem?.menu==nil,"context menu remains attached and captures ordinary left clicks")
  check(NSApp.sendAction(statusButton.action!,to:statusButton.target,from:statusButton),"status icon is not wired")
  check(controller.popover.isShown,"left click does not show the session panel")
  let inside=NSEvent.mouseEvent(with:.leftMouseDown,location:NSPoint(x:10,y:10),modifierFlags:[],timestamp:0,windowNumber:controller.content.view.window!.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:1)!
  _=controller.handleLocalMouseDown(inside)
  check(controller.popover.isShown,"an inside click dismisses the panel")
  let outside=NSWindow(contentRect:NSRect(x:0,y:0,width:100,height:100),styleMask:[],backing:.buffered,defer:false)
  let outsideClick=NSEvent.mouseEvent(with:.rightMouseDown,location:NSPoint(x:10,y:10),modifierFlags:[],timestamp:0,windowNumber:outside.windowNumber,context:nil,eventNumber:2,clickCount:1,pressure:1)!
  check(controller.handleLocalMouseDown(outsideClick)===outsideClick,"outside dismissal consumes another window's click")
  check(!controller.popover.isShown,"outside click does not dismiss the panel")
  let gear=descendants(controller.content.view).compactMap{$0 as? NSButton}.first{$0.accessibilityLabel()=="打开 DSH Notify 设置"}
  check(gear != nil,"settings gear is not named for Notify settings")
  gear!.performClick(nil)
  let path=directory.appendingPathComponent("open-session.json")
  let request=try JSONSerialization.jsonObject(with:Data(contentsOf:path)) as! [String:Any]
  check(opens==2 && request["kind"] as? String=="open-notify-settings","gear does not request the Notify settings page")
  var receipt=request;receipt["confirmedAt"]=Date().timeIntervalSince1970*1000
  try JSONSerialization.data(withJSONObject:receipt).write(to:directory.appendingPathComponent("jump-result.json"));controller.poll()
  activate("打开 DSH Notify 设置")
  let next=try JSONSerialization.jsonObject(with:Data(contentsOf:path)) as! [String:Any]
  check(opens==3 && next["kind"] as? String=="open-notify-settings" && next["requestId"] as? String != request["requestId"] as? String,"context settings action does not issue an independent request")
  activate("隐藏菜单栏")
  let commands=try manager.contentsOfDirectory(at:directory.appendingPathComponent("menu-commands"),includingPropertiesForKeys:nil)
  let hide=try JSONSerialization.jsonObject(with:Data(contentsOf:commands.first!)) as! [String:Any]
  check(hide["kind"] as? String=="set-menu-enabled" && hide["enabled"] as? Bool==false,"hide menu does not persist its setting through Host")
  print("PASS native status actions, Notify settings gear, guarded quit, stale/truncated status and non-consuming outside click dismissal")
 }
}

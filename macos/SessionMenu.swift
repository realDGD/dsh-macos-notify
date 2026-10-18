import Cocoa
enum MenuQuitWarning {case running,unknown}
final class SessionMenuController:NSObject,NSPopoverDelegate {
 private let directory:String,store=SessionMenuStore(),control:SessionMenuControl
 private let openSession:(String,@escaping(String?)->Void)->Void,openDesktop:()->Bool
 private let quitDesktop:()->Bool,confirmQuit:(MenuQuitWarning)->Bool
 private let interactions:()->[MenuInteraction],performInteraction:(MenuInteraction,MenuInteractionAction)->String?
 private(set) var statusItem:NSStatusItem?
 private let iconState=MenuIconState()
 private var iconView:MenuIconView?
 let popover=NSPopover()
 let content:SessionMenuViewController
 private var actionError:String? {didSet{renderActionError=actionError.map(UILocalization.translated)}}
 private var renderActionError:(()->String)?,opening=false
 private var menuTrackingDepth=0,menuObservers:[NSObjectProtocol]=[]
 private var localMouseMonitor:Any?,globalMouseMonitor:Any?
 init(directory:String,openSession:@escaping(String,@escaping(String?)->Void)->Void,openDesktop:@escaping()->Bool,
      quitDesktop:@escaping()->Bool={
       let apps=NSRunningApplication.runningApplications(withBundleIdentifier:"com.deepseek.dsh").filter{!$0.isTerminated}
       return !apps.isEmpty && apps.map{$0.terminate()}.allSatisfy{$0}
      },confirmQuit:@escaping(MenuQuitWarning)->Bool={warning in
       let alert=NSAlert();alert.alertStyle = .warning;alert.messageText=L("退出 DSH？")
       alert.informativeText=warning == .running ? L("仍有任务正在运行或等待处理，退出 DSH 可能中断这些任务。是否继续？"):L("暂时无法确认任务状态，退出 DSH 可能中断任务。是否继续？")
       alert.addButton(withTitle:L("取消"));alert.addButton(withTitle:L("退出 DSH"));alert.buttons[1].keyEquivalent=""
       NSApp.activate(ignoringOtherApps:true)
       return alert.runModal() == .alertSecondButtonReturn
      },interactions:@escaping()->[MenuInteraction]={[]},performInteraction:@escaping(MenuInteraction,MenuInteractionAction)->String?={_,_ in L("请求暂不可用。")}) {
  self.directory=directory;self.openSession=openSession;self.openDesktop=openDesktop;control=SessionMenuControl(directory:directory)
  self.quitDesktop=quitDesktop;self.confirmQuit=confirmQuit
  self.interactions=interactions;self.performInteraction=performInteraction
  let screen=NSScreen.main?.visibleFrame.size ?? NSSize(width:420,height:600)
  content=SessionMenuViewController(availableSize:NSSize(width:min(420,max(180,screen.width-24)),height:min(600,max(180,screen.height-48))))
  super.init();popover.behavior = .transient;popover.animates=false;popover.contentViewController=content;popover.delegate=self
  content.onOpenSession={[weak self] id in self?.navigate(id)}
  content.onInteraction={[weak self] item,action in self?.act(item,action:action)}
  content.onClose={[weak self] in self?.closePopover()}
  content.onResize={[weak self] size in
   guard let self=self,self.popover.contentSize != size else{return}
   self.popover.contentSize=size
  }
  content.onOpenSettings={[weak self] in self?.openNotifySettings()}
  menuObservers.append(NotificationCenter.default.addObserver(forName:NSMenu.didBeginTrackingNotification,object:nil,queue:.main){[weak self] _ in self?.menuTrackingDepth+=1})
  menuObservers.append(NotificationCenter.default.addObserver(forName:NSMenu.didEndTrackingNotification,object:nil,queue:.main){[weak self] _ in
   guard let self=self else{return};self.menuTrackingDepth=max(0,self.menuTrackingDepth-1)
   if self.menuTrackingDepth==0 && self.popover.isShown {self.render()}
  })
  menuObservers.append(NotificationCenter.default.addObserver(forName:NSApplication.didResignActiveNotification,object:NSApp,queue:.main){[weak self] _ in
   guard let self=self,self.menuTrackingDepth==0 else{return};self.closePopover()
  })
 }
 deinit {stopDismissalMonitoring();for observer in menuObservers{NotificationCenter.default.removeObserver(observer)};if let item=statusItem{NSStatusBar.system.removeStatusItem(item)}}
 func poll(at now:Double=Date().timeIntervalSince1970*1000) {
  control.poll(at:now)
  let path=(directory as NSString).appendingPathComponent("session-menu.json")
  if let size=(try? FileManager.default.attributesOfItem(atPath:path)[.size]) as? Int,size<=4194304,
     let data=try? Data(contentsOf:URL(fileURLWithPath:path)) {store.ingest(data,at:now)}
  else {store.unavailable()}
  if store.snapshot?.enabled==false {
   closePopover();if let item=statusItem{NSStatusBar.system.removeStatusItem(item);statusItem=nil;iconView=nil}
  } else if statusItem==nil {
   let item=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength);statusItem=item
   if let button=item.button {
    let icon=MenuIconView(frame:button.bounds);icon.autoresizingMask=[.width,.height];button.addSubview(icon);iconView=icon
   }
   item.button?.toolTip="DSH Notify";item.button?.target=self;item.button?.action=#selector(statusClicked)
   item.button?.sendAction(on:[.leftMouseUp,.rightMouseUp])
   if let button=item.button { uiAccessibility(button,L("DSH Notify 会话面板")) }
  }
  iconState.update(store.snapshot?.cohort,generation:store.snapshot?.generation,stale:store.isStale(at:now) || store.snapshot?.availability != "ready")
  iconView?.update(iconState.appearance)
  if popover.isShown && menuTrackingDepth==0 {render(at:now)}
 }
 private func render(at now:Double=Date().timeIntervalSince1970*1000) {
  content.update(snapshot:store.snapshot,status:store.status(at:now),stale:store.isStale(at:now),error:renderActionError?(),interactions:interactions())
 }
 @objc private func statusClicked() {
  if let event=NSApp.currentEvent,event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
   showStatusMenu()
   return
  }
  if popover.isShown{closePopover();return}
  guard let button=statusItem?.button else{return}
  iconState.acknowledge();iconView?.update(iconState.appearance)
  NSApp.activate(ignoringOtherApps:true)
  render();popover.show(relativeTo:button.bounds,of:button,preferredEdge:.minY)
  startDismissalMonitoring()
  content.view.window?.makeKey()
  content.view.window?.makeFirstResponder(content.table)
 }
 func showStatusMenu() {
  closePopover()
  guard let item=statusItem,let button=item.button else{return}
  item.menu=statusMenu()
  defer{item.menu=nil}
  button.performClick(nil)
 }
 func statusMenu()->NSMenu {
  let menu=NSMenu();menu.autoenablesItems=false
  for (title,symbol,action) in [(L("打开 DSH"),"macwindow",#selector(openDSH)),(L("打开 DSH Notify 设置"),"gearshape",#selector(openNotifySettings)),(L("隐藏菜单栏"),"menubar.rectangle",#selector(disable))] {
   let item=NSMenuItem(title:title,action:action,keyEquivalent:"");item.target=self
   item.image=NSImage(systemSymbolName:symbol,accessibilityDescription:nil);menu.addItem(item)
  }
  menu.addItem(.separator())
  let quit=NSMenuItem(title:L("退出 DSH"),action:#selector(quitDSH),keyEquivalent:"");quit.target=self;menu.addItem(quit)
  return menu
 }
 private func startDismissalMonitoring() {
  stopDismissalMonitoring()
  let mask:NSEvent.EventTypeMask=[.leftMouseDown,.rightMouseDown,.otherMouseDown]
  localMouseMonitor=NSEvent.addLocalMonitorForEvents(matching:mask){[weak self] event in self?.handleLocalMouseDown(event) ?? event}
  globalMouseMonitor=NSEvent.addGlobalMonitorForEvents(matching:mask){[weak self] _ in self?.closePopover()}
 }
 private func stopDismissalMonitoring() {
  if let monitor=localMouseMonitor{NSEvent.removeMonitor(monitor);localMouseMonitor=nil}
  if let monitor=globalMouseMonitor{NSEvent.removeMonitor(monitor);globalMouseMonitor=nil}
 }
 func handleLocalMouseDown(_ event:NSEvent)->NSEvent {
  guard popover.isShown,menuTrackingDepth==0 else{return event}
  if event.window===content.view.window{return event}
  if let button=statusItem?.button,event.window===button.window,
     button.bounds.contains(button.convert(event.locationInWindow,from:nil)){return event}
  closePopover();return event
 }
 private func closePopover(){stopDismissalMonitoring();popover.performClose(nil)}
 func popoverDidClose(_ notification:Notification){stopDismissalMonitoring()}
 @objc private func openDSH() {
  closePopover();if !openDesktop(){actionError=L("无法打开 DSH Desktop。");render()}
 }
 @objc private func openNotifySettings() {
  closePopover();actionError=nil
  control.openSettings(openDesktop:openDesktop){[weak self] error in self?.actionError=error;self?.render()}
 }
 @objc private func quitDSH() {
  closePopover();poll()
  let warning:MenuQuitWarning?
  if store.snapshot?.cohort?.running==true || store.snapshot?.nodes.contains(where:{$0.state.isLive || MenuSessionState(rawValue:$0.descendantBadge ?? "")?.isLive==true})==true {warning = .running}
  else if !store.isReady(at:Date().timeIntervalSince1970*1000) || (store.snapshot?.omittedCount ?? 0)>0
    || store.snapshot?.nodes.contains(where:{$0.state == .unknown || $0.descendantBadge=="unknown"})==true {warning = .unknown}
  else {warning=nil}
  if let warning=warning,!confirmQuit(warning){return}
  if !quitDesktop(){actionError=L("无法退出 DSH，请在 DSH 中重试。");render()}
 }
 func navigate(_ id:String) {
  guard !opening,menuSessionIdValid(id),store.snapshot?.nodes.contains(where:{$0.id==id})==true else{return}
  closePopover();opening=true;actionError=nil
  openSession(id){[weak self] error in self?.opening=false;self?.actionError=error;self?.render()}
 }
 func act(_ item:MenuInteraction,action:MenuInteractionAction,at now:Double=Date().timeIntervalSince1970*1000) {
  guard !store.isStale(at:now),store.snapshot?.nodes.contains(where:{$0.id==item.sessionId})==true,
        let current=interactions().first(where:{$0.requestId==item.requestId && $0.sessionId==item.sessionId && $0.kind==item.kind}),
        current.actions.contains(action),current.enabled(action) else {
   actionError=L("请求已失效或正在提交，请等待连接和菜单刷新。");render(at:now);return
  }
  actionError=performInteraction(current,action)
  if actionError==nil && (action == .answer || action == .details){closePopover()}
  render(at:now)
 }
 @objc private func disable() {
  closePopover()
  control.setEnabled(false){[weak self] error in self?.actionError=error;self?.render()}
 }
}

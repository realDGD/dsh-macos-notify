import Cocoa
final class SessionMenuController:NSObject {
 private let directory:String,store=SessionMenuStore(),control:SessionMenuControl
 private let openSession:(String,@escaping(String?)->Void)->Void,openDesktop:()->Bool
 private let interactions:()->[MenuInteraction],performInteraction:(MenuInteraction,MenuInteractionAction)->String?
 private(set) var statusItem:NSStatusItem?
 private let iconState=MenuIconState()
 private var iconView:MenuIconView?
 let popover=NSPopover()
 let content:SessionMenuViewController
 private var actionError:String?,opening=false
 private var menuTrackingDepth=0,menuObservers:[NSObjectProtocol]=[]
 init(directory:String,openSession:@escaping(String,@escaping(String?)->Void)->Void,openDesktop:@escaping()->Bool,interactions:@escaping()->[MenuInteraction]={[]},performInteraction:@escaping(MenuInteraction,MenuInteractionAction)->String?={_,_ in "请求暂不可用。"}) {
  self.directory=directory;self.openSession=openSession;self.openDesktop=openDesktop;control=SessionMenuControl(directory:directory)
  self.interactions=interactions;self.performInteraction=performInteraction
  let screen=NSScreen.main?.visibleFrame.size ?? NSSize(width:420,height:600)
  content=SessionMenuViewController(availableSize:NSSize(width:min(420,max(180,screen.width-24)),height:min(600,max(180,screen.height-48))))
  super.init();popover.behavior = .transient;popover.animates=false;popover.contentViewController=content
  content.onOpenSession={[weak self] id in self?.navigate(id)}
  content.onInteraction={[weak self] item,action in self?.act(item,action:action)}
  content.onClose={[weak self] in self?.popover.performClose(nil)}
  content.onResize={[weak self] size in
   guard let self=self,self.popover.contentSize != size else{return}
   self.popover.contentSize=size
  }
  content.onDisableMenu={[weak self] in self?.disable()}
  content.onOpenDesktop={[weak self] in guard let self=self else{return};if !self.openDesktop(){self.actionError="无法打开 DSH Desktop。";self.render()}}
  menuObservers.append(NotificationCenter.default.addObserver(forName:NSMenu.didBeginTrackingNotification,object:nil,queue:.main){[weak self] _ in self?.menuTrackingDepth+=1})
  menuObservers.append(NotificationCenter.default.addObserver(forName:NSMenu.didEndTrackingNotification,object:nil,queue:.main){[weak self] _ in
   guard let self=self else{return};self.menuTrackingDepth=max(0,self.menuTrackingDepth-1)
   if self.menuTrackingDepth==0 && self.popover.isShown {self.render()}
  })
 }
 deinit {for observer in menuObservers{NotificationCenter.default.removeObserver(observer)};if let item=statusItem{NSStatusBar.system.removeStatusItem(item)}}
 func poll(at now:Double=Date().timeIntervalSince1970*1000) {
  control.poll(at:now)
  let path=(directory as NSString).appendingPathComponent("session-menu.json")
  if let size=(try? FileManager.default.attributesOfItem(atPath:path)[.size]) as? Int,size<=4194304,
     let data=try? Data(contentsOf:URL(fileURLWithPath:path)) {store.ingest(data,at:now)}
  else {store.unavailable()}
  if store.snapshot?.enabled==false {
   popover.performClose(nil);if let item=statusItem{NSStatusBar.system.removeStatusItem(item);statusItem=nil;iconView=nil}
  } else if statusItem==nil {
   let item=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength);statusItem=item
   if let button=item.button {
    let icon=MenuIconView(frame:button.bounds);icon.autoresizingMask=[.width,.height];button.addSubview(icon);iconView=icon
   }
   item.button?.toolTip="DSH Notify";item.button?.target=self;item.button?.action=#selector(toggle)
   item.button?.setAccessibilityLabel("DSH Notify 会话面板")
  }
  iconState.update(store.snapshot?.cohort,generation:store.snapshot?.generation,stale:store.isStale(at:now) || store.snapshot?.availability != "ready")
  iconView?.update(iconState.appearance)
  if popover.isShown && menuTrackingDepth==0 {render(at:now)}
 }
 private func render(at now:Double=Date().timeIntervalSince1970*1000) {
  content.update(snapshot:store.snapshot,status:store.status(at:now),stale:store.isStale(at:now),error:actionError,interactions:interactions())
 }
 @objc private func toggle() {
  if popover.isShown{popover.performClose(nil);return}
  guard let button=statusItem?.button else{return}
  iconState.acknowledge();iconView?.update(iconState.appearance)
  render();popover.show(relativeTo:button.bounds,of:button,preferredEdge:.minY)
  content.view.window?.makeFirstResponder(content.table)
 }
 func navigate(_ id:String) {
  guard !opening,menuSessionIdValid(id),store.snapshot?.nodes.contains(where:{$0.id==id})==true else{return}
  popover.performClose(nil);opening=true;actionError=nil
  openSession(id){[weak self] error in self?.opening=false;self?.actionError=error;self?.render()}
 }
 func act(_ item:MenuInteraction,action:MenuInteractionAction,at now:Double=Date().timeIntervalSince1970*1000) {
  guard !store.isStale(at:now),store.snapshot?.nodes.contains(where:{$0.id==item.sessionId})==true,
        let current=interactions().first(where:{$0.requestId==item.requestId && $0.sessionId==item.sessionId && $0.kind==item.kind}),
        current.actions.contains(action),current.enabled(action) else {
   actionError="请求已失效或正在提交，请等待连接和菜单刷新。";render(at:now);return
  }
  actionError=performInteraction(current,action)
  if actionError==nil && (action == .answer || action == .details){popover.performClose(nil)}
  render(at:now)
 }
 private func disable() {
  control.setEnabled(false){[weak self] error in self?.actionError=error;self?.render()}
 }
}

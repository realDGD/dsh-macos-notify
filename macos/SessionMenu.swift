import Cocoa
final class SessionMenuController:NSObject {
 private let directory:String,store=SessionMenuStore(),control:SessionMenuControl
 private let openSession:(String,@escaping(String?)->Void)->Void,openDesktop:()->Bool
 private(set) var statusItem:NSStatusItem?
 let popover=NSPopover()
 let content:SessionMenuViewController
 private var actionError:String?,opening=false
 init(directory:String,openSession:@escaping(String,@escaping(String?)->Void)->Void,openDesktop:@escaping()->Bool) {
  self.directory=directory;self.openSession=openSession;self.openDesktop=openDesktop;control=SessionMenuControl(directory:directory)
  let screen=NSScreen.main?.visibleFrame.size ?? NSSize(width:420,height:600)
  content=SessionMenuViewController(availableSize:NSSize(width:min(420,max(180,screen.width-24)),height:min(600,max(180,screen.height-48))))
  super.init();popover.behavior = .transient;popover.contentViewController=content
  content.onOpenSession={[weak self] id in self?.navigate(id)}
  content.onClose={[weak self] in self?.popover.performClose(nil)}
  content.onDisableMenu={[weak self] in self?.disable()}
  content.onOpenDesktop={[weak self] in guard let self=self else{return};if !self.openDesktop(){self.actionError="无法打开 DSH Desktop。";self.render()}}
 }
 deinit {if let item=statusItem{NSStatusBar.system.removeStatusItem(item)}}
 func poll(at now:Double=Date().timeIntervalSince1970*1000) {
  control.poll(at:now)
  let path=(directory as NSString).appendingPathComponent("session-menu.json")
  if let size=(try? FileManager.default.attributesOfItem(atPath:path)[.size]) as? Int,size<=4194304,
     let data=try? Data(contentsOf:URL(fileURLWithPath:path)) {store.ingest(data,at:now)}
  else {store.unavailable()}
  if store.snapshot?.enabled==false {
   popover.performClose(nil);if let item=statusItem{NSStatusBar.system.removeStatusItem(item);statusItem=nil}
  } else if statusItem==nil {
   let item=NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength);statusItem=item
   item.button?.image=NSImage(systemSymbolName:"bubble.left.and.bubble.right",accessibilityDescription:"DSH Notify")
   item.button?.image?.isTemplate=true;item.button?.toolTip="DSH Notify";item.button?.target=self;item.button?.action=#selector(toggle)
   item.button?.setAccessibilityLabel("DSH Notify 会话面板")
  }
  render(at:now)
 }
 private func render(at now:Double=Date().timeIntervalSince1970*1000) {
  content.update(snapshot:store.snapshot,status:store.status(at:now),stale:store.isStale(at:now),error:actionError)
  popover.contentSize=content.view.frame.size
 }
 @objc private func toggle() {
  if popover.isShown{popover.performClose(nil);return}
  guard let button=statusItem?.button else{return}
  render();popover.show(relativeTo:button.bounds,of:button,preferredEdge:.minY)
  content.view.window?.makeFirstResponder(content.table)
 }
 func navigate(_ id:String) {
  guard !opening,menuSessionIdValid(id),store.snapshot?.nodes.contains(where:{$0.id==id})==true else{return}
  popover.performClose(nil);opening=true;actionError=nil
  openSession(id){[weak self] error in self?.opening=false;self?.actionError=error;self?.render()}
 }
 private func disable() {
  control.setEnabled(false){[weak self] error in self?.actionError=error;self?.render()}
 }
}

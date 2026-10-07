import Cocoa
@main @MainActor struct NativeSessionMenuTests {
 static func main() throws {
  NSApplication.shared.setActivationPolicy(.prohibited)
  func check(_ value:Bool,_ message:String){if !value{print("FAIL "+message);exit(1)}}
  let generation=UUID().uuidString
  func node(_ id:String,_ parent:String?=nil,_ children:[String]=[],_ state:String="running",_ progress:[String:Int]?=nil)->[String:Any] {
   ["id":id,"parentId":parent as Any? ?? NSNull(),"workspaceTitle":"工作区","sessionTitle":"会话 "+id,"state":state,
    "preview":String(repeating:"长中文🙂",count:35),"previewKind":"user","pinned":false,"pinIndex":NSNull(),
    "progress":progress as Any? ?? NSNull(),"childIds":children,"descendantBadge":NSNull(),"updatedAt":1000]
  }
  func data(_ nodes:[[String:Any]],active:[String]=["parent"],revision:Int=1,updated:Double=1000,enabled:Bool=true,history:[String]=[])->Data {
   try! JSONSerialization.data(withJSONObject:["version":1,"generation":generation,"revision":revision,"updatedAt":updated,"enabled":enabled,"availability":"ready",
     "nodes":nodes,"activeIds":active,"orphanIds":[],"historyIds":history,"omittedCount":0])
  }
  let children=(0..<400).map{"child-\($0)"}
  let nodes=[node("parent",nil,children,"completed",["completed":3,"total":5])]+children.map{node($0,"parent")}
  let store=SessionMenuStore()
  check(store.ingest(data(nodes),at:1000),"valid snapshot decode")
  check(!store.ingest(data(nodes,revision:0),at:1000),"older revision replaced current view")
  check(!store.ingest(Data("{broken".utf8),at:1000),"corrupt snapshot accepted")
  check(store.snapshot?.nodes.count==401,"invalid input erased validated data")
  check(!store.ingest(data([node("parent"),node("parent")]),at:1000),"duplicate identity accepted")
  check(!store.ingest(Data(repeating:32,count:4194305),at:1000),"oversized data accepted")
  check(store.status(at:7001).contains("未连接"),"stale status not explicit")
  check(store.snapshot?.nodes[0].state == .completed,"staleness changed session facts")
  check(store.ingest(data(nodes,revision:2,updated:8000),at:8000),"fresh recovery rejected")
  let content=SessionMenuViewController(availableSize:NSSize(width:420,height:600))
  var opened:[String]=[]
  content.onOpenSession={opened.append($0)}
  content.update(snapshot:store.snapshot,status:store.status(at:8000),stale:false,error:nil)
  let window=NSWindow(contentRect:content.view.frame,styleMask:[],backing:.buffered,defer:false)
  window.contentViewController=content
  content.view.layoutSubtreeIfNeeded()
  check(content.visibleRows.compactMap(\.sessionId)==["parent"],"children not initially collapsed")
  content.toggle("parent");content.view.layoutSubtreeIfNeeded()
  check(opened.isEmpty,"disclosure opened Desktop")
  check(content.visibleRows.compactMap(\.sessionId).count==401,"expanded children lost")
  check(content.view.frame.width<=420 && content.view.frame.height<=600,"popover bounds")
  check(content.scrollView.hasVerticalScroller,"long tree lacks scrolling")
  let firstIndex=content.visibleRows.firstIndex{$0.sessionId=="parent"}!
  let row=content.table.view(atColumn:0,row:firstIndex,makeIfNecessary:true) as! SessionMenuRowView
  row.layoutSubtreeIfNeeded()
  check(row.preview.maximumNumberOfLines==1,"preview wraps")
  check(row.preview.lineBreakMode == .byTruncatingTail,"preview not ellipsized")
  check(row.title.frame.width>100 && row.preview.frame.maxX<=row.bounds.width,"title/preview are clipped by row geometry")
  check(row.accessibilityLabel()?.contains("3/5")==true,"progress not accessible")
  check(row.progress.completed==3 && row.progress.total==5,"real todo progress")
  let last=content.visibleRows.count-1
  content.table.scrollRowToVisible(last);content.view.layoutSubtreeIfNeeded()
  check(content.table.rows(in:content.scrollView.contentView.bounds).location<=last,"scroll end inaccessible")
  let narrow=SessionMenuViewController(availableSize:NSSize(width:300,height:400))
  narrow.update(snapshot:store.snapshot,status:"已连接",stale:false,error:nil);narrow.view.layoutSubtreeIfNeeded()
  check(narrow.view.frame.width<=300 && narrow.view.frame.height<=400,"narrow screen bounds")
  content.table.selectRowIndexes(IndexSet(integer:firstIndex),byExtendingSelection:false)
  content.handleKey(124);content.handleKey(36)
  check(opened==["child-0"],"keyboard right/return targets wrong session")
  content.handleKey(123)
  check(content.visibleRows[content.table.selectedRow].sessionId=="parent","keyboard left does not return to parent")
  content.toggle("parent");check(content.visibleRows.compactMap(\.sessionId)==["parent"],"collapse failed")
  let deep=(0..<30).map{i in node("deep-\(i)",i==0 ? nil:"deep-\(i-1)",i==29 ? []:["deep-\(i+1)"])}
  let deepStore=SessionMenuStore();check(deepStore.ingest(data(deep,active:["deep-0"]),at:1000),"valid deep tree")
  narrow.update(snapshot:deepStore.snapshot,status:"已连接",stale:false,error:nil)
  for i in 0..<29{narrow.toggle("deep-\(i)")};narrow.view.layoutSubtreeIfNeeded()
  check(narrow.visibleRows.last?.depth==29,"deep ancestry lost")
  let depthRow=narrow.table.view(atColumn:0,row:narrow.visibleRows.count-1,makeIfNecessary:true) as! SessionMenuRowView
  depthRow.layoutSubtreeIfNeeded();check(depthRow.title.frame.minX<230,"deep indentation hides title")
  check(depthRow.title.frame.width>20 && depthRow.preview.frame.maxX<=depthRow.bounds.width,"narrow deep row content clipped")
  let directory=FileManager.default.temporaryDirectory.appendingPathComponent("native-menu-"+UUID().uuidString)
  try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
  defer{try? FileManager.default.removeItem(at:directory)}
  try data([node("parent")]).write(to:directory.appendingPathComponent("session-menu.json"))
  var navigationCompletion:((String?)->Void)?
  let controller=SessionMenuController(directory:directory.path,openSession:{id,completion in opened.append(id);navigationCompletion=completion},openDesktop:{false})
  controller.poll(at:1000);check(controller.statusItem != nil,"enabled status item missing")
  let beforeNavigation=opened.count
  controller.navigate("parent");controller.navigate("parent");controller.navigate("/invalid")
  check(opened.count==beforeNavigation+1 && opened.last=="parent","duplicate or invalid menu jump")
  navigationCompletion?("无法连接 DSH Desktop")
  func descendants(_ view:NSView)->[NSView]{[view]+view.subviews.flatMap(descendants)}
  check(descendants(controller.content.view).compactMap{$0 as? NSTextField}.contains{$0.stringValue=="无法连接 DSH Desktop"},"jump failure not retained in menu")
  try data([],active:[],revision:2,updated:2000,enabled:false).write(to:directory.appendingPathComponent("session-menu.json"))
  controller.poll(at:2000);check(controller.statusItem==nil && !controller.popover.isShown,"disabled menu retained")
  try data([node("parent")],revision:3,updated:3000).write(to:directory.appendingPathComponent("session-menu.json"))
  controller.poll(at:3000);check(controller.statusItem != nil,"reenabled status item missing")
  // An acknowledgment must not hide a run or required input, and undo restores it.
  let activityNodes=[node("done",nil,[],"completed"),node("failure",nil,[],"error"),node("live"),node("question",nil,[],"waiting-questions")]
  let mixed=SessionMenuStore()
  check(mixed.ingest(data(activityNodes,active:["failure","question","live","done"]),at:1000),"activity fixture decode")
  let controls=SessionMenuViewController(availableSize:NSSize(width:420,height:600))
  controls.update(snapshot:mixed.snapshot,status:"DSH 已连接",stale:false,error:nil)
  let readButton=descendants(controls.view).compactMap{$0 as? NSButton}.first{$0.title=="一键已读"}
  check(readButton != nil,"activity acknowledgment control missing")
  readButton!.performClick(nil)
  check(controls.visibleRows.compactMap(\.sessionId)==["question","live"],"read action concealed running or waiting session")
  readButton!.performClick(nil)
  check(controls.visibleRows.compactMap(\.sessionId)==["failure","question","live","done"],"undo failed to restore acknowledged activity")
  let filter=descendants(controls.view).compactMap{$0 as? NSPopUpButton}.first
  check(filter != nil,"activity filter missing")
  filter!.selectItem(at:1);filter!.sendAction(filter!.action,to:filter!.target)
  check(controls.visibleRows.compactMap(\.sessionId)==["failure"],"error filter included completed or live sessions")
  filter!.selectItem(at:2);filter!.sendAction(filter!.action,to:filter!.target)
  check(controls.visibleRows.compactMap(\.sessionId)==["question","live"],"live filter lost required input")
  filter!.selectItem(at:0);filter!.sendAction(filter!.action,to:filter!.target)
  readButton!.performClick(nil)
  var newTurn=activityNodes;newTurn[0]["activityToken"]="turn:2"
  check(mixed.ingest(data(newTurn,active:["failure","question","live","done"],revision:2),at:1000),"new turn decode")
  controls.update(snapshot:mixed.snapshot,status:"DSH 已连接",stale:false,error:nil)
  check(controls.visibleRows.compactMap(\.sessionId)==["question","live","done"],"new run was concealed by older read acknowledgment")
  let recentIds=(0..<5).map{"recent-\($0)"}
  let split=SessionMenuStore()
  check(split.ingest(data(nodes+recentIds.map{node($0,nil,[],"completed")},history:recentIds),at:1000),"split fixture decode")
  content.update(snapshot:split.snapshot,status:"DSH 已连接",stale:false,error:nil)
  if !content.visibleRows.contains(where:{$0.sessionId=="child-0"}){content.toggle("parent")}
  content.view.layoutSubtreeIfNeeded()
  let historyFrame=content.historyList.convert(content.historyList.bounds,to:content.view)
  check(historyFrame.minY>=0 && historyFrame.maxY<=content.view.bounds.maxY,"recent section requires scrolling the activity list")
  check(content.historyList.rows.compactMap(\.sessionId)==recentIds,"recent history lost root slots to children")
  let historyOffset=content.historyList.scrollView.contentView.bounds.origin
  content.table.scrollRowToVisible(content.visibleRows.count-1);content.activeList.updateSticky();content.view.layoutSubtreeIfNeeded()
  check(content.historyList.scrollView.contentView.bounds.origin==historyOffset,"activity scrolling moved recent history")
  check(content.activeList.stickyRootId=="parent","expanded root scrolled away from its children")
  content.table.selectRowIndexes(IndexSet(integer:content.visibleRows.count-1),byExtendingSelection:false)
  for _ in 0..<20{content.handleKey(126)}
  let selectedRect=content.table.rect(ofRow:content.table.selectedRow)
  check(selectedRect.minY>=content.scrollView.contentView.bounds.minY+64,"keyboard selection is covered by the pinned root")
  let collapse=descendants(content.activeList).compactMap{$0 as? NSButton}.first{button in
   button.accessibilityLabel()=="收起会话 parent的子代理" && !button.isHidden && button.convert(button.bounds,to:content.activeList).intersects(content.activeList.bounds)
  }
  check(collapse != nil,"sticky root has no reachable collapse button")
  collapse!.performClick(nil)
  check(content.visibleRows.compactMap(\.sessionId)==["parent"],"sticky collapse did not close descendants")
  check(content.scrollView.contentView.bounds.minY<64,"collapse left the viewport below its sole remaining root")
  let persisted=SessionMenuViewController(availableSize:NSSize(width:420,height:600),directory:directory.path)
  persisted.update(snapshot:mixed.snapshot,status:"DSH 已连接",stale:false,error:nil)
  let persistedRead=descendants(persisted.view).compactMap{$0 as? NSButton}.first{$0.title=="一键已读"}!
  persistedRead.performClick(nil)
  let restored=SessionMenuViewController(availableSize:NSSize(width:420,height:600),directory:directory.path)
  restored.update(snapshot:mixed.snapshot,status:"DSH 已连接",stale:false,error:nil)
  check(restored.visibleRows.compactMap(\.sessionId)==["question","live"],"helper restart lost read acknowledgments")
  let disabledStore=SessionMenuStore()
  check(disabledStore.ingest(data([],active:[],revision:3,enabled:false),at:1000),"disabled snapshot decode")
  restored.update(snapshot:disabledStore.snapshot,status:"DSH 已连接",stale:false,error:nil)
  restored.update(snapshot:mixed.snapshot,status:"DSH 已连接",stale:false,error:nil)
  check(restored.visibleRows.compactMap(\.sessionId)==["question","live"],"temporary menu disable erased read acknowledgments")
  let restartUndo=descendants(restored.view).compactMap{$0 as? NSButton}.first{$0.title=="取消已读"}
  check(restartUndo != nil,"helper restart discarded the undo batch while retaining hidden read entries")
  restartUndo!.performClick(nil)
  check(restored.visibleRows.compactMap(\.sessionId)==["failure","question","live","done"],"restored undo cannot reveal its acknowledged entries")
  let permission=try FileManager.default.attributesOfItem(atPath:directory.appendingPathComponent("session-menu-read.json").path)[.posixPermissions] as! NSNumber
  check(permission.intValue==0o600,"read state is not private")
  if let target=ProcessInfo.processInfo.environment["DSH_MENU_PREVIEW"] {
   content.view.appearance=NSAppearance(named:.darkAqua)
   content.view.layoutSubtreeIfNeeded()
   let bitmap=content.view.bitmapImageRepForCachingDisplay(in:content.view.bounds)!
   content.view.cacheDisplay(in:content.view.bounds,to:bitmap)
   try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:target))
  }
  print("PASS native menu decode/bounds/stale/recovery, 400-child layout/scroll, deep tree, keyboard/accessibility, real progress and enabled lifecycle")
 }
}

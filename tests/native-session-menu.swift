import Cocoa
import CryptoKit
@main @MainActor struct NativeSessionMenuTests {
 static func main() throws {
  UILocalization.set("zh")
  NSApplication.shared.setActivationPolicy(.prohibited)
  func check(_ value:Bool,_ message:String){if !value{print("FAIL "+message);exit(1)}}
  let generation=UUID().uuidString
  func node(_ id:String,_ parent:String?=nil,_ children:[String]=[],_ state:String="running",_ progress:[String:Int]?=nil)->[String:Any] {
   ["id":id,"parentId":parent as Any? ?? NSNull(),"workspaceTitle":"工作区","sessionTitle":"会话 "+id,"state":state,
    "preview":String(repeating:"长中文🙂",count:35),"previewKind":"user","pinned":false,"pinIndex":NSNull(),
    "progress":progress as Any? ?? NSNull(),"childIds":children,"descendantBadge":NSNull(),"updatedAt":1000]
  }
  func data(_ nodes:[[String:Any]],active:[String]=["parent"],revision:Int=1,updated:Double=1000,enabled:Bool=true,history:[String]=[],omitted:Int=0)->Data {
   try! JSONSerialization.data(withJSONObject:["version":1,"generation":generation,"revision":revision,"updatedAt":updated,"enabled":enabled,"availability":"ready",
     "nodes":nodes,"activeIds":active,"orphanIds":[],"historyIds":history,"omittedCount":omitted])
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
  check(!content.scrollView.hasVerticalScroller,"long tree still shows a scrollbar instead of expansion arrows")
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
  check(controller.statusItem?.button?.subviews.contains(where:{$0.accessibilityLabel()=="fish.circle"})==true,"menu icon is not the requested white fish.circle")
  check(controller.content.visibleRows.isEmpty,"closed menu rebuilds invisible session rows on every poll")
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
  // Every connection-local status remains visible; the removed controls cannot hide it.
  let activityNodes=[node("done",nil,[],"completed"),node("failure",nil,[],"error"),node("live"),node("question",nil,[],"waiting-questions")]
  let mixed=SessionMenuStore()
  check(mixed.ingest(data(activityNodes,active:["failure","question","live","done"]),at:1000),"activity fixture decode")
  let controls=SessionMenuViewController(availableSize:NSSize(width:420,height:600))
  controls.update(snapshot:mixed.snapshot,status:"DSH 已连接",stale:false,error:nil)
  check(!descendants(controls.view).compactMap{$0 as? NSButton}.contains{["一键已读","取消已读"].contains($0.title) || $0.accessibilityLabel()=="活动会话筛选"},"removed read/filter controls remain in the panel")
  check(controls.visibleRows.compactMap(\.sessionId)==["failure","question","live","done"],"activity statuses were hidden or reordered")
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
   button.accessibilityLabel()=="收起会话 parent的子智能体" && !button.isHidden && button.convert(button.bounds,to:content.activeList).intersects(content.activeList.bounds)
  }
  check(collapse != nil,"sticky root has no reachable collapse button")
  collapse!.performClick(nil)
  check(content.visibleRows.compactMap(\.sessionId)==["parent"],"sticky collapse did not close descendants")
  check(content.scrollView.contentView.bounds.minY<64,"collapse left the viewport below its sole remaining root")
  func oldFingerprint(_ id:String,_ state:String)->String {SHA256.hash(data:Data((id+"|legacy:1000.0|"+state).utf8)).map{String(format:"%02x",$0)}.joined()}
  let legacyFile=directory.appendingPathComponent("session-menu-read.json")
  let legacyData=try JSONSerialization.data(withJSONObject:["generation":generation,"read":["done":oldFingerprint("done","completed"),"failure":oldFingerprint("failure","error")]])
  try legacyData.write(to:legacyFile)
  let restarted=SessionMenuController(directory:directory.path,openSession:{_,_ in},openDesktop:{false})
  let restored=restarted.content
  restored.update(snapshot:mixed.snapshot,status:"DSH 已连接",stale:false,error:nil)
  check(restored.visibleRows.compactMap(\.sessionId)==["failure","question","live","done"],"legacy read marks still hide activity after restart")
  check(restored.historyList.rows.compactMap(\.sessionId).isEmpty,"legacy read marks inserted activity into recent history")
  let disabledStore=SessionMenuStore()
  check(disabledStore.ingest(data([],active:[],revision:3,enabled:false),at:1000),"disabled snapshot decode")
  restored.update(snapshot:disabledStore.snapshot,status:"DSH 已连接",stale:false,error:nil)
  restored.update(snapshot:mixed.snapshot,status:"DSH 已连接",stale:false,error:nil)
  check(restored.visibleRows.compactMap(\.sessionId)==["failure","question","live","done"],"menu enable cycle concealed activity")
  check(try Data(contentsOf:legacyFile)==legacyData,"obsolete private read state was rewritten")
  if let target=ProcessInfo.processInfo.environment["DSH_MENU_PREVIEW"] {
   content.view.appearance=NSAppearance(named:.darkAqua)
   content.view.layoutSubtreeIfNeeded()
   let bitmap=content.view.bitmapImageRepForCachingDisplay(in:content.view.bounds)!
   content.view.cacheDisplay(in:content.view.bounds,to:bitmap)
   try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:target))
  }
  // Compact sections share four whole rows: keep a balanced split when both
  // overflow and lend unused slots without showing an unnecessary disclosure.
  for (aCount,hCount,aSlots,hSlots) in [(5,5,2,2),(1,5,1,3),(5,1,3,1),(0,5,0,4),(5,0,4,0),(3,1,3,1),(2,2,2,2),(1,1,1,1)] {
   let aIds=(0..<aCount).map{"pool-a-\($0)"},hIds=(0..<hCount).map{"pool-h-\($0)"}
   let pooledStore=SessionMenuStore()
   check(pooledStore.ingest(data((aIds+hIds).map{node($0)},active:aIds,history:hIds),at:1000),"pooled fixture decode")
   let pooled=SessionMenuViewController(availableSize:NSSize(width:420,height:600))
   pooled.update(snapshot:pooledStore.snapshot,status:"DSH 已连接",stale:false,error:nil)
   let pooledWindow=NSWindow(contentRect:pooled.view.frame,styleMask:[],backing:.buffered,defer:false)
   pooledWindow.contentViewController=pooled;pooled.view.layoutSubtreeIfNeeded()
   check(pooled.activeList.frame.height==CGFloat(aSlots==0 ? 32:aSlots*64),"activity did not receive its pooled compact slots for \(aCount)/\(hCount)")
   check(pooled.historyList.frame.height==CGFloat(hSlots==0 ? 32:hSlots*64),"history did not receive its pooled compact slots for \(aCount)/\(hCount)")
   let labels=Set(descendants(pooled.view).compactMap{$0 as? NSButton}.filter{!$0.isHiddenOrHasHiddenAncestor}.compactMap{$0.accessibilityLabel()})
   check(labels.contains("展开活动会话")==Bool(aCount>aSlots),"activity disclosure threshold disagrees with allocated slots")
   check(labels.contains("展开最近会话")==Bool(hCount>hSlots),"history disclosure threshold disagrees with allocated slots")
  }
  let constrainedStore=SessionMenuStore()
  check(constrainedStore.ingest(data(["a1","a2","h1","h2"].map{node($0)},active:["a1","a2"],history:["h1","h2"],omitted:1),at:1000),"constrained disclosure fixture decode")
  let constrained=SessionMenuViewController(availableSize:NSSize(width:420,height:400))
  constrained.update(snapshot:constrainedStore.snapshot,status:"DSH 已连接",stale:false,error:"测试错误")
  let constrainedWindow=NSWindow(contentRect:constrained.view.frame,styleMask:[],backing:.buffered,defer:false)
  constrainedWindow.contentViewController=constrained;constrained.view.layoutSubtreeIfNeeded()
  let constrainedLabels=Set(descendants(constrained.view).compactMap{$0 as? NSButton}.filter{!$0.isHiddenOrHasHiddenAncestor}.compactMap{$0.accessibilityLabel()})
  check(constrained.activeList.frame.height==64 && constrained.historyList.frame.height==64 && constrained.view.frame.height<=400,"constrained panel cuts a row or exceeds the screen")
  check(constrainedLabels.contains("展开活动会话") && constrainedLabels.contains("展开最近会话"),"final constrained heights conceal a session without its disclosure")
  let sections=SessionMenuViewController(availableSize:NSSize(width:420,height:600))
  sections.update(snapshot:split.snapshot,status:"DSH 已连接",stale:false,error:nil)
  sections.toggle("parent")
  let sectionWindow=NSWindow(contentRect:sections.view.frame,styleMask:[],backing:.buffered,defer:false)
  sectionWindow.contentViewController=sections;sections.view.layoutSubtreeIfNeeded()
  func sectionButton(_ label:String)->NSButton? {descendants(sections.view).compactMap{$0 as? NSButton}.first{!$0.isHidden && $0.accessibilityLabel()==label}}
  check(sectionButton("展开活动会话") != nil && sectionButton("展开最近会话") != nil,"overflow sections lack expansion controls")
  let wheel=NSEvent(cgEvent:CGEvent(scrollWheelEvent2Source:nil,units:.pixel,wheelCount:1,wheel1:-160,wheel2:0,wheel3:0)!)!
  let fixedOrigin=sections.activeList.scrollView.contentView.bounds.origin
  sections.activeList.scrollView.scrollWheel(with:wheel)
  sections.activeList.table.scrollWheel(with:wheel)
  check(sections.activeList.scrollView.contentView.bounds.origin==fixedOrigin,"wheel still moves the fixed session panel")
  var resized:NSSize?,sizeBeforeParentResize:NSSize?
  sections.onResize={resized=$0;sizeBeforeParentResize=sections.view.frame.size}
  let collapsedActivity=sections.activeList.frame.height,collapsedHistory=sections.historyList.frame.height,collapsedPanel=sections.view.frame.height
  let existingRoot=sections.activeList.table.view(atColumn:0,row:0,makeIfNecessary:true)
  sectionButton("展开活动会话")!.performClick(nil)
  check(sizeBeforeParentResize?.height==collapsedPanel,"child resized before its popover parent, allowing AppKit to restore the old window size")
  check(sections.activeList.table.view(atColumn:0,row:0,makeIfNecessary:true)===existingRoot,"section expansion rebuilt unchanged visible rows")
  sectionButton("收起活动会话")!.performClick(nil)
  check(sections.activeList.table.view(atColumn:0,row:0,makeIfNecessary:true)===existingRoot,"section collapse rebuilt unchanged visible rows")
  sectionButton("展开活动会话")!.performClick(nil)
  check(sections.activeList.frame.height>collapsedActivity && sections.view.frame.height>collapsedPanel,"activity expansion did not increase its viewport")
  check(sections.historyList.frame.height==collapsedHistory,"activity expansion changed the collapsed history viewport")
  check(resized==sections.view.frame.size,"expanded size did not reach the popover callback")
  check(sectionButton("收起活动会话") != nil && sections.view.frame.height<=600,"expanded activity cannot collapse or exceeds screen bounds")
  let expandedActivity=sections.activeList.frame.height
  check(sectionButton("向下查看活动会话")?.isEnabled==true,"screen-bounded tree has no arrow to reach further children")
  var steps=0
  while let next=sectionButton("向下查看活动会话"),next.isEnabled,steps<500 {next.performClick(nil);steps+=1}
  let end=sections.activeList.scrollView.contentView.bounds
  check(end.maxY>=sections.activeList.naturalHeight-1 && steps>0 && steps<500,"arrow navigation cannot reach the last child")
  check(sections.activeList.stickyRootId=="parent" && sectionButton("向上查看活动会话")?.isEnabled==true,"arrow navigation lost the root or return control")
  let stickyContainer=sections.activeList.subviews.compactMap{$0 as? NSVisualEffectView}.first!
  let stableStickyRow=stickyContainer.subviews.first
  sections.activeList.updateSticky()
  check(stickyContainer.subviews.first===stableStickyRow,"unchanged sticky root was rebuilt during viewport layout")
  let endOrigin=end.origin
  sections.activeList.table.scrollWheel(with:wheel);sections.activeList.scrollView.scrollWheel(with:wheel)
  check(sections.activeList.scrollView.contentView.bounds.origin==endOrigin,"expanded panel still responds to the wheel")
  sections.update(snapshot:split.snapshot,status:"DSH 已连接",stale:false,error:nil)
  check(sections.activeList.frame.height==expandedActivity && sections.activeList.scrollView.contentView.bounds.origin==endOrigin,"ordinary refresh resets expansion or arrow position")
  sectionButton("向上查看活动会话")!.performClick(nil)
  check(sections.activeList.scrollView.contentView.bounds.minY<end.minY,"up arrow did not return to previous children")
  sectionButton("收起活动会话")!.performClick(nil)
  check(sections.activeList.frame.height==collapsedActivity,"activity collapse did not restore compact height")
  check(sections.activeList.scrollView.contentView.bounds.minY==0,"section collapse did not reset the fixed viewport")
  let existingRecent=sections.historyList.table.view(atColumn:0,row:0,makeIfNecessary:true)
  sectionButton("展开最近会话")!.performClick(nil)
  check(sections.historyList.table.view(atColumn:0,row:0,makeIfNecessary:true)===existingRecent,"history expansion rebuilt unchanged visible rows")
  check(sections.historyList.frame.height>collapsedHistory && sections.activeList.frame.height==collapsedActivity,"history expansion failed or changed activity viewport")
  check(!sections.activeList.scrollView.hasVerticalScroller && !sections.historyList.scrollView.hasVerticalScroller,"a section retained a scrollbar")
  sectionButton("展开活动会话")!.performClick(nil)
  check(sections.view.frame.height<=600 && sections.activeList.frame.height.truncatingRemainder(dividingBy:64)==0 && sections.historyList.frame.height.truncatingRemainder(dividingBy:64)==0,"two expanded sections exceed bounds or cut a row")
  sections.activeList.table.scrollRowToVisible(sections.activeList.rows.count-1)
  check(sections.activeList.table.rows(in:sections.activeList.scrollView.contentView.bounds).contains(sections.activeList.rows.count-1),"bounded expanded tree lost its last child")
  let shortScreen=SessionMenuViewController(availableSize:NSSize(width:300,height:400))
  shortScreen.update(snapshot:split.snapshot,status:"DSH 已连接",stale:false,error:nil);shortScreen.toggle("parent")
  let shortWindow=NSWindow(contentRect:shortScreen.view.frame,styleMask:[],backing:.buffered,defer:false)
  shortWindow.contentViewController=shortScreen;shortScreen.view.layoutSubtreeIfNeeded()
  let shortActivity=shortScreen.activeList.frame.height,shortHistory=shortScreen.historyList.frame.height
  func shortButton(_ label:String)->NSButton? {descendants(shortScreen.view).compactMap{$0 as? NSButton}.first{!$0.isHidden && $0.accessibilityLabel()==label}}
  shortButton("展开活动会话")!.performClick(nil)
  check(shortScreen.activeList.frame.height>=shortActivity && shortScreen.historyList.frame.height==shortHistory,"small-screen expansion shrank activity or enlarged collapsed history")
  shortButton("向下查看活动会话")!.performClick(nil)
  let shortClip=shortScreen.activeList.scrollView.contentView.bounds
  check((0..<shortScreen.activeList.rows.count).contains{index in let rect=shortScreen.activeList.table.rect(ofRow:index);return shortScreen.activeList.rows[index].depth>0 && rect.minY>=shortClip.minY+64 && rect.maxY<=shortClip.maxY},"sticky root covers every child on a short screen")
  shortButton("展开最近会话")!.performClick(nil)
  check(shortScreen.activeList.frame.height>=shortActivity && shortScreen.historyList.frame.height>=shortHistory && shortScreen.view.frame.height<=400,"two-section expansion shrinks compact rows or exceeds short screen")
  let few=SessionMenuStore();check(few.ingest(data([node("one"),node("recent",nil,[],"completed")],active:["one"],history:["recent"]),at:1000),"short section fixture decode")
  sections.update(snapshot:few.snapshot,status:"DSH 已连接",stale:false,error:nil);sections.view.layoutSubtreeIfNeeded()
  check(sectionButton("展开活动会话")==nil && sectionButton("展开最近会话")==nil && sectionButton("收起最近会话")==nil,"short sections retain useless expansion controls")
  check(sections.activeList.table.frame.height<=sections.activeList.scrollView.contentView.bounds.height+1,"fitting rows retain phantom scrollable space")
  var fallback=node("fallback");fallback["workspaceTitle"]="未分组";fallback["workspaceUnassigned"]=true;fallback["sessionTitle"]="未命名会话";fallback["sessionUntitled"]=true;fallback["preview"]="无文字输入";fallback["previewKind"]="empty"
  var literal=node("literal");literal["workspaceTitle"]="未分组";literal["sessionTitle"]="未命名会话";literal["preview"]="无文字输入"
  let languageStore=SessionMenuStore();check(languageStore.ingest(data([fallback,literal],active:["fallback","literal"]),at:1000),"language provenance fixture decode")
  UILocalization.set("en")
  sections.update(snapshot:languageStore.snapshot,status:languageStore.status(at:1000),stale:false,error:nil)
  let localized=languageStore.snapshot!.nodes.first{$0.id=="fallback"}!,raw=languageStore.snapshot!.nodes.first{$0.id=="literal"}!
  check(localized.title=="Ungrouped · Untitled" && localized.displayPreview=="No text input","synthetic menu fallbacks not localized")
  check(raw.title=="未分组 · 未命名会话" && raw.displayPreview=="无文字输入","actual names/content matching UI keys were translated")
  check(sections.activeList.table.accessibilityLabel()=="Active session list" && sections.historyList.table.accessibilityLabel()=="Recent session list","existing list accessibility did not switch live")
  UILocalization.set("zh")
  check(sections.activeList.table.accessibilityLabel()=="活动会话列表","accessibility did not switch back")
  print("PASS native menu decode/bounds/stale/recovery, 400-child arrow navigation, fixed wheel, deep tree, keyboard/accessibility, real progress, section expansion, language provenance and enabled lifecycle")
 }
}

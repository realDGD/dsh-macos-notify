import Cocoa
struct MenuVisibleRow {
 let sessionId:String?;let section:String?;let depth:Int
}
final class MenuProgressView:NSView {
 var completed=0,total=0
 override func draw(_ dirtyRect:NSRect) {
  guard total>0 else{return}
  let rect=NSRect(x:3,y:bounds.midY-10,width:20,height:20)
  NSColor.tertiaryLabelColor.setStroke();let track=NSBezierPath(ovalIn:rect);track.lineWidth=2;track.stroke()
  NSColor.controlAccentColor.setStroke();let arc=NSBezierPath();arc.lineWidth=2
  arc.appendArc(withCenter:NSPoint(x:rect.midX,y:rect.midY),radius:10,startAngle:90,endAngle:90-360*CGFloat(completed)/CGFloat(total),clockwise:true);arc.stroke()
  let text="\(completed)/\(total)" as NSString
  text.draw(in:NSRect(x:29,y:bounds.midY-8,width:max(0,bounds.width-29),height:17),withAttributes:[.font:NSFont.systemFont(ofSize:10),.foregroundColor:NSColor.secondaryLabelColor])
 }
}
final class SessionMenuRowView:NSTableCellView {
 let title=NSTextField(labelWithString:""),preview=NSTextField(labelWithString:""),status=NSTextField(labelWithString:""),progress=MenuProgressView()
 private let disclosure=NSButton(title:"",target:nil,action:nil),dot=NSView()
 private var onDisclosure:(()->Void)?
 init(node:MenuNode,depth:Int,expanded:Bool,stale:Bool,onDisclosure:@escaping()->Void) {
  super.init(frame:.zero);self.onDisclosure=onDisclosure
  for label in [title,preview,status] {label.maximumNumberOfLines=1;label.lineBreakMode = .byTruncatingTail;label.cell?.truncatesLastVisibleLine=true}
  title.stringValue=(depth>8 ? "第\(depth)层 · ":"")+node.title;title.font = .systemFont(ofSize:12,weight:.semibold)
  preview.stringValue=(node.previewKind=="task" ? "任务：":"")+node.preview;preview.font = .systemFont(ofSize:11);preview.textColor = .secondaryLabelColor
  status.stringValue=(node.pinned ? "📌 ":"")+node.state.label
  if let badge=node.descendantBadge,let state=MenuSessionState(rawValue:badge){status.stringValue+=" · 子代理"+state.label}
  status.font = .systemFont(ofSize:10);status.textColor = .secondaryLabelColor
  dot.wantsLayer=true;dot.layer?.cornerRadius=4
  let color:NSColor
  switch node.state {case .waitingQuestions,.waitingApproval:color = .systemYellow;case .error,.interrupted,.maxTokens:color = .systemRed
   case .running:color = .systemBlue;case .completed:color = .systemGreen;default:color = .systemGray}
  dot.layer?.backgroundColor=color.cgColor
  disclosure.title=node.childIds.isEmpty ? "":expanded ? "▾":"▸";disclosure.isBordered=false;disclosure.isEnabled = !node.childIds.isEmpty
  disclosure.target=self;disclosure.action=#selector(toggle);disclosure.setAccessibilityLabel((expanded ? "收起":"展开")+node.sessionTitle+"的子代理")
  if let value=node.progress {progress.completed=value.completed;progress.total=value.total}
  progress.isHidden=node.progress==nil;progress.setAccessibilityLabel(node.progress.map{"任务 \($0.completed)/\($0.total)"})
  let offset=CGFloat(min(depth,8))*12
  for child in [disclosure,dot,title,preview,status,progress] {child.translatesAutoresizingMaskIntoConstraints=false;addSubview(child)}
  let textEnd=node.progress==nil ? trailingAnchor:progress.leadingAnchor
  NSLayoutConstraint.activate([
   disclosure.leadingAnchor.constraint(equalTo:leadingAnchor,constant:4+offset),disclosure.widthAnchor.constraint(equalToConstant:16),disclosure.topAnchor.constraint(equalTo:topAnchor,constant:5),disclosure.heightAnchor.constraint(equalToConstant:20),
   dot.leadingAnchor.constraint(equalTo:disclosure.trailingAnchor,constant:2),dot.widthAnchor.constraint(equalToConstant:8),dot.heightAnchor.constraint(equalToConstant:8),dot.topAnchor.constraint(equalTo:topAnchor,constant:12),
   title.leadingAnchor.constraint(equalTo:dot.trailingAnchor,constant:6),title.trailingAnchor.constraint(equalTo:textEnd,constant:-6),title.topAnchor.constraint(equalTo:topAnchor,constant:5),title.heightAnchor.constraint(equalToConstant:17),
   preview.leadingAnchor.constraint(equalTo:title.leadingAnchor),preview.trailingAnchor.constraint(equalTo:textEnd,constant:-6),preview.topAnchor.constraint(equalTo:title.bottomAnchor,constant:2),preview.heightAnchor.constraint(equalToConstant:16),
   status.leadingAnchor.constraint(equalTo:title.leadingAnchor),status.trailingAnchor.constraint(equalTo:textEnd,constant:-6),status.topAnchor.constraint(equalTo:preview.bottomAnchor,constant:2),status.heightAnchor.constraint(equalToConstant:14),
   progress.trailingAnchor.constraint(equalTo:trailingAnchor,constant:-6),progress.widthAnchor.constraint(equalToConstant:66),progress.centerYAnchor.constraint(equalTo:centerYAnchor),progress.heightAnchor.constraint(equalToConstant:26)])
  alphaValue=stale ? 0.5:1;setAccessibilityElement(true);setAccessibilityRole(.row);setAccessibilityLabel(node.accessibleLabel)
 }
 required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")}
 @objc private func toggle(){onDisclosure?()}
}
final class MenuTableView:NSTableView {
 var keyHandler:((UInt16)->Bool)?
 override func keyDown(with event:NSEvent){if keyHandler?(event.keyCode) != true {super.keyDown(with:event)}}
}
final class SessionMenuViewController:NSViewController,NSTableViewDataSource,NSTableViewDelegate {
 let table=MenuTableView(),scrollView=NSScrollView()
 private(set) var visibleRows:[MenuVisibleRow]=[]
 var onOpenSession:((String)->Void)?,onDisableMenu:(()->Void)?,onOpenDesktop:(()->Void)?,onClose:(()->Void)?
 private let connection=NSTextField(labelWithString:""),errorLabel=NSTextField(labelWithString:""),footer=NSTextField(labelWithString:"")
 private var snapshot:MenuSnapshot?,nodes:[String:MenuNode]=[:],expanded=Set<String>(),stale=false
 private let availableSize:NSSize
 init(availableSize:NSSize){self.availableSize=availableSize;super.init(nibName:nil,bundle:nil);loadView()}
 required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")}
 override func loadView() {
  view=NSView(frame:NSRect(x:0,y:0,width:min(420,availableSize.width),height:min(220,availableSize.height)))
  let heading=NSTextField(labelWithString:"DSH Notify"),gear=NSButton(image:NSImage(systemSymbolName:"gearshape",accessibilityDescription:"菜单栏设置") ?? NSImage(),target:self,action:#selector(settingsMenu))
  heading.font = .systemFont(ofSize:14,weight:.semibold);gear.isBordered=false
  connection.font = .systemFont(ofSize:11);connection.textColor = .secondaryLabelColor
  errorLabel.font = .systemFont(ofSize:11);errorLabel.textColor = .systemRed;errorLabel.maximumNumberOfLines=2
  footer.font = .systemFont(ofSize:11);footer.textColor = .secondaryLabelColor;footer.maximumNumberOfLines=1
  for label in [connection,errorLabel,footer]{label.lineBreakMode = .byTruncatingTail}
  let column=NSTableColumn(identifier:NSUserInterfaceItemIdentifier("session"));table.addTableColumn(column)
  table.headerView=nil;table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle;table.selectionHighlightStyle = .regular
  table.intercellSpacing=NSSize(width:0,height:0);table.dataSource=self;table.delegate=self;table.target=self;table.action=#selector(clicked)
  table.keyHandler={[weak self] key in self?.handleKey(key) ?? false}
  table.setAccessibilityLabel("DSH 会话列表")
  table.backgroundColor = .clear
  scrollView.drawsBackground=false;scrollView.contentView.drawsBackground=false
  scrollView.documentView=table;scrollView.hasVerticalScroller=true;scrollView.hasHorizontalScroller=false;scrollView.autohidesScrollers=true
  for child in [heading,gear,connection,scrollView,errorLabel,footer]{child.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(child)}
  NSLayoutConstraint.activate([
   heading.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:14),heading.topAnchor.constraint(equalTo:view.topAnchor,constant:12),heading.heightAnchor.constraint(equalToConstant:20),
   gear.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-10),gear.topAnchor.constraint(equalTo:view.topAnchor,constant:8),gear.widthAnchor.constraint(equalToConstant:26),gear.heightAnchor.constraint(equalToConstant:26),
   connection.leadingAnchor.constraint(equalTo:heading.leadingAnchor),connection.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-12),connection.topAnchor.constraint(equalTo:heading.bottomAnchor,constant:3),connection.heightAnchor.constraint(equalToConstant:17),
   scrollView.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:6),scrollView.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-6),scrollView.topAnchor.constraint(equalTo:connection.bottomAnchor,constant:8),
   errorLabel.leadingAnchor.constraint(equalTo:heading.leadingAnchor),errorLabel.trailingAnchor.constraint(equalTo:connection.trailingAnchor),errorLabel.topAnchor.constraint(equalTo:scrollView.bottomAnchor,constant:4),errorLabel.heightAnchor.constraint(equalToConstant:30),
   footer.leadingAnchor.constraint(equalTo:heading.leadingAnchor),footer.trailingAnchor.constraint(equalTo:connection.trailingAnchor),footer.topAnchor.constraint(equalTo:errorLabel.bottomAnchor,constant:2),footer.bottomAnchor.constraint(equalTo:view.bottomAnchor,constant:-8),footer.heightAnchor.constraint(equalToConstant:17)])
 }
 func update(snapshot:MenuSnapshot?,status:String,stale:Bool,error:String?) {
  self.snapshot=snapshot;self.stale=stale;nodes=Dictionary(uniqueKeysWithValues:(snapshot?.nodes ?? []).map{($0.id,$0)})
  connection.stringValue=status;errorLabel.stringValue=error ?? ""
  footer.stringValue=(snapshot?.omittedCount ?? 0)>0 ? "另有 \(snapshot!.omittedCount) 条，请在 DSH 查看":"点击会话打开 DSH · 箭头展开子代理"
  rebuild()
 }
 private func rebuild() {
  let selected=table.selectedRow>=0 && table.selectedRow<visibleRows.count ? visibleRows[table.selectedRow].sessionId:nil
  visibleRows=[]
  func section(_ title:String,_ ids:[String]) {
   guard !ids.isEmpty else{return};visibleRows.append(MenuVisibleRow(sessionId:nil,section:title,depth:0))
   var stack=ids.reversed().map{($0,0)}
   while let (id,depth)=stack.popLast(),let node=nodes[id] {
    visibleRows.append(MenuVisibleRow(sessionId:id,section:nil,depth:depth))
    if expanded.contains(id) {for child in node.childIds.reversed(){stack.append((child,depth+1))}}
   }
  }
  if let snapshot=snapshot {section("活动会话",snapshot.activeIds);section("未归属子代理",snapshot.orphanIds);section("最近会话",snapshot.historyIds)}
  if visibleRows.isEmpty{visibleRows=[MenuVisibleRow(sessionId:nil,section:snapshot?.availability=="loading" ? "正在加载会话…":"暂无会话",depth:0)]}
  table.reloadData()
  let height=CGFloat(visibleRows.reduce(0){$0+($1.sessionId==nil ? 26:64)})+126
  view.setFrameSize(NSSize(width:min(420,availableSize.width),height:min(max(180,height),min(600,availableSize.height))))
  view.layoutSubtreeIfNeeded()
  if let selected=selected,let index=visibleRows.firstIndex(where:{$0.sessionId==selected}) {table.selectRowIndexes(IndexSet(integer:index),byExtendingSelection:false)}
 }
 func toggle(_ id:String){guard nodes[id] != nil else{return};if expanded.contains(id){expanded.remove(id)}else{expanded.insert(id)};rebuild()}
 func numberOfRows(in tableView:NSTableView)->Int {visibleRows.count}
 func tableView(_ tableView:NSTableView,heightOfRow row:Int)->CGFloat {visibleRows[row].sessionId==nil ? 26:64}
 func tableView(_ tableView:NSTableView,shouldSelectRow row:Int)->Bool {visibleRows[row].sessionId != nil}
 func tableView(_ tableView:NSTableView,viewFor tableColumn:NSTableColumn?,row:Int)->NSView? {
  let item=visibleRows[row]
  if let id=item.sessionId,let node=nodes[id] {return SessionMenuRowView(node:node,depth:item.depth,expanded:expanded.contains(id),stale:stale){[weak self] in self?.toggle(id)}}
  let label=NSTextField(labelWithString:item.section ?? "");label.font = .systemFont(ofSize:11,weight:.semibold);label.textColor = .secondaryLabelColor;return label
 }
 @objc private func clicked(){let row=table.clickedRow;guard row>=0,row<visibleRows.count,let id=visibleRows[row].sessionId else{return};onOpenSession?(id)}
 @discardableResult func handleKey(_ key:UInt16)->Bool {
  if key==53{onClose?();return true}
  var index=table.selectedRow
  if key==125 || key==126 {
   let direction=key==125 ? 1:-1;index=index<0 ? (direction==1 ? -1:visibleRows.count):index
   repeat{index+=direction}while index>=0 && index<visibleRows.count && visibleRows[index].sessionId==nil
   if index>=0 && index<visibleRows.count{table.selectRowIndexes(IndexSet(integer:index),byExtendingSelection:false);table.scrollRowToVisible(index)}
   return true
  }
  guard index>=0,index<visibleRows.count,let id=visibleRows[index].sessionId,let node=nodes[id] else{return false}
  if key==36{onOpenSession?(id);return true}
  if key==124 {
   if !node.childIds.isEmpty && !expanded.contains(id){toggle(id)}
   else if let child=node.childIds.first,let row=visibleRows.firstIndex(where:{$0.sessionId==child}){table.selectRowIndexes(IndexSet(integer:row),byExtendingSelection:false);table.scrollRowToVisible(row)}
   return true
  }
  if key==123 {
   if expanded.contains(id){toggle(id)}
   else if let parent=node.parentId,let row=visibleRows.firstIndex(where:{$0.sessionId==parent}){table.selectRowIndexes(IndexSet(integer:row),byExtendingSelection:false);table.scrollRowToVisible(row)}
   return true
  }
  return false
 }
 @objc private func settingsMenu(_ sender:NSButton) {
  let menu=NSMenu();for (title,action) in [("关闭菜单栏",#selector(disableMenu)),("打开 DSH",#selector(openDesktop))] {
   let item=NSMenuItem(title:title,action:action,keyEquivalent:"");item.target=self;menu.addItem(item)
  }
  let note=NSMenuItem(title:"重新启用：DSH 设置 → DSH Notify",action:nil,keyEquivalent:"");note.isEnabled=false;menu.addItem(note)
  menu.popUp(positioning:nil,at:NSPoint(x:0,y:sender.bounds.minY),in:sender)
 }
 @objc private func disableMenu(){onDisableMenu?()}
 @objc private func openDesktop(){onOpenDesktop?()}
}

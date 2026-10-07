import Cocoa
struct MenuVisibleRow {
 let sessionId:String?;let section:String?;let depth:Int
}
final class MenuProgressView:NSView {
 var completed=0,total=0
 override func draw(_ dirtyRect:NSRect) {
  guard total>0 else{return}
  let diameter:CGFloat=34,rect=NSRect(x:(bounds.width-diameter)/2,y:(bounds.height-diameter)/2,width:diameter,height:diameter)
  let done=completed>=total
  (done ? NSColor.systemGreen:NSColor.tertiaryLabelColor).setStroke()
  let track=NSBezierPath(ovalIn:rect);track.lineWidth=2;track.stroke()
  if done {
   let check=NSBezierPath();check.lineWidth=2.5;check.lineCapStyle = .round;check.lineJoinStyle = .round
   check.move(to:NSPoint(x:rect.minX+9,y:rect.midY));check.line(to:NSPoint(x:rect.minX+15,y:rect.midY-6));check.line(to:NSPoint(x:rect.minX+25,y:rect.midY+7));check.stroke()
  } else {
   NSColor.controlAccentColor.setStroke();let arc=NSBezierPath();arc.lineWidth=2
   arc.appendArc(withCenter:NSPoint(x:rect.midX,y:rect.midY),radius:diameter/2,startAngle:90,endAngle:90-360*CGFloat(completed)/CGFloat(total),clockwise:true);arc.stroke()
   let text="\(completed)/\(total)" as NSString
   var size:CGFloat=9
   while size>5 && text.size(withAttributes:[.font:NSFont.monospacedDigitSystemFont(ofSize:size,weight:.medium)]).width>diameter-6{size-=0.5}
   let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.monospacedDigitSystemFont(ofSize:size,weight:.medium),.foregroundColor:NSColor.secondaryLabelColor]
   let measured=text.size(withAttributes:attrs)
   text.draw(at:NSPoint(x:rect.midX-measured.width/2,y:rect.midY-measured.height/2),withAttributes:attrs)
  }
 }
}
final class SessionMenuRowView:NSTableCellView {
 let title=NSTextField(labelWithString:""),preview=NSTextField(labelWithString:""),status=NSTextField(labelWithString:""),progress=MenuProgressView()
 private let disclosure=NSButton(title:"",target:nil,action:nil),dot=NSView()
 private let controls=NSView(),actions=NSStackView(),picker=NSPopUpButton(frame:.zero,pullsDown:true)
 private var actionTargets:[MenuActionTarget]=[]
 private let interactions:[MenuInteraction],stale:Bool
 private let onInteraction:(MenuInteraction,MenuInteractionAction)->Void
 var onOpen:(()->Void)?
 private var onDisclosure:(()->Void)?
 init(node:MenuNode,depth:Int,expanded:Bool,stale:Bool,interactions:[MenuInteraction]=[],onDisclosure:@escaping()->Void,onInteraction:@escaping(MenuInteraction,MenuInteractionAction)->Void={_,_ in}) {
  self.interactions=interactions.filter{$0.sessionId==node.id && !$0.actions.isEmpty};self.stale=stale;self.onInteraction=onInteraction
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
  disclosure.image=node.childIds.isEmpty ? nil:NSImage(systemSymbolName:expanded ? "chevron.down":"chevron.right",accessibilityDescription:nil)
  disclosure.isHidden=node.childIds.isEmpty
  disclosure.contentTintColor = .labelColor;disclosure.isBordered=false;disclosure.isEnabled = !node.childIds.isEmpty
  disclosure.target=self;disclosure.action=#selector(toggle);disclosure.setAccessibilityLabel((expanded ? "收起":"展开")+node.sessionTitle+"的子代理")
  if let value=node.progress {progress.completed=value.completed;progress.total=value.total}
  progress.isHidden=node.progress==nil;progress.setAccessibilityLabel(node.progress.map{"任务 \($0.completed)/\($0.total)"})
  let offset=CGFloat(min(depth,8))*12
  let disclosureWidth:CGFloat=node.childIds.isEmpty && depth==0 ? 0:28
  for child in [disclosure,dot,title,preview,status,progress] {child.translatesAutoresizingMaskIntoConstraints=false;addSubview(child)}
  addSubview(controls)
  configureActions()
  let textEnd=node.progress==nil ? trailingAnchor:progress.leadingAnchor
  NSLayoutConstraint.activate([
   disclosure.leadingAnchor.constraint(equalTo:leadingAnchor,constant:4+offset),disclosure.widthAnchor.constraint(equalToConstant:disclosureWidth),disclosure.topAnchor.constraint(equalTo:topAnchor,constant:5),disclosure.heightAnchor.constraint(equalToConstant:32),
   dot.leadingAnchor.constraint(equalTo:disclosure.trailingAnchor,constant:disclosureWidth==0 ? 0:2),dot.widthAnchor.constraint(equalToConstant:8),dot.heightAnchor.constraint(equalToConstant:8),dot.centerYAnchor.constraint(equalTo:centerYAnchor),
   title.leadingAnchor.constraint(equalTo:dot.trailingAnchor,constant:6),title.trailingAnchor.constraint(equalTo:textEnd,constant:-6),title.topAnchor.constraint(equalTo:topAnchor,constant:5),title.heightAnchor.constraint(equalToConstant:17),
   preview.leadingAnchor.constraint(equalTo:title.leadingAnchor),preview.trailingAnchor.constraint(equalTo:textEnd,constant:-6),preview.topAnchor.constraint(equalTo:title.bottomAnchor,constant:2),preview.heightAnchor.constraint(equalToConstant:16),
   status.leadingAnchor.constraint(equalTo:title.leadingAnchor),status.trailingAnchor.constraint(equalTo:textEnd,constant:-6),status.topAnchor.constraint(equalTo:preview.bottomAnchor,constant:2),status.heightAnchor.constraint(equalToConstant:14),
   progress.trailingAnchor.constraint(equalTo:trailingAnchor,constant:-6),progress.widthAnchor.constraint(equalToConstant:40),progress.centerYAnchor.constraint(equalTo:centerYAnchor),progress.heightAnchor.constraint(equalToConstant:40)])
  alphaValue=stale ? 0.5:1;setAccessibilityElement(true);setAccessibilityRole(.row);setAccessibilityLabel(node.accessibleLabel)
 }
 required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")}
 private func configureActions() {
  actions.orientation = .horizontal;actions.spacing=4
  picker.font = .systemFont(ofSize:10);picker.addItem(withTitle:interactions.count>1 ? "处理请求（\(interactions.count)）":"处理请求")
  picker.menu?.autoenablesItems=false
  picker.setAccessibilityLabel("处理当前会话的审批或问答")
  let callback=onInteraction
  func target(_ item:MenuInteraction,_ action:MenuInteractionAction)->MenuActionTarget {
   let result=MenuActionTarget{callback(item,action)};actionTargets.append(result);return result
  }
  for (index,item) in interactions.enumerated() {
   let menu=NSMenu();menu.autoenablesItems=false
   for action in item.actions {
    let entry=NSMenuItem(title:action.title,action:#selector(MenuActionTarget.invoke),keyEquivalent:"")
    let handler=target(item,action);entry.target=handler;entry.representedObject=handler
    entry.isEnabled = !stale && item.enabled(action);menu.addItem(entry)
    if interactions.count==1 {
     let button=NSButton(title:action.title,target:entry.target,action:entry.action)
     button.font = .systemFont(ofSize:10);button.bezelStyle = .rounded;button.isEnabled=entry.isEnabled
     button.setAccessibilityLabel(action.title+" · "+item.title);actions.addArrangedSubview(button)
    }
   }
   if interactions.count==1 {for entry in menu.items {menu.removeItem(entry);picker.menu?.addItem(entry)}}
   else {let entry=NSMenuItem(title:(item.kind=="approval" ? "审批":"问答")+" \(index+1)："+item.title,action:nil,keyEquivalent:"");entry.submenu=menu;picker.menu?.addItem(entry)}
  }
  picker.isEnabled = !stale
  for child in [actions,picker]{controls.addSubview(child)}
 }
 override func layout() {
  super.layout()
  let available=max(0,preview.frame.width),direct=actions.fittingSize.width
  let compact=interactions.count>1 || available<direct+50
  controls.isHidden=interactions.isEmpty;actions.isHidden=compact;picker.isHidden = !compact
  let width=interactions.isEmpty ? 0:compact ? min(available,min(120,max(44,available-45))):direct
  controls.frame=NSRect(x:preview.frame.maxX-width,y:status.frame.midY-12,width:width,height:24)
  actions.frame=controls.bounds;picker.frame=controls.bounds
  status.frame.size.width=max(0,available-(width==0 ? 0:width+4))
 }
 override func mouseDown(with event:NSEvent){if let onOpen=onOpen{onOpen()}else{super.mouseDown(with:event)}}
 @objc private func toggle(){onDisclosure?()}
}
private final class MenuActionTarget:NSObject {
 private let callback:()->Void
 init(_ callback:@escaping()->Void){self.callback=callback}
 @objc func invoke(){callback()}
}
final class MenuTableView:NSTableView {
 var keyHandler:((UInt16)->Bool)?
 override func keyDown(with event:NSEvent){if keyHandler?(event.keyCode) != true {super.keyDown(with:event)}}
}
final class SessionMenuViewController:NSViewController {
 let activeList=MenuSessionList(frame:.zero),historyList=MenuSessionList(frame:.zero)
 var table:MenuTableView {activeList.table}
 var scrollView:NSScrollView {activeList.scrollView}
 var visibleRows:[MenuVisibleRow] {activeList.rows}
 var onOpenSession:((String)->Void)?,onDisableMenu:(()->Void)?,onOpenDesktop:(()->Void)?,onClose:(()->Void)?
 var onInteraction:((MenuInteraction,MenuInteractionAction)->Void)?
 private let connection=NSTextField(labelWithString:""),errorLabel=NSTextField(labelWithString:""),footer=NSTextField(labelWithString:"")
 private let readButton=NSButton(title:"一键已读",target:nil,action:nil),filter=NSPopUpButton(frame:.zero,pullsDown:false)
 private let activityState:MenuActivityState
 private var snapshot:MenuSnapshot?,nodes:[String:MenuNode]=[:],expanded=Set<String>(),stale=false
 private let availableSize:NSSize
 private var activeHeight:NSLayoutConstraint!,historyHeight:NSLayoutConstraint!
 init(availableSize:NSSize,directory:String?=nil){self.availableSize=availableSize;activityState=MenuActivityState(directory:directory);super.init(nibName:nil,bundle:nil);loadView()}
 required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")}
 override func loadView() {
  view=NSView(frame:NSRect(x:0,y:0,width:min(420,availableSize.width),height:min(280,availableSize.height)))
  let heading=NSTextField(labelWithString:"DSH Notify"),gear=NSButton(image:NSImage(systemSymbolName:"gearshape",accessibilityDescription:"菜单栏设置") ?? NSImage(),target:self,action:#selector(settingsMenu))
  let activityHeading=NSTextField(labelWithString:"活动会话"),historyHeading=NSTextField(labelWithString:"最近会话"),divider=NSBox()
  heading.font = .systemFont(ofSize:14,weight:.semibold);gear.isBordered=false
  for label in [activityHeading,historyHeading]{label.font = .systemFont(ofSize:11,weight:.semibold);label.textColor = .secondaryLabelColor}
  connection.font = .systemFont(ofSize:10);connection.textColor = .secondaryLabelColor
  connection.setContentCompressionResistancePriority(.defaultLow,for:.horizontal)
  errorLabel.font = .systemFont(ofSize:11);errorLabel.textColor = .systemRed;errorLabel.maximumNumberOfLines=2
  footer.font = .systemFont(ofSize:10);footer.textColor = .secondaryLabelColor;footer.maximumNumberOfLines=1
  for label in [connection,errorLabel,footer]{label.lineBreakMode = .byTruncatingTail}
  readButton.font = .systemFont(ofSize:10);readButton.bezelStyle = .rounded;readButton.target=self;readButton.action=#selector(toggleRead)
  filter.addItems(withTitles:["全部","只看报错","只看活动中"]);filter.font = .systemFont(ofSize:10);filter.target=self;filter.action=#selector(filterChanged)
  filter.setAccessibilityLabel("活动会话筛选")
  divider.boxType = .separator
  for list in [activeList,historyList] {
   list.onOpen={[weak self] id in self?.onOpenSession?(id)};list.onToggle={[weak self] id in self?.toggle(id)}
   list.onInteraction={[weak self] item,action in self?.onInteraction?(item,action)}
   list.table.keyHandler={[weak self,weak list] key in guard let list=list else{return false};return self?.handleKey(key,list:list) ?? false}
  }
  activeList.table.setAccessibilityLabel("活动会话列表");historyList.table.setAccessibilityLabel("最近会话列表")
  for child in [heading,gear,connection,activityHeading,readButton,filter,activeList,divider,historyHeading,historyList,errorLabel,footer]{child.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(child)}
  activeHeight=activeList.heightAnchor.constraint(equalToConstant:64);historyHeight=historyList.heightAnchor.constraint(equalToConstant:64)
  NSLayoutConstraint.activate([
   heading.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:14),heading.topAnchor.constraint(equalTo:view.topAnchor,constant:12),heading.heightAnchor.constraint(equalToConstant:20),
   gear.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-10),gear.topAnchor.constraint(equalTo:view.topAnchor,constant:8),gear.widthAnchor.constraint(equalToConstant:26),gear.heightAnchor.constraint(equalToConstant:26),
   connection.leadingAnchor.constraint(equalTo:heading.trailingAnchor,constant:9),connection.trailingAnchor.constraint(lessThanOrEqualTo:gear.leadingAnchor,constant:-4),connection.centerYAnchor.constraint(equalTo:heading.centerYAnchor),
   activityHeading.leadingAnchor.constraint(equalTo:heading.leadingAnchor),activityHeading.topAnchor.constraint(equalTo:heading.bottomAnchor,constant:12),activityHeading.heightAnchor.constraint(equalToConstant:22),
   filter.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-12),filter.centerYAnchor.constraint(equalTo:activityHeading.centerYAnchor),filter.widthAnchor.constraint(equalToConstant:100),
   readButton.trailingAnchor.constraint(equalTo:filter.leadingAnchor,constant:-4),readButton.centerYAnchor.constraint(equalTo:activityHeading.centerYAnchor),readButton.widthAnchor.constraint(equalToConstant:76),
   activeList.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:6),activeList.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-6),activeList.topAnchor.constraint(equalTo:activityHeading.bottomAnchor,constant:4),activeHeight,
   divider.leadingAnchor.constraint(equalTo:heading.leadingAnchor),divider.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-14),divider.topAnchor.constraint(equalTo:activeList.bottomAnchor,constant:8),divider.heightAnchor.constraint(equalToConstant:1),
   historyHeading.leadingAnchor.constraint(equalTo:heading.leadingAnchor),historyHeading.topAnchor.constraint(equalTo:divider.bottomAnchor,constant:7),historyHeading.heightAnchor.constraint(equalToConstant:20),
   historyList.leadingAnchor.constraint(equalTo:activeList.leadingAnchor),historyList.trailingAnchor.constraint(equalTo:activeList.trailingAnchor),historyList.topAnchor.constraint(equalTo:historyHeading.bottomAnchor,constant:3),historyHeight,
   errorLabel.leadingAnchor.constraint(equalTo:heading.leadingAnchor),errorLabel.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-12),errorLabel.topAnchor.constraint(equalTo:historyList.bottomAnchor,constant:4),errorLabel.heightAnchor.constraint(equalToConstant:30),
   footer.leadingAnchor.constraint(equalTo:heading.leadingAnchor),footer.trailingAnchor.constraint(equalTo:errorLabel.trailingAnchor),footer.topAnchor.constraint(equalTo:errorLabel.bottomAnchor,constant:2),footer.bottomAnchor.constraint(equalTo:view.bottomAnchor,constant:-8),footer.heightAnchor.constraint(equalToConstant:17)])
 }
 func update(snapshot:MenuSnapshot?,status:String,stale:Bool,error:String?,interactions:[MenuInteraction]=[]) {
  self.snapshot=snapshot;self.stale=stale;nodes=Dictionary(uniqueKeysWithValues:(snapshot?.nodes ?? []).map{($0.id,$0)})
  activityState.update(snapshot)
  let grouped=Dictionary(grouping:interactions,by:{$0.sessionId})
  activeList.interactions=grouped;historyList.interactions=grouped
  expanded.formIntersection(Set(nodes.keys))
  connection.stringValue=status;errorLabel.stringValue=error ?? ""
  footer.stringValue=(snapshot?.omittedCount ?? 0)>0 ? "另有 \(snapshot!.omittedCount) 条，请在 DSH 查看":"点击会话打开 DSH · 箭头展开子代理"
  rebuild()
 }
 private func rebuild() {
  let ids=(snapshot?.activeIds ?? [])+(snapshot?.orphanIds ?? [])
  let active=ids.filter{activityState.includes($0,nodes:nodes)}
  let readHistory=(snapshot?.activeIds ?? []).filter{activityState.isRead($0,nodes:nodes)}
  let recent=Array(Set((snapshot?.historyIds ?? [])+readHistory)).sorted{a,b in
   let ta=nodes[a]?.updatedAt ?? 0,tb=nodes[b]?.updatedAt ?? 0;return ta==tb ? a<b:ta>tb
  }
  activeList.update(ids:active,nodes:nodes,expanded:expanded,stale:stale,empty:snapshot?.availability=="loading" ? "正在加载会话…":activityState.filter == .all ? "暂无本次连接的活动会话":"没有符合筛选的活动会话")
  historyList.update(ids:Array(recent.prefix(5)),nodes:nodes,expanded:expanded,stale:stale,empty:"暂无最近会话")
  readButton.title=activityState.canUndo ? "取消已读":"一键已读"
  readButton.isEnabled=activityState.canUndo || ids.contains{id in !activityState.isRead(id,nodes:nodes) && !activityState.branch(id,nodes:nodes).contains{$0.state.isLive}}
  // Reserve space for both lists; neither must be reached by scrolling the other.
  let budget=max(0,min(600,availableSize.height)-170)
  var a=min(activeList.naturalHeight,budget*0.62),h=min(historyList.naturalHeight,budget*0.38)
  let spare=budget-a-h
  if spare>0{a+=min(spare,max(0,activeList.naturalHeight-a));h=min(historyList.naturalHeight,budget-a)}
  activeHeight.constant=a;historyHeight.constant=h
  view.setFrameSize(NSSize(width:min(420,availableSize.width),height:min(availableSize.height,a+h+170)))
  view.layoutSubtreeIfNeeded();activeList.updateScrollChrome();historyList.updateScrollChrome();activeList.updateSticky();historyList.updateSticky()
 }
 func toggle(_ id:String){guard nodes[id] != nil else{return};if expanded.contains(id){expanded.remove(id)}else{expanded.insert(id)};rebuild()}
 @objc private func toggleRead(){activityState.toggleRead(ids:(snapshot?.activeIds ?? [])+(snapshot?.orphanIds ?? []),nodes:nodes);rebuild()}
 @objc private func filterChanged(){activityState.filter=MenuActivityFilter(rawValue:filter.indexOfSelectedItem) ?? .all;rebuild()}
 @discardableResult func handleKey(_ key:UInt16,list:MenuSessionList?=nil)->Bool {
  let list=list ?? activeList,rows=list.rows,table=list.table
  if key==53{onClose?();return true}
  var index=table.selectedRow
  if key==125 || key==126 {
   let direction=key==125 ? 1:-1;index=index<0 ? (direction==1 ? -1:rows.count):index
   repeat{index+=direction}while index>=0 && index<rows.count && rows[index].sessionId==nil
   if index>=0 && index<rows.count,let id=rows[index].sessionId{list.select(id)}
   return true
  }
  guard index>=0,index<rows.count,let id=rows[index].sessionId,let node=nodes[id] else{return false}
  if key==36{onOpenSession?(id);return true}
  if key==124 {
   if !node.childIds.isEmpty && !expanded.contains(id){toggle(id)}
   else if let child=node.childIds.first{list.select(child)}
   return true
  }
  if key==123 {
   if expanded.contains(id){toggle(id)}
   else if let parent=node.parentId{list.select(parent)}
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

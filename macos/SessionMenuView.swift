import Cocoa
struct MenuVisibleRow {
 let sessionId:String?;let section:String?;let depth:Int;let moreParentId:String?;let moreExpanded:Bool
 init(sessionId:String?=nil,section:String?=nil,depth:Int=0,moreParentId:String?=nil,moreExpanded:Bool=false) {
  self.sessionId=sessionId;self.section=section;self.depth=depth;self.moreParentId=moreParentId;self.moreExpanded=moreExpanded
 }
 var rowHeight:CGFloat {
  if sessionId != nil {return 64}
  if moreParentId != nil {return 24}
  return 32
 }
}
final class MenuProgressView:NSView {
 var completed=0,total=0
 override func draw(_ dirtyRect:NSRect) {
  guard total>0 else{return}
  let done=completed>=total
  let diameter:CGFloat=done ? 22:28,rect=NSRect(x:(bounds.width-diameter)/2,y:(bounds.height-diameter)/2,width:diameter,height:diameter)
  if done {
   MenuStatusPalette.green.withAlphaComponent(0.75).setStroke()
   let track=NSBezierPath(ovalIn:rect);track.lineWidth=1.6;track.stroke()
   let check=NSBezierPath();check.lineWidth=1.8;check.lineCapStyle = .round;check.lineJoinStyle = .round
   check.move(to:NSPoint(x:rect.minX+6.2,y:rect.midY-0.2))
   check.line(to:NSPoint(x:rect.minX+9.8,y:rect.midY-3.8))
   check.line(to:NSPoint(x:rect.minX+16.0,y:rect.midY+3.8))
   check.stroke()
  } else {
   NSColor.tertiaryLabelColor.setStroke()
   let track=NSBezierPath(ovalIn:rect);track.lineWidth=1.8;track.stroke()
   NSColor.controlAccentColor.setStroke()
   let arc=NSBezierPath();arc.lineWidth=2.0;arc.lineCapStyle = .round
   arc.appendArc(withCenter:NSPoint(x:rect.midX,y:rect.midY),radius:diameter/2,startAngle:90,endAngle:90-360*CGFloat(completed)/CGFloat(total),clockwise:true)
   arc.stroke()
   let text="\(completed)/\(total)" as NSString
   var size:CGFloat=8.5
   while size>5 && text.size(withAttributes:[.font:NSFont.monospacedDigitSystemFont(ofSize:size,weight:.medium)]).width>diameter-6{size-=0.5}
   let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.monospacedDigitSystemFont(ofSize:size,weight:.medium),.foregroundColor:NSColor.secondaryLabelColor]
   let measured=text.size(withAttributes:attrs)
   text.draw(at:NSPoint(x:rect.midX-measured.width/2,y:rect.midY-measured.height/2),withAttributes:attrs)
  }
 }
}
private final class MenuApprovalButton:NSButton {
 // This custom drawing uses the whole bounds. Native rounded-bezel alignment
 // margins on older AppKit would enlarge a 76x22 control to 90x34.
 override var alignmentRectInsets:NSEdgeInsets {NSEdgeInsets(top:0,left:0,bottom:0,right:0)}
 override func draw(_ dirtyRect:NSRect) {
  let color=bezelColor ?? MenuStatusPalette.green
  let shape=NSBezierPath(roundedRect:bounds.insetBy(dx:1,dy:1),xRadius:6,yRadius:6)
  color.withAlphaComponent(isEnabled ? (cell?.isHighlighted==true ? 0.28:0.14):0.06).setFill();shape.fill()
  color.withAlphaComponent(isEnabled ? 0.35:0.12).setStroke();shape.lineWidth=0.7;shape.stroke()
  if window?.firstResponder===self {NSGraphicsContext.saveGraphicsState();NSFocusRingPlacement.only.set();shape.fill();NSGraphicsContext.restoreGraphicsState()}
  let attrs:[NSAttributedString.Key:Any]=[.font:font ?? NSFont.systemFont(ofSize:10),.foregroundColor:isEnabled ? color:NSColor.disabledControlTextColor]
  let text=title as NSString,size=text.size(withAttributes:attrs)
  text.draw(at:NSPoint(x:(bounds.width-size.width)/2,y:(bounds.height-size.height)/2),withAttributes:attrs)
 }
}
private final class MenuDisclosureButton:NSButton {
 private var hoverArea:NSTrackingArea?,hovered=false
 override var alignmentRectInsets:NSEdgeInsets {NSEdgeInsets(top:0,left:0,bottom:0,right:0)}
 override func updateTrackingAreas() {
  super.updateTrackingAreas()
  if let area=hoverArea{removeTrackingArea(area)}
  let area=NSTrackingArea(rect:.zero,options:[.mouseEnteredAndExited,.activeAlways,.inVisibleRect],owner:self,userInfo:nil)
  addTrackingArea(area);hoverArea=area
  hovered=window.map{!isHiddenOrHasHiddenAncestor && bounds.contains(convert($0.mouseLocationOutsideOfEventStream,from:nil))} ?? false
  needsDisplay=true
 }
 override func mouseEntered(with event:NSEvent){hovered=true;needsDisplay=true}
 override func mouseExited(with event:NSEvent){hovered=false;needsDisplay=true}
 override func draw(_ dirtyRect:NSRect) {
  if isEnabled && (hovered || cell?.isHighlighted==true) {
   NSColor.labelColor.withAlphaComponent(cell?.isHighlighted==true ? 0.14:0.08).setFill()
   NSBezierPath(roundedRect:bounds.insetBy(dx:1,dy:1),xRadius:5,yRadius:5).fill()
  }
  super.draw(dirtyRect)
 }
}
final class SessionMenuRowView:NSTableCellView {
 let title=NSTextField(labelWithString:""),preview=NSTextField(labelWithString:""),status=NSTextField(labelWithString:""),progress=MenuProgressView()
 private let disclosure=MenuDisclosureButton(title:"",target:nil,action:nil),dot=NSView()
 private let controls=NSView(),actions=NSStackView(),picker=NSPopUpButton(frame:.zero,pullsDown:true)
 private var actionTargets:[MenuActionTarget]=[],textTrails:[NSLayoutConstraint]=[]
 private let interactions:[MenuInteraction],stale:Bool
 private let onInteraction:(MenuInteraction,MenuInteractionAction)->Void
 var onOpen:(()->Void)?
 private var onDisclosure:(()->Void)?
 init(node:MenuNode,depth:Int,expanded:Bool,stale:Bool,interactions:[MenuInteraction]=[],onDisclosure:@escaping()->Void,onInteraction:@escaping(MenuInteraction,MenuInteractionAction)->Void={_,_ in}) {
  self.interactions=interactions.filter{$0.sessionId==node.id && !$0.actions.isEmpty};self.stale=stale;self.onInteraction=onInteraction
  super.init(frame:.zero);self.onDisclosure=onDisclosure
  for label in [title,preview,status] {label.maximumNumberOfLines=1;label.lineBreakMode = .byTruncatingTail;label.cell?.truncatesLastVisibleLine=true;label.setContentCompressionResistancePriority(.defaultLow,for:.horizontal)}
  title.stringValue=(depth>8 ? L("第{0}层 · ", ["0": String(describing: depth)]):"")+node.title;title.font = .systemFont(ofSize:12,weight:.semibold)
  preview.stringValue=(node.previewKind=="task" ? L("任务："):"")+node.displayPreview;preview.font = .systemFont(ofSize:11);preview.textColor = .secondaryLabelColor
  let statusFont=NSFont.systemFont(ofSize:10)
  let statusText=node.state.label+(node.descendantBadge.flatMap{MenuSessionState(rawValue:$0)}.map{L(" · 子智能体")+$0.label} ?? "")
  if node.pinned,let pinImage=NSImage(systemSymbolName:"pin.fill",accessibilityDescription:nil)?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize:8.0,weight:.medium)) {
   let boxSize=NSSize(width:9,height:9)
   let tinted=NSImage(size:boxSize,flipped:false){rect in
    let imgSize=pinImage.size
    pinImage.draw(in:NSRect(x:(rect.width-imgSize.width)/2,y:(rect.height-imgSize.height)/2,width:imgSize.width,height:imgSize.height))
    NSColor.secondaryLabelColor.setFill();rect.fill(using:.sourceIn);return true
   }
   let attachment=NSTextAttachment();attachment.image=tinted
   attachment.bounds=NSRect(x:0,y:-1.25,width:boxSize.width,height:boxSize.height)
   let attr=NSMutableAttributedString(attachment:attachment)
   attr.append(NSAttributedString(string:" "+statusText,attributes:[.font:statusFont,.foregroundColor:NSColor.secondaryLabelColor]))
   status.font=statusFont;status.textColor = .secondaryLabelColor;status.attributedStringValue=attr
  } else {
   status.stringValue=(node.pinned ? "📌 ":"")+statusText
   status.font=statusFont;status.textColor = .secondaryLabelColor
  }
  dot.wantsLayer=true;dot.layer?.cornerRadius=4
  let color:NSColor
  switch node.state {case .waitingQuestions,.waitingApproval:color = .systemYellow;case .error,.interrupted,.maxTokens:color = .systemRed
   case .running:color = .systemBlue;case .completed:color = .systemGreen;default:color = .systemGray}
  dot.layer?.backgroundColor=color.cgColor
  disclosure.image=node.childIds.isEmpty ? nil:NSImage(systemSymbolName:expanded ? "chevron.down":"chevron.right",accessibilityDescription:nil)?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize:12,weight:.regular))
  disclosure.isHidden=node.childIds.isEmpty
  disclosure.contentTintColor = .secondaryLabelColor;disclosure.isBordered=false;disclosure.isEnabled = !node.childIds.isEmpty
  disclosure.imagePosition = .imageOnly
  disclosure.target=self;disclosure.action=#selector(toggle);disclosure.setAccessibilityLabel((expanded ? L("收起"):L("展开"))+node.displaySessionTitle+L("的子智能体"))
  if let value=node.progress {progress.completed=value.completed;progress.total=value.total}
  progress.isHidden=node.progress==nil;progress.setAccessibilityLabel(node.progress.map{L("任务 {0}/{1}", ["0": String(describing: $0.completed), "1": String(describing: $0.total)])})
  let offset=CGFloat(min(depth,8))*12
  for child in [disclosure,dot,title,preview,status,progress] {child.translatesAutoresizingMaskIntoConstraints=false;addSubview(child)}
  addSubview(controls)
  configureActions()
  let textEnd=node.progress==nil ? trailingAnchor:progress.leadingAnchor
  textTrails=[disclosure,preview,status].map{$0.trailingAnchor.constraint(equalTo:textEnd,constant:-6)}
  NSLayoutConstraint.activate(textTrails+[
   dot.leadingAnchor.constraint(equalTo:leadingAnchor,constant:2+offset),dot.widthAnchor.constraint(equalToConstant:8),dot.heightAnchor.constraint(equalToConstant:8),dot.centerYAnchor.constraint(equalTo:centerYAnchor),
   disclosure.widthAnchor.constraint(equalToConstant:28),disclosure.centerYAnchor.constraint(equalTo:title.centerYAnchor),disclosure.heightAnchor.constraint(equalToConstant:26),
   title.leadingAnchor.constraint(equalTo:leadingAnchor,constant:15+offset),title.trailingAnchor.constraint(equalTo:disclosure.leadingAnchor,constant:-6),title.topAnchor.constraint(equalTo:topAnchor,constant:5),title.heightAnchor.constraint(equalToConstant:17),
   preview.leadingAnchor.constraint(equalTo:title.leadingAnchor),preview.topAnchor.constraint(equalTo:title.bottomAnchor,constant:2),preview.heightAnchor.constraint(equalToConstant:16),
   status.leadingAnchor.constraint(equalTo:title.leadingAnchor),status.topAnchor.constraint(equalTo:preview.bottomAnchor,constant:2),status.heightAnchor.constraint(equalToConstant:14),
   progress.trailingAnchor.constraint(equalTo:trailingAnchor,constant:-6),progress.widthAnchor.constraint(equalToConstant:40),progress.centerYAnchor.constraint(equalTo:centerYAnchor),progress.heightAnchor.constraint(equalToConstant:40)])
  alphaValue=stale ? 0.5:1;setAccessibilityElement(true);setAccessibilityRole(.row);setAccessibilityLabel(node.accessibleLabel)
 }
 required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")}
 private func configureActions() {
  actions.orientation = .vertical;actions.alignment = .width;actions.spacing=3
  picker.font = .systemFont(ofSize:10);picker.addItem(withTitle:interactions.count>1 ? L("处理请求（{0}）", ["0": String(describing: interactions.count)]):L("处理请求"))
  picker.menu?.autoenablesItems=false
  picker.setAccessibilityLabel(L("处理当前会话的审批或问答"))
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
     let button:NSButton=(action == .allow || action == .deny) ? MenuApprovalButton(title:action.title,target:entry.target,action:entry.action):NSButton(title:action.title,target:entry.target,action:entry.action)
     button.font = .systemFont(ofSize:10);button.bezelStyle = .rounded;button.isEnabled=entry.isEnabled
     if action == .allow || action == .deny {button.bezelColor=action == .allow ? MenuStatusPalette.green:MenuStatusPalette.red;button.contentTintColor = .white;button.widthAnchor.constraint(equalToConstant:76).isActive=true;button.heightAnchor.constraint(equalToConstant:22).isActive=true}
     button.setAccessibilityLabel(action.title+" · "+item.title);actions.addArrangedSubview(button)
    }
   }
   if interactions.count==1 {for entry in menu.items {menu.removeItem(entry);picker.menu?.addItem(entry)}}
   else {let entry=NSMenuItem(title:(item.kind=="approval" ? L("审批"):L("问答"))+" \(index+1)："+item.title,action:nil,keyEquivalent:"");entry.submenu=menu;picker.menu?.addItem(entry)}
  }
  picker.isEnabled = !stale
  for child in [actions,picker]{controls.addSubview(child)}
 }
 override func layout() {
  super.layout()
  let end=progress.isHidden ? bounds.width:progress.frame.minX
  let available=max(0,end-6-title.frame.minX),direct=actions.fittingSize.width
  let reserve:CGFloat=disclosure.isHidden ? 0:34
  let titleAvailable=max(0,available-reserve)
  let compact=interactions.count>1 || titleAvailable<direct+50
  controls.isHidden=interactions.isEmpty;actions.isHidden=compact;picker.isHidden = !compact
  let width=interactions.isEmpty ? 0:compact ? min(titleAvailable,min(120,max(44,titleAvailable-45))):direct
  let height:CGFloat=compact ? 24:max(24,actions.fittingSize.height)
  controls.frame=NSRect(x:end-6-width,y:(bounds.height-height)/2,width:width,height:height)
  actions.frame=controls.bounds;picker.frame=controls.bounds
  for trail in textTrails {let constant:CGFloat = -6-(width==0 ? 0:width+6);if trail.constant != constant{trail.constant=constant}}
  // Keep the current layout pass consistent with the constraints that AppKit
  // will resolve on the next pass, including on older control metrics.
  let textWidth=max(0,available-(width==0 ? 0:width+6))
  for label in [preview,status]{label.frame.size.width=textWidth}
  title.frame.size.width=max(0,textWidth-reserve)
  disclosure.frame.origin.x=title.frame.minX+max(0,textWidth-28)
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
 override func scrollWheel(with event:NSEvent) {}
}
final class MenuSubagentMoreRowView:NSTableCellView {
 private let button=MenuDisclosureButton(title:"",target:nil,action:nil)
 private let iconView=NSImageView(),labelField=NSTextField(labelWithString:"")
 private var onToggle:(()->Void)?
 init(parent:MenuNode,depth:Int,expanded:Bool,onToggle:@escaping()->Void) {
  super.init(frame:.zero);self.onToggle=onToggle
  let hiddenCount=max(1,parent.childIds.count-2)
  let offset=CGFloat(min(depth,8))*12
  button.translatesAutoresizingMaskIntoConstraints=false
  button.isBordered=false
  button.title=""
  button.target=self;button.action=#selector(toggle)
  let a11y=(expanded ? L("收起"):L("展开更多"))+parent.displaySessionTitle+L("的子智能体")
  button.setAccessibilityLabel(a11y);button.toolTip=a11y
  iconView.translatesAutoresizingMaskIntoConstraints=false
  iconView.image=NSImage(systemSymbolName:expanded ? "chevron.up":"chevron.down",accessibilityDescription:nil)?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize:9,weight:.semibold))
  iconView.contentTintColor = .secondaryLabelColor
  labelField.translatesAutoresizingMaskIntoConstraints=false
  labelField.font = .systemFont(ofSize:10.5,weight:.regular)
  labelField.textColor = .secondaryLabelColor
  if UILocalization.language=="zh" {
   labelField.stringValue=expanded ? "收起其余 \(hiddenCount) 个子智能体":"还有 \(hiddenCount) 个子智能体"
  } else {
   let suffix=hiddenCount==1 ? "subagent":"subagents"
   labelField.stringValue=expanded ? "Collapse \(hiddenCount) \(suffix)":"\(hiddenCount) more \(suffix)"
  }
  addSubview(iconView);addSubview(labelField);addSubview(button)
  NSLayoutConstraint.activate([
   iconView.centerXAnchor.constraint(equalTo:leadingAnchor,constant:6+offset),
   iconView.centerYAnchor.constraint(equalTo:centerYAnchor),
   labelField.leadingAnchor.constraint(equalTo:leadingAnchor,constant:15+offset),
   labelField.centerYAnchor.constraint(equalTo:centerYAnchor),
   button.leadingAnchor.constraint(equalTo:leadingAnchor,constant:max(0,offset-2)),
   button.trailingAnchor.constraint(equalTo:labelField.trailingAnchor,constant:8),
   button.topAnchor.constraint(equalTo:topAnchor,constant:1),
   button.bottomAnchor.constraint(equalTo:bottomAnchor,constant:-1)])
 }
 required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")}
 @objc private func toggle(){onToggle?()}
}
private final class MenuSectionControls:NSView {
 private let more=NSButton(),previous=NSButton(),next=NSButton()
 private let section:String
 var onExpand:(()->Void)?,onStep:((Int)->Void)?
 init(_ section:String) {
  self.section=section;super.init(frame:.zero)
  for button in [more,previous,next] {
   button.translatesAutoresizingMaskIntoConstraints=false;button.isBordered=false;button.contentTintColor = .secondaryLabelColor;button.target=self;addSubview(button)
  }
  more.action=#selector(expand);previous.action=#selector(up);next.action=#selector(down)
  previous.image=NSImage(systemSymbolName:"chevron.up",accessibilityDescription:nil);next.image=NSImage(systemSymbolName:"chevron.down",accessibilityDescription:nil)
  previous.setAccessibilityLabel(L("向上查看")+L(section));next.setAccessibilityLabel(L("向下查看")+L(section))
  previous.toolTip=L("查看上面的会话");next.toolTip=L("查看更多会话")
  more.font = .systemFont(ofSize:10);more.imageHugsTitle=true
  NSLayoutConstraint.activate([
   more.centerXAnchor.constraint(equalTo:centerXAnchor),more.widthAnchor.constraint(equalToConstant:80),more.topAnchor.constraint(equalTo:topAnchor),more.bottomAnchor.constraint(equalTo:bottomAnchor),
   previous.leadingAnchor.constraint(equalTo:leadingAnchor,constant:14),previous.widthAnchor.constraint(equalToConstant:32),previous.topAnchor.constraint(equalTo:topAnchor),previous.bottomAnchor.constraint(equalTo:bottomAnchor),
   next.trailingAnchor.constraint(equalTo:trailingAnchor,constant:-14),next.widthAnchor.constraint(equalToConstant:32),next.topAnchor.constraint(equalTo:topAnchor),next.bottomAnchor.constraint(equalTo:bottomAnchor)])
 }
 required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")}
 func update(needed:Bool,expanded:Bool,expandable:Bool,overflows:Bool,list:MenuSessionList) {
  previous.setAccessibilityLabel(L("向上查看")+L(section));next.setAccessibilityLabel(L("向下查看")+L(section))
  previous.toolTip=L("查看上面的会话");next.toolTip=L("查看更多会话")
  isHidden = !needed;more.isHidden = !needed || !expandable
  let navigation=overflows && (list.canMoveUp || list.canMoveDown)
  previous.isHidden = !navigation;next.isHidden = !navigation
  previous.isEnabled=list.canMoveUp;next.isEnabled=list.canMoveDown
  more.image=NSImage(systemSymbolName:expanded ? "chevron.up":"chevron.down",accessibilityDescription:nil)
  more.title=navigation ? (expanded ? L("收起"):L("展开")):"";more.imagePosition=navigation ? .imageLeft:.imageOnly
  more.setAccessibilityLabel((expanded ? L("收起"):L("展开"))+L(section));more.toolTip=(expanded ? L("收起"):L("展开更多"))+L(section)
 }
 @objc private func expand(){onExpand?()}
 @objc private func up(){onStep?(-1)}
 @objc private func down(){onStep?(1)}
}
final class SessionMenuViewController:NSViewController {
 let activeList=MenuSessionList(frame:.zero),historyList=MenuSessionList(frame:.zero)
 var table:MenuTableView {activeList.table}
 var scrollView:NSScrollView {activeList.scrollView}
 var visibleRows:[MenuVisibleRow] {activeList.rows}
 var onOpenSession:((String)->Void)?,onOpenSettings:(()->Void)?,onClose:(()->Void)?
 var onInteraction:((MenuInteraction,MenuInteractionAction)->Void)?
 var onResize:((NSSize)->Void)?
 private let connection=NSTextField(labelWithString:""),errorLabel=NSTextField(labelWithString:""),footer=NSTextField(labelWithString:"")
 private let activeMore=MenuSectionControls("活动会话"),historyMore=MenuSectionControls("最近会话")
 private var activityExpanded=false,historyExpanded=false
 private var activityHasMoreRoots=false,historyHasMoreRoots=false
 private var activeDesiredHeight:CGFloat=0,historyDesiredHeight:CGFloat=0
 private var resizeAnimation:MenuResizeAnimation?
 private var renderedLanguage="",hasRendered=false,currentInteractions:[MenuInteraction]=[]
 private var snapshot:MenuSnapshot?,nodes:[String:MenuNode]=[:],expanded=Set<String>(),expandedChildren=Set<String>(),stale=false
 private let availableSize:NSSize
 private var activeHeight:NSLayoutConstraint!,historyHeight:NSLayoutConstraint!
 private var activeMoreHeight:NSLayoutConstraint!,historyMoreHeight:NSLayoutConstraint!
 private var errorHeight:NSLayoutConstraint!,errorSpacing:NSLayoutConstraint!,footerHeight:NSLayoutConstraint!,footerSpacing:NSLayoutConstraint!
 init(availableSize:NSSize){self.availableSize=availableSize;super.init(nibName:nil,bundle:nil);loadView()}
 required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")}
 override func loadView() {
  view=NSView(frame:NSRect(x:0,y:0,width:min(420,availableSize.width),height:min(280,availableSize.height)))
  let heading=NSTextField(labelWithString:"DSH Notify"),gear=NSButton(image:NSImage(systemSymbolName:"gearshape",accessibilityDescription:L("打开 DSH Notify 设置")) ?? NSImage(),target:self,action:#selector(openSettings))
  let activityHeading=uiLabel(L("活动会话")),historyHeading=uiLabel(L("最近会话")),divider=NSBox()
  heading.font = .systemFont(ofSize:14,weight:.semibold);gear.isBordered=false;uiAccessibility(gear,L("打开 DSH Notify 设置"));gear.toolTip=L("打开 DSH Notify 设置")
  for label in [activityHeading,historyHeading]{label.font = .systemFont(ofSize:11,weight:.semibold);label.textColor = .secondaryLabelColor}
  connection.font = .systemFont(ofSize:10);connection.textColor = .secondaryLabelColor
  connection.setContentCompressionResistancePriority(.defaultLow,for:.horizontal)
  errorLabel.font = .systemFont(ofSize:11);errorLabel.textColor = .systemRed;errorLabel.maximumNumberOfLines=2
  footer.font = .systemFont(ofSize:10);footer.textColor = .secondaryLabelColor;footer.maximumNumberOfLines=1
  for label in [connection,errorLabel,footer]{label.lineBreakMode = .byTruncatingTail}
  activeMore.onExpand={[weak self] in self?.toggleActivityExpansion()};historyMore.onExpand={[weak self] in self?.toggleHistoryExpansion()}
  activeMore.onStep={[weak self] direction in self?.activeList.move(direction)};historyMore.onStep={[weak self] direction in self?.historyList.move(direction)}
  activeList.onViewportChange={[weak self] in self?.refreshSectionControls()};historyList.onViewportChange={[weak self] in self?.refreshSectionControls()}
  divider.boxType = .separator
  for list in [activeList,historyList] {
   list.onOpen={[weak self] id in self?.onOpenSession?(id)};list.onToggle={[weak self] id in self?.toggle(id)}
   list.onToggleChildren={[weak self] id in self?.toggleChildren(id)}
   list.onInteraction={[weak self] item,action in self?.onInteraction?(item,action)}
   list.table.keyHandler={[weak self,weak list] key in guard let list=list else{return false};return self?.handleKey(key,list:list) ?? false}
  }
  uiAccessibility(activeList.table,L("活动会话列表"));uiAccessibility(historyList.table,L("最近会话列表"))
  for child in [heading,gear,connection,activityHeading,activeList,activeMore,divider,historyHeading,historyList,historyMore,errorLabel,footer]{child.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(child)}
  activeHeight=activeList.heightAnchor.constraint(equalToConstant:64);historyHeight=historyList.heightAnchor.constraint(equalToConstant:64)
  activeMoreHeight=activeMore.heightAnchor.constraint(equalToConstant:0);historyMoreHeight=historyMore.heightAnchor.constraint(equalToConstant:0)
  errorHeight=errorLabel.heightAnchor.constraint(equalToConstant:0);errorSpacing=errorLabel.topAnchor.constraint(equalTo:historyMore.bottomAnchor)
  footerHeight=footer.heightAnchor.constraint(equalToConstant:0);footerSpacing=footer.topAnchor.constraint(equalTo:errorLabel.bottomAnchor)
  NSLayoutConstraint.activate([
   heading.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:14),heading.topAnchor.constraint(equalTo:view.topAnchor,constant:12),heading.heightAnchor.constraint(equalToConstant:20),
   gear.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-10),gear.topAnchor.constraint(equalTo:view.topAnchor,constant:8),gear.widthAnchor.constraint(equalToConstant:26),gear.heightAnchor.constraint(equalToConstant:26),
   connection.leadingAnchor.constraint(equalTo:heading.trailingAnchor,constant:9),connection.trailingAnchor.constraint(lessThanOrEqualTo:gear.leadingAnchor,constant:-4),connection.firstBaselineAnchor.constraint(equalTo:heading.firstBaselineAnchor,constant:-0.5),
   activityHeading.leadingAnchor.constraint(equalTo:heading.leadingAnchor),activityHeading.topAnchor.constraint(equalTo:heading.bottomAnchor,constant:12),activityHeading.heightAnchor.constraint(equalToConstant:22),
   activeList.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:12),activeList.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-10),activeList.topAnchor.constraint(equalTo:activityHeading.bottomAnchor,constant:4),activeHeight,
   activeMore.leadingAnchor.constraint(equalTo:activeList.leadingAnchor),activeMore.trailingAnchor.constraint(equalTo:activeList.trailingAnchor),activeMore.topAnchor.constraint(equalTo:activeList.bottomAnchor),activeMoreHeight,
   divider.leadingAnchor.constraint(equalTo:heading.leadingAnchor),divider.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-14),divider.topAnchor.constraint(equalTo:activeMore.bottomAnchor,constant:8),divider.heightAnchor.constraint(equalToConstant:1),
   historyHeading.leadingAnchor.constraint(equalTo:heading.leadingAnchor),historyHeading.topAnchor.constraint(equalTo:divider.bottomAnchor,constant:7),historyHeading.heightAnchor.constraint(equalToConstant:20),
   historyList.leadingAnchor.constraint(equalTo:activeList.leadingAnchor),historyList.trailingAnchor.constraint(equalTo:activeList.trailingAnchor),historyList.topAnchor.constraint(equalTo:historyHeading.bottomAnchor,constant:3),historyHeight,
   historyMore.leadingAnchor.constraint(equalTo:historyList.leadingAnchor),historyMore.trailingAnchor.constraint(equalTo:historyList.trailingAnchor),historyMore.topAnchor.constraint(equalTo:historyList.bottomAnchor),historyMoreHeight,
   errorLabel.leadingAnchor.constraint(equalTo:heading.leadingAnchor),errorLabel.trailingAnchor.constraint(equalTo:view.trailingAnchor,constant:-12),errorSpacing,errorHeight,
   footer.leadingAnchor.constraint(equalTo:heading.leadingAnchor),footer.trailingAnchor.constraint(equalTo:errorLabel.trailingAnchor),footerSpacing,footer.bottomAnchor.constraint(equalTo:view.bottomAnchor,constant:-8),footerHeight])
 }
 func update(snapshot:MenuSnapshot?,status:String,stale:Bool,error:String?,interactions:[MenuInteraction]=[]) {
  let changed = renderedLanguage != UILocalization.language || !hasRendered || self.snapshot?.nodes != snapshot?.nodes || self.snapshot?.activeIds != snapshot?.activeIds || self.snapshot?.orphanIds != snapshot?.orphanIds || self.snapshot?.historyIds != snapshot?.historyIds || self.snapshot?.availability != snapshot?.availability || self.snapshot?.omittedCount != snapshot?.omittedCount || self.stale != stale || errorLabel.stringValue != (error ?? "") || currentInteractions != interactions
  renderedLanguage=UILocalization.language;hasRendered=true;currentInteractions=interactions
  self.snapshot=snapshot;self.stale=stale;nodes=Dictionary(uniqueKeysWithValues:(snapshot?.nodes ?? []).map{($0.id,$0)})
  let grouped=Dictionary(grouping:interactions,by:{$0.sessionId})
  activeList.interactions=grouped;historyList.interactions=grouped
  expanded.formIntersection(Set(nodes.keys))
  expandedChildren.formIntersection(expanded)
  let pStyle=NSMutableParagraphStyle();pStyle.lineBreakMode = .byTruncatingTail
  let connFont=NSFont.systemFont(ofSize:10.5,weight:.medium)
  let connColor=(!stale && snapshot?.availability=="ready") ? MenuStatusPalette.green:MenuStatusPalette.yellow
  let dotSize:CGFloat=6
  let dotImage=NSImage(size:NSSize(width:dotSize,height:dotSize),flipped:false){rect in
   connColor.setFill();NSBezierPath(ovalIn:rect).fill();return true
  }
  let dotAttachment=NSTextAttachment();dotAttachment.image=dotImage
  dotAttachment.bounds=NSRect(x:0,y:0.75,width:dotSize,height:dotSize)
  let connAttr=NSMutableAttributedString(attachment:dotAttachment)
  connAttr.append(NSAttributedString(string:"  "+status,attributes:[.font:connFont,.foregroundColor:NSColor.secondaryLabelColor,.paragraphStyle:pStyle]))
  connection.attributedStringValue=connAttr
  uiSet(errorLabel,error ?? "")
  let hasError = !errorLabel.stringValue.isEmpty,hasOverflow=(snapshot?.omittedCount ?? 0)>0
  errorLabel.isHidden = !hasError;errorHeight.constant=hasError ? 30:0;errorSpacing.constant=hasError ? 4:0
  footer.stringValue=hasOverflow ? L("另有 {0} 条，请在 DSH 查看", ["0": String(describing: snapshot!.omittedCount)]):""
  footer.isHidden = !hasOverflow;footerHeight.constant=hasOverflow ? 17:0;footerSpacing.constant=hasOverflow ? (hasError ? 2:4):0
  if changed{rebuild()}
 }
 deinit {resizeAnimation?.invalidate()}
 private func rebuild(reloadRows:Bool=true,animate:Bool=false) {
  resizeAnimation?.invalidate();resizeAnimation=nil
  if reloadRows {
   let ids=(snapshot?.activeIds ?? [])+(snapshot?.orphanIds ?? [])
   activeList.update(ids:ids,nodes:nodes,expanded:expanded,expandedChildren:expandedChildren,stale:stale,empty:snapshot?.availability=="loading" ? L("正在加载会话…"):L("暂无本次连接的活动会话"))
   historyList.update(ids:Array((snapshot?.historyIds ?? []).prefix(5)),nodes:nodes,expanded:expanded,expandedChildren:expandedChildren,stale:stale,empty:L("暂无最近会话"))
  }
  // Reserve space for both lists; neither must be reached by scrolling the other.
  let base=117+errorSpacing.constant+errorHeight.constant+footerSpacing.constant+footerHeight.constant
  let perSection=2,aCount=activeList.rootCount,hCount=historyList.rootCount
  var aSlots=min(aCount,perSection),hSlots=min(hCount,perSection)
  let spareSlots=perSection*2-aSlots-hSlots
  let extraA=min(spareSlots,aCount-aSlots);aSlots+=extraA
  hSlots+=min(spareSlots-extraA,hCount-hSlots)
  let compactA=activeList.heightForRoots(aSlots),compactH=historyList.heightForRoots(hSlots)
  let desiredA=activityExpanded ? activeList.naturalHeight:compactA
  let desiredH=historyExpanded ? historyList.naturalHeight:compactH
  activeDesiredHeight=desiredA;historyDesiredHeight=desiredH
  activityHasMoreRoots=aCount>aSlots;historyHasMoreRoots=hCount>hSlots
  var aMore=activityHasMoreRoots,hMore=historyHasMoreRoots
  func heights(_ overhead:CGFloat)->(CGFloat,CGFloat) {
   let budget=max(0,min(720,availableSize.height)-overhead)
   var a=min(compactA,budget*0.62),h=min(compactH,budget*0.38)
   let spare=budget-a-h
   if spare>0 {a+=min(spare,max(0,compactA-a));h=min(compactH,budget-a)}
   // Never cut a session row in half at the viewport edge.
   func fit(_ height:CGFloat,_ list:MenuSessionList)->CGFloat {
    guard list.rows.contains(where:{$0.sessionId != nil}) else{return floor(height/32)*32}
    var total:CGFloat=0
    for row in list.rows {
     if total+row.rowHeight>height {break}
     total+=row.rowHeight
    }
    return total
   }
   a=fit(a,activeList);h=fit(h,historyList)
   // Growth starts from the actual compact allocation. A section expansion must
   // never enlarge the other collapsed section and shrink its own sticky tree.
   if activityExpanded && !historyExpanded {a=fit(min(desiredA,budget-h),activeList)}
   else if historyExpanded && !activityExpanded {h=fit(min(desiredH,budget-a),historyList)}
   else if activityExpanded && historyExpanded {
    let extra=budget-a-h
    a=fit(min(desiredA,a+extra/2),activeList);h=fit(min(desiredH,h+extra/2),historyList)
    a=fit(min(desiredA,budget-h),activeList);h=fit(min(desiredH,budget-a),historyList)
   }
   return (a,h)
  }
  var overhead=base+(aMore ? 24:0)+(hMore ? 24:0)
  var (a,h)=heights(overhead)
  // A new disclosure consumes space and may make the other list overflow.
  // Each flag can only become true, so this settles after at most two additions.
  while true {
   let nextA=aMore || (aCount>0 && activeList.naturalHeight>a+1)
   let nextH=hMore || (hCount>0 && historyList.naturalHeight>h+1)
   if nextA==aMore && nextH==hMore{break}
   aMore=nextA;hMore=nextH;overhead=base+(aMore ? 24:0)+(hMore ? 24:0);(a,h)=heights(overhead)
  }
  activeMoreHeight.constant=aMore ? 24:0;historyMoreHeight.constant=hMore ? 24:0
  let startA=activeHeight.constant,startH=historyHeight.constant
  guard animate,view.window?.isVisible==true,!NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
        abs(startA-a)+abs(startH-h)>1 else {applyLayout(a,h,overhead:overhead);return}
  let started=ProcessInfo.processInfo.systemUptime
  let animation=MenuResizeAnimation(view:view){[weak self] in
   guard let self=self else{return false}
   let t=min(1,(ProcessInfo.processInfo.systemUptime-started)/0.26)
   if t>=1 || self.view.window?.isVisible != true {
    self.resizeAnimation=nil;self.applyLayout(a,h,overhead:overhead);return false
   }
   let eased=CGFloat(t*t*(3-2*t))
   self.applyLayout(startA+(a-startA)*eased,startH+(h-startH)*eased,overhead:overhead)
   return true
  }
  resizeAnimation=animation
 }
 private func applyLayout(_ a:CGFloat,_ h:CGFloat,overhead:CGFloat) {
  activeHeight.constant=a;historyHeight.constant=h
  let desiredSize=NSSize(width:min(420,availableSize.width),height:min(availableSize.height,a+h+overhead))
  // Resize the popover before its child view. Resizing the child first lets
  // AppKit queue a window resize back to the old size on the next run loop.
  onResize?(desiredSize)
  view.setFrameSize(desiredSize)
  view.layoutSubtreeIfNeeded();activeList.updateScrollChrome();historyList.updateScrollChrome();activeList.updateSticky();historyList.updateSticky()
 }
 private func refreshSectionControls() {
  guard activeMoreHeight != nil else{return}
  activeMore.update(needed:activeMoreHeight.constant>0,expanded:activityExpanded,expandable:activityHasMoreRoots,overflows:activeDesiredHeight>activeHeight.constant+1,list:activeList)
  historyMore.update(needed:historyMoreHeight.constant>0,expanded:historyExpanded,expandable:historyHasMoreRoots,overflows:historyDesiredHeight>historyHeight.constant+1,list:historyList)
 }
 private func toggleActivityExpansion(){activityExpanded.toggle();rebuild(reloadRows:false,animate:true);if !activityExpanded{activeList.resetViewport()}}
 private func toggleHistoryExpansion(){historyExpanded.toggle();rebuild(reloadRows:false,animate:true);if !historyExpanded{historyList.resetViewport()}}
 func toggle(_ id:String){guard nodes[id] != nil else{return};if expanded.contains(id){expanded.remove(id);expandedChildren.remove(id)}else{expanded.insert(id)};rebuild()}
 func toggleChildren(_ id:String,animate:Bool=true){guard nodes[id] != nil,expanded.contains(id) else{return};if expandedChildren.contains(id){expandedChildren.remove(id)}else{expandedChildren.insert(id)};rebuild(animate:animate)}
 @discardableResult func handleKey(_ key:UInt16,list:MenuSessionList?=nil)->Bool {
  let list=list ?? activeList,rows=list.rows,table=list.table
  if key==53{onClose?();return true}
  var index=table.selectedRow
  if key==125 || key==126 {
   let direction=key==125 ? 1:-1;index=index<0 ? (direction==1 ? -1:rows.count):index
   repeat{index+=direction}while index>=0 && index<rows.count && rows[index].sessionId==nil && rows[index].moreParentId==nil
   if index>=0 && index<rows.count{list.selectRow(index)}
   return true
  }
  guard index>=0,index<rows.count else{return false}
  let item=rows[index]
  if let parent=item.moreParentId {
   if key==36 || key==49 || (key==124 && !item.moreExpanded) {
    toggleChildren(parent,animate:false)
    if !item.moreExpanded,let child=nodes[parent]?.childIds.dropFirst(2).first {list.select(child)}
    else if let row=list.rows.firstIndex(where:{$0.moreParentId==parent}) {list.selectRow(row)}
    return true
   }
   if key==123{list.select(parent);return true}
   return false
  }
  guard let id=item.sessionId,let node=nodes[id] else{return false}
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
 @objc private func openSettings(){onOpenSettings?()}
}

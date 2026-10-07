import Cocoa

/// Each section owns its viewport. The current expanded root stays reachable.
final class MenuSessionList:NSView,NSTableViewDataSource,NSTableViewDelegate {
 let table=MenuTableView(),scrollView=NSScrollView()
 private(set) var rows:[MenuVisibleRow]=[]
 private(set) var stickyRootId:String?
 private var nodes:[String:MenuNode]=[:],expanded=Set<String>(),stale=false,observer:NSObjectProtocol?
 private let sticky=NSVisualEffectView()
 var onOpen:((String)->Void)?,onToggle:((String)->Void)?
 override init(frame:NSRect) {
  super.init(frame:frame)
  let column=NSTableColumn(identifier:NSUserInterfaceItemIdentifier("session"));table.addTableColumn(column)
  table.headerView=nil;table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle;table.selectionHighlightStyle = .regular
  table.intercellSpacing=NSSize(width:0,height:0);table.backgroundColor = .clear
  table.dataSource=self;table.delegate=self;table.target=self;table.action=#selector(clicked)
  scrollView.drawsBackground=false;scrollView.contentView.drawsBackground=false;scrollView.documentView=table
  scrollView.hasVerticalScroller=true;scrollView.hasHorizontalScroller=false;scrollView.autohidesScrollers=true
  scrollView.contentView.postsBoundsChangedNotifications=true
  sticky.material = .popover;sticky.blendingMode = .withinWindow;sticky.state = .active;sticky.isHidden=true
  for child in [scrollView,sticky] {child.translatesAutoresizingMaskIntoConstraints=false;addSubview(child)}
  NSLayoutConstraint.activate([
   scrollView.leadingAnchor.constraint(equalTo:leadingAnchor),scrollView.trailingAnchor.constraint(equalTo:trailingAnchor),
   scrollView.topAnchor.constraint(equalTo:topAnchor),scrollView.bottomAnchor.constraint(equalTo:bottomAnchor),
   sticky.leadingAnchor.constraint(equalTo:leadingAnchor),sticky.trailingAnchor.constraint(equalTo:trailingAnchor),sticky.topAnchor.constraint(equalTo:topAnchor),sticky.heightAnchor.constraint(equalToConstant:64)])
  observer=NotificationCenter.default.addObserver(forName:NSView.boundsDidChangeNotification,object:scrollView.contentView,queue:.main){[weak self] _ in self?.updateSticky()}
 }
 required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")}
 deinit {if let observer=observer{NotificationCenter.default.removeObserver(observer)}}
 override func layout(){super.layout();updateScrollChrome()}
 func updateScrollChrome() {
  // NSTableView can retain a 52pt minimum frame for a 32pt empty-state row.
  // Only real content overflow warrants a visible scrollbar.
  let needed=rows.contains{$0.sessionId != nil} && naturalHeight>scrollView.bounds.height+1
  if scrollView.hasVerticalScroller != needed{scrollView.hasVerticalScroller=needed}
 }
 func update(ids:[String],nodes:[String:MenuNode],expanded:Set<String>,stale:Bool,empty:String) {
  let selected=selectedId
  self.nodes=nodes;self.expanded=expanded;self.stale=stale;rows=[]
  var stack=ids.reversed().map{($0,0)}
  while let (id,depth)=stack.popLast() {
   guard let node=nodes[id] else{continue}
   rows.append(MenuVisibleRow(sessionId:id,section:nil,depth:depth))
   if expanded.contains(id) {for child in node.childIds.reversed(){stack.append((child,depth+1))}}
  }
  if rows.isEmpty{rows=[MenuVisibleRow(sessionId:nil,section:empty,depth:0)]}
  table.reloadData()
  updateScrollChrome()
  if let selected=selected,let index=rows.firstIndex(where:{$0.sessionId==selected}){table.selectRowIndexes(IndexSet(integer:index),byExtendingSelection:false)}
  updateSticky()
 }
 var selectedId:String? {table.selectedRow>=0 && table.selectedRow<rows.count ? rows[table.selectedRow].sessionId:nil}
 var naturalHeight:CGFloat {CGFloat(rows.reduce(0){$0+($1.sessionId==nil ? 32:64)})}
 func select(_ id:String) {
  guard let row=rows.firstIndex(where:{$0.sessionId==id}) else{return}
  table.selectRowIndexes(IndexSet(integer:row),byExtendingSelection:false);reveal(row)
 }
 func reveal(_ row:Int) {
  table.scrollRowToVisible(row);updateSticky()
  let rect=table.rect(ofRow:row),clip=scrollView.contentView
  if stickyRootId != nil,rect.minY<clip.bounds.minY+64 {
   clip.scroll(to:NSPoint(x:0,y:max(0,rect.minY-64)));scrollView.reflectScrolledClipView(clip);updateSticky()
  }
 }
 func updateSticky() {
  var root:String?
  let top=scrollView.contentView.bounds.minY
  let index=table.row(at:NSPoint(x:1,y:top+1))
  if index>=0,index<rows.count,let id=rows[index].sessionId,rows[index].depth>0 {
   var candidate=id,seen=Set<String>()
   while let parent=nodes[candidate]?.parentId,seen.insert(candidate).inserted{candidate=parent}
   if expanded.contains(candidate){root=candidate}
  }
  stickyRootId=root;sticky.isHidden=root==nil
  for child in sticky.subviews{child.removeFromSuperview()}
  guard let id=root,let node=nodes[id] else{return}
  let row=SessionMenuRowView(node:node,depth:0,expanded:true,stale:stale){[weak self] in self?.onToggle?(id)}
  row.onOpen={[weak self] in self?.onOpen?(id)}
  row.translatesAutoresizingMaskIntoConstraints=false;sticky.addSubview(row)
  NSLayoutConstraint.activate([row.leadingAnchor.constraint(equalTo:sticky.leadingAnchor),row.trailingAnchor.constraint(equalTo:sticky.trailingAnchor),row.topAnchor.constraint(equalTo:sticky.topAnchor),row.bottomAnchor.constraint(equalTo:sticky.bottomAnchor)])
 }
 func numberOfRows(in tableView:NSTableView)->Int {rows.count}
 func tableView(_ tableView:NSTableView,heightOfRow row:Int)->CGFloat {rows[row].sessionId==nil ? 32:64}
 func tableView(_ tableView:NSTableView,shouldSelectRow row:Int)->Bool {rows[row].sessionId != nil}
 func tableView(_ tableView:NSTableView,viewFor tableColumn:NSTableColumn?,row:Int)->NSView? {
  let item=rows[row]
  if let id=item.sessionId,let node=nodes[id]{return SessionMenuRowView(node:node,depth:item.depth,expanded:expanded.contains(id),stale:stale){[weak self] in self?.onToggle?(id)}}
  let label=NSTextField(labelWithString:item.section ?? "");label.font = .systemFont(ofSize:11);label.textColor = .secondaryLabelColor;return label
 }
 @objc private func clicked(){let row=table.clickedRow;guard row>=0,row<rows.count,let id=rows[row].sessionId else{return};onOpen?(id)}
}

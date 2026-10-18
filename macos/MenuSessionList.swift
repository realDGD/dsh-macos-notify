import Cocoa

/// List movement is explicit: section arrows and keyboard selection, never wheel gestures.
final class FixedMenuScrollView:NSScrollView {
 override func scrollWheel(with event:NSEvent) {}
}

/// Each section owns its viewport. The current expanded root stays reachable.
final class MenuSessionList:NSView,NSTableViewDataSource,NSTableViewDelegate {
 let table=MenuTableView(),scrollView=FixedMenuScrollView()
 private(set) var rows:[MenuVisibleRow]=[]
 private(set) var stickyRootId:String?
 private var nodes:[String:MenuNode]=[:],expanded=Set<String>(),expandedChildren=Set<String>(),stale=false,observer:NSObjectProtocol?
 private let sticky=NSVisualEffectView()
 var onOpen:((String)->Void)?,onToggle:((String)->Void)?,onToggleChildren:((String)->Void)?
 var onViewportChange:(()->Void)?
 var interactions:[String:[MenuInteraction]]=[:]
 var onInteraction:((MenuInteraction,MenuInteractionAction)->Void)?
 override init(frame:NSRect) {
  super.init(frame:frame)
  let column=NSTableColumn(identifier:NSUserInterfaceItemIdentifier("session"));table.addTableColumn(column)
  table.headerView=nil;table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle;table.selectionHighlightStyle = .regular
  table.style = .plain
  table.intercellSpacing=NSSize(width:0,height:0);table.backgroundColor = .clear
  table.dataSource=self;table.delegate=self;table.target=self;table.action=#selector(clicked)
  scrollView.drawsBackground=false;scrollView.contentView.drawsBackground=false;scrollView.documentView=table
  scrollView.hasVerticalScroller=false;scrollView.hasHorizontalScroller=false;scrollView.autohidesScrollers=true
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
  // Section arrows replace scrollbars and wheel gestures.
  if scrollView.hasVerticalScroller{scrollView.hasVerticalScroller=false}
 }
 func update(ids:[String],nodes:[String:MenuNode],expanded:Set<String>,expandedChildren:Set<String>=Set(),stale:Bool,empty:String) {
  let selected=selectedItem
  self.nodes=nodes;self.expanded=expanded;self.expandedChildren=expandedChildren;self.stale=stale;rows=[]
  func appendSubtree(_ id:String,depth:Int) {
   guard let node=nodes[id] else{return}
   rows.append(MenuVisibleRow(sessionId:id,section:nil,depth:depth))
   guard expanded.contains(id),!node.childIds.isEmpty else{return}
   let hasMore=node.childIds.count>2
   let showAll = !hasMore || expandedChildren.contains(id)
   let visible=showAll ? node.childIds:Array(node.childIds.prefix(2))
   for child in visible {appendSubtree(child,depth:depth+1)}
   if hasMore {
    rows.append(MenuVisibleRow(sessionId:nil,section:nil,depth:depth+1,moreParentId:id,moreExpanded:showAll))
   }
  }
  for id in ids {appendSubtree(id,depth:0)}
  if rows.isEmpty{rows=[MenuVisibleRow(sessionId:nil,section:empty,depth:0)]}
  table.reloadData()
  updateScrollChrome()
  if let selected=selected,let index=rows.firstIndex(where:{row in
   if let id=selected.sessionId{return row.sessionId==id}
   return selected.moreParentId != nil && row.moreParentId==selected.moreParentId
  }){table.selectRowIndexes(IndexSet(integer:index),byExtendingSelection:false)}
  updateSticky(force:true)
 }
 var selectedItem:MenuVisibleRow? {rows.indices.contains(table.selectedRow) ? rows[table.selectedRow]:nil}
 var selectedId:String? {selectedItem?.sessionId}
 var naturalHeight:CGFloat {rows.reduce(0){$0+$1.rowHeight}}
 var rootCount:Int {rows.filter{$0.sessionId != nil && $0.depth==0}.count}
 var hasExpandedChildren:Bool {rows.contains{$0.depth>0}}
 func heightForRoots(_ limit:Int)->CGFloat {
  guard rows.first?.sessionId != nil else{return naturalHeight}
  var roots=0,height:CGFloat=0
  for row in rows {
   if row.depth==0{roots+=1}
   if roots>limit{break}
   height+=row.rowHeight
  }
  return height
 }
 var canMoveUp:Bool {scrollView.contentView.bounds.minY>1}
 var canMoveDown:Bool {scrollView.contentView.bounds.maxY<naturalHeight-1}
 func resetViewport() {
  scrollView.contentView.scroll(to:.zero);scrollView.reflectScrolledClipView(scrollView.contentView);updateSticky()
 }
 func move(_ direction:Int) {
  let clip=scrollView.contentView
  let covered:CGFloat=stickyRootId==nil ? 0:64
  let target=direction>0
   ? rows.indices.first{table.rect(ofRow:$0).maxY>clip.bounds.maxY+0.5}
   : rows.indices.last{table.rect(ofRow:$0).minY<clip.bounds.minY+covered-0.5}
  guard let row=target else{return}
  let rect=table.rect(ofRow:row)
  let inset:CGFloat=clip.bounds.height>=128 && rows[row].depth>0 ? 64:0
  // Place the next hidden row wholly inside the viewport, below any pinned root.
  let destination=direction>0 ? rect.minY-inset:rect.maxY-clip.bounds.height
  let y=min(max(0,naturalHeight-clip.bounds.height),max(0,destination))
  clip.scroll(to:NSPoint(x:0,y:y));scrollView.reflectScrolledClipView(clip);reveal(row)
 }
 func select(_ id:String) {
  guard let row=rows.firstIndex(where:{$0.sessionId==id}) else{return}
  selectRow(row)
 }
 func selectRow(_ row:Int) {
  guard rows.indices.contains(row),rows[row].sessionId != nil || rows[row].moreParentId != nil else{return}
  table.selectRowIndexes(IndexSet(integer:row),byExtendingSelection:false);reveal(row)
 }
 func reveal(_ row:Int) {
  table.scrollRowToVisible(row);updateSticky()
  let rect=table.rect(ofRow:row),clip=scrollView.contentView
  if stickyRootId != nil,rect.minY<clip.bounds.minY+64 {
   clip.scroll(to:NSPoint(x:0,y:max(0,rect.minY-64)));scrollView.reflectScrolledClipView(clip);updateSticky()
  }
 }
 func updateSticky(force:Bool=false) {
  defer{onViewportChange?()}
  var root:String?
  let top=scrollView.contentView.bounds.minY
  let index=table.row(at:NSPoint(x:1,y:top+1))
  if scrollView.contentView.bounds.height>=128,index>=0,index<rows.count,rows[index].depth>0,
     let id=rows[index].sessionId ?? rows[index].moreParentId {
   var candidate=id,seen=Set<String>()
   while let parent=nodes[candidate]?.parentId,seen.insert(candidate).inserted{candidate=parent}
   if expanded.contains(candidate){root=candidate}
  }
  let previousRoot=stickyRootId
  stickyRootId=root;sticky.isHidden=root==nil
  if !force && previousRoot==root{return}
  for child in sticky.subviews{child.removeFromSuperview()}
  guard let id=root,let node=nodes[id] else{return}
  let row=makeRow(node,depth:0,expanded:true)
  row.onOpen={[weak self] in self?.onOpen?(id)}
  row.translatesAutoresizingMaskIntoConstraints=false;sticky.addSubview(row)
  NSLayoutConstraint.activate([row.leadingAnchor.constraint(equalTo:sticky.leadingAnchor),row.trailingAnchor.constraint(equalTo:sticky.trailingAnchor),row.topAnchor.constraint(equalTo:sticky.topAnchor),row.bottomAnchor.constraint(equalTo:sticky.bottomAnchor)])
 }
 func numberOfRows(in tableView:NSTableView)->Int {rows.count}
 func tableView(_ tableView:NSTableView,heightOfRow row:Int)->CGFloat {rows[row].rowHeight}
 func tableView(_ tableView:NSTableView,shouldSelectRow row:Int)->Bool {rows[row].sessionId != nil || rows[row].moreParentId != nil}
 func tableView(_ tableView:NSTableView,viewFor tableColumn:NSTableColumn?,row:Int)->NSView? {
  let item=rows[row]
  if let id=item.sessionId,let node=nodes[id]{return makeRow(node,depth:item.depth,expanded:expanded.contains(id))}
  if let parentId=item.moreParentId,let parent=nodes[parentId] {
   return MenuSubagentMoreRowView(parent:parent,depth:item.depth,expanded:item.moreExpanded){[weak self] in self?.onToggleChildren?(parentId)}
  }
  let label=NSTextField(labelWithString:item.section ?? "");label.font = .systemFont(ofSize:11);label.textColor = .secondaryLabelColor;return label
 }
 private func makeRow(_ node:MenuNode,depth:Int,expanded:Bool)->SessionMenuRowView {
  SessionMenuRowView(node:node,depth:depth,expanded:expanded,stale:stale,interactions:interactions[node.id] ?? [],onDisclosure:{[weak self] in self?.onToggle?(node.id)},onInteraction:{[weak self] item,action in self?.onInteraction?(item,action)})
 }
 @objc private func clicked() {
  let row=table.clickedRow
  guard row>=0,row<rows.count else{return}
  if let id=rows[row].sessionId {onOpen?(id)}
  else if let parentId=rows[row].moreParentId {onToggleChildren?(parentId)}
 }
}

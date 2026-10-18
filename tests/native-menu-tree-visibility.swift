import Cocoa
@main @MainActor struct NativeMenuTreeVisibilityTests {
 static func descendants(_ view:NSView)->[NSView]{[view]+view.subviews.flatMap(descendants)}
 static func main() {
  UILocalization.set("zh");NSApplication.shared.setActivationPolicy(.prohibited)
  func check(_ value:Bool,_ message:String){if !value{print("FAIL "+message);exit(1)}}
  func node(_ id:String,_ children:[String]=[],_ parent:String?=nil)->MenuNode {
   MenuNode(id:id,parentId:parent,workspaceTitle:"测试",sessionTitle:id,state:.running,preview:"",previewKind:"user",pinned:false,pinIndex:nil,progress:nil,childIds:children,descendantBadge:nil,updatedAt:1000,activityToken:nil)
  }
  var windows:[NSWindow]=[]
  func panel(_ nodes:[MenuNode],active:[String],history:[String],height:CGFloat=600)->SessionMenuViewController {
   let snapshot=MenuSnapshot(version:1,generation:UUID().uuidString,revision:1,updatedAt:1000,enabled:true,availability:"ready",cohort:nil,nodes:nodes,activeIds:active,orphanIds:[],historyIds:history,omittedCount:0)
   let panel=SessionMenuViewController(availableSize:NSSize(width:300,height:height))
   panel.update(snapshot:snapshot,status:"已连接",stale:false,error:nil)
   let window=NSWindow(contentRect:panel.view.frame,styleMask:[],backing:.buffered,defer:false)
   window.contentViewController=panel;panel.view.layoutSubtreeIfNeeded();windows.append(window);return panel
  }
  func button(_ panel:SessionMenuViewController,_ label:String)->NSButton? {
   descendants(panel.view).compactMap{$0 as? NSButton}.first{!$0.isHiddenOrHasHiddenAncestor && $0.accessibilityLabel()==label}
  }
  func visibleIds(_ list:MenuSessionList)->Set<String> {
   let clip=list.scrollView.contentView.bounds,covered:CGFloat=list.stickyRootId==nil ? 0:64
   return Set(list.rows.enumerated().compactMap{index,item in
    let rect=list.table.rect(ofRow:index)
    return rect.minY>=clip.minY+covered && rect.maxY<=clip.maxY+0.5 ? (item.sessionId ?? item.moreParentId.map{"more:"+$0}):nil
   })
  }
  func visitAll(_ panel:SessionMenuViewController,_ list:MenuSessionList,_ section:String,direction:Int=1)->Set<String> {
   if direction>0{list.resetViewport()}
   var seen=visibleIds(list),pages=0
   while (direction>0 ? list.canMoveDown:list.canMoveUp) && pages<2000 {
    guard let next=button(panel,(direction>0 ? "向下查看":"向上查看")+section),next.isEnabled else{check(false,section+" needs a second expansion before its children can be paged");return seen}
    let before=list.scrollView.contentView.bounds.minY
    next.performClick(nil);seen.formUnion(visibleIds(list));pages+=1
    check(CGFloat(direction)*(list.scrollView.contentView.bounds.minY-before)>0.5,section+" paging arrow made no progress")
   }
   check(pages<2000,section+" paging did not terminate")
   return seen
  }
  let children=(0..<4).map{"child-\($0)"}
  let tree=[node("parent",children)]+children.map{node($0,[],"parent")}
  for inHistory in [false,true] {
   let roots=[node("peer-1"),node("peer-2")]
   let view=panel(tree+roots,active:inHistory ? ["peer-1","peer-2"]:["parent"],history:inHistory ? ["parent"]:["peer-1","peer-2"])
   view.toggle("parent")
   let list=inHistory ? view.historyList:view.activeList,peer=inHistory ? view.activeList:view.historyList
   check(list.frame.height==216 && peer.frame.height==128,"initial subagent expansion should show two children plus the 24pt more row in \(inHistory ? "history":"activity")")
   check(Set(["parent","child-0","child-1"]).isSubset(of:visibleIds(list)),"initial two subagents not visible")
   button(view,"展开更多parent的子智能体")!.performClick(nil)
   check(list.frame.height==344 && peer.frame.height==128,"expanded descendants consume the default root quota in \(inHistory ? "history":"activity")")
   check(Set(children).isSubset(of:visibleIds(list)),"a fitting subtree requires a second section expansion")
   view.toggle("parent")
   check(list.frame.height==64,"collapsing a subtree retains its extra height")
  }
  for inHistory in [false,true] {
   let roots=[node("peer-1"),node("peer-2")],active=inHistory ? ["peer-1","peer-2"]:["parent"],history=inHistory ? ["parent"]:["peer-1","peer-2"]
   let view=panel(tree+roots,active:active,history:history)
   let list=inHistory ? view.historyList:view.activeList
   var opened:[String]=[];view.onOpenSession={opened.append($0)}
   list.select("parent");view.handleKey(124,list:list)
   for _ in 0..<3{view.handleKey(125,list:list)}
   check(list.table.selectedRow>=0 && list.rows[list.table.selectedRow].moreParentId=="parent","down arrow skips the more-subagents control")
   check(visibleIds(list).contains("more:parent"),"keyboard focus on the more control is hidden")
   view.handleKey(36,list:list)
   check(list.selectedId=="child-2","Enter does not reveal and focus the first newly expanded child")
   view.handleKey(125,list:list);check(list.selectedId=="child-3","keyboard cannot reach the last expanded child")
   view.handleKey(125,list:list)
   let refreshed=MenuSnapshot(version:1,generation:UUID().uuidString,revision:2,updatedAt:1000,enabled:true,availability:"ready",cohort:nil,nodes:tree+roots,activeIds:active,orphanIds:[],historyIds:history,omittedCount:0)
   view.update(snapshot:refreshed,status:"未连接",stale:true,error:nil)
   check(list.table.selectedRow>=0 && list.rows[list.table.selectedRow].moreParentId=="parent","menu refresh loses focus on the more control")
   view.handleKey(49,list:list)
   check(list.rows.compactMap(\.sessionId)==["parent","child-0","child-1"],"Space does not collapse extra subagents")
   check(list.rows[list.table.selectedRow].moreParentId=="parent" && visibleIds(list).contains("more:parent"),"collapse leaves keyboard focus outside the visible more control")
   view.handleKey(124,list:list);check(list.selectedId=="child-2","right arrow cannot activate the collapsed more control")
   view.handleKey(125,list:list);view.handleKey(125,list:list);view.handleKey(123,list:list)
   check(list.selectedId=="parent","left arrow on the more control does not return to its parent")
   check(opened.isEmpty,"more-subagents keyboard actions navigate to a session")
  }
  for count in [4,400] {for height:CGFloat in [400,600] {
   let aChildren=(0..<count).map{"a-\($0)"},hChildren=(0..<4).map{"h-\($0)"}
   let grandchildren=["grandchild-1","grandchild-2"]
   let nodes=[node("active",aChildren),node("recent",hChildren)]
    + aChildren.enumerated().map{index,id in node(id,index==0 ? grandchildren:[],"active")}
    + hChildren.map{node($0,[],"recent")}+grandchildren.map{node($0,[],aChildren[0])}
   let view=panel(nodes,active:["active"],history:["recent"],height:height)
   view.toggle("recent");view.toggleChildren("recent");view.historyList.move(1)
   view.toggle("active");view.toggleChildren("active");view.toggle(aChildren[0])
   check(view.view.frame.height<=height,"expanded trees exceed the available menu height")
   for (list,section,ids) in [(view.activeList,"活动会话",aChildren+grandchildren),(view.historyList,"最近会话",hChildren)] {
    check(list.frame.height>=64,"tree viewport has no whole row")
    check(Set(ids).isSubset(of:visitAll(view,list,section)),section+" has unreachable children at height \(height)")
    if list.frame.height==64 {check(list.stickyRootId==nil,"a sticky parent fills the single-row viewport")}
    else {
     check(list.stickyRootId != nil,"a multi-row tree lost its sticky parent")
     let sticky=list.subviews.compactMap{$0 as? NSVisualEffectView}.first!,stableRow=sticky.subviews.first
     list.updateSticky()
     check(sticky.subviews.first===stableRow,"unchanged sticky root was rebuilt during viewport layout")
    }
    list.select(ids.last!)
    check(visibleIds(list).contains(ids.last!),"keyboard selection remains hidden behind its sticky parent")
   }
  }}
  let busyChildren=(0..<10).map{"busy-\($0)"},firstChildren=(0..<4).map{"first-\($0)"},secondChildren=(0..<4).map{"second-\($0)"}
  let mixedNodes=[node("busy",busyChildren),node("first",firstChildren),node("second",secondChildren)]
   + busyChildren.map{node($0,[],"busy")}+firstChildren.map{node($0,[],"first")}+secondChildren.map{node($0,[],"second")}
  let expected=Set(["first","second","more:first","more:second"]+firstChildren+secondChildren)
  for inHistory in [false,true] {for height:CGFloat in [400,600] {
   let view=panel(mixedNodes,active:inHistory ? ["busy"]:["first","second"],history:inHistory ? ["first","second"]:["busy"],height:height)
   for id in ["busy","first","second"]{view.toggle(id);view.toggleChildren(id)}
   let list=inHistory ? view.historyList:view.activeList,section=inHistory ? "最近会话":"活动会话"
   for direction in [1,-1] {
    let seen=visitAll(view,list,section,direction:direction)
    check(expected.isSubset(of:seen),section+" mixed 24/64pt rows are unreachable in direction \(direction) at height \(height): \(expected.subtracting(seen).sorted())")
   }
  }}
  let seven=(0..<7).map{"seven-\($0)"},three=(0..<3).map{"three-\($0)"}
  let bottomNodes=[node("seven",seven),node("three",three),node("peer-1"),node("peer-2")]
   + seven.map{node($0,[],"seven")}+three.map{node($0,[],"three")}
  let bottomExpected=Set(["seven","three","more:seven","more:three"]+seven+three)
  for inHistory in [false,true] {
   let view=panel(bottomNodes,active:inHistory ? ["peer-1","peer-2"]:["seven","three"],history:inHistory ? ["seven","three"]:["peer-1","peer-2"])
   for id in ["seven","three"]{view.toggle(id);view.toggleChildren(id)}
   let list=inHistory ? view.historyList:view.activeList,section=inHistory ? "最近会话":"活动会话"
   check(list.frame.height==320,"bottom-clamp fixture no longer exercises a five-row viewport")
   for direction in [1,-1] {
    let seen=visitAll(view,list,section,direction:direction)
    check(bottomExpected.isSubset(of:seen),section+" bottom clamp hides rows behind the previous sticky root: \(bottomExpected.subtracting(seen).sorted())")
   }
  }
  print("PASS root quotas, automatic subtree height, activity/history paging through 400 children and nested descendants, mixed-height multi-root paging in both directions, keyboard more controls and refresh focus, single-row sticky fallback and selection visibility")
 }
}

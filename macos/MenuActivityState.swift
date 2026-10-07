import Foundation
import CryptoKit

enum MenuActivityFilter:Int {case all,failures,live}

/// Local display acknowledgments never answer or cancel an official request.
final class MenuActivityState {
 private var generation:String?,read:[String:String]=[:],undo:[String:String]?
 private let file:URL?
 var filter=MenuActivityFilter.all
 var canUndo:Bool {undo != nil}
 init(directory:String?=nil) {
  file=directory.map{URL(fileURLWithPath:$0).appendingPathComponent("session-menu-read.json")}
  if let file=file,let size=(try? FileManager.default.attributesOfItem(atPath:file.path)[.size]) as? Int,size<=524288,
     let data=try? Data(contentsOf:file),let saved=try? JSONDecoder().decode(Saved.self,from:data),saved.read.count<=2000,
     UUID(uuidString:saved.generation) != nil,saved.read.allSatisfy({menuSessionIdValid($0.key)&&$0.value.count==64}) {
   generation=saved.generation;read=saved.read
  }
 }
 private struct Saved:Codable {let generation:String;let read:[String:String]}
 func update(_ snapshot:MenuSnapshot?) {
  guard let snapshot=snapshot else{return}
  if generation != snapshot.generation {generation=snapshot.generation;read=[:];undo=nil;save()}
  let ids=Set(snapshot.activeIds+snapshot.orphanIds+snapshot.historyIds)
  read=read.filter{ids.contains($0.key)}
 }
 func branch(_ id:String,nodes:[String:MenuNode])->[MenuNode] {
  var result:[MenuNode]=[],stack=[id],seen=Set<String>()
  while let id=stack.popLast(),seen.insert(id).inserted,let node=nodes[id] {result.append(node);stack.append(contentsOf:node.childIds)}
  return result
 }
 private func fingerprint(_ branch:[MenuNode])->String {
  let text=branch.sorted{$0.id<$1.id}.map{node in
   node.id+"|"+(node.activityToken ?? "legacy:\(node.updatedAt)")+"|"+node.state.rawValue
  }.joined(separator:"\n")
  return SHA256.hash(data:Data(text.utf8)).map{String(format:"%02x",$0)}.joined()
 }
 func isRead(_ id:String,nodes:[String:MenuNode])->Bool {read[id]==fingerprint(branch(id,nodes:nodes))}
 func includes(_ id:String,nodes:[String:MenuNode])->Bool {
  guard !isRead(id,nodes:nodes) else{return false}
  let values=branch(id,nodes:nodes)
  switch filter {case .all:return true;case .failures:return values.contains{$0.state.isFailure};case .live:return values.contains{$0.state.isLive}}
 }
 func toggleRead(ids:[String],nodes:[String:MenuNode]) {
  if let undo=undo {
   for (id,value) in undo where read[id]==value {read.removeValue(forKey:id)}
   self.undo=nil
  } else {
   var batch:[String:String]=[:]
   for id in ids {
    let values=branch(id,nodes:nodes)
    guard !values.isEmpty,!values.contains(where:{$0.state.isLive}),!isRead(id,nodes:nodes) else{continue}
    let value=fingerprint(values);read[id]=value;batch[id]=value
   }
   if !batch.isEmpty {undo=batch}
  }
  save()
 }
 private func save() {
  guard let file=file,let generation=generation,let data=try? JSONEncoder().encode(Saved(generation:generation,read:read)),data.count<=524288 else{return}
  do {
   try FileManager.default.createDirectory(at:file.deletingLastPathComponent(),withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
   try data.write(to:file,options:.atomic)
   try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path)
  } catch { /* A view preference cannot interfere with approvals or questions. */ }
 }
}

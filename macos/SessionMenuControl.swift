import Foundation
final class SessionMenuControl {
 private struct Command: Codable {let version:Int;let commandId:String;let createdAt:Double;let kind:String;let enabled:Bool}
 private struct Result: Codable {let commandId:String;let kind:String;let enabled:Bool;let status:String;let completedAt:Double}
 private struct Pending {let createdAt:Double;let enabled:Bool;let completion:(String?)->Void}
 private let directory:String
 private var pending:[String:Pending]=[:]
 init(directory:String){self.directory=directory}
 func setEnabled(_ enabled:Bool,at now:Double=Date().timeIntervalSince1970*1000,completion:@escaping(String?)->Void) {
  let id=UUID().uuidString,manager=FileManager.default,folder=(directory as NSString).appendingPathComponent("menu-commands")
  do {
   try manager.createDirectory(atPath:folder,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
   try manager.setAttributes([.posixPermissions:0o700],ofItemAtPath:folder)
   let file=(folder as NSString).appendingPathComponent(id+".json")
   let data=try JSONEncoder().encode(Command(version:1,commandId:id,createdAt:now,kind:"set-menu-enabled",enabled:enabled))
   try data.write(to:URL(fileURLWithPath:file),options:.atomic)
   try manager.setAttributes([.posixPermissions:0o600],ofItemAtPath:file)
   pending[id]=Pending(createdAt:now,enabled:enabled,completion:completion)
  } catch {completion(L("未能发送菜单栏设置，请在 DSH 设置中重试。"))}
 }
 func poll(at now:Double=Date().timeIntervalSince1970*1000) {
  for (id,item) in pending {
   let file=(directory as NSString).appendingPathComponent("menu-results/"+id+".json")
   if let size=(try? FileManager.default.attributesOfItem(atPath:file)[.size]) as? Int,size<=4096,
      let data=try? Data(contentsOf:URL(fileURLWithPath:file)),let result=try? JSONDecoder().decode(Result.self,from:data),
      result.commandId==id,result.kind=="set-menu-enabled",result.completedAt.isFinite,
      result.completedAt>=item.createdAt,result.completedAt<=now+10000,
      ["accepted","invalid","failed","stale"].contains(result.status) {
    if result.status != "accepted" {pending.removeValue(forKey:id)?.completion(L("DSH 未接受菜单栏设置，请重试。"));continue}
    if result.enabled==item.enabled {pending.removeValue(forKey:id)?.completion(nil);continue}
   }
   if now-item.createdAt>15000 {
    pending.removeValue(forKey:id)?.completion(L("未确认设置已保存，请检查 DSH 连接后重试。"))
    try? FileManager.default.removeItem(atPath:(directory as NSString).appendingPathComponent("menu-commands/"+id+".json"))
   }
  }
 }
}

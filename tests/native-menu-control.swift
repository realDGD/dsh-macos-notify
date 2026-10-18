import Foundation
@main struct NativeMenuControlTests {
 static func main() throws {
  UILocalization.set("zh")
  let manager=FileManager.default,directory=manager.temporaryDirectory.appendingPathComponent("menu-control-"+UUID().uuidString)
  defer {try? manager.removeItem(at:directory)}
  let control=SessionMenuControl(directory:directory.path)
  var success=0,failures=0
  control.setEnabled(false,at:1000){if $0==nil {success+=1}else{failures+=1}}
  let commands=directory.appendingPathComponent("menu-commands"),results=directory.appendingPathComponent("menu-results")
  let name=try manager.contentsOfDirectory(atPath:commands.path).first!
  let command=try JSONSerialization.jsonObject(with:Data(contentsOf:commands.appendingPathComponent(name))) as! [String:Any]
  let id=command["commandId"] as! String
  precondition(UUID(uuidString:id) != nil && name==id+".json")
  precondition(command["enabled"] as? Bool == false)
  let folderMode=(try manager.attributesOfItem(atPath:commands.path)[.posixPermissions] as? NSNumber)?.intValue
  let fileMode=(try manager.attributesOfItem(atPath:commands.appendingPathComponent(name).path)[.posixPermissions] as? NSNumber)?.intValue
  let baseMode=(try manager.attributesOfItem(atPath:directory.path)[.posixPermissions] as? NSNumber)?.intValue
  precondition(folderMode==0o700 && fileMode==0o600)
  if baseMode != 0o700 {print("FAIL private base directory mode: \(baseMode ?? -1)");exit(1)}
  try manager.createDirectory(at:results,withIntermediateDirectories:true)
  func result(_ identity:String,_ enabled:Bool,_ completed:Double,_ status:String="accepted") throws {
   try JSONSerialization.data(withJSONObject:["commandId":identity,"kind":"set-menu-enabled","enabled":enabled,"status":status,"completedAt":completed]).write(to:results.appendingPathComponent(name))
  }
  try result(UUID().uuidString,false,2000);control.poll(at:2000);precondition(success==0 && failures==0)
  try result(id,true,2000);control.poll(at:2000);precondition(success==0 && failures==0)
  try result(id,false,999);control.poll(at:2000);precondition(success==0 && failures==0)
  try result(id,false,2000);control.poll(at:2000);control.poll(at:2001);precondition(success==1 && failures==0)
  control.setEnabled(true,at:3000){if $0==nil{success+=1}else{failures+=1}}
  control.poll(at:18001);precondition(success==1 && failures==1)
  precondition(!manager.fileExists(atPath:directory.appendingPathComponent("settings.json").path))
  var opened=0,settingsResults:[String?]=[]
  control.openSettings(openDesktop:{opened+=1;return true},at:20000){settingsResults.append($0)}
  let requestPath=directory.appendingPathComponent("open-session.json"),receiptPath=directory.appendingPathComponent("jump-result.json")
  let request=try JSONSerialization.jsonObject(with:Data(contentsOf:requestPath)) as! [String:Any]
  precondition(opened==1 && request["kind"] as? String=="open-notify-settings" && request["sessionId"]==nil)
  let requestMode=(try manager.attributesOfItem(atPath:requestPath.path)[.posixPermissions] as? NSNumber)?.intValue
  precondition(requestMode==0o600)
  var receipt=request;receipt["confirmedAt"]=21000;receipt["kind"]="other"
  try JSONSerialization.data(withJSONObject:receipt).write(to:receiptPath);control.poll(at:21000)
  precondition(settingsResults.isEmpty)
  receipt["kind"]="open-notify-settings";receipt["createdAt"]=19999
  try JSONSerialization.data(withJSONObject:receipt).write(to:receiptPath);control.poll(at:21000)
  precondition(settingsResults.isEmpty)
  receipt["createdAt"]=20000
  try JSONSerialization.data(withJSONObject:receipt).write(to:receiptPath);control.poll(at:21000)
  precondition(settingsResults.count==1 && settingsResults[0]==nil)
  control.openSettings(openDesktop:{false},at:22000){settingsResults.append($0)}
  precondition(settingsResults.count==2 && settingsResults[1] != nil)
  precondition(!manager.fileExists(atPath:requestPath.path))
  control.openSettings(openDesktop:{true},at:23000){settingsResults.append($0)}
  control.poll(at:38001)
  precondition(settingsResults.count==3 && settingsResults[2] != nil && !manager.fileExists(atPath:requestPath.path))
  print("PASS native typed menu command identity, private modes, stale/foreign/incorrect result rejection and timeout")
 }
}

import Cocoa
@main struct DesktopLifecycleTests {
 static func main() {
  func check(_ ok:Bool,_ message:String){if !ok{fputs("FAIL \(message)\n",stderr);exit(1)}}
  let center=NotificationCenter();var running=true,stops=0
  let lifecycle=DesktopLifecycle(center:center,running:{running},onStopped:{stops+=1})
  check(lifecycle.start(),"running Desktop rejected")
  center.post(name:NSWorkspace.didTerminateApplicationNotification,object:nil)
  check(stops==0,"one app exit terminated a still-running Desktop helper")
  running=false;center.post(name:NSWorkspace.didTerminateApplicationNotification,object:nil)
  check(stops==1,"Desktop exit did not stop the helper")
  check(!lifecycle.check() && stops==1,"repeated checks terminate twice")
  var absentStops=0
  let absent=DesktopLifecycle(center:center,running:{false},onStopped:{absentStops+=1})
  check(!absent.start() && absentStops==1,"helper can remain alive without Desktop")
  var alive=true,crashStops=0
  let crash=DesktopLifecycle(center:center,running:{alive},onStopped:{crashStops+=1})
  check(crash.start(),"crash fixture startup")
  alive=false;check(!crash.check() && crashStops==1,"missed termination notification keeps helper alive")
  print("PASS native Desktop presence, termination notifications, missing Desktop and crash polling")
 }
}

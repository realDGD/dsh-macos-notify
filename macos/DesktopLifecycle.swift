import Cocoa

/// Follow the Desktop process, not window focus, minimization or Host reloads.
final class DesktopLifecycle {
 private let center:NotificationCenter,running:()->Bool,onStopped:()->Void
 private var observer:NSObjectProtocol?,stopped=false
 init(center:NotificationCenter=NSWorkspace.shared.notificationCenter,
      running:@escaping()->Bool={NSRunningApplication.runningApplications(withBundleIdentifier:"com.deepseek.dsh").contains{!$0.isTerminated}},
      onStopped:@escaping()->Void) {
  self.center=center;self.running=running;self.onStopped=onStopped
 }
 deinit {if let observer=observer{center.removeObserver(observer)}}
 @discardableResult func start()->Bool {
  if observer==nil && !stopped {
   observer=center.addObserver(forName:NSWorkspace.didTerminateApplicationNotification,object:nil,queue:.main){[weak self] _ in self?.check()}
  }
  return check()
 }
 @discardableResult func check()->Bool {
  guard !stopped else{return false}
  guard running() else {
   stopped=true;if let observer=observer{center.removeObserver(observer);self.observer=nil}
   onStopped();return false
  }
  return true
 }
}

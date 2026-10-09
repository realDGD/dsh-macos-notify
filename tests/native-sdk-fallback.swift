import Cocoa

// Compile without DSH_HAS_DISPLAY_LINK to exercise the SDK-13 build path.
@main struct NativeSDKFallbackTests {
 static func main() {
  NSApplication.shared.setActivationPolicy(.prohibited)
  let view=NSView(frame:NSRect(x:0,y:0,width:100,height:100))
  var frames=0
  let animation=MenuResizeAnimation(view:view) {frames+=1;return frames<3}
  RunLoop.main.run(until:Date().addingTimeInterval(0.2))
  guard frames==3 else {print("FAIL SDK-13 animation fallback produced \(frames) frames");exit(1)}
  animation.invalidate()
  RunLoop.main.run(until:Date().addingTimeInterval(0.05))
  guard frames==3 else {print("FAIL fallback continued after invalidation");exit(1)}
  print("PASS SDK-13 timer animation and cleanup")
 }
}

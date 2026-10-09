import Cocoa
import QuartzCore
private protocol MenuFrameDriver:AnyObject {func invalidate()}
#if DSH_HAS_DISPLAY_LINK
@available(macOS 14.0,*)
private final class MenuDisplayDriver:NSObject,MenuFrameDriver {
 private var link:CADisplayLink?
 private let tick:()->Bool
 init(view:NSView,tick:@escaping()->Bool){
  self.tick=tick;super.init()
  let link=view.displayLink(target:self,selector:#selector(frame));self.link=link
  let rate=Float(view.window?.screen?.maximumFramesPerSecond ?? 60)
  link.preferredFrameRateRange=CAFrameRateRange(minimum:30,maximum:rate,preferred:rate)
  link.add(to:.main,forMode:.common)
 }
 @objc private func frame(){if !tick(){invalidate()}}
 func invalidate(){link?.invalidate();link=nil}
 deinit{invalidate()}
}
#endif
// Follow the display cadence on macOS 14+, with a screen-rate timer on macOS 13.
final class MenuResizeAnimation:NSObject {
 private var driver:MenuFrameDriver?,timer:Timer?
 init(view:NSView,tick:@escaping()->Bool) {
  super.init()
#if DSH_HAS_DISPLAY_LINK
  if #available(macOS 14.0,*) {driver=MenuDisplayDriver(view:view,tick:tick);return}
#endif
  let rate=Double(view.window?.screen?.maximumFramesPerSecond ?? 60)
  let timer=Timer(timeInterval:1/max(30,rate),repeats:true){timer in if !tick(){timer.invalidate()}};self.timer=timer;RunLoop.main.add(timer,forMode:.common)
 }
 func invalidate(){driver?.invalidate();driver=nil;timer?.invalidate();timer=nil}
 deinit{invalidate()}
}

import Cocoa
import QuartzCore
enum MenuStatusPalette {
 static let green=NSColor(calibratedRed:98.0/255,green:186.0/255,blue:70.0/255,alpha:1)
 static let red=NSColor(calibratedRed:255.0/255,green:83.0/255,blue:86.0/255,alpha:1)
 static let yellow=NSColor(calibratedRed:247.0/255,green:131.0/255,blue:24.0/255,alpha:1)
}
struct MenuCohort:Codable {let id:Int;let revision:Int;let running:Bool;let tone:String}
struct MenuIconAppearance:Equatable {let running:Bool;let filled:Bool;let tone:String}
final class MenuIconState {
 private var cohort:MenuCohort?,generation:String?,acknowledged:String?,stale=true
 private var token:String {"\(generation ?? ""):\(cohort?.id ?? 0):\(cohort?.revision ?? 0)"}
 func update(_ value:MenuCohort?,generation:String?,stale:Bool) {
  if self.generation != generation{acknowledged=nil}
  self.cohort=value;self.generation=generation;self.stale=stale
 }
 func acknowledge(){acknowledged=token}
 var appearance:MenuIconAppearance {
  guard !stale,let value=cohort else{return MenuIconAppearance(running:false,filled:false,tone:"white")}
  let tone=acknowledged==token ? "white":value.tone
  return MenuIconAppearance(running:value.running,filled:!value.running && tone != "white",tone:tone)
 }
}
// Only the inner fish layer rotates; the status ring never rotates or flashes.
final class MenuIconView:NSView {
 private let ring=CALayer(),fish=CALayer()
 private var cachedAppearance:MenuIconAppearance?,reduceMotion:Bool?
 override init(frame:NSRect){super.init(frame:frame);wantsLayer=true;layer?.addSublayer(ring);layer?.addSublayer(fish);setAccessibilityElement(false)}
 required init?(coder:NSCoder){fatalError("init(coder:) has not been implemented")}
 override func hitTest(_ point:NSPoint)->NSView?{nil}
 override func layout(){super.layout();let rect=NSRect(x:(bounds.width-22)/2,y:(bounds.height-22)/2,width:22,height:22);CATransaction.begin();CATransaction.setDisableActions(true);ring.frame=rect;fish.frame=rect;CATransaction.commit()}
 func update(_ value:MenuIconAppearance,reduceMotion:Bool=NSWorkspace.shared.accessibilityDisplayShouldReduceMotion) {
  guard cachedAppearance != value || self.reduceMotion != reduceMotion else{return}
  cachedAppearance=value;self.reduceMotion=reduceMotion
  let color:NSColor=value.tone=="yellow" ? MenuStatusPalette.yellow:value.tone=="red" ? MenuStatusPalette.red:value.tone=="green" ? MenuStatusPalette.green:.white
  let name=value.filled ? "fish.circle.fill":"fish.circle"
  setAccessibilityLabel(name)
  let scale=window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
  CATransaction.begin();CATransaction.setDisableActions(true)
  ring.contentsScale=scale;fish.contentsScale=scale
  ring.contents=Self.raster(name:name,part:value.running ? 1:0,tint:color,scale:scale);fish.contents=value.running ? Self.raster(name:name,part:2,tint:.white,scale:scale):nil
  CATransaction.commit()
  if value.running && !reduceMotion {
   if fish.animation(forKey:"swim")==nil {
    let rotation=CAKeyframeAnimation(keyPath:"transform.rotation.z")
    rotation.values=[0,-Double.pi*2,-Double.pi*2];rotation.keyTimes=[0,0.5,1];rotation.duration=2;rotation.repeatCount = .infinity
    rotation.timingFunctions=[CAMediaTimingFunction(name:.easeInEaseOut),CAMediaTimingFunction(name:.linear)]
    fish.add(rotation,forKey:"swim")
   }
  } else {fish.removeAnimation(forKey:"swim")}
 }
 static func raster(name:String,part:Int,tint:NSColor,scale:CGFloat)->CGImage? {
   let base=NSImage(systemSymbolName:name,accessibilityDescription:nil)
   let image=NSImage(size:NSSize(width:22,height:22),flipped:false){rect in
    NSGraphicsContext.saveGraphicsState();defer{NSGraphicsContext.restoreGraphicsState()}
    if part != 0 {
     let path=NSBezierPath(ovalIn:NSRect(x:3.6,y:3.6,width:14.8,height:14.8))
     if part==1 {path.appendRect(rect);path.windingRule = .evenOdd}
     path.addClip()
    }
    base?.draw(in:NSRect(x:1,y:1,width:20,height:20));tint.setFill();rect.fill(using:.sourceIn);return true
   }
   var rect=NSRect(x:0,y:0,width:22,height:22)
   guard let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(22*scale),pixelsHigh:Int(22*scale),bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0) else{return nil}
   bitmap.size=NSSize(width:22,height:22)
   return image.cgImage(forProposedRect:&rect,context:NSGraphicsContext(bitmapImageRep:bitmap),hints:nil)
  }
}

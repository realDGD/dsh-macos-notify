import Cocoa
@main struct NativeMenuIconTests {
 static func main(){
  NSApplication.shared.setActivationPolicy(.prohibited)
  func check(_ value:Bool,_ message:String){if !value{print("FAIL "+message);exit(1)}}
  let raster=MenuIconView.raster(name:"fish.circle",part:0,tint:.white,scale:2)
  check(raster?.width==44 && raster?.height==44,"Retina icon raster is only 1x")
  let state=MenuIconState()
  func update(_ id:Int,_ revision:Int,_ running:Bool,_ tone:String,_ stale:Bool=false){state.update(MenuCohort(id:id,revision:revision,running:running,tone:tone),generation:"generation",stale:stale)}
  update(1,1,true,"white");check(state.appearance.running && !state.appearance.filled,"running fish missing")
  update(1,2,true,"yellow");check(state.appearance.running && state.appearance.tone=="yellow" && !state.appearance.filled,"approval stops another task's fish")
  state.acknowledge();check(state.appearance.running && state.appearance.tone=="white" && !state.appearance.filled,"opening panel did not acknowledge the current alert")
  update(1,2,true,"yellow");check(state.appearance.tone=="white","heartbeat repeats acknowledged alert")
  update(1,3,false,"green");check(state.appearance.filled && state.appearance.tone=="green" && !state.appearance.running,"final completion has no filled icon")
  state.acknowledge();check(!state.appearance.filled && state.appearance.tone=="white","filled icon remains after opening panel")
  update(2,1,true,"white");check(state.appearance.running && state.appearance.tone=="white","old cohort colors a new run")
  update(2,2,false,"white");check(!state.appearance.filled && state.appearance.tone=="white","sole user cancellation produces an alert")
  update(3,1,false,"red");check(state.appearance.filled && state.appearance.tone=="red","abnormal stop is not a filled alert")
  update(3,1,true,"red",true);check(!state.appearance.running && !state.appearance.filled && state.appearance.tone=="white","disconnected data keeps spinning or invents completion")
  let view=MenuIconView(frame:NSRect(x:0,y:0,width:24,height:24))
  view.update(MenuIconAppearance(running:true,filled:false,tone:"yellow"),reduceMotion:false)
  check(view.layer?.sublayers?.first?.contents != nil && view.layer?.sublayers?.last?.animation(forKey:"swim") != nil,"fish or status ring missing")
  check(view.layer?.sublayers?.first?.animationKeys()?.isEmpty != false,"outer ring rotates with fish")
  view.update(MenuIconAppearance(running:true,filled:false,tone:"red"),reduceMotion:true)
  check(view.layer?.sublayers?.last?.animationKeys()?.isEmpty != false,"Reduce Motion ignored")
  view.update(MenuIconAppearance(running:false,filled:true,tone:"green"))
  check(view.accessibilityLabel()=="fish.circle.fill" && view.layer?.sublayers?.last?.contents==nil,"completed icon does not use fish.circle.fill")
  print("PASS native fish icon, running/alert/fill, acknowledgment, fresh cohort, stale data and Reduce Motion")
 }
}

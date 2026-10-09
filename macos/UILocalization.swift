import Cocoa

private struct UIRecipe {let source:String;let values:[String:String]}
private final class UIBinding {
 weak var owner:AnyObject?
 let update:(AnyObject)->Void
 init(_ owner:AnyObject,_ update:@escaping(AnyObject)->Void){self.owner=owner;self.update=update}
}
// Bind only product-authored text. User choices, commands and editable text
// never enter this registry. Language changes do not reconstruct controls.
private struct UILanguageRecord:Decodable {let version:Int;let locale:String}
enum UILocalization {
 private(set) static var language = Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true ? "zh":"en"
 private static var bindings:[String:UIBinding]=[:],recipes:[String:UIRecipe]=[:]
 static func text(_ source:String,_ values:[String:String]=[:])->String {
  var result=language == "zh" ? source:uiEnglish[source] ?? source
  // Replace placeholders in a single pass; user values remain literal data.
  let regex=try! NSRegularExpression(pattern:#"\{([0-9]+)\}"#)
  let original=result as NSString
  for match in regex.matches(in:result,range:NSRange(location:0,length:original.length)).reversed() {
   if let value=values[original.substring(with:match.range(at:1))],let range=Range(match.range,in:result){result.replaceSubrange(range,with:value)}
  }
  if recipes.count>2048 {recipes.removeAll(keepingCapacity:true)}
  recipes[result]=UIRecipe(source:source,values:values)
  return result
 }
 static func bind<T:AnyObject>(_ owner:T,slot:String,update:@escaping(T)->Void) {
  bindings=bindings.filter{$0.value.owner != nil}
  bindings["\(ObjectIdentifier(owner))-\(slot)"]=UIBinding(owner){if let value=$0 as? T{update(value)}}
  update(owner)
 }
 static func translated(_ displayed:String)->()->String {
  let recipe=recipes[displayed] ?? UIRecipe(source:displayed,values:[:])
  return {text(recipe.source,recipe.values)}
 }
 @discardableResult static func set(_ value:String)->Bool {
  guard ["en","zh"].contains(value),value != language else{return false}
  language=value
  let current=bindings
  for binding in current.values {if let owner=binding.owner{binding.update(owner)}}
  NotificationCenter.default.post(name:Notification.Name("DSHNotifyUILanguageChanged"),object:nil)
  return true
 }
 @discardableResult static func poll(directory:String)->Bool {
  let file=(directory as NSString).appendingPathComponent("ui-language.json")
  guard let size=(try? FileManager.default.attributesOfItem(atPath:file)[.size]) as? Int,size<=1024,
   let data=try? Data(contentsOf:URL(fileURLWithPath:file)),let record=try? JSONDecoder().decode(UILanguageRecord.self,from:data),
   record.version == 1,["zh","en"].contains(record.locale) else{return false}
  return set(record.locale)
 }
}
func L(_ source:String,_ values:[String:String]=[:])->String {UILocalization.text(source,values)}
func uiLabel(_ text:String)->NSTextField {
 let field=NSTextField(labelWithString:text);uiSet(field,text);return field
}
func uiSet(_ field:NSTextField,_ text:String) {
 let render=UILocalization.translated(text)
 UILocalization.bind(field,slot:"text"){$0.stringValue=render()}
}
func uiButton(title:String,target:Any?,action:Selector?)->NSButton {
 let button=NSButton(title:title,target:target,action:action),render=UILocalization.translated(title)
 UILocalization.bind(button,slot:"title"){$0.title=render()};return button
}
func uiCheckbox(checkboxWithTitle:String,target:Any?,action:Selector?)->NSButton {
 let button=NSButton(checkboxWithTitle:checkboxWithTitle,target:target,action:action),render=UILocalization.translated(checkboxWithTitle)
 UILocalization.bind(button,slot:"title"){$0.title=render()};return button
}
func uiAccessibility(_ view:NSView,_ text:String) {
 let render=UILocalization.translated(text);UILocalization.bind(view,slot:"accessibility"){$0.setAccessibilityLabel(render())}
}

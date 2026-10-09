import Cocoa
import UserNotifications

// Link the real Interactions.swift without starting its file/notification pump.
let stateDir = NSTemporaryDirectory()
func logLine(_ message: String) {}

@main
@MainActor
struct NativeQuestionLayoutTests {
    static func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(descendants)
    }

    static func main() {
  UILocalization.set("zh")
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let cases: [(String, Int, Bool, NSSize)] = [
            ("single short question", 1, false, NSSize(width: 640, height: 700)),
            ("two short questions", 2, false, NSSize(width: 640, height: 700)),
            ("three questions", 3, false, NSSize(width: 640, height: 700)),
            ("long scrollable question", 1, true, NSSize(width: 640, height: 700)),
            ("narrow resized window", 1, false, NSSize(width: 460, height: 400)),
        ]
        let controllers = cases.map { _, count, long, size in
            let questions = (1...count).map { number in
                NativeQuestion(id: "q\(number)", question: "请选择一个选项，也可以在下方补充文字。", header: nil,
                    detail: long ? String(repeating: "这是一段完整显示并可滚动阅读的说明。\n", count: 30) : nil,
                    options: [NativeOption(label: "选项 A", description: nil), NativeOption(label: "选项 B", description: nil)], multiSelect: false)
            }
            let request = NativeRequest(id: UUID().uuidString, kind: "questions", sessionId: "layout-test", title: "布局测试", subtitle: "布局测试", body: "", questions: questions, phase: "foreground")
            let controller = QuestionWindow(request)
            controller.window!.setContentSize(size)
            controller.window!.contentView!.layoutSubtreeIfNeeded()
            return controller
        }
        // Run after the production initial-scroll callback, with no visible
        // window, so this test checks actual clipping rather than AX existence.
        DispatchQueue.main.async {
            var failures = 0
            let markdown = renderedMarkdown("## 标题\n**选项** 与 `echo 中文`\n- 列表\n[文档](https://example.com)\n```json\n{\"ok\":true}\n```", bold: false)
            let rendered = markdown.string as NSString
            let boldFont = markdown.attribute(.font, at: rendered.range(of: "选项").location, effectiveRange: nil) as? NSFont
            let codeFont = markdown.attribute(.font, at: rendered.range(of: "echo 中文").location, effectiveRange: nil) as? NSFont
            let link = markdown.attribute(.link, at: rendered.range(of: "文档").location, effectiveRange: nil) as? URL
            if markdown.string.contains("**") || !markdown.string.contains("• 列表") || !markdown.string.contains("{\"ok\":true}") || boldFont?.fontDescriptor.symbolicTraits.contains(.bold) != true || codeFont?.isFixedPitch != true || link?.absoluteString != "https://example.com" {
                print("FAIL Markdown text, emphasis, code, lists or links"); failures += 1
            }
            let optionQuestion = NativeQuestion(id: "md", question: "**题目**", header: nil, detail: nil, options: [NativeOption(label: "**原始选项**", description: "`说明`")], multiSelect: false)
            let optionEditor = QuestionEditor(optionQuestion, number: 1)
            let optionButton = descendants(optionEditor.view).compactMap { $0 as? NSButton }.first!
            optionButton.performClick(nil)
            if optionEditor.answer["selected"] as? [String] != ["**原始选项**"] { print("FAIL Markdown changed the submitted option label"); failures += 1 }
            let code = "echo \"中文\\n\"; $HOME # comment"
            let colored = highlightedCode(code, language: "shell")
            let source = code as NSString
            let keywordColor = colored.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
            let stringColor = colored.attribute(.foregroundColor, at: source.range(of: "中文").location, effectiveRange: nil) as? NSColor
            if colored.string != code || keywordColor == stringColor { print("FAIL Shell colors or original text preservation"); failures += 1 }
            let combiningJSON = "{\"s\":\"\u{0301} a b\",\"n\":1}"
            let combiningFormatted = formattedArguments(combiningJSON)
            let combiningValue = try! JSONSerialization.jsonObject(with: Data(combiningFormatted.utf8)) as! [String: Any]
            if combiningValue["s"] as? String != "\u{0301} a b" || !combiningFormatted.contains("\n  \"n\": 1") {
                print("FAIL JSON lexical scan changed a leading combining character/string spaces"); failures += 1
            }
            let preciseJSON = #"{ "z":900719925474099312345, "a":1.20e+10, "z":"\\u4e2d", "list":[{},[],true,null] }"#
            let formatted = formattedArguments(preciseJSON)
            if !formatted.contains("900719925474099312345") || !formatted.contains("1.20e+10") || !formatted.contains(#""z": "\\u4e2d""#) || formattedArguments("{bad json") != "{bad json" {
                print("FAIL JSON formatting changed numbers, escapes, duplicate keys or invalid source"); failures += 1
            }
            let json = "{\"command\":\"echo \\\"中文\\\"\",\"enabled\":true,\"count\":12}"
            let coloredJSON = highlightedCode(json, language: "json")
            let jsonSource = json as NSString
            let keyColor = coloredJSON.attribute(.foregroundColor, at: jsonSource.range(of: "command").location, effectiveRange: nil) as? NSColor
            let valueColor = coloredJSON.attribute(.foregroundColor, at: jsonSource.range(of: "echo").location, effectiveRange: nil) as? NSColor
            if coloredJSON.string != json || keyColor == valueColor { print("FAIL JSON escaped strings or key/value colors"); failures += 1 }
            let directory = NSTemporaryDirectory() + UUID().uuidString
            try! FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(atPath: directory) }
            let waiter = DesktopJumpWaiter(directory: directory)
            var confirmations = 0
            var navigationErrors = 0
            waiter.wait(requestId: "own", sessionId: "target", createdAt: 1000) { error in
                if error == nil { confirmations += 1 } else { navigationErrors += 1 }
            }
            func ack(_ id: String, _ session: String, _ created: Double, _ confirmed: Double) {
                let data = try! JSONSerialization.data(withJSONObject: ["requestId": id, "sessionId": session, "createdAt": created, "confirmedAt": confirmed])
                try! data.write(to: URL(fileURLWithPath: directory + "/jump-result.json"))
            }
            ack("other", "target", 1000, 2000); waiter.poll(at: 2000)
            ack("own", "wrong", 1000, 2000); waiter.poll(at: 2000)
            ack("own", "target", 1000, 999); waiter.poll(at: 2000)
            if confirmations != 0 { print("FAIL foreign or stale ack confirmed navigation"); failures += 1 }
            ack("own", "target", 1000, 2000); waiter.poll(at: 2000); waiter.poll(at: 2001)
            if confirmations != 1 { print("FAIL matching ack did not settle once"); failures += 1 }
            waiter.wait(requestId: "timeout", sessionId: "target", createdAt: 1000) { error in
                if error == nil { confirmations += 1 } else { navigationErrors += 1 }
            }
            waiter.poll(at: 17000)
            if navigationErrors != 1 || confirmations != 1 { print("FAIL missing ack did not report timeout"); failures += 1 }
            else { print("PASS matching ack, stale/foreign ack and timeout") }
            let rich = Data(#"{"id":"details-test","kind":"approval","sessionId":"s1","title":"请求批准","subtitle":"Old","body":"summary","sessionTitle":"真实名称","cwd":"/工作区","context":[{"role":"user","text":"为什么要执行？"}],"approval":{"toolName":"bash","reason":"需要权限","command":"printf '完整命令\\n'","arguments":"{\"command\":\"printf '完整命令\\\\n'\"}"}}"#.utf8)
            let request = try! JSONDecoder().decode(NativeRequest.self, from: rich)
            let details = QuestionWindow(request)
            let draftQuestion=NativeQuestion(id:"draft",question:"保留草稿？",header:nil,detail:nil,options:nil,multiSelect:false)
            let draftWindow=QuestionWindow(NativeRequest(id:UUID().uuidString,kind:"questions",sessionId:"draft-target",title:"草稿",subtitle:"草稿",body:"",questions:[draftQuestion],phase:"foreground"))
            let draftInput=descendants(draftWindow.window!.contentView!).compactMap{$0 as? NSTextView}.first{$0.isEditable}!
            draftInput.string="尚未提交的独立草稿"
            let menuData=try! JSONSerialization.data(withJSONObject:["version":1,"generation":UUID().uuidString,"revision":1,"updatedAt":2000,"enabled":true,"availability":"ready",
              "activeIds":["menu-target"],"orphanIds":[],"historyIds":[],"omittedCount":0,
              "nodes":[["id":"menu-target","parentId":NSNull(),"workspaceTitle":"测试工作区","sessionTitle":"菜单会话","state":"running","preview":"用户输入","previewKind":"user","pinned":false,"pinIndex":NSNull(),"progress":NSNull(),"childIds":[],"descendantBadge":NSNull(),"updatedAt":2000]]])
            try! menuData.write(to:URL(fileURLWithPath:directory+"/session-menu.json"))
            var menuOpened:[String]=[]
            let sessionMenu=SessionMenuController(directory:directory,openSession:{id,completion in menuOpened.append(id);completion(nil)},openDesktop:{false})
            sessionMenu.poll(at:2000);sessionMenu.navigate("menu-target");sessionMenu.popover.performClose(nil)
            if menuOpened != ["menu-target"] || draftInput.string != "尚未提交的独立草稿" || draftWindow.window==nil {
                print("FAIL menu close altered independent question draft");failures+=1
            } else {print("PASS menu navigation and close preserve independent question draft")}
            let views = descendants(details.window!.contentView!)
            let hasDetails = details.window!.title.contains("真实名称") && views.compactMap { $0 as? NSTextView }.contains { $0.string == "printf '完整命令\\n'" }
            print("\(hasDetails ? "PASS" : "FAIL") approval displays the exact command and real title")
            if !hasDetails { failures += 1 }
            let argumentsView = views.compactMap { $0 as? NSTextView }.first { $0.accessibilityLabel() == "完整工具参数" }!
            let expectedArguments = "{\n  \"command\": \"printf '完整命令\\\\n'\"\n}"
            if argumentsView.string != expectedArguments {
                print("FAIL arguments are not formatted with one property per line"); failures += 1
            }
            let rawToggle = views.compactMap { $0 as? NSButton }.first { $0.title == "查看原文" }
            rawToggle?.performClick(nil)
            if rawToggle == nil || argumentsView.string != request.approval?.arguments {
                print("FAIL original arguments cannot be viewed exactly"); failures += 1
            }
            rawToggle?.performClick(nil)
            let clipboard = NSPasteboard.general.pasteboardItems?.map { item -> NSPasteboardItem in
                let saved = NSPasteboardItem()
                for type in item.types { if let data = item.data(forType: type) { saved.setData(data, forType: type) } }
                return saved
            } ?? []
            let copyArguments = views.compactMap { $0 as? NSButton }.first { $0.title == "复制原始参数" }
            copyArguments?.performClick(nil)
            if copyArguments == nil || NSPasteboard.general.string(forType: .string) != request.approval?.arguments {
                print("FAIL copied arguments differ from original"); failures += 1
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects(clipboard)
            let longCommand = "echo " + String(repeating: "veryLongTokenWithoutBreaks", count: 120) + String(repeating: "中文", count: 80)
            let compactCommand = "printf 'approval preview'; date '+%Y-%m-%d %H:%M:%S' > /example/probe.txt && cat /example/probe.txt"
            let compactArguments = #"{"command":"printf 'approval preview'; date '+%Y-%m-%d %H:%M:%S' > /example/probe.txt && cat /example/probe.txt","description":"Preview approval without executing anything","justification":"测试审批详情：需要核实工作区之外的文件写入，允许或拒绝之前先查看完整上下文。","sandbox_permissions":"danger-full-access"}"#
            let compactRequest = NativeRequest(id: "compact-approval", kind: "approval", sessionId: "layout-only", title: "审批布局", subtitle: "", body: "", questions: nil, phase: "foreground", approval: NativeApproval(toolName: "bash", reason: "escalate sandbox to danger-full-access: 测试审批详情：需要核实工作区之外的文件写入，允许或拒绝之前先查看完整上下文。", callId: nil, arguments: compactArguments, command: compactCommand))
            let compactWindow = QuestionWindow(compactRequest)
            compactWindow.window!.setContentSize(NSSize(width: 640, height: 700))
            let compactRoot = compactWindow.window!.contentView!
            compactRoot.layoutSubtreeIfNeeded()
            let compactScroll = descendants(compactRoot).compactMap { $0 as? NSScrollView }.first!
            let compactDocument = compactScroll.documentView!
            let contextToggle = descendants(compactDocument).compactMap { $0 as? NSButton }.first { $0.title == "查看相关上下文与会话信息" }!
            let toggleRect = contextToggle.convert(contextToggle.bounds, to: compactDocument)
            if !compactScroll.documentVisibleRect.contains(toggleRect) {
                print("FAIL short approval context needs a taller window: toggle=\(toggleRect), viewport=\(compactScroll.documentVisibleRect), document=\(compactDocument.frame)"); failures += 1
            } else { print("PASS short approval exposes context without resizing") }
            compactWindow.window!.setContentSize(NSSize(width: 460, height: 400))
            compactRoot.layoutSubtreeIfNeeded()
            let compactBottom = max(0, compactDocument.bounds.height - compactScroll.contentView.bounds.height)
            compactScroll.contentView.scroll(to: NSPoint(x: 0, y: compactBottom))
            compactScroll.reflectScrolledClipView(compactScroll.contentView)
            let narrowToggleRect = contextToggle.convert(contextToggle.bounds, to: compactDocument)
            if !compactScroll.documentVisibleRect.contains(narrowToggleRect) {
                print("FAIL narrow approval cannot scroll to context: toggle=\(narrowToggleRect), viewport=\(compactScroll.documentVisibleRect)"); failures += 1
            } else { print("PASS narrow approval can scroll to its final context control") }
            let wrappingRequest = NativeRequest(id: "wrap", kind: "approval", sessionId: "s1", title: "换行", subtitle: "", body: "", questions: nil, phase: "foreground", approval: NativeApproval(toolName: "bash", reason: "", callId: nil, arguments: "{\"command\":\"" + longCommand + "\"}", command: longCommand))
            let wrappingWindow = QuestionWindow(wrappingRequest)
            wrappingWindow.window!.setContentSize(NSSize(width: 460, height: 400))
            wrappingWindow.window!.contentView!.layoutSubtreeIfNeeded()
            for textView in descendants(wrappingWindow.window!.contentView!).compactMap({ $0 as? NSTextView }) {
                let scrollView = textView.enclosingScrollView!
                textView.layoutManager!.ensureLayout(for: textView.textContainer!)
                let used = textView.layoutManager!.usedRect(for: textView.textContainer!)
                if scrollView.hasHorizontalScroller || textView.isHorizontallyResizable || textView.textContainer?.widthTracksTextView != true || used.width > scrollView.contentSize.width || used.height <= 24 {
                    print("FAIL command/arguments do not wrap at narrow width: used=\(used), frame=\(textView.frame), container=\(textView.textContainer!.containerSize), clip=\(scrollView.contentSize)"); failures += 1
                }
            }
            let back = views.compactMap { $0 as? NSButton }.first { $0.title == "回到 DSH 会话" }!
            var completion: ((String?) -> Void)?
            NotificationInteractions.shared.openSession = { _, callback in completion = callback }
            var closed = false
            details.onClose = { closed = true }
            details.setUnavailable(true)
            back.performClick(nil)
            details.setUnavailable(false)
            completion?("跳转超时")
            if closed { print("FAIL jump failure closed the panel"); failures += 1 }
            let recovered = views.compactMap { $0 as? NSButton }.first { $0.title == "允许一次" }!.isEnabled
            if !recovered { print("FAIL reconnect during failed jump kept approval disabled"); failures += 1 }
            back.performClick(nil)
            let allowButton = views.compactMap { $0 as? NSButton }.first { $0.title == "允许一次" }!
            details.setUnavailable(true)
            var accidentalSubmissions = 0
            details.onSubmit = { _ in accidentalSubmissions += 1 }
            allowButton.performClick(nil)
            if allowButton.isEnabled || accidentalSubmissions != 0 { print("FAIL pending jump allowed a disconnected submission"); failures += 1 }
            completion?(nil)
            if !closed { print("FAIL confirmed jump did not close the panel"); failures += 1 }
            else { print("PASS only confirmed navigation closes the panel") }
            for (index, controller) in controllers.enumerated() {
                let name = cases[index].0
                let root = controller.window!.contentView!
                root.layoutSubtreeIfNeeded()
                let scroll = descendants(root).compactMap { $0 as? NSScrollView }.first!
                let document = scroll.documentView!
                let firstHeading = descendants(document).compactMap { $0 as? NSTextField }.first { $0.stringValue == "问题 1" }!
                let headingRect = firstHeading.convert(firstHeading.bounds, to: document)
                let visibleRect = scroll.documentVisibleRect
                let visible = headingRect.width > 0 && headingRect.height > 0 && visibleRect.contains(headingRect)
                print("\(visible ? "PASS" : "FAIL") \(name): first question \(NSStringFromRect(headingRect)), viewport \(NSStringFromRect(visibleRect))")
                if !visible { failures += 1 }
                if cases[index].2 {
                    // Long content must remain navigable after the initial top
                    // position and a later resize, including its final input.
                    controller.window!.setContentSize(NSSize(width: 460, height: 400))
                    root.layoutSubtreeIfNeeded()
                    let resizedHeading = firstHeading.convert(firstHeading.bounds, to: document)
                    let topVisible = scroll.documentVisibleRect.contains(resizedHeading)
                    print("\(topVisible ? "PASS" : "FAIL") long question after resize: first question remains visible")
                    if !topVisible { failures += 1 }
                    let lastInputScroll = descendants(document).compactMap { $0 as? NSScrollView }.last!
                    let bottom = max(0, document.bounds.height - scroll.contentView.bounds.height)
                    scroll.contentView.scroll(to: NSPoint(x: 0, y: bottom))
                    scroll.reflectScrolledClipView(scroll.contentView)
                    let inputRect = lastInputScroll.convert(lastInputScroll.bounds, to: document)
                    let inputVisible = scroll.documentVisibleRect.contains(inputRect)
                    print("\(inputVisible ? "PASS" : "FAIL") long question end: input \(NSStringFromRect(inputRect)), viewport \(NSStringFromRect(scroll.documentVisibleRect))")
                    if !inputVisible { failures += 1 }
                }
            }
            exit(failures == 0 ? 0 : 1)
        }
        app.run()
    }
}

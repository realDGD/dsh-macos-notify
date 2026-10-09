import Cocoa
import UserNotifications

struct NativeOption: Codable { let label: String; let description: String? }
struct NativeQuestion: Codable {
    let id: String
    let question: String
    let header: String?
    let detail: String?
    let options: [NativeOption]?
    let multiSelect: Bool?
}
struct NativeContext: Codable { let role: String; let text: String; let truncated: Bool? }
struct NativeApproval: Codable {
    let toolName: String; let reason: String?; let callId: String?
    let arguments: String?; let command: String?
    var toolUnnamed: Bool? = nil
    var displayToolName: String { toolUnnamed == true ? L("操作") : toolName }
}
struct NativeRequest: Codable {
    let id: String
    let kind: String
    let sessionId: String
    let title: String
    let subtitle: String
    let body: String
    let questions: [NativeQuestion]?
    let phase: String?
    var sessionTitle: String? = nil
    var cwd: String? = nil
    var context: [NativeContext]? = nil
    var approval: NativeApproval? = nil
    var sessionUntitled: Bool? = nil
    var displayTitle: String { sessionUntitled == true ? L("未命名") : sessionTitle ?? subtitle }
    var displaySubtitle: String { sessionUntitled == true ? displayTitle : subtitle }
}
struct NativeSnapshot: Codable {
    let version: Int; let updatedAt: Double; let requests: [NativeRequest]
    var preferences: [String: Bool]? = nil
    var quietSessionId: String? = nil
}
func nativePreferences() -> [String: Bool] {
    let path = (stateDir as NSString).appendingPathComponent("settings.json")
    guard let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size]) as? Int, size <= 4096,
          let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let parsed = try? JSONDecoder().decode([String: Bool].self, from: data) else { return [:] }
    return parsed
}
struct CommandResult: Codable { let status: String }

// Waking Desktop is not proof of navigation. Only the authenticated plugin's
// matching acknowledgement permits the initiating panel to close.
final class DesktopJumpWaiter {
    private struct Pending {
        let sessionId: String; let createdAt: Double; let completion: (String?) -> Void
    }
    private let directory: String
    private var pending: [String: Pending] = [:]
    init(directory: String) { self.directory = directory }
    func wait(requestId: String, sessionId: String, createdAt: Double, completion: @escaping (String?) -> Void) {
        pending[requestId] = Pending(sessionId: sessionId, createdAt: createdAt, completion: completion)
    }
    func fail(requestId: String, message: String) { pending.removeValue(forKey: requestId)?.completion(message) }
    func poll(at now: Double = Date().timeIntervalSince1970 * 1000) {
        let path = (directory as NSString).appendingPathComponent("jump-result.json")
        var ack: [String: Any]?
        if let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size]) as? Int, size <= 4096,
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            ack = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
        for (id, item) in pending {
            if ack?["requestId"] as? String == id, ack?["sessionId"] as? String == item.sessionId,
               ack?["createdAt"] as? Double == item.createdAt,
               let confirmed = ack?["confirmedAt"] as? Double, confirmed.isFinite,
               confirmed >= item.createdAt, confirmed <= now + 10000 {
                pending.removeValue(forKey: id)?.completion(nil)
            } else if now - item.createdAt > 15000 {
                fail(requestId: id, message: L("未确认已打开目标会话，窗口已保留。请检查 DSH 后重试。"))
            }
        }
    }
}

func renderedMarkdown(_ text: String, bold: Bool) -> NSAttributedString {
    let baseFont = bold ? NSFont.boldSystemFont(ofSize: 14) : NSFont.systemFont(ofSize: 13)
    let output = NSMutableAttributedString(string: "")
    var pieces = 0
    func emit(_ value: NSAttributedString) {
        if pieces > 0 { output.append(NSAttributedString(string: "\n", attributes: [.font: baseFont])) }
        output.append(value); pieces += 1
    }
    func inline(_ source: String, font: NSFont) -> NSAttributedString {
        guard let parsed = try? AttributedString(markdown: source, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) else {
            return NSAttributedString(string: source, attributes: [.font: font, .foregroundColor: NSColor.labelColor])
        }
        let result = NSMutableAttributedString(string: "")
        for run in parsed.runs {
            var style: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
            let intent = run.inlinePresentationIntent
            var runFont = font
            if intent?.contains(.stronglyEmphasized) == true { runFont = NSFontManager.shared.convert(runFont, toHaveTrait: .boldFontMask) }
            if intent?.contains(.emphasized) == true { runFont = NSFontManager.shared.convert(runFont, toHaveTrait: .italicFontMask) }
            if intent?.contains(.code) == true {
                runFont = .monospacedSystemFont(ofSize: 12, weight: .regular)
                style[.backgroundColor] = NSColor.controlBackgroundColor
            }
            style[.font] = runFont
            if let link = run.link, ["http", "https"].contains(link.scheme?.lowercased() ?? "") {
                style[.link] = link; style[.foregroundColor] = NSColor.linkColor; style[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            result.append(NSAttributedString(string: String(parsed[run.range].characters), attributes: style))
        }
        return result
    }
    let heading = try! NSRegularExpression(pattern: #"^ {0,3}(#{1,6})\s+(.+)$"#)
    let list = try! NSRegularExpression(pattern: #"^(\s*)[-+*]\s+(.+)$"#)
    let fence = try! NSRegularExpression(pattern: #"^ {0,3}(`{3,}|~{3,})([^\s]*)\s*$"#)
    var code: [String] = [], delimiter: String?, language = ""
    for line in text.components(separatedBy: "\n") {
        let source = line as NSString
        let range = NSRange(location: 0, length: source.length)
        if let mark = fence.firstMatch(in: line, range: range) {
            let candidate = source.substring(with: mark.range(at: 1))
            if let opened = delimiter {
                if candidate.first == opened.first && candidate.count >= opened.count && source.substring(with: mark.range(at: 2)).isEmpty {
                    emit(highlightedCode(code.joined(separator: "\n"), language: language)); code = []; delimiter = nil
                } else { code.append(line) }
            } else {
                delimiter = candidate
                let hint = source.substring(with: mark.range(at: 2)).lowercased()
                language = ["sh", "bash", "shell", "zsh"].contains(hint) ? "shell" : hint
            }
        } else if delimiter != nil { code.append(line) }
        else if let match = heading.firstMatch(in: line, range: range) {
            let level = match.range(at: 1).length
            emit(inline(source.substring(with: match.range(at: 2)), font: .boldSystemFont(ofSize: CGFloat(max(14, 21 - level)))))
        } else if let match = list.firstMatch(in: line, range: range) {
            emit(inline(source.substring(with: match.range(at: 1)) + "• " + source.substring(with: match.range(at: 2)), font: baseFont))
        } else if line.hasPrefix("> ") { emit(inline("│ " + String(line.dropFirst(2)), font: baseFont)) }
        else { emit(inline(line, font: baseFont)) }
    }
    if delimiter != nil { emit(highlightedCode(code.joined(separator: "\n"), language: language)) }
    return output
}

private func wrapped(_ text: String, bold: Bool = false, markdown: Bool = false) -> NSTextField {
    let field = NSTextField(wrappingLabelWithString: text)
    field.font = bold ? .boldSystemFont(ofSize: 14) : .systemFont(ofSize: 13)
    if markdown { field.attributedStringValue = renderedMarkdown(text, bold: bold); field.allowsEditingTextAttributes = true }
    field.isSelectable = true
    field.lineBreakMode = .byWordWrapping
    field.maximumNumberOfLines = 0
    field.setContentCompressionResistancePriority(.required, for: .vertical)
    return field
}

private final class QuestionDocumentView: NSView {
    override var isFlipped: Bool { true }
}

final class QuestionEditor: NSObject, NSTextViewDelegate {
    let question: NativeQuestion
    let view = NSStackView()
    let input = NSTextView()
    private var buttons: [NSButton] = []
    var changed: (() -> Void)?
    init(_ question: NativeQuestion, number: Int) {
        self.question = question
        super.init()
        view.orientation = .vertical
        view.alignment = .leading
        view.spacing = 9
        func add(_ child: NSView) {
            view.addArrangedSubview(child)
            child.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        }
        add(uiWrapped(L("问题 {0}{1}", ["0": String(describing: number), "1": String(describing: question.header.map { " · " + $0 } ?? "")]), bold: true))
        add(wrapped(question.question, markdown: true))
        if let detail = question.detail, !detail.isEmpty { add(wrapped(detail, markdown: true)) }
        if !(question.options ?? []).isEmpty {
            let hint = uiWrapped(question.multiSelect == true ? L("可选择多个选项，也可以补充文字") : L("可选择一个选项，也可以补充文字"))
            hint.textColor = .secondaryLabelColor
            add(hint)
        }
        for (index, option) in (question.options ?? []).enumerated() {
            let button = NSButton(title: "", target: self, action: #selector(selectOption(_:)))
            button.setButtonType(question.multiSelect == true ? .switch : .radio)
            button.tag = index
            button.setAccessibilityLabel(option.label)
            button.widthAnchor.constraint(equalToConstant: 22).isActive = true
            buttons.append(button)
            let label = wrapped(option.label + (option.description.map { "\n" + $0 } ?? ""), markdown: true)
            let row = NSStackView(views: [button, label])
            row.orientation = .horizontal
            row.alignment = .top
            row.spacing = 5
            add(row)
        }
        add(uiWrapped(L("自定义答案／补充（可与选项一起提交）")))
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.heightAnchor.constraint(equalToConstant: 90).isActive = true
        input.isRichText = false
        input.font = .systemFont(ofSize: 13)
        input.isVerticallyResizable = true
        input.isHorizontallyResizable = false
        input.autoresizingMask = [.width]
        input.textContainerInset = NSSize(width: 7, height: 7)
        input.textContainer?.widthTracksTextView = true
        input.delegate = self
        uiAccessibility(input, L("问题 {0} 的自定义答案", ["0": String(describing: number)]))
        scroll.documentView = input
        add(scroll)
        let separator = NSBox()
        separator.boxType = .separator
        add(separator)
    }
    @objc private func selectOption(_ sender: NSButton) {
        if question.multiSelect != true { for button in buttons { button.state = button === sender ? .on : .off } }
        changed?()
    }
    func textDidChange(_ notification: Notification) { changed?() }
    var answered: Bool { buttons.contains { $0.state == .on } || !input.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var answer: [String: Any] {
        ["id": question.id, "selected": buttons.filter { $0.state == .on }.map { question.options![$0.tag].label }, "custom": input.string]
    }
    func clearAnswer() {
        buttons.forEach { $0.state = .off }
        input.string = ""
        input.undoManager?.removeAllActions()
        changed?()
    }
    func setEnabled(_ enabled: Bool) { for button in buttons { button.isEnabled = enabled }; input.isEditable = enabled }
}

private final class ContextSection: NSStackView {
    private let contents = NSStackView()
    private var markdown: MarkdownContextView?
    private let contextItems: [NativeContext]
    init(_ request: NativeRequest) {
        contextItems = request.context ?? []
        super.init(frame: .zero)
        orientation = .vertical; alignment = .leading; spacing = 10
        let toggle = uiCheckbox(checkboxWithTitle: L("查看相关上下文与会话信息"), target: nil, action: nil)
        toggle.target = self; toggle.action = #selector(toggleContext(_:))
        addArrangedSubview(toggle)
        contents.orientation = .vertical; contents.alignment = .leading; contents.spacing = 10
        func add(_ text: String, markdown: Bool = false) {
            let field = wrapped(text, markdown: markdown)
            contents.addArrangedSubview(field)
            field.widthAnchor.constraint(equalTo: contents.widthAnchor).isActive = true
        }
        let identity = uiWrapped(L("会话 ID：{0}", ["0": request.sessionId])); contents.addArrangedSubview(identity); identity.widthAnchor.constraint(equalTo: contents.widthAnchor).isActive = true
        addArrangedSubview(contents)
        contents.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        setVisibilityPriority(.notVisible, for: contents)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    @objc private func toggleContext(_ sender: NSButton) {
        if sender.state == .on {
            if markdown == nil {
                let view = MarkdownContextView(contextItems)
                markdown = view
                contents.insertArrangedSubview(view, at: 0)
                view.widthAnchor.constraint(equalTo: contents.widthAnchor).isActive = true
            }
            markdown?.load()
        }
        setVisibilityPriority(sender.state == .on ? .mustHold : .notVisible, for: contents)
    }
}

func highlightedCode(_ text: String, language: String) -> NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byCharWrapping
    let result = NSMutableAttributedString(string: text, attributes: [
        .paragraphStyle: paragraph,
        .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular), .foregroundColor: NSColor.labelColor,
    ])
    // Color existing UTF-16 ranges only. Never parse/reserialize the command,
    // replace escapes, or include colors in the copied plain text.
    guard ["shell", "json"].contains(language) else { return result }
    let pattern = language == "json"
        ? ##"("(?:\\[\s\S]|[^"\\])*")(?=\s*:)|("(?:\\[\s\S]|[^"\\])*")|\b(?:true|false|null)\b|-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b|[{}\[\]:,]"##
        : ##"'[^']*'|"(?:\\[\s\S]|[^"\\])*"|(?:^|(?<=[\s;]))#[^\n]*|\$\{[^}]*\}|\$(?:[A-Za-z_][A-Za-z0-9_]*|[0-9@?#$!*\-])|\b(?:if|then|else|elif|fi|for|in|do|done|while|case|esac|function|export|local|readonly|return|exit|echo|printf|cd|cat|date)\b|\b\d+\b|&&|\|\||[;|&<>]"##
    guard let expression = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return result }
    let source = text as NSString
    for match in expression.matches(in: text, range: NSRange(location: 0, length: source.length)) {
        let token = source.substring(with: match.range)
        let color: NSColor
        if language == "json" {
            if match.range(at: 1).location != NSNotFound { color = .systemBlue }
            else if match.range(at: 2).location != NSNotFound { color = .systemGreen }
            else if ["true", "false", "null"].contains(token) { color = .systemPurple }
            else if token.first?.isNumber == true || token.hasPrefix("-") { color = .systemOrange }
            else { color = .secondaryLabelColor }
        } else if token.hasPrefix("#") { color = .secondaryLabelColor }
        else if token.hasPrefix("\"") || token.hasPrefix("'") { color = .systemGreen }
        else if token.hasPrefix("$") || token.first?.isNumber == true { color = .systemOrange }
        else { color = .systemBlue }
        result.addAttribute(.foregroundColor, value: color, range: match.range)
    }
    return result
}

private final class CodePreviewScrollView: NSScrollView {
    var previewHeight: NSLayoutConstraint?
    override func layout() {
        super.layout()
        guard contentSize.width > 0, let text = documentView as? NSTextView,
              let container = text.textContainer, let manager = text.layoutManager else { return }
        manager.ensureLayout(for: container)
        let textHeight = ceil(manager.usedRect(for: container).height + text.textContainerInset.height * 2)
        let next = min(180, max(44, textHeight + 2))
        if let height = previewHeight, abs(height.constant - next) > 0.5 { height.constant = next }
        // Keep a short preview from retaining its original tall document frame.
        text.setFrameSize(NSSize(width: contentSize.width, height: max(contentSize.height, textHeight)))
    }
}

func readOnlyText(_ text: String, label: String, language: String) -> NSScrollView {
    let scroll = CodePreviewScrollView()
    scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = false
    scroll.autohidesScrollers = true
    scroll.borderType = .bezelBorder
    let height = scroll.heightAnchor.constraint(equalToConstant: 180)
    // A fallback context pane can also pin this view to its own bounded height.
    height.priority = .init(999)
    height.isActive = true
    scroll.previewHeight = height
    // Match the initial clip width (zero before layout), so autoresizing
    // follows clip growth without retaining an independent 600px baseline.
    // The macOS 15 regression also checks the final glyph bounds.
    let view = NSTextView(frame: NSRect(x: 0, y: 0, width: scroll.contentSize.width, height: 180))
    view.isRichText = false; view.isEditable = false; view.isSelectable = true
    view.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
    view.isVerticallyResizable = true; view.isHorizontallyResizable = false
    view.autoresizingMask = [.width]
    view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    view.textContainer?.widthTracksTextView = true
    view.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
    view.textContainer?.lineBreakMode = .byCharWrapping
    view.textContainerInset = NSSize(width: 7, height: 7)
    view.textStorage?.setAttributedString(highlightedCode(text, language: language))
    uiAccessibility(view, label)
    scroll.documentView = view
    return scroll
}

// Validate syntax, then change only insignificant whitespace outside strings.
// JSONSerialization re-encoding would change key order, escapes and large numbers.
func formattedArguments(_ original: String) -> String {
    guard let data = original.data(using: .utf8),
          (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil else { return original }
    var result = "", indent = 0, inString = false, escaped = false
    func newline() { result += "\n" + String(repeating: "  ", count: indent) }
    for character in original.unicodeScalars {
        if inString {
            result.unicodeScalars.append(character)
            if escaped { escaped = false }
            else if character == "\\" { escaped = true }
            else if character == "\"" { inString = false }
            continue
        }
        switch character {
        case "\"":
            if result.last == "{" || result.last == "[" { newline() }
            inString = true; result.unicodeScalars.append(character)
        case " ", "\n", "\r", "\t": continue
        case "{", "[":
            if result.last == "{" || result.last == "[" { newline() }
            result.unicodeScalars.append(character); indent += 1
        case "}", "]":
            indent = max(0, indent - 1)
            if result.last != "{" && result.last != "[" { newline() }
            result.unicodeScalars.append(character)
        case ",": result.unicodeScalars.append(character); newline()
        case ":": result += ": "
        default:
            if result.last == "{" || result.last == "[" { newline() }
            result.unicodeScalars.append(character)
        }
    }
    return result
}

private final class ArgumentsSection: NSStackView {
    private let original: String
    private let formatted: String
    private let text: NSTextView
    init(_ arguments: String) {
        original = arguments; formatted = formattedArguments(arguments)
        let scroll = readOnlyText(formatted, label: L("完整工具参数"), language: "json")
        text = scroll.documentView as! NSTextView
        super.init(frame: .zero)
        orientation = .vertical; alignment = .leading; spacing = 8
        addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        let toggle = uiCheckbox(checkboxWithTitle: L("查看原文"), target: self, action: #selector(showOriginal(_:)))
        let copy = uiButton(title: L("复制原始参数"), target: self, action: #selector(copyOriginal))
        copy.bezelStyle = .rounded
        let controls = NSStackView(views: [toggle, copy]); controls.spacing = 14
        addArrangedSubview(controls)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    @objc private func showOriginal(_ sender: NSButton) {
        text.textStorage?.setAttributedString(highlightedCode(sender.state == .on ? original : formatted, language: "json"))
        text.enclosingScrollView?.needsLayout = true
        text.scrollRangeToVisible(NSRange(location: 0, length: 0))
    }
    @objc private func copyOriginal() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(original, forType: .string)
    }
}

final class QuestionWindow: NSWindowController, NSWindowDelegate {
    let request: NativeRequest
    private var editors: [QuestionEditor] = []
    private let status = wrapped("")
    private let submit = uiButton(title: L("提交全部回答"), target: nil, action: nil)
    private let clear = uiButton(title: L("清空回答"), target: nil, action: nil)
    private let desktop = uiButton(title: L("回到 DSH 会话"), target: nil, action: nil)
    private let allow = uiButton(title: L("允许一次"), target: nil, action: nil)
    private let deny = uiButton(title: L("拒绝"), target: nil, action: nil)
    private var navigating = false
    private var sending = false
    private var terminal = false
    private var transitioning = false
    private var unavailable = false
    var acceptsAnswers: Bool { !terminal }
    var hasDraft: Bool { editors.contains { $0.answered || !$0.input.string.isEmpty } }
    var onSubmit: ((Any) -> Void)?
    var onClose: (() -> Void)?
    init(_ request: NativeRequest) {
        self.request = request
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 700), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        UILocalization.bind(window, slot: "title") { $0.title = "DSH · " + request.displayTitle + (request.kind == "approval" ? L(" · 审批详情") : L(" · 问答")) }
        window.minSize = NSSize(width: 460, height: 400)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        let root = NSView()
        window.contentView = root
        let heading = NSStackView()
        heading.orientation = .vertical; heading.alignment = .leading; heading.spacing = 5
        for field in [request.sessionUntitled == true ? uiWrapped(L("未命名"), bold: true) : wrapped(request.displayTitle, bold: true), wrapped(request.cwd ?? "")] {
            heading.addArrangedSubview(field)
            field.widthAnchor.constraint(equalTo: heading.widthAnchor).isActive = true
        }
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let document = QuestionDocumentView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 24
        document.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        document.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -15),
        ])
        func addSection(_ view: NSView) {
            stack.addArrangedSubview(view)
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        func addGroup(_ views: [NSView]) {
            let group = NSStackView(views: views)
            group.orientation = .vertical; group.alignment = .leading; group.spacing = 8
            for child in views where !(child is NSButton) {
                child.widthAnchor.constraint(equalTo: group.widthAnchor).isActive = true
            }
            addSection(group)
        }
        if request.kind == "approval" {
            addSection(request.approval?.toolUnnamed == true ? uiWrapped(L("操作"), bold: true) : wrapped(request.approval?.toolName ?? request.body, bold: true))
            if let reason = request.approval?.reason { addSection(uiWrapped(L("请求原因\n{0}", ["0": reason]), markdown: true)) }
            if let command = request.approval?.command {
                let copy = uiButton(title: L("复制完整命令"), target: self, action: #selector(copyCommand))
                copy.bezelStyle = .rounded
                addGroup([uiWrapped(L("待执行命令"), bold: true), readOnlyText(command, label: L("完整待执行命令"), language: "shell"), copy])
            }
            if let arguments = request.approval?.arguments {
                addGroup([uiWrapped(L("完整工具参数（含权限与工作目录设置）"), bold: true), ArgumentsSection(arguments)])
            } else { addSection(uiWrapped(L("无法取得此请求的完整工具参数，请回到 DSH 核实后决定。"))) }
        }
        addSection(ContextSection(request))
        for (index, question) in (request.questions ?? []).enumerated() {
            let editor = QuestionEditor(question, number: index + 1)
            editor.changed = { [weak self] in self?.refresh() }
            editors.append(editor)
            stack.addArrangedSubview(editor.view)
            editor.view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        submit.target = self
        submit.action = #selector(send)
        submit.bezelStyle = .rounded
        desktop.target = self; desktop.action = #selector(openDesktop)
        desktop.bezelStyle = .rounded
        allow.target = self; allow.action = #selector(sendDecision(_:)); allow.bezelStyle = .rounded
        deny.target = self; deny.action = #selector(sendDecision(_:)); deny.bezelStyle = .rounded
        clear.target = self; clear.action = #selector(clearAnswers); clear.bezelStyle = .rounded
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let footer = NSStackView(views: request.kind == "approval" ? [desktop, deny, allow] : [clear, spacer, desktop, submit])
        footer.orientation = .horizontal
        for child in [heading, scroll, status, footer] {
            root.addSubview(child)
            child.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            heading.topAnchor.constraint(equalTo: root.topAnchor, constant: 18),
            heading.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            heading.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            scroll.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 15),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            scroll.bottomAnchor.constraint(equalTo: status.topAnchor, constant: -12),
            status.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            status.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            status.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -10),
            footer.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            footer.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -15),
        ])
        footer.leadingAnchor.constraint(greaterThanOrEqualTo: root.leadingAnchor, constant: 20).isActive = true
        if request.kind == "questions" { footer.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20).isActive = true }
        window.center()
        refresh()
        // A flipped document starts at its top-left. Scrolling to the document
        // height places the viewport beyond its content and can show a blank form.
        DispatchQueue.main.async {
            root.layoutSubtreeIfNeeded()
            scroll.contentView.scroll(to: .zero)
            scroll.reflectScrolledClipView(scroll.contentView)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    func windowWillClose(_ notification: Notification) { onClose?() }
    private func refresh() {
        guard !terminal && !sending else { return }
        if request.kind == "approval" {
            allow.isEnabled = !unavailable && !navigating; deny.isEnabled = !unavailable && !navigating
            if !navigating { uiSet(status, unavailable ? L("暂时无法连接 DSH，请恢复连接后处理。") : L("请核实命令、参数和权限后决定。"))}
            return
        }
        clear.isEnabled = !navigating && hasDraft
        let count = editors.filter { $0.answered }.count
        if !navigating { uiSet(status, unavailable ? L("暂时无法连接 DSH，已保留草稿。恢复连接后可继续。") : (transitioning ? L("DSH 正在将问题转入后台，请稍候…") : L("已回答 {0} / {1} · 每题至少选择一个选项或填写自定义答案", ["0": String(describing: count), "1": String(describing: editors.count)])))}
        submit.isEnabled = !unavailable && !transitioning && !navigating && !editors.isEmpty && count == editors.count
    }
    @objc private func clearAnswers() {
        guard clear.isEnabled, !sending, !terminal, !navigating else { return }
        editors.forEach { $0.clearAnswer() }
        refresh()
    }
    @objc private func send() {
        guard submit.isEnabled, !sending, !terminal, !navigating else { return }
        sending = true
        submit.isEnabled = false; clear.isEnabled = false
        editors.forEach { $0.setEnabled(false) }
        uiSet(status, L("正在提交，请稍候…"))
        onSubmit?(["answers": editors.map { $0.answer }])
    }
    @objc private func copyCommand() {
        guard let command = request.approval?.command else { return }
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(command, forType: .string)
    }
    @objc private func sendDecision(_ sender: NSButton) {
        guard sender.isEnabled, !sending, !terminal, !navigating else { return }
        sending = true; allow.isEnabled = false; deny.isEnabled = false
        uiSet(status, L("正在提交，请稍候…"))
        onSubmit?(sender === allow ? "allowed-once" : "rejected")
    }
    @objc private func openDesktop() {
        guard !navigating, let open = NotificationInteractions.shared.openSession else { return }
        navigating = true; desktop.isEnabled = false
        refresh()
        uiSet(status, L("正在打开目标 DSH 会话…"))
        open(request.sessionId) { [weak self] error in
            guard let self = self else { return }
            self.navigating = false; self.desktop.isEnabled = true
            self.refresh()
            if let error = error { uiSet(self.status, error)}
            else { self.close() }
        }
    }
    func finish(_ message: String, discardDraft: Bool = true) {
        let alreadyTerminal = terminal
        terminal = true
        // A later authoritative withdrawal also scrubs a result-unknown form.
        if discardDraft { editors.forEach { $0.clearAnswer() } }
        guard !alreadyTerminal else { return }
        sending = false
        submit.isEnabled = false; clear.isEnabled = false; allow.isEnabled = false; deny.isEnabled = false
        editors.forEach { $0.setEnabled(false) }
        uiSet(status, message)
    }
    func markSending() {
        guard !terminal else { return }
        sending = true; submit.isEnabled = false; clear.isEnabled = false; allow.isEnabled = false; deny.isEnabled = false
        editors.forEach { $0.setEnabled(false) }
        uiSet(status, L("正在提交，请稍候…"))
    }
    func failed(_ message: String) {
        guard !terminal else { return }
        sending = false
        editors.forEach { $0.setEnabled(true) }
        refresh()
        uiSet(status, message)
    }
    func setTransitioning(_ value: Bool) { guard transitioning != value else { return }; transitioning = value; refresh() }
    func setUnavailable(_ value: Bool) {
        guard unavailable != value else { return }
        unavailable = value
        if !terminal && !sending { editors.forEach { $0.setEnabled(!value) } }
        refresh()
    }
    func present() { showWindow(nil); NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil) }
}

final class NotificationInteractions {
    static let shared = NotificationInteractions()
    static let categoryApproval = "DSH_APPROVAL"
    static let categoryQuestions = "DSH_QUESTIONS"
    static let allow = "DSH_ALLOW_ONCE"
    static let deny = "DSH_DENY"
    static let answer = "DSH_ANSWER"
    static let details = "DSH_DETAILS"
    var openSession: ((String, @escaping (String?) -> Void) -> Void)?
    private var active: [String: NativeRequest] = [:]
    private var hostConnected = false
    private var seen = Set<String>()
    private var windows: [String: QuestionWindow] = [:]
    private var pendingCommands: [String: (NativeRequest, Date)] = [:]
    private var submitting = Set<String>()
    private var settled = Set<String>()
    private let directory: String
    private let centerOverride: UNUserNotificationCenter?
    private let usesSystemCenter: Bool
    private var center: UNUserNotificationCenter? { usesSystemCenter ? .current() : centerOverride }
    init(directory: String = stateDir) {
        self.directory = directory; self.centerOverride = nil; self.usesSystemCenter = true
    }
    init(directory: String, center: UNUserNotificationCenter?) {
        self.directory = directory; self.centerOverride = center; self.usesSystemCenter = false
    }
    func menuInteractions() -> [MenuInteraction] {
        active.values.filter { !settled.contains($0.id) && ["approval", "questions"].contains($0.kind) }.sorted { $0.id < $1.id }.map {
            let title: String
            if let approval = $0.approval {
                title = approval.displayToolName + " · " + (approval.command ?? approval.reason ?? (approval.toolUnnamed == true ? "" : $0.body))
            } else { title = $0.body.isEmpty ? $0.displayTitle : $0.body }
            return MenuInteraction(requestId: $0.id, sessionId: $0.sessionId, kind: $0.kind,
                title: String(title.split(whereSeparator: { $0.isNewline }).joined(separator: " ").prefix(100)),
                canSubmit: !submitting.contains($0.id) && $0.phase != "transitioning")
        }
    }
    func handleMenuInteraction(_ item: MenuInteraction, action: MenuInteractionAction) -> String? {
        // Resolve the current request again. Menu cells may outlive a Host answer.
        poll()
        guard !settled.contains(item.requestId), let request = active[item.requestId], request.sessionId == item.sessionId,
              request.kind == item.kind, (item.actions.contains(action) || (action == .details && item.kind == "approval")) else {
            return L("请求已回答或失效，请等待菜单刷新。")
        }
        if action == .allow || action == .deny {
            guard !submitting.contains(request.id) else { return L("此请求正在提交，请等待 DSH 确认。") }
            guard request.phase != "transitioning" else { return L("请求正在转入后台，请稍后重试。") }
            return submit(request, answer: action == .allow ? "allowed-once" : "rejected")
        } else { showQuestions(request) }
        return nil
    }
    func register() {
        center?.setNotificationCategories(Self.categories())
    }
    static func categories() -> Set<UNNotificationCategory> {
        var categories = Set<UNNotificationCategory>()
        // Locale-specific IDs keep delivered notification buttons in their
        // sending language. Keep old IDs for pre-upgrade notifications.
        for suffix in ["", ".en", ".zh"] {
            let locale = suffix.isEmpty ? "zh" : String(suffix.dropFirst())
            func copy(_ source: String) -> String { locale == "zh" ? source : uiEnglish[source] ?? source }
            categories.insert(UNNotificationCategory(identifier: categoryApproval + suffix, actions: [
                UNNotificationAction(identifier: allow, title: suffix.isEmpty ? "允许本次 (Allow)" : copy("允许一次"), options: []),
                UNNotificationAction(identifier: deny, title: suffix.isEmpty ? "拒绝 (Deny)" : copy("拒绝"), options: [.destructive]),
                UNNotificationAction(identifier: details, title: copy("查看详情"), options: [.foreground]),
            ], intentIdentifiers: [], options: []))
            categories.insert(UNNotificationCategory(identifier: categoryQuestions + suffix, actions: [
                UNNotificationAction(identifier: answer, title: copy("打开完整问答"), options: [.foreground]),
            ], intentIdentifiers: [], options: []))
        }
        return categories
    }
    static func content(_ request: NativeRequest) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = request.kind == "approval" ? L("请求批准") : L("需要回答 {0} 个问题", ["0": String(request.questions?.count ?? 0)])
        content.subtitle = request.displaySubtitle
        content.body = request.approval?.toolUnnamed == true ? L("操作") + (request.approval?.reason.map { "\n" + $0 } ?? "") : request.body
        content.categoryIdentifier = (request.kind == "approval" ? categoryApproval : categoryQuestions) + "." + UILocalization.language
        content.userInfo = ["interactionId": request.id, "sessionId": request.sessionId]
        return content
    }
    func poll() {
        let path = (self.directory as NSString).appendingPathComponent("interactions.json")
        var requests: [NativeRequest] = []
        var connected = false
        var preferences: [String: Bool] = [:]
        var quietSessionId: String?
        if let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size]) as? Int,
           size <= 4 * 1024 * 1024,
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let snapshot = try? JSONDecoder().decode(NativeSnapshot.self, from: data),
           snapshot.version == 1,
           abs(Date().timeIntervalSince1970 * 1000 - snapshot.updatedAt) < 5000 {
            requests = snapshot.requests
            preferences = snapshot.preferences ?? [:]
            quietSessionId = snapshot.quietSessionId
            connected = true
        }
        let next = Dictionary(requests.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for id in Set(active.keys).union(windows.keys) where next[id] == nil {
            center?.removeDeliveredNotifications(withIdentifiers: ["interaction-" + id])
            center?.removePendingNotificationRequests(withIdentifiers: ["interaction-" + id])
            if !connected {
                // Sleep/App Nap or transient I/O can age a snapshot without
                // settling its request. Pause safely, retaining the draft.
                windows[id]?.setUnavailable(true)
                seen.remove(id)
            } else if !submitting.contains(id) || windows[id]?.acceptsAnswers == false { windows[id]?.finish(L("此请求已在 DSH 回答、取消或失效，无需再次提交。")) }
        }
        hostConnected = connected
        active = next
        settled.formIntersection(Set(next.keys))
        for request in requests {
            windows[request.id]?.setUnavailable(false)
            windows[request.id]?.setTransitioning(request.phase == "transitioning")
        }
        for request in requests where !seen.contains(request.id) {
            if preferences[request.kind == "approval" ? "approval" : "questions"] != false && request.sessionId != quietSessionId { seen.insert(request.id); post(request) }
        }
        // Also clean notifications left by a previous helper process.
        center?.getDeliveredNotifications { [weak self] notices in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let ids = Set(self.active.keys.map { "interaction-" + $0 })
                let expired = notices.map { $0.request.identifier }.filter { $0.hasPrefix("interaction-") && !ids.contains($0) }
                self.center?.removeDeliveredNotifications(withIdentifiers: expired)
            }
        }
        for (commandId, (request, started)) in pendingCommands {
            let requestId = request.id
            let resultPath = (self.directory as NSString).appendingPathComponent("results/\(commandId).json")
            if let data = try? Data(contentsOf: URL(fileURLWithPath: resultPath)),
               let result = try? JSONDecoder().decode(CommandResult.self, from: data) {
                pendingCommands.removeValue(forKey: commandId)
                submitting.remove(requestId)
                if result.status == "accepted" || result.status == "stale" { settled.insert(requestId) }
                try? FileManager.default.removeItem(atPath: resultPath)
                logLine("interaction-result request=\(requestId) status=\(result.status)")
                if result.status == "accepted" { windows[requestId]?.finish(request.kind == "approval" ? L("决定已提交，DSH 已接受。") : L("已提交全部回答。")) }
                else if result.status == "stale" {
                    if let window = windows[requestId] { window.finish(L("请求已回答或失效，本次没有重复提交。")) }
                    else { resultNotice(request, message: L("请求已回答或失效，本次没有重复提交。")) }
                } else if result.status == "waiting" { windows[requestId]?.failed(L("问题正在转入后台，请稍后提交。")) }
                else { reportFailure(request, message: L("提交未成功（{0}），请检查回答或回到 DSH。", ["0": String(describing: result.status)]), retryable: true) }
            } else if Date().timeIntervalSince(started) > 15 {
                pendingCommands.removeValue(forKey: commandId)
                // Do not auto-retry a command whose Host result is unknown.
                reportFailure(request, message: L("未收到确认，请回到 DSH 核实结果。本助手不会自动重试。"), retryable: false)
                logLine("interaction-result-timeout request=\(requestId)")
            }
        }
        // Closed forms may retain unsent answers, but never retain a settled
        // request after a fresh Host withdrawal or a submission result.
        for (id, window) in windows where !window.acceptsAnswers && window.window?.isVisible != true {
            windows.removeValue(forKey: id)
        }
        writePanelLease()
    }
    private func post(_ request: NativeRequest) {
        let content = Self.content(request)
        content.sound = nativePreferences()["sound"] == false ? nil : .default
        center?.add(UNNotificationRequest(identifier: "interaction-" + request.id, content: content, trigger: nil)) { error in
            logLine(error.map { "interaction-post-failed \($0.localizedDescription)" } ?? "interaction-posted request=\(request.id) kind=\(request.kind)")
        }
    }
    func handle(id: String, action: String) {
        poll()
        guard let request = active[id] else {
            if !hostConnected, let cached = windows[id], cached.acceptsAnswers {
                cached.present()
                return
            }
            windows[id]?.finish(L("请求已回答或失效。"))
            logLine("interaction-click-stale request=\(id)")
            return
        }
        if action == Self.allow || action == Self.deny {
            submit(request, answer: action == Self.allow ? "allowed-once" : "rejected")
        } else { showQuestions(request) }
    }
    func showQuestions(_ request: NativeRequest) {
        if let existing = windows[request.id] { existing.present(); return }
        let controller = QuestionWindow(request)
        controller.onSubmit = { [weak self] answer in self?.submit(request, answer: answer) }
        controller.onClose = { [weak self, weak controller] in
            guard let self = self, let controller = controller else { return }
            // Closing is not canceling the Host request. Keep its original
            // controls and drafts in memory until the request settles.
            if request.kind != "questions" || !controller.acceptsAnswers || !controller.hasDraft {
                self.windows.removeValue(forKey: request.id)
            }
            self.writePanelLease(excludingVisible: request.id)
        }
        windows[request.id] = controller
        controller.setTransitioning(request.phase == "transitioning")
        if submitting.contains(request.id) { controller.markSending() }
        controller.present()
        writePanelLease()
    }
    private func writePanelLease(excludingVisible: String? = nil) {
        let ids = windows.filter {
            $0.key != excludingVisible && $0.value.request.kind == "questions" && $0.value.acceptsAnswers &&
                $0.value.window?.isVisible == true
        }.map { $0.key }
        let draftIds = windows.filter {
            $0.value.request.kind == "questions" && $0.value.acceptsAnswers && $0.value.hasDraft
        }.map { $0.key }
        let path = (self.directory as NSString).appendingPathComponent("open-panels.json")
        if let data = try? JSONSerialization.data(withJSONObject: ["updatedAt": Date().timeIntervalSince1970 * 1000, "ids": ids, "draftIds": draftIds]) {
            try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        }
    }
    @discardableResult private func submit(_ request: NativeRequest, answer: Any) -> String? {
        guard !submitting.contains(request.id) else { return L("此请求正在提交，请等待 DSH 确认。") }
        guard !settled.contains(request.id), active[request.id] != nil else {
            windows[request.id]?.finish(L("请求已提交或失效。"))
            return L("请求已提交或失效。")
        }
        let commandId = UUID().uuidString
        let directory = (self.directory as NSString).appendingPathComponent("commands")
        do {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let data = try JSONSerialization.data(withJSONObject: ["commandId": commandId, "requestId": request.id, "answer": answer])
            let path = (directory as NSString).appendingPathComponent(commandId + ".json")
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
            submitting.insert(request.id)
            windows[request.id]?.markSending()
            pendingCommands[commandId] = (request, Date())
            logLine("interaction-submitted request=\(request.id)")
            return nil
        } catch {
            let message = L("无法提交：{0}。请回到 DSH 处理。", ["0": String(describing: error.localizedDescription)])
            reportFailure(request, message: message, retryable: true)
            logLine("interaction-submit-failed \(error.localizedDescription)")
            return message
        }
    }
    private func reportFailure(_ request: NativeRequest, message: String, retryable: Bool) {
        if let window = windows[request.id] {
            if retryable { window.failed(message) } else { window.finish(message, discardDraft: false) }
        } else { resultNotice(request, message: message) }
    }
    private func resultNotice(_ request: NativeRequest, message: String) {
        let content = UNMutableNotificationContent()
        content.title = L("DSH · 请求处理提示")
        content.subtitle = request.displaySubtitle
        content.body = message
        var components = URLComponents(string: "http://127.0.0.1:3080/")!
        components.queryItems = [URLQueryItem(name: "session", value: request.sessionId)]
        content.userInfo = ["url": components.url!.absoluteString]
        center?.add(UNNotificationRequest(identifier: "dsh-result-" + UUID().uuidString, content: content, trigger: nil)) { error in
            if let error = error { logLine("interaction-result-notice-failed \(error.localizedDescription)") }
        }
    }
}

func uiWrapped(_ text:String,bold:Bool=false,markdown:Bool=false)->NSTextField {
 let field=wrapped(text,bold:bold,markdown:markdown),render=UILocalization.translated(text)
 UILocalization.bind(field,slot:"text") { value in
  if markdown {value.attributedStringValue=renderedMarkdown(render(),bold:bold)} else {value.stringValue=render()}
 }
 return field
}

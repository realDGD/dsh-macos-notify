// DSH Notify — native macOS interactive notification helper.
import Cocoa
import UserNotifications

// MARK: - 路径与日志

/// Chrome 的 bundle id —— **注意是大写的 C**（`com.google.Chrome`）。
///
/// 这个大小写极容易踩：`NSWorkspace.urlForApplication` 的查找**不区分**大小写，所以写成
/// 小写照样能打开 Chrome，问题不会暴露；但 `NSRunningApplication.runningApplications`
/// 是**精确匹配**的，小写会返回空数组。实测后果：标签页复用静默失效、连"补激活"也一起失效，
/// 而且因为提前 return 没打日志，表现成"点了什么都没发生"。
let chromeBundleID = "com.google.Chrome"
let desktopBundleID = "com.deepseek.dsh"

let dshHome = ProcessInfo.processInfo.environment["DSH_HOME"] ?? (NSHomeDirectory() as NSString).appendingPathComponent(".dsh")
let stateDir = (dshHome as NSString).appendingPathComponent("dsh-jump")
let pendingPath = (stateDir as NSString).appendingPathComponent("pending.txt")
let logPath = (stateDir as NSString).appendingPathComponent("applet.log")

/// 追加一行日志。日志失败绝不能影响通知功能本身。
func logLine(_ message: String) {
    let stamp = ISO8601DateFormatter().string(from: Date())
    guard let data = "[\(stamp)] \(message)\n".data(using: .utf8) else { return }
    let manager = FileManager.default
    if !manager.fileExists(atPath: logPath) {
        manager.createFile(atPath: logPath, contents: data)
        return
    }
    guard let handle = FileHandle(forWritingAtPath: logPath) else { return }
    defer { try? handle.close() }
    do {
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    } catch {
        // 忽略：日志不是关键路径
    }
}

// MARK: - 任务负载

/// pending.txt 支持两种格式：
///   1. 纯 URL（方便手工测试：`printf '%s' '<url>' > pending.txt`）
///   2. JSON `{"url","title","subtitle","body"}`（Bridge 用这种）
///
/// 三段式对应 macOS 通知的三行：
///   title    = 事件类型（"✅ 任务完成"）—— 放最前，扫一眼就知道要不要现在处理
///   subtitle = 哪个会话（"dsh 通知功能咨询 · DSH"）
///   body     = 会话内容（最后一轮的回复摘要）
struct Payload {
    let url: String
    let title: String
    let subtitle: String
    let body: String

    static let defaultTitle = "DSH Harness"
    static let defaultSubtitle = ""
    static let defaultBody = "任务完成 — 点我回到会话"
}

/// 解析 pending.txt 内容。非法（含写了一半）返回 nil，调用方会等待重试。
func parsePayload(_ raw: String) -> Payload? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    func isHttp(_ value: String) -> Bool {
        value.hasPrefix("http://") || value.hasPrefix("https://")
    }

    /// 空串视为"没给"，回退到默认值。
    func field(_ key: String, in object: [String: Any], fallback: String) -> String {
        (object[key] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallback
    }

    if trimmed.hasPrefix("{") {
        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let url = object["url"] as? String,
              isHttp(url)
        else { return nil }
        return Payload(
            url: url,
            title: field("title", in: object, fallback: Payload.defaultTitle),
            subtitle: field("subtitle", in: object, fallback: Payload.defaultSubtitle),
            body: field("body", in: object, fallback: Payload.defaultBody)
        )
    }

    guard isHttp(trimmed) else { return nil }
    return Payload(
        url: trimmed,
        title: Payload.defaultTitle,
        subtitle: Payload.defaultSubtitle,
        body: Payload.defaultBody
    )
}

// MARK: - 通知助手

final class Notifier: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    /// 连续多少次读到非法 pending 内容才丢弃（防止半截写入导致死循环）。
    private var invalidTicks = 0
    /// 超过这个年龄的 pending 直接丢弃：陈旧任务不该在很久以后突然弹出来。
    private let staleSeconds: TimeInterval = 600
    private var pumpTimer: Timer?
    private let jumpWaiter = DesktopJumpWaiter(directory: stateDir)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessory apps have no default Edit menu. Install standard responder
        // commands so multiline fields support Cmd+C/V/A and undo normally.
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "DSH Notify")
        appMenu.addItem(withTitle: "关闭问答窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "编辑")
        edit.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        menu.addItem(editItem)
        NSApp.mainMenu = menu
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        NotificationInteractions.shared.register()
        NotificationInteractions.shared.openSession = { [weak self] id, completion in
            var components = URLComponents(string: "http://127.0.0.1:3080/")!
            components.queryItems = [URLQueryItem(name: "session", value: id)]
            guard let self = self, let url = components.url,
                  self.openInDesktop(url, completion: completion) else {
                completion("无法打开 DSH Desktop，窗口已保留。")
                return
            }
        }
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            var line = "auth granted=\(granted)"
            if let error = error { line += " error=\(error.localizedDescription)" }
            logLine(line)
        }

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pump()
            NotificationInteractions.shared.poll()
            self?.jumpWaiter.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        pumpTimer = timer

        logLine("started pid=\(ProcessInfo.processInfo.processIdentifier)")
        pump()
        NotificationInteractions.shared.poll()
        // Read-only presentation hook for isolated native form validation.
        if let index = CommandLine.arguments.firstIndex(of: "--question-panel"), CommandLine.arguments.count > index + 1 {
            NotificationInteractions.shared.handle(id: CommandLine.arguments[index + 1], action: NotificationInteractions.answer)
        }
    }

    // MARK: 状态文件 → 通知

    /// 消费 pending.txt：出现合法任务就投递一条通知。
    private func pump() {
        writeHeartbeat()
        let queue = (stateDir as NSString).appendingPathComponent("notifications")
        let manager = FileManager.default
        if let files = try? manager.contentsOfDirectory(atPath: queue) {
            for name in files.sorted().prefix(64) where name.hasSuffix(".json") {
                let path = (queue as NSString).appendingPathComponent(name)
                guard let attrs = try? manager.attributesOfItem(atPath: path),
                      let size = attrs[.size] as? Int, size <= 16384,
                      let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                      let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                      let createdAt = object["createdAt"] as? Double,
                      abs(Date().timeIntervalSince1970 * 1000 - createdAt) < 120000,
                      let raw = String(data: data, encoding: .utf8), let payload = parsePayload(raw) else {
                    try? manager.removeItem(atPath: path); continue
                }
                try? manager.removeItem(atPath: path)
                post(payload)
            }
        }
        guard FileManager.default.fileExists(atPath: pendingPath) else { return }

        // 过期保护：写入后助手长时间没在跑（例如 app 被删过一阵）留下的陈旧任务，
        // 不该在很久以后突然弹出来。
        if let attributes = try? FileManager.default.attributesOfItem(atPath: pendingPath),
           let modified = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) > staleSeconds {
            try? FileManager.default.removeItem(atPath: pendingPath)
            logLine("dropped-stale age=\(Int(Date().timeIntervalSince(modified)))s")
            return
        }

        guard let raw = try? String(contentsOfFile: pendingPath, encoding: .utf8) else { return }

        guard let payload = parsePayload(raw) else {
            // 可能是写入到一半：先等，连续多次仍非法才丢弃。
            invalidTicks += 1
            if invalidTicks > 10 {
                try? FileManager.default.removeItem(atPath: pendingPath)
                logLine("dropped-invalid after \(invalidTicks) ticks")
                invalidTicks = 0
            }
            return
        }
        invalidTicks = 0
        try? FileManager.default.removeItem(atPath: pendingPath)
        post(payload)
    }

    private func writeHeartbeat() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let permission: String
            switch settings.authorizationStatus {
            case .authorized: permission = "authorized"
            case .denied: permission = "denied"
            case .notDetermined: permission = "notDetermined"
            case .provisional: permission = "provisional"
            default: permission = "unknown"
            }
            let value: [String: Any] = ["version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0",
                "pid": ProcessInfo.processInfo.processIdentifier, "updatedAt": Date().timeIntervalSince1970 * 1000, "permission": permission]
            let path = (stateDir as NSString).appendingPathComponent("helper-status.json")
            do {
                try FileManager.default.createDirectory(atPath: stateDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                try JSONSerialization.data(withJSONObject: value).write(to: URL(fileURLWithPath: path), options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
            } catch { }
        }
    }
    private func post(_ payload: Payload) {
        let content = UNMutableNotificationContent()
        content.title = payload.title
        if !payload.subtitle.isEmpty { content.subtitle = payload.subtitle }
        content.body = payload.body
        content.sound = nativePreferences()["sound"] == false ? nil : .default
        content.userInfo = ["url": payload.url]

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                logLine("post-failed \(error.localizedDescription)")
            } else {
                logLine("posted \(payload.url)")

            }
        }
    }

    // MARK: UNUserNotificationCenterDelegate

    /// 即使本 app 在前台也显示横幅（agent 应用很少在前台，但保持行为一致）。
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// 点击回调——这就是 AppleScript applet 做不到的那一步。
    ///
    /// 时序很重要：**必须先把点击交还给系统，再去做启动 Chrome 这种重活。**
    /// `NSWorkspace.open` 会阻塞主 run loop（LaunchServices 握手），若在点击回调里同步
    /// 执行，通知面板的退场与**鼠标按键的抬起**都被拖到后面处理。实测症状：跳转之后
    /// 整个网页"点什么都得点两次"——第一次被窗口激活/按键状态吃掉。
    /// 所以这里立刻 completionHandler()，再用小延迟把工作挪到下一个 run loop 周期。
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        logLine("clicked action=\(response.actionIdentifier)")
        let info = response.notification.request.content.userInfo
        let urlString = info["url"] as? String

        // 先把点击交还系统：让通知面板完成退场、让鼠标按键抬起。
        completionHandler()

        if response.actionIdentifier == UNNotificationDismissActionIdentifier { return }
        if let id = info["interactionId"] as? String {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NotificationInteractions.shared.handle(id: id, action: response.actionIdentifier)
            }
            return
        }

        guard let urlString = urlString, let url = URL(string: urlString) else {
            logLine("clicked-no-url")
            return
        }
        logLine("jumping:\(urlString)")
        // 记录点击瞬间的激活状态：点通知会把"通知的属主"（= 本助手）激活，而助手是
        // 零窗口的 agent，没人接手 key 状态——这正是窗口级焦点出问题的温床。
        let front = NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
        logLine("pre-open state: helperActive=\(NSApp.isActive) frontmost=\(front)")

        // 让出一个 run loop 周期再动手，别和通知系统的收尾抢主线程。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.jump(to: url)
        }
    }

    // MARK: 跳转

    /// 跳转的统一入口。
    ///
    /// 优先**复用已有的 DSH 标签页**，而不是每次新开一个。这不只是"少几个标签页"的问题：
    /// DSH 把"当前会话"持久化在 **localStorage**，而同源标签页**共享** localStorage ——
    /// 多个 DSH 标签页各自的跳转会互相覆盖这个键。实测症状：两条推送间隔过密时，
    /// 页面会退回"只显示工作区、不显示会话"。
    private func jump(to url: URL) {
        // 交出助手自己的激活态（点通知时系统会把属主激活，而属主是零窗口 agent，
        // 没有任何窗口能接手 key 状态）。
        if NSApp.isActive {
            if #available(macOS 14.0, *) {
                NSApp.deactivate()
                logLine("helper-deactivated (returned activation to the system)")
            }
        }
        if openInDesktop(url) { return }
        if reuseDSHTab(url) { return }
        openInChrome(url)
    }

    /// Keep the clicked notification's own session ID, including old Web links.
    /// Desktop 0.2.0-rc.2 accepts only dsh://open; the plugin performs selection.
    private func openInDesktop(_ url: URL, completion: ((String?) -> Void)? = nil) -> Bool {
        guard let host = url.host,
              ["127.0.0.1", "localhost", "::1", "[::1]"].contains(host),
              ["http", "https"].contains(url.scheme ?? ""),
              let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                .first(where: { $0.name == "session" })?.value,
              id.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]{0,199}$", options: .regularExpression) != nil,
              let desktop = NSWorkspace.shared.urlForApplication(withBundleIdentifier: desktopBundleID)
        else { return false }

        let requestId = UUID().uuidString
        let createdAt = Date().timeIntervalSince1970 * 1000
        let request: [String: Any] = [
            "requestId": requestId, "sessionId": id,
            "createdAt": createdAt,
        ]
        do {
            try FileManager.default.createDirectory(atPath: stateDir, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            let data = try JSONSerialization.data(withJSONObject: request)
            let path = (stateDir as NSString).appendingPathComponent("open-session.json")
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        } catch {
            logLine("desktop-request-failed \(error.localizedDescription)")
            completion?("无法保存跳转请求，窗口已保留：\(error.localizedDescription)")
            return true
        }
        if let completion = completion {
            jumpWaiter.wait(requestId: requestId, sessionId: id, createdAt: createdAt, completion: completion)
        }
        logLine("desktop-request request=\(requestId) session=\(id)")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false
        NSWorkspace.shared.open([URL(string: "dsh://open")!], withApplicationAt: desktop,
            configuration: configuration) { [weak self] app, error in
            if let error = error {
                logLine("desktop-open-failed \(error.localizedDescription)")
                DispatchQueue.main.async { self?.jumpWaiter.fail(requestId: requestId, message: "DSH Desktop 打开失败，窗口已保留：\(error.localizedDescription)") }
            } else {
                logLine("opened-desktop \(app?.bundleIdentifier ?? desktopBundleID) session=\(id)")
            }
        }
        return true
    }

    /// 把**已有的** DSH 标签页导航到目标 URL 并激活它。
    ///
    /// 复用失败一律返回 false，由调用方回退到"新开标签页"——没有授权、Chrome 没运行、
    /// 或者一个 DSH 标签页都没有时，都走这条路。跳转本身永远不能因为复用失败而失败。
    ///
    /// 需要一个一次性的 macOS 授权（"DSH Jump"想要控制"Google Chrome"）；拒绝之后
    /// 系统不会反复弹窗，助手就永久走"新开标签页"的老路，功能不受影响。
    private func reuseDSHTab(_ url: URL) -> Bool {
        // 每一条提前返回都要留下日志。这一课是踩出来的：bundle id 写错大小写时，
        // 这里静默 return false，日志里一行都没有，表现成"点了什么都没发生"，
        // 排查时完全看不出是复用环节出的问题。
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: chromeBundleID)
        guard !running.isEmpty else {
            logLine("tab-reuse-skip: Chrome 未运行")
            return false
        }
        guard let scheme = url.scheme, let host = url.host else {
            logLine("tab-reuse-skip: URL 缺少 scheme/host (\(url.absoluteString))")
            return false
        }
        var origin = "\(scheme)://\(host)"
        if let port = url.port { origin += ":\(port)" }

        let target = url.absoluteString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "Google Chrome"
          set targetURL to "\(target)"
          repeat with w in windows
            set i to 0
            repeat with t in tabs of w
              set i to i + 1
              if (URL of t) starts with "\(origin)" then
                set URL of t to targetURL
                set active tab index of w to i
                set index of w to 1
                activate
                return "reused"
              end if
            end repeat
          end repeat
          return "none"
        end tell
        """

        guard let script = NSAppleScript(source: source) else {
            logLine("tab-reuse-skip: AppleScript 编译失败")
            return false
        }
        var errorInfo: NSDictionary?
        let started = Date()
        let result = script.executeAndReturnError(&errorInfo)
        let elapsed = Int(Date().timeIntervalSince(started) * 1000)
        if let errorInfo = errorInfo {
            // 未授权 / 超时 / 脚本错误都走这里：记一笔，然后回退到新开标签页。
            let message = (errorInfo[NSAppleScript.errorMessage] as? String) ?? "unknown"
            let code = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? 0
            logLine("tab-reuse-unavailable code=\(code) msg=\(message) (\(elapsed)ms)")
            return false
        }
        let verdict = result.stringValue ?? ""
        logLine("tab-reuse \(verdict) (\(elapsed)ms)")
        return verdict == "reused"
    }

    // MARK: 打开

    /// 兜底路径：**新开**一个 Chrome 标签页打开 URL（没装 Chrome 则退回默认浏览器）。
    /// 显式指定 Chrome 也顺手修掉了"系统默认浏览器是 Safari 时跳到 Safari"的问题。
    ///
    /// 只在 `reuseDSHTab` 没能复用时才走到这里。这里多花一点力气补激活，是因为
    /// "新开标签页"这条路上窗口的焦点最容易被通知面板的退场吃掉：
    /// 通知面板退场、窗口就绪都有延迟，单次激活会被吞，所以连续补几次。
    private func openInChrome(_ url: URL) {
        guard let chrome = NSWorkspace.shared.urlForApplication(withBundleIdentifier: chromeBundleID) else {
            NSWorkspace.shared.open(url)
            logLine("opened-default (chrome not found)")
            return
        }

        // 注意：助手激活态已在 jump(to:) 里交还，这里不用重复做。

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false
        NSWorkspace.shared.open([url], withApplicationAt: chrome, configuration: configuration) { app, error in
            if let error = error {
                logLine("chrome-open-failed \(error.localizedDescription) → fallback")
                NSWorkspace.shared.open(url)
                return
            }
            self.activateChrome(attempt: 1)
            logLine("opened-chrome \(app?.bundleIdentifier ?? "com.google.Chrome") active=\(app?.isActive ?? false)")
        }
    }

    /// 连续补激活：通知面板退场与窗口就绪都有延迟，一次激活常常被吃掉。
    /// 每次都记日志，便于事后判断到底第几次才成功。
    private func activateChrome(attempt: Int) {
        guard let chrome = NSRunningApplication
            .runningApplications(withBundleIdentifier: chromeBundleID).first else {
            logLine("activate-skip: 找不到运行中的 Chrome 进程")
            return
        }
        chrome.activate(options: [.activateAllWindows])
        if attempt >= 6 { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self else { return }
            // 已经稳定在前台就收手，别和用户的操作抢焦点。
            if chrome.isActive && attempt >= 3 { return }
            self.activateChrome(attempt: attempt + 1)
        }
    }
}

// MARK: - 入口

let application = NSApplication.shared
let notifier = Notifier()
application.delegate = notifier
application.setActivationPolicy(.accessory) // agent：不进 Dock、不抢焦点
application.run()

import Cocoa
import UserNotifications
import WebKit
let stateDir = NSTemporaryDirectory()
func logLine(_ message: String) {}
@main @MainActor
struct NativeMarkdownContextTests {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let source = #"""
        ## 表格与公式
        | 参数 | 内容 |
        | --- | --- |
        | **命令** | `echo 中文` |
        | 长字段 | LONG_TOKEN |

        行内 $E=mc^2$ 与 \(x_1\)。
        $$
        \frac{a}{b}
        $$
        \[\sum_{i=1}^{n}i\]

        ```shell
        echo "中文"
        ```
        <script>window.pwned=true</script>
        ![不要联网](https://example.com/tracker)
        [本地文件](file:///tmp/context-private)
        """#.replacingOccurrences(of: "LONG_TOKEN", with: String(repeating: "长字段abcdef", count: 120))
        let question = NativeQuestion(id: "q1", question: "请选择", header: nil, detail: nil, options: [NativeOption(label: "原始选项", description: nil)], multiSelect: false)
        let request = NativeRequest(id: "md-test", kind: "questions", sessionId: "test", title: "测试", subtitle: "上下文测试", body: "", questions: [question], phase: "foreground", context: [NativeContext(role: "user", text: source, truncated: false)])
        let controller = QuestionWindow(request)
        let window = controller.window!
        window.setContentSize(NSSize(width: 460, height: 600))
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        guard !descendants(window.contentView!).contains(where: { $0 is MarkdownContextView }) else { print("FAIL renderer was created before disclosure opened"); exit(1) }
        let toggle = descendants(window.contentView!).compactMap { $0 as? NSButton }.first { $0.title == "查看相关上下文与会话信息" }!
        toggle.performClick(nil)
        let view = descendants(window.contentView!).compactMap { $0 as? MarkdownContextView }.first!
        window.contentView!.layoutSubtreeIfNeeded()
        view.onRendered = { error in
            guard error == nil else { print("FAIL WebKit renderer: \(error!)"); exit(1) }
            view.webView.callAsyncJavaScript("""
                await document.fonts.load('13px KaTeX_Main');
                await document.fonts.ready;
                return {
                  tables: document.querySelectorAll('table').length,
                  math: document.querySelectorAll('.katex').length,
                  image: document.querySelectorAll('img').length,
                  script: typeof window.pwned,
                  overflow: document.documentElement.scrollWidth > innerWidth + 1,
                  syntax: document.querySelectorAll('.syntax-keyword').length,
                  fonts: document.fonts.check('13px KaTeX_Main'),
                  external: performance.getEntriesByType('resource').some(x => !x.name.startsWith('file:')),
                  loadedFonts: Array.from(document.fonts).filter(x => x.status === 'loaded').length,
                  height: document.getElementById('context').getBoundingClientRect().height,
                  localLink: !!document.querySelector('a[href^="file:"]')
                }
                """, arguments: [:], in: nil, in: .page) { result in
                guard case .success(let value) = result, let metrics = value as? [String: Any],
                      metrics["tables"] as? Int == 1, metrics["math"] as? Int == 4,
                      metrics["image"] as? Int == 0, metrics["script"] as? String == "undefined",
                      metrics["overflow"] as? Bool == false, (metrics["syntax"] as? Int ?? 0) > 0,
                      metrics["external"] as? Bool == false, (metrics["loadedFonts"] as? Int ?? 0) > 0,
                      metrics["fonts"] as? Bool == true, metrics["localLink"] as? Bool == false,
                      (metrics["height"] as? Double ?? 0) > 500 else { print("FAIL offline WebKit layout: \(result)"); exit(1) }
                print("PASS actual WebKit tables, 4 math delimiters, fonts, code, long cell wrapping, no external resources: \(metrics)")
                // Programmatic external navigation has no permission to leave
                // the view or open a browser. Verify the document is retained.
                view.webView.evaluateJavaScript("location.href='https://example.com/not-allowed'") { _, _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        if view.webView.url != view.documentURL { print("FAIL programmatic navigation escaped context"); exit(1) }
                        window.contentView!.layoutSubtreeIfNeeded()
                        if view.frame.width <= 0 || view.frame.height > 481 || view.frame.height < 60 { print("FAIL context pane has invalid native geometry: \(view.frame)"); exit(1) }
                        print("PASS lazy context disclosure and bounded scrollable native pane: \(view.frame)")
                        print("PASS programmatic external navigation blocked")
                        withExtendedLifetime(window) { exit(0) }
                    }
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) { print("FAIL WebKit render timed out"); exit(1) }
        app.run()
    }
}

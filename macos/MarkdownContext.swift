import Cocoa
import WebKit

private final class ContextHeightHandler: NSObject, WKScriptMessageHandler {
    weak var owner: MarkdownContextView?
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, message.frameInfo.request.url == owner?.documentURL,
              let value = message.body as? Double, value.isFinite else { return }
        owner?.updateHeight(value)
    }
}

// Only this read-only context view uses WebKit. Decisions and answer inputs
// remain native, and the renderer has no access to Host/approval capabilities.
final class MarkdownContextView: NSView, WKNavigationDelegate {
    let webView: WKWebView
    let documentURL: URL
    private let items: [NativeContext]
    private var height: NSLayoutConstraint!
    var onRendered: ((Error?) -> Void)?

    static var assetsURL: URL {
        let bundled = Bundle.main.resourceURL?.appendingPathComponent("renderer", isDirectory: true)
        if let bundled, FileManager.default.fileExists(atPath: bundled.appendingPathComponent("context.html").path) { return bundled }
        // Source-linked native tests run without an application bundle.
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("assets", isDirectory: true)
    }
    init(_ items: [NativeContext]) {
        self.items = items
        documentURL = Self.assetsURL.appendingPathComponent("context.html")
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let handler = ContextHeightHandler()
        configuration.userContentController.add(handler, name: "contextHeight")
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: .zero)
        handler.owner = self
        webView.navigationDelegate = self
        webView.underPageBackgroundColor = .windowBackgroundColor
        webView.setAccessibilityLabel("相关上下文 Markdown")
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
        height = heightAnchor.constraint(equalToConstant: 100)
        NSLayoutConstraint.activate([
            height, webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor), webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    private var started = false
    func load() {
        guard !started else { return }; started = true
        guard FileManager.default.fileExists(atPath: documentURL.path) else { fallback(nil); return }
        webView.loadFileURL(documentURL, allowingReadAccessTo: Self.assetsURL)
    }
    fileprivate func updateHeight(_ value: Double) {
        // Long context remains fully scrollable inside this bounded read-only
        // pane; short context does not create a large empty area in the form.
        let next = CGFloat(min(480, max(60, ceil(value))))
        if abs(height.constant - next) > 1 { height.constant = next }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView.url == documentURL else { return }
        do {
            let data = try JSONEncoder().encode(items)
            let json = String(decoding: data, as: UTF8.self)
                .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
                .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
            // JSON is an expression supplied by native code, not HTML/template
            // interpolation. Quotes, slashes and user text stay data.
            webView.evaluateJavaScript("window.renderContext(\(json))") { [weak self] _, error in
                if let error { self?.fallback(error) } else { self?.onRendered?(nil) }
            }
        } catch { fallback(error) }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fallback(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fallback(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { fallback(nil) }
    private func fallback(_ error: Error?) {
        guard webView.superview != nil else { return }
        webView.removeFromSuperview()
        let source = "Markdown 显示暂不可用，以下为原文：\n\n" + items.map {
            ($0.role == "user" ? "你的请求" : "助手说明") + "\n" + $0.text
                + ($0.truncated == true ? "\n（较长内容显示前 20,000 字符，请回到 DSH 阅读全文。）" : "")
        }.joined(separator: "\n\n")
        let scroll = readOnlyText(source, label: "上下文原文", language: "text")
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll); height.constant = 180
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor), scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor), scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        onRendered?(error ?? NSError(domain: "DSHNotifyRenderer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Renderer unavailable; original context retained"]))
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        if action.navigationType == .other, action.targetFrame?.isMainFrame == true, url == documentURL {
            decisionHandler(.allow); return
        }
        if action.navigationType == .linkActivated, ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
            NSWorkspace.shared.open(url)
        }
        decisionHandler(.cancel)
    }
}

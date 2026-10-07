import Foundation

struct Payload {
    let url: String
    let title: String
    let subtitle: String
    let body: String
    let testId: String?

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
            body: field("body", in: object, fallback: Payload.defaultBody),
            testId: object["kind"] as? String == "test" ? (object["id"] as? String).flatMap { UUID(uuidString: $0) == nil ? nil : $0 } : nil
        )
    }

    guard isHttp(trimmed) else { return nil }
    return Payload(
        url: trimmed,
        title: Payload.defaultTitle,
        subtitle: Payload.defaultSubtitle,
        body: Payload.defaultBody,
        testId: nil
    )
}

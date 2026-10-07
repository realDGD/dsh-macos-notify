import Foundation

func recordTestDelivery(directory: String, id: String, accepted: Bool, at now: Double = Date().timeIntervalSince1970 * 1000) {
    guard UUID(uuidString: id) != nil else { return }
    let manager = FileManager.default
    let folder = URL(fileURLWithPath: directory).appendingPathComponent("test-delivery", isDirectory: true)
    do {
        try manager.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let value: [String: Any] = ["id": id, "state": accepted ? "posted" : "failed", "updatedAt": now]
        let path = folder.appendingPathComponent(id + ".json")
        try JSONSerialization.data(withJSONObject: value).write(to: path, options: .atomic)
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
        func modified(_ url: URL) -> Date { (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast }
        let own = try manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter { $0.pathExtension == "json" && UUID(uuidString: $0.deletingPathExtension().lastPathComponent) != nil }
            .sorted { modified($0) < modified($1) }
        for old in own.prefix(max(0, own.count - 32)) { try? manager.removeItem(at: old) }
    } catch { /* Diagnostic failure must never interfere with a notification. */ }
}

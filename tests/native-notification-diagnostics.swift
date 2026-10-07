import Foundation
@main struct NativeNotificationDiagnosticsTests {
    static func main() throws {
        func check(_ value: Bool, _ message: String) { if !value { print("FAIL " + message); exit(1) } }
        let id = UUID().uuidString
        func payload(_ kind: String = "test", _ value: String = id) -> Payload? {
            let object = ["id": value, "kind": kind, "url": "http://localhost/?session=test", "title": "安全测试", "body": "原始正文"]
            return parsePayload(String(data: try! JSONSerialization.data(withJSONObject: object), encoding: .utf8)!)
        }
        check(payload()?.testId == id, "test identity was discarded")
        check(payload()?.body == "原始正文", "body changed")
        check(payload("completed")?.testId == nil, "ordinary reminder marked as test")
        check(payload("test", "../outside")?.testId == nil, "unsafe identity retained")
        check(parsePayload("http://localhost/?session=test")?.testId == nil, "legacy URL marked as test")
        check(parsePayload("{broken") == nil, "partial JSON accepted")
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent("dsh-diagnostics-" + UUID().uuidString)
        defer { try? manager.removeItem(at: directory) }
        recordTestDelivery(directory: directory.path, id: id, accepted: true, at: 123)
        let folder = directory.appendingPathComponent("test-delivery")
        let file = folder.appendingPathComponent(id + ".json")
        func receipt() throws -> [String: Any] { try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any] }
        check(try receipt()["state"] as? String == "posted", "accepted delivery not recorded")
        check((try manager.attributesOfItem(atPath: folder.path)[.posixPermissions] as? NSNumber)?.intValue == 0o700, "folder mode")
        check((try manager.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber)?.intValue == 0o600, "receipt mode")
        recordTestDelivery(directory: directory.path, id: id, accepted: false, at: 124)
        check(try receipt()["state"] as? String == "failed", "rejected delivery not recorded")
        check(Set(try receipt().keys) == Set(["id", "state", "updatedAt"]), "unbounded diagnostic content")
        let unknown = folder.appendingPathComponent("unowned.txt")
        try Data("preserve".utf8).write(to: unknown)
        recordTestDelivery(directory: directory.path, id: "../outside", accepted: true)
        for _ in 0..<40 { recordTestDelivery(directory: directory.path, id: UUID().uuidString, accepted: true) }
        let files = try manager.contentsOfDirectory(atPath: folder.path)
        check(files.filter { $0.hasSuffix(".json") }.count == 32, "receipt history not bounded")
        check(manager.fileExists(atPath: unknown.path), "unowned file removed")
        print("PASS native payload compatibility, safe-test identity, delivery states, private permissions and bounded history")
    }
}

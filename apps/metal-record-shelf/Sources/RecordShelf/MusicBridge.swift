import Foundation
import Security

protocol MusicRequesting: Sendable {
    func call(_ op: String, fields: [String: String]) async throws -> Data
}
extension MusicRequesting {
    func call(_ op: String) async throws -> Data { try await call(op, fields: [:]) }
}
struct MusicBridge: MusicRequesting {
    let resources: URL
    func call(_ op: String, fields: [String: String] = [:]) async throws -> Data {
        let request = try JSONSerialization.data(withJSONObject: fields.merging(["op": op]) { _, new in new })
        let base = resources
        return try await Task.detached(priority: .userInitiated) {
            let process = Process(), input = Pipe(), output = Pipe()
            let bundled = base.appendingPathComponent("Runtime/node")
            let dev = URL(fileURLWithPath: NSHomeDirectory() + "/.local/bin/node")
            process.executableURL = FileManager.default.isExecutableFile(atPath: bundled.path) ? bundled : dev
            process.arguments = [base.appendingPathComponent("Backend/request.cjs").path]
            process.currentDirectoryURL = base.appendingPathComponent("Backend")
            process.standardInput = input; process.standardOutput = output; process.standardError = FileHandle.nullDevice
            try process.run()
            let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
            DispatchQueue.global().asyncAfter(deadline: .now() + 28, execute: timeout)
            defer { timeout.cancel() }
            try input.fileHandleForWriting.write(contentsOf: request)
            try input.fileHandleForWriting.close()
            let result = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard !result.isEmpty, result.count < 8 * 1024 * 1024,
                  let object = try JSONSerialization.jsonObject(with: result) as? [String: Any] else {
                throw MusicFailure(message: "网易云连接未返回结果，请检查网络后重试。")
            }
            if let error = object["error"] as? String { throw MusicFailure(message: error) }
            return result
        }.value
    }
}
struct MusicFailure: LocalizedError { let message: String; var errorDescription: String? { message } }

protocol SessionStoring: Sendable {
    func load() -> String?
    func save(_ value: String) throws
    func clear() -> Bool
}
struct SecureSessionStore: SessionStoring {
    func load() -> String? { SessionVault.load() }
    func save(_ value: String) throws { try SessionVault.save(value) }
    func clear() -> Bool { SessionVault.clear() }
}
struct SessionVault {
    private static let service = "cn.local.MetalRecordShelf.netease"
    // Never ask for the Mac login password. If the OS cannot grant silent
    // access, keep its protection intact and let the user scan in for this run.
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: "session",
         kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]
    }
    static func load() -> String? {
        var q = query
        q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &value) == errSecSuccess, let data = value as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ value: String) throws {
        let data = Data(value.utf8)
        let result = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if result == errSecSuccess { return }
        guard result == errSecItemNotFound else { throw MusicFailure(message: "无法保存本机授权，请重试。") }
        var q = query
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { throw MusicFailure(message: "无法保存本机授权，请重试。") }
    }
    @discardableResult static func clear() -> Bool {
        let result = SecItemDelete(query as CFDictionary)
        return result == errSecSuccess || result == errSecItemNotFound
    }
}

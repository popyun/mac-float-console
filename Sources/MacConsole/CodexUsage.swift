import Foundation
import Darwin

struct CodexQuotaWindow: Codable, Sendable {
    let usedPercent: Double?
    let windowDurationMins: Int?
    let resetsAt: TimeInterval?

    var remainingPercent: Int? {
        guard let usedPercent, usedPercent.isFinite else { return nil }
        return Int((100 - min(100, max(0, usedPercent))).rounded())
    }

    func title(fallback: String) -> String {
        guard let minutes = windowDurationMins, minutes > 0 else { return fallback }
        if minutes == 10080 { return "每周额度" }
        if minutes % 60 == 0 { return "\(minutes / 60) 小时额度" }
        return "\(minutes) 分钟额度"
    }

    var resetText: String {
        guard let resetsAt, resetsAt > 0 else { return "重置时间暂不可用" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return "\(formatter.string(from: Date(timeIntervalSince1970: resetsAt))) 重置"
    }
}

struct CodexQuota: Codable, Sendable {
    let primary: CodexQuotaWindow?
    let secondary: CodexQuotaWindow?

    static func decode(_ data: Data) throws -> CodexQuota {
        struct Response: Decodable {
            let rateLimits: CodexQuota?
            let rateLimitsByLimitId: [String: CodexQuota]?
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard let quota = response.rateLimitsByLimitId?["codex"] ?? response.rateLimits,
              quota.primary != nil || quota.secondary != nil else {
            throw CodexQuotaError.unavailable
        }
        return quota
    }
}

enum CodexQuotaError: LocalizedError {
    case missingCLI, unavailable, timeout, connection
    var errorDescription: String? {
        switch self {
        case .missingCLI: return "未找到 Codex CLI，请先安装并登录 Codex。"
        case .unavailable: return "当前账户暂未提供额度，请确认 Codex 已使用 ChatGPT 账户登录。"
        case .timeout: return "额度查询超时，请稍后刷新。"
        case .connection: return "无法读取 Codex 额度，请检查登录状态和网络后刷新。"
        }
    }
}

// Use the official local app-server protocol. No tokens are read by this app,
// and no thread, model turn, or quota-reset request is created.
final class CodexQuotaReader: @unchecked Sendable {
    private let executableCandidates: [String]
    private let lock = NSLock()
    private var activeProcess: Process?
    private var stopped = false

    init(executableCandidates: [String] = ["/opt/homebrew/bin/codex", "/usr/local/bin/codex",
                                          "/Applications/Codex.app/Contents/Resources/codex"]) {
        self.executableCandidates = executableCandidates
    }

    func stop() {
        lock.lock()
        stopped = true
        if let process = activeProcess, process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
        lock.unlock()
    }

    func read(timeout: TimeInterval = 20) throws -> CodexQuota {
        guard let executable = executableCandidates.first(where: FileManager.default.isExecutableFile(atPath:)) else {
            throw CodexQuotaError.missingCLI
        }
        let process = Process()
        let input = Pipe(), output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["app-server", "--listen", "stdio://", "--disable", "computer_use"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        // LaunchServices does not provide the interactive shell's PATH.
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        lock.lock()
        if stopped { lock.unlock(); throw CodexQuotaError.connection }
        do { try process.run() } catch { lock.unlock(); throw CodexQuotaError.connection }
        activeProcess = process
        lock.unlock()
        defer {
            try? input.fileHandleForWriting.close()
            lock.lock()
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            activeProcess = nil
            lock.unlock()
            process.waitUntilExit()
            try? output.fileHandleForReading.close()
        }
        func send(_ message: [String: Any]) throws {
            var data = try JSONSerialization.data(withJSONObject: message)
            data.append(10)
            try input.fileHandleForWriting.write(contentsOf: data)
        }
        var pending = Data()
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        func response(id: Int) throws -> [String: Any] {
            while ProcessInfo.processInfo.systemUptime < deadline {
                while let newline = pending.firstIndex(of: 10) {
                    let line = Data(pending[..<newline])
                    pending.removeSubrange(...newline)
                    guard let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                          message["id"] as? Int == id else { continue }
                    guard message["error"] == nil,
                          let result = message["result"] as? [String: Any] else {
                        throw CodexQuotaError.unavailable
                    }
                    return result
                }
                var descriptor = pollfd(fd: output.fileHandleForReading.fileDescriptor, events: Int16(POLLIN), revents: 0)
                let ready = poll(&descriptor, 1, 100)
                if ready < 0 {
                    if errno == EINTR { continue }
                    throw CodexQuotaError.connection
                }
                if ready == 0 { continue }
                var bytes = [UInt8](repeating: 0, count: 8192)
                let count = Darwin.read(descriptor.fd, &bytes, bytes.count)
                guard count > 0 else { throw CodexQuotaError.connection }
                pending.append(contentsOf: bytes.prefix(count))
                guard pending.count < 2_000_000 else { throw CodexQuotaError.connection }
            }
            throw CodexQuotaError.timeout
        }
        try send(["id": 0, "method": "initialize", "params": [
            "clientInfo": ["name": "mac_console", "title": "系统控制台", "version": "0.4.0"]
        ]])
        _ = try response(id: 0)
        try send(["method": "initialized"])
        try send(["id": 1, "method": "account/rateLimits/read"])
        return try CodexQuota.decode(JSONSerialization.data(withJSONObject: response(id: 1)))
    }
}

import Foundation
import Darwin

@main
struct CheckQuota {
    static func main() throws {
        func decode(_ json: String) throws -> CodexQuota {
            try CodexQuota.decode(Data(json.utf8))
        }
        let modern = try decode(#"{"rateLimits":{"primary":{"usedPercent":80}},"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":18,"windowDurationMins":300,"resetsAt":1790708482},"secondary":{"usedPercent":30,"windowDurationMins":10080,"resetsAt":1791054053}}}}"#)
        precondition(modern.primary?.remainingPercent == 82, "Prefer the codex bucket")
        precondition(modern.secondary?.remainingPercent == 70)
        precondition(modern.primary?.title(fallback: "") == "5 小时额度")
        precondition(modern.secondary?.title(fallback: "") == "每周额度")
        precondition(modern.primary?.resetText.contains("重置") == true)
        let legacy = try decode(#"{"rateLimits":{"primary":{"usedPercent":101},"secondary":null}}"#)
        precondition(legacy.primary?.remainingPercent == 0)
        precondition(legacy.secondary == nil)
        let missing = try decode(#"{"rateLimits":{"primary":{"usedPercent":null,"resetsAt":null},"secondary":{"usedPercent":-2}}}"#)
        precondition(missing.primary?.remainingPercent == nil, "Unavailable is not zero usage")
        precondition(missing.primary?.resetText == "重置时间暂不可用")
        precondition(missing.secondary?.remainingPercent == 100)
        do {
            _ = try decode(#"{"rateLimits":null,"rateLimitsByLimitId":{}}"#)
            preconditionFailure("Reject missing quota")
        } catch CodexQuotaError.unavailable {}

        // A hung server must time out and leave no child process behind.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fake = directory.appendingPathComponent("hung-server")
        let pidFile = directory.appendingPathComponent("pid")
        try "#!/bin/zsh\nprint $$ > '\(pidFile.path)'\nexec /bin/sleep 30\n".write(to: fake, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: fake.path)
        let started = Date()
        do {
            _ = try CodexQuotaReader(executableCandidates: [fake.path]).read(timeout: 1)
            preconditionFailure("Expected timeout")
        } catch CodexQuotaError.timeout {}
        precondition(Date().timeIntervalSince(started) < 3)
        let pid = Int32(try String(contentsOf: pidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines))!
        precondition(kill(pid, 0) == -1 && errno == ESRCH, "Reader must reap its child")
        print("PASS: multi-bucket, legacy, missing values, boundaries, reset labels, timeout and child cleanup")
        fflush(stdout)

        if CommandLine.arguments.contains("--live") {
            let quota = try CodexQuotaReader().read()
            for window in [quota.primary, quota.secondary].compactMap({ $0 }) {
                print("\(window.title(fallback: "额度")): 剩余 \(window.remainingPercent.map(String.init) ?? "未知")% · \(window.resetText)")
            }
            if let index = CommandLine.arguments.firstIndex(of: "--output"), CommandLine.arguments.count > index + 1 {
                let bucket = try JSONSerialization.jsonObject(with: JSONEncoder().encode(quota))
                try JSONSerialization.data(withJSONObject: ["rateLimits": bucket], options: .prettyPrinted)
                    .write(to: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
            }
        }
    }
}

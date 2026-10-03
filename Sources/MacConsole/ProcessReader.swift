import Foundation

struct ProcessReading: Identifiable {
    let pid: Int
    let name: String
    let cpuPercent: Double
    let residentBytes: UInt64

    var id: Int { pid }
}

enum ProcessReader {
    static func read() throws -> [ProcessReading] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-A", "-o", "pid=", "-o", "%cpu=", "-o", "rss=", "-o", "comm="]
        process.environment = ProcessInfo.processInfo.environment.merging(["LC_ALL": "C"]) { _, new in new }
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, let text = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "MacConsole.ProcessReader", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "无法读取进程列表"])
        }
        return parse(text)
    }

    static func parse(_ output: String) -> [ProcessReading] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(maxSplits: 3, whereSeparator: \.isWhitespace)
            guard fields.count == 4,
                  let pid = Int(fields[0]),
                  let cpu = Double(fields[1]), cpu.isFinite,
                  let residentKiB = UInt64(fields[2]),
                  residentKiB <= UInt64.max / 1024 else { return nil }
            let command = String(fields[3])
            let name = URL(fileURLWithPath: command).lastPathComponent
            return ProcessReading(pid: pid, name: name.isEmpty ? "进程 \(pid)" : name,
                                  cpuPercent: max(0, cpu), residentBytes: residentKiB * 1024)
        }
    }
}

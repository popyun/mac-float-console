import Foundation
import Darwin

struct CPUTimeSnapshot {
    let ticks: [UInt32]

    static func utilization(from old: CPUTimeSnapshot, to new: CPUTimeSnapshot) -> Int? {
        guard old.ticks.count == new.ticks.count,
              !new.ticks.isEmpty,
              new.ticks.count.isMultiple(of: Int(CPU_STATE_MAX)) else { return nil }
        var busy: UInt64 = 0
        var total: UInt64 = 0
        for index in new.ticks.indices {
            let delta = UInt64(new.ticks[index] &- old.ticks[index])
            total += delta
            if index % Int(CPU_STATE_MAX) != Int(CPU_STATE_IDLE) { busy += delta }
        }
        guard total > 0 else { return nil }
        return Int((Double(busy) * 100 / Double(total)).rounded())
    }
}

struct MemoryReading {
    let usedBytes: UInt64
    let totalBytes: UInt64
    let activeBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let inactiveBytes: UInt64

    var percent: Int {
        guard totalBytes > 0 else { return 0 }
        return Int((Double(min(usedBytes, totalBytes)) * 100 / Double(totalBytes)).rounded())
    }

    var detail: String {
        let used = ByteCountFormatter.string(fromByteCount: Int64(clamping: usedBytes), countStyle: .memory)
        let total = ByteCountFormatter.string(fromByteCount: Int64(clamping: totalBytes), countStyle: .memory)
        return "\(used) / \(total)"
    }
}

// Read system-wide Mach counters without privileges or shell subprocesses.
final class SystemMonitor {
    private var previousCPU: CPUTimeSnapshot?

    func sampleCPU() -> Int? {
        guard let current = readCPUTicks() else { previousCPU = nil; return nil }
        defer { previousCPU = current }
        guard let previousCPU else { return nil }
        return CPUTimeSnapshot.utilization(from: previousCPU, to: current)
    }

    func sampleMemory() -> MemoryReading? {
        let host = mach_host_self()
        var statistics = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        var pageSize: vm_size_t = 0
        guard host_page_size(host, &pageSize) == KERN_SUCCESS, pageSize > 0 else { return nil }
        let total = ProcessInfo.processInfo.physicalMemory
        guard total > 0 else { return nil }
        // Active + wired + physical compressor pages approximates Activity
        // Monitor's Memory Used; inactive file cache is available to reuse.
        let pageBytes = UInt64(pageSize)
        let active = UInt64(statistics.active_count) * pageBytes
        let wired = UInt64(statistics.wire_count) * pageBytes
        let compressed = UInt64(statistics.compressor_page_count) * pageBytes
        let inactive = UInt64(statistics.inactive_count) * pageBytes
        return MemoryReading(usedBytes: min(total, active + wired + compressed), totalBytes: total,
                             activeBytes: active, wiredBytes: wired, compressedBytes: compressed,
                             inactiveBytes: inactive)
    }

    private func readCPUTicks() -> CPUTimeSnapshot? {
        var processorCount: natural_t = 0
        var information: processor_info_array_t?
        var informationCount: mach_msg_type_number_t = 0
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                         &processorCount, &information, &informationCount)
        guard result == KERN_SUCCESS, let information else { return nil }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: information)),
                          vm_size_t(Int(informationCount) * MemoryLayout<integer_t>.size))
        }
        let expected = Int(processorCount) * Int(CPU_STATE_MAX)
        guard expected > 0, Int(informationCount) >= expected else { return nil }
        let ticks = (0..<expected).map { UInt32(bitPattern: information[$0]) }
        return CPUTimeSnapshot(ticks: ticks)
    }
}

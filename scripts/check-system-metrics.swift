import Foundation

@main
struct CheckSystemMetrics {
    static func main() {
        let previous = CPUTimeSnapshot(ticks: [10, 10, 80, 0])
        let current = CPUTimeSnapshot(ticks: [20, 20, 160, 0])
        precondition(CPUTimeSnapshot.utilization(from: previous, to: current) == 20)
        precondition(CPUTimeSnapshot.utilization(from: previous, to: previous) == nil)
        precondition(CPUTimeSnapshot.utilization(from: previous, to: CPUTimeSnapshot(ticks: [])) == nil)
        let wrapping = CPUTimeSnapshot.utilization(
            from: CPUTimeSnapshot(ticks: [UInt32.max - 2, 0, 0, 0]),
            to: CPUTimeSnapshot(ticks: [1, 0, 0, 0]))
        precondition(wrapping == 100, "32-bit tick rollover must not create a spike")

        let monitor = SystemMonitor()
        guard let memory = monitor.sampleMemory(),
              memory.totalBytes > 0,
              memory.usedBytes > 0,
              memory.usedBytes <= memory.totalBytes else {
            fatalError("Could not read physical memory")
        }
        _ = monitor.sampleCPU()
        Thread.sleep(forTimeInterval: 2)
        guard let cpu = monitor.sampleCPU(), (0...100).contains(cpu) else {
            fatalError("Could not read processor ticks")
        }
        print("PASS: CPU delta, rollover, live CPU \(cpu)%, live memory \(memory.percent)% (\(memory.detail))")
    }
}

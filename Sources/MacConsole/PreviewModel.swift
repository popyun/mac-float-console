import SwiftUI

struct SystemMetric {
    let title: String
    let symbol: String
    let percent: Int?
    let detail: String
    let accent: Color
}

struct ShortcutItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    var isEnabled = false
}

@MainActor
final class PreviewModel: ObservableObject {
    @Published var metrics = [
        SystemMetric(title: "CPU", symbol: "cpu", percent: nil,
                     detail: "正在读取处理器占用率", accent: Color(red: 0.24, green: 0.48, blue: 0.91)),
        SystemMetric(title: "内存", symbol: "memorychip", percent: nil,
                     detail: "正在读取内存使用率", accent: Color(red: 0.24, green: 0.59, blue: 0.60))
    ]
    static let exampleMetrics = [
        SystemMetric(title: "CPU", symbol: "cpu", percent: 24,
                     detail: "处理器占用率", accent: Color(red: 0.24, green: 0.48, blue: 0.91)),
        SystemMetric(title: "内存", symbol: "memorychip", percent: 61,
                     detail: "9.8 / 16 GB", accent: Color(red: 0.24, green: 0.59, blue: 0.60))
    ]

    @Published var shortcuts = [
        ShortcutItem(id: "awake", title: "防止休眠", detail: "让 Mac 保持唤醒", symbol: "sun.max"),
        ShortcutItem(id: "focus", title: "勿扰模式", detail: "暂时屏蔽通知打扰", symbol: "moon"),
        ShortcutItem(id: "hidden-files", title: "显示隐藏文件", detail: "在访达中显示隐藏项目", symbol: "eye"),
        ShortcutItem(id: "dock", title: "自动隐藏 Dock", detail: "为桌面留出更多空间", symbol: "dock.rectangle")
    ]
    @Published var isPinned = true
    @Published var isLocked = false
    @Published var areShortcutsExpanded = false
    @Published var isCompact = false
    @Published var codexQuota: CodexQuota?
    @Published var isRefreshingQuota = false
    @Published var quotaError: String?
    @Published var quotaUpdatedAt: Date?
    private let quotaReader = CodexQuotaReader()
    private var quotaTimer: Timer?
    @Published var lastSystemUpdateAt: Date?
    private let systemMonitor = SystemMonitor()
    private var systemTimer: Timer?
    static let compactOpacity = 0.75
    static let systemRefreshInterval: TimeInterval = 2
    static let quotaRefreshInterval: TimeInterval = 5 * 60

    func startSystemUpdates() {
        refreshSystemMetrics()
        systemTimer?.invalidate()
        let timer = Timer(timeInterval: Self.systemRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshSystemMetrics() }
        }
        systemTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stopSystemUpdates() { systemTimer?.invalidate() }

    private func refreshSystemMetrics() {
        let cpu = systemMonitor.sampleCPU()
        let memory = systemMonitor.sampleMemory()
        metrics = [
            SystemMetric(title: "CPU", symbol: "cpu", percent: cpu,
                         detail: cpu == nil ? "正在读取处理器占用率" : "全机处理器占用率 · 每 2 秒更新",
                         accent: Self.exampleMetrics[0].accent),
            SystemMetric(title: "内存", symbol: "memorychip", percent: memory?.percent,
                         detail: memory?.detail ?? "内存数据暂不可用",
                         accent: Self.exampleMetrics[1].accent)
        ]
        lastSystemUpdateAt = Date()
    }

    func startQuotaUpdates() {
        refreshQuota()
        quotaTimer?.invalidate()
        let timer = Timer(timeInterval: Self.quotaRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshQuota() }
        }
        quotaTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stopQuotaUpdates() {
        quotaTimer?.invalidate()
        quotaReader.stop()
    }

    func refreshQuota() {
        guard !isRefreshingQuota else { return }
        isRefreshingQuota = true
        let reader = quotaReader
        Task { [weak self] in
            let result = await Task.detached(priority: .utility) {
                Result { try reader.read() }
            }.value
            guard let self else { return }
            isRefreshingQuota = false
            switch result {
            case .success(let quota):
                codexQuota = quota
                quotaUpdatedAt = Date()
                quotaError = nil
            case .failure(let error):
                quotaError = error.localizedDescription
            }
        }
    }

    static func panelSize(compact: Bool, shortcutsExpanded: Bool) -> CGSize {
        if compact { return CGSize(width: 180, height: 106) }
        return CGSize(width: 280, height: shortcutsExpanded ? 366 : 242)
    }
}

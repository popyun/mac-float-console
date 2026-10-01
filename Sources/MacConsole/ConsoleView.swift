import AppKit
import SwiftUI

private let ink = Color(red: 0.16, green: 0.20, blue: 0.27)
private let secondaryInk = Color(red: 0.46, green: 0.50, blue: 0.57)
private let consoleBlue = Color(red: 0.24, green: 0.48, blue: 0.91)
private let enabledGreen = Color(red: 0.19, green: 0.65, blue: 0.36)
private let disabledRed = Color(red: 0.86, green: 0.27, blue: 0.30)

private struct StaticPreviewKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var exportsStaticPreview: Bool {
        get { self[StaticPreviewKey.self] }
        set { self[StaticPreviewKey.self] = newValue }
    }
}

struct ConsoleView: View {
    @Environment(\.exportsStaticPreview) private var exportsStaticPreview
    @ObservedObject var model: PreviewModel
    let close: () -> Void

    private var size: CGSize {
        PreviewModel.panelSize(compact: model.isCompact, shortcutsExpanded: model.areShortcutsExpanded)
    }

    var body: some View {
        Group {
            if model.isCompact {
                HStack(spacing: 6) {
                    VStack(spacing: 4) {
                        metrics
                        Rectangle().fill(ink.opacity(0.07)).frame(height: 1)
                        compactCodexUsage
                    }
                    .overlay {
                        if !exportsStaticPreview {
                            WindowDragArea(isLocked: model.isLocked) { model.isCompact = false }
                        }
                    }
                    Button {
                        model.isCompact = false
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(consoleBlue)
                            .frame(width: 22, height: 26)
                            .background(consoleBlue.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("展开控制台")
                    .help("展开控制台")
                }
                    .onTapGesture(count: 2) { model.isCompact = false }
                    .contextMenu {
                        Button("恢复完整控制台") { model.isCompact = false }
                        Button(model.isLocked ? "解锁位置" : "锁定位置") { model.isLocked.toggle() }
                        Button(model.isPinned ? "取消置顶" : "置顶浮窗") { model.isPinned.toggle() }
                        Divider()
                        Button("关闭浮窗", action: close)
                    }
                    .help(model.isLocked ? "位置已锁定，可右键解锁；点击右侧按钮展开" :
                          "CPU / 内存每 2 秒更新 · 按住数据区域拖动浮窗；点击右侧按钮展开")
            } else {
                fullConsole
            }
        }
        .padding(10)
        .frame(width: size.width, height: size.height)
        .foregroundStyle(ink)
        .background {
            ZStack {
                if exportsStaticPreview {
                    Color(red: 0.86, green: 0.89, blue: 0.94)
                } else {
                    VisualEffectBackground()
                }
                LinearGradient(colors: [.white.opacity(0.72), Color(red: 0.92, green: 0.95, blue: 0.98).opacity(0.70)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(.white.opacity(0.8)))
        .environment(\.colorScheme, .light)
    }

    private var compactCodexUsage: some View {
        VStack(spacing: 2) {
            compactQuotaRow(model.codexQuota?.primary, label: "5小时")
            compactQuotaRow(model.codexQuota?.secondary, label: "周限额")
        }
        .frame(height: 32)
        .help(quotaStatusDetail)
    }

    private func compactQuotaRow(_ window: CodexQuotaWindow?, label: String) -> some View {
        HStack(spacing: 4) {
            Text("Codex · \(label)").font(.system(size: 9, weight: .medium))
                .foregroundStyle(secondaryInk)
            Spacer(minLength: 0)
            Text(window?.remainingPercent.map { "\($0)%" } ?? (model.isRefreshingQuota ? "…" : "—"))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(model.quotaError != nil ? secondaryInk :
                    (window?.remainingPercent ?? 100) <= 10 ? disabledRed : enabledGreen)
        }
        .frame(height: 15)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Codex \(label)，\(window?.remainingPercent.map { "剩余 \($0)%" } ?? "额度暂不可用")")
    }

    private var fullConsole: some View {
        VStack(spacing: 0) {
            header.frame(height: 22)
            Spacer().frame(height: 6)
            metrics
            Spacer().frame(height: 6)
            Rectangle().fill(ink.opacity(0.07)).frame(height: 1)
            Spacer().frame(height: 6)
            codexUsageCard
            Spacer().frame(height: 6)
            Rectangle().fill(ink.opacity(0.07)).frame(height: 1)
            Spacer().frame(height: 4)
            Button {
                model.areShortcutsExpanded.toggle()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: model.areShortcutsExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold)).frame(width: 10)
                    Text("系统设置").font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text("\(model.shortcuts.filter(\.isEnabled).count) / \(model.shortcuts.count) 已开启")
                        .font(.system(size: 9)).foregroundStyle(secondaryInk).monospacedDigit()
                }
                .frame(height: 22).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("系统设置")
            .accessibilityValue(model.areShortcutsExpanded ? "已展开" : "已折叠")
            .help(model.areShortcutsExpanded ? "折叠系统设置" : "展开系统设置")
            if model.areShortcutsExpanded {
                Spacer().frame(height: 4)
                VStack(spacing: 0) {
                    ForEach($model.shortcuts) { $item in
                        ShortcutRow(item: $item)
                            .overlay(alignment: .bottom) {
                                if item.id != model.shortcuts.last?.id {
                                    Rectangle().fill(ink.opacity(0.055)).frame(height: 1)
                                        .padding(.leading, 35).padding(.trailing, 10)
                                }
                            }
                    }
                }
                .background(.white.opacity(0.54), in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(.white.opacity(0.65)))
            }
            Spacer().frame(height: 6)
            footer.frame(height: 14)
        }
    }

    private var codexUsageCard: some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "terminal").font(.system(size: 10)).foregroundStyle(consoleBlue)
                Text("Codex 额度").font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(model.isRefreshingQuota ? "更新中" : model.quotaError != nil ?
                     (model.codexQuota == nil ? "未同步" : "上次额度") : "已同步")
                    .font(.system(size: 8)).foregroundStyle(secondaryInk)
                    .help(quotaStatusDetail)
                Button { model.refreshQuota() } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 10))
                        .foregroundStyle(consoleBlue).frame(width: 20, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).disabled(model.isRefreshingQuota)
                .accessibilityLabel("刷新 Codex 额度").help("刷新额度 · 每 5 分钟自动更新")
            }.frame(height: 16)
            if let quota = model.codexQuota {
                VStack(spacing: 4) {
                    quotaRow(quota.primary, fallback: "短期额度")
                    quotaRow(quota.secondary, fallback: "长期额度")
                }
                .help(quotaStatusDetail)
            } else {
                Text(model.quotaError ?? "正在读取已登录 Codex 的额度…")
                    .font(.system(size: 10)).foregroundStyle(secondaryInk)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56, alignment: .leading)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(height: 84)
        .background(.white.opacity(0.54), in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(.white.opacity(0.65)))
    }

    private var quotaStatusDetail: String {
        if let error = model.quotaError {
            return model.codexQuota == nil ? error : "\(error) 当前显示上次读取的额度。"
        }
        guard let updated = model.quotaUpdatedAt else { return "正在读取额度" }
        return "\(updated.formatted(date: .abbreviated, time: .shortened)) 更新 · 重置时间为本机时区 · 每 5 分钟自动更新"
    }

    private func quotaRow(_ window: CodexQuotaWindow?, fallback: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(window?.title(fallback: fallback) ?? fallback)
                    .font(.system(size: 10, weight: .medium))
                Spacer()
                if let remaining = window?.remainingPercent {
                    Text("剩余 \(remaining)%").font(.system(size: 10, weight: .semibold))
                        .monospacedDigit().foregroundStyle(remaining <= 10 ? disabledRed : enabledGreen)
                } else {
                    Text("暂不可用").font(.system(size: 9)).foregroundStyle(secondaryInk)
                }
            }
            Text(window?.resetText ?? "重置时间暂不可用")
                .font(.system(size: 9)).monospacedDigit().foregroundStyle(secondaryInk)
        }
        .frame(height: 26)
        .accessibilityElement(children: .combine)
    }

    private var metrics: some View {
        VStack(spacing: 4) {
            ForEach(model.metrics, id: \.title) { MetricBar(metric: $0, compact: model.isCompact) }
        }.frame(height: 44)
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 11)).foregroundStyle(consoleBlue)
                .frame(width: 16).accessibilityHidden(true)
            Text("系统控制台").font(.system(size: 12, weight: .semibold))
            Spacer(minLength: 8)
            headerButton(symbol: model.isPinned ? "pin.fill" : "pin", label: "置顶浮窗",
                         help: model.isPinned ? "取消置顶" : "置顶浮窗", selected: model.isPinned) {
                model.isPinned.toggle()
            }
            headerButton(symbol: model.isLocked ? "lock.fill" : "lock.open", label: "锁定位置",
                         help: model.isLocked ? "解锁位置，允许拖动" : "锁定位置，防止误拖动", selected: model.isLocked) {
                model.isLocked.toggle()
            }
            headerButton(symbol: "arrow.down.right.and.arrow.up.left", label: "缩小为缩略状态",
                         help: "缩略状态显示 CPU、内存和 Codex 额度，点击展开按钮恢复") {
                model.isCompact = true
            }
            headerButton(symbol: "xmark", label: "关闭浮窗", help: "关闭浮窗，可从菜单栏重新打开", action: close)
        }.background {
            if !exportsStaticPreview { WindowDragArea(isLocked: model.isLocked) }
        }
    }

    private func headerButton(symbol: String, label: String, help: String, selected: Bool? = nil,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 10, weight: .medium))
                .foregroundStyle(selected == true ? consoleBlue : secondaryInk)
                .frame(width: 22, height: 22)
                .background(selected == true ? consoleBlue.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).help(help).accessibilityLabel(label)
        .accessibilityValue(selected.map { $0 ? "开启" : "关闭" } ?? "")
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Circle().fill(consoleBlue.opacity(0.6)).frame(width: 3, height: 3)
            Text(exportsStaticPreview ? "界面预览 · 示例数据" : "指标实时 · 开关为示例")
                .font(.system(size: 8)).foregroundStyle(secondaryInk)
            if !exportsStaticPreview, let updated = model.lastSystemUpdateAt {
                Text(updated, format: .dateTime.hour().minute().second())
                    .font(.system(size: 8)).monospacedDigit().foregroundStyle(secondaryInk)
            }
            Spacer()
            Button {} label: {
                Label("编辑", systemImage: "square.and.pencil").font(.system(size: 9))
            }
            .buttonStyle(.plain).disabled(true).foregroundStyle(secondaryInk.opacity(0.65))
            .accessibilityLabel("编辑快捷功能").help("编辑快捷功能暂未开放")
        }
    }
}

private struct MetricBar: View {
    let metric: SystemMetric
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            Text(metric.title).font(.system(size: 10, weight: .medium))
                .frame(width: 28, alignment: .leading)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(metric.accent.opacity(0.12))
                    Capsule().fill(metric.accent)
                        .frame(width: geometry.size.width * Double(metric.percent ?? 0) / 100)
                }
            }.frame(height: compact ? 6 : 8)
            Text(metric.percent.map { "\($0)%" } ?? "—")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit().frame(width: compact ? 30 : 32, alignment: .trailing)
        }
        .frame(height: 20).help(metric.detail)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(metric.title)，\(metric.percent.map { "\($0)%" } ?? "读取中")")
    }
}

private struct ShortcutRow: View {
    @Binding var item: ShortcutItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.symbol).font(.system(size: 12))
                .foregroundStyle(item.isEnabled ? enabledGreen : secondaryInk)
                .frame(width: 17).accessibilityHidden(true)
            Text(item.title).font(.system(size: 11, weight: .medium))
            Spacer(minLength: 4)
            Toggle(item.title, isOn: $item.isEnabled).labelsHidden()
                .toggleStyle(StatusSwitchStyle(label: item.title))
                .help("\(item.detail) · 仅切换预览状态")
        }.padding(.horizontal, 10).frame(height: 30)
    }
}

private struct StatusSwitchStyle: ToggleStyle {
    let label: String

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Capsule().fill(configuration.isOn ? enabledGreen : disabledRed)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle().fill(.white).frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.10), radius: 1, y: 1).padding(2)
                }
                .frame(width: 32, height: 18).padding(.vertical, 6).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel(label)
        .accessibilityValue(configuration.isOn ? "开启" : "关闭")
        .animation(.easeInOut(duration: 0.12), value: configuration.isOn)
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private struct WindowDragArea: NSViewRepresentable {
    let isLocked: Bool
    var onDoubleClick: (() -> Void)? = nil

    final class DragView: NSView {
        var isLocked = false
        var onDoubleClick: (() -> Void)?
        override func mouseDown(with event: NSEvent) {
            if event.clickCount >= 2 {
                onDoubleClick?()
                return
            }
            guard !isLocked else { return }
            window?.performDrag(with: event)
        }
    }
    func makeNSView(context: Context) -> DragView {
        let view = DragView()
        view.isLocked = isLocked
        view.onDoubleClick = onDoubleClick
        return view
    }
    func updateNSView(_ nsView: DragView, context: Context) {
        nsView.isLocked = isLocked
        nsView.onDoubleClick = onDoubleClick
    }
}

import AppKit
import SwiftUI

// Render the actual SwiftUI view directly, without capturing desktop pointer overlays.
@main
private struct ExportPreviews {
    @MainActor
    static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "artifacts", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let model = PreviewModel()
        model.metrics = PreviewModel.exampleMetrics
        // A stripped live response can be supplied for a quota preview. Without
        // one, keep the loading state instead of inventing account percentages.
        if CommandLine.arguments.dropFirst().contains("--demo") {
            let now = Date().timeIntervalSince1970
            model.codexQuota = CodexQuota(
                primary: CodexQuotaWindow(usedPercent: 32, windowDurationMins: 300,
                                          resetsAt: now + 2 * 60 * 60),
                secondary: CodexQuotaWindow(usedPercent: 57, windowDurationMins: 10080,
                                            resetsAt: now + 4 * 24 * 60 * 60)
            )
            model.quotaUpdatedAt = Date()
            let gib: UInt64 = 1_073_741_824
            let active = 6 * gib
            let wired = 3 * gib
            let compressed = 4 * gib / 5
            model.memoryReading = MemoryReading(usedBytes: active + wired + compressed,
                                                totalBytes: 16 * gib,
                                                activeBytes: active, wiredBytes: wired,
                                                compressedBytes: compressed,
                                                inactiveBytes: 16 * gib / 5)
            model.processes = [
                ProcessReading(pid: 101, name: "Web Browser", cpuPercent: 48.2, residentBytes: 1_400_000_000),
                ProcessReading(pid: 102, name: "Code Editor", cpuPercent: 22.1, residentBytes: 920_000_000),
                ProcessReading(pid: 103, name: "WindowServer", cpuPercent: 8.4, residentBytes: 660_000_000),
                ProcessReading(pid: 104, name: "Mail", cpuPercent: 3.7, residentBytes: 440_000_000),
                ProcessReading(pid: 105, name: "Finder", cpuPercent: 1.2, residentBytes: 280_000_000)
            ]
        } else if CommandLine.arguments.count > 2, !CommandLine.arguments[2].isEmpty {
            model.codexQuota = try CodexQuota.decode(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
            model.quotaUpdatedAt = Date()
        } else {
            model.isRefreshingQuota = true
        }
        model.shortcuts[0].isEnabled = true
        model.shortcuts[3].isEnabled = true
        let demo = CommandLine.arguments.dropFirst().contains("--demo")
        let modes: [(String, Bool, Bool, MetricDetail?)] = [
            ("console-preview.png", false, true, nil),
            ("console-collapsed.png", false, false, nil),
            ("console-mini.png", true, false, nil)
        ] + (demo ? [
            ("console-cpu-detail.png", false, false, .cpu),
            ("console-memory-detail.png", false, false, .memory)
        ] : [])
        for (filename, compact, expanded, detail) in modes {
            model.isCompact = compact
            model.areShortcutsExpanded = expanded
            model.selectedMetric = detail
            let size = PreviewModel.panelSize(compact: compact, shortcutsExpanded: expanded,
                                              metricDetail: detail)
            let renderer = ImageRenderer(content: ConsoleView(model: model, close: {})
                .environment(\.exportsStaticPreview, true))
            renderer.scale = 2
            renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
            guard let renderedImage = renderer.cgImage else {
                throw NSError(domain: "MacConsole.PreviewExport", code: 1)
            }
            // NSPanel fades the composited window. Apply the same alpha while
            // drawing the export, rather than fading individual SwiftUI layers.
            var image = renderedImage
            if compact {
                guard let context = CGContext(data: nil, width: image.width, height: image.height,
                                              bitsPerComponent: 8, bytesPerRow: 0,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                    throw NSError(domain: "MacConsole.PreviewExport", code: 2)
                }
                context.setAlpha(PreviewModel.compactOpacity)
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
                guard let transparentImage = context.makeImage() else {
                    throw NSError(domain: "MacConsole.PreviewExport", code: 3)
                }
                image = transparentImage
            }
            guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                throw NSError(domain: "MacConsole.PreviewExport", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Could not render \(filename)"])
            }
            try data.write(to: output.appendingPathComponent(filename))
            print("Exported: \(output.appendingPathComponent(filename).path)")
        }
    }
}

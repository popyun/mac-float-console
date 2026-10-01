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
        } else if CommandLine.arguments.count > 2, !CommandLine.arguments[2].isEmpty {
            model.codexQuota = try CodexQuota.decode(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
            model.quotaUpdatedAt = Date()
        } else {
            model.isRefreshingQuota = true
        }
        model.shortcuts[0].isEnabled = true
        model.shortcuts[3].isEnabled = true
        let modes = [
            ("console-preview.png", false, true),
            ("console-collapsed.png", false, false),
            ("console-mini.png", true, false)
        ]
        for (filename, compact, expanded) in modes {
            model.isCompact = compact
            model.areShortcutsExpanded = expanded
            let size = PreviewModel.panelSize(compact: compact, shortcutsExpanded: expanded)
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

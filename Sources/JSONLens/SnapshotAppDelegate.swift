import AppKit
import Foundation

final class SnapshotAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let outputPath = ProcessInfo.processInfo.environment["JSONLENS_SNAPSHOT_PATH"] else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard let window = NSApplication.shared.windows.first(where: \.isVisible),
                  let contentView = window.contentView,
                  let bitmap = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds) else {
                fputs("Unable to capture JSON Lens window\n", stderr)
                NSApplication.shared.terminate(nil)
                return
            }

            contentView.cacheDisplay(in: contentView.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else {
                fputs("Unable to encode JSON Lens snapshot\n", stderr)
                NSApplication.shared.terminate(nil)
                return
            }

            do {
                try data.write(to: URL(fileURLWithPath: outputPath))
            } catch {
                fputs("Unable to write JSON Lens snapshot: \(error)\n", stderr)
            }
            NSApplication.shared.terminate(nil)
        }
    }
}

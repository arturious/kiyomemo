import AppKit
import SwiftUI

@main
struct KiyomemoApp: App {
    @NSApplicationDelegateAdaptor(KiyomemoAppDelegate.self) private var appDelegate
    @StateObject private var monitor = MemoryMonitor()
    private let updater = SparkleUpdater.shared
    private let launchAtLogin = LaunchAtLoginController.shared

    private static func menuBarIcon(
        freePercentage: Int,
        content: MenuBarBadgeContent,
        tone: MenuBarBadgeTone
    ) -> NSImage {
        let text = content == .percentage ? "\(freePercentage)%" : "kiyo"
        let fontSize: CGFloat = 11.5
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let opacity: CGFloat = tone == .normal ? 1 : 0.58
        let badgeColor = NSColor.black.withAlphaComponent(opacity)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: badgeColor,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let size = NSSize(
            width: max(4 + ceil(textSize.width) + 4, 17),
            height: 16
        )
        let image = NSImage(size: size, flipped: false) { bounds in
            NSGraphicsContext.current?.cgContext.setShouldSmoothFonts(false)

            let textRect = bounds.offsetBy(dx: 0, dy: -1)
            (text as NSString).draw(in: textRect, withAttributes: attributes)

            badgeColor.setStroke()
            let border = NSBezierPath(
                roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
                xRadius: 3,
                yRadius: 3
            )
            border.lineWidth = 1
            border.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }

    var body: some Scene {
        MenuBarExtra {
            MemoryPopover(monitor: monitor)
        } label: {
            Image(
                nsImage: Self.menuBarIcon(
                    freePercentage: monitor.snapshot.freePercentage,
                    content: monitor.menuBarBadgeContent,
                    tone: monitor.menuBarBadgeTone
                )
            )
        }
        .menuBarExtraStyle(.window)
    }
}

private final class KiyomemoAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            DockSwipeQuitController.shared.refreshPermissions()
        }
    }
}

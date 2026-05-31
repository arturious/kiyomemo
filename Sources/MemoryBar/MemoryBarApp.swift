import AppKit
import SwiftUI

@main
struct MemoryBarApp: App {
    @StateObject private var monitor = MemoryMonitor()

    private static func menuBarIcon(freePercentage: Int) -> NSImage {
        let text = "\(freePercentage)%"
        let fontSize: CGFloat = 11.5
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
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

            NSColor.black.set()
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .xor
            NSBezierPath(roundedRect: bounds, xRadius: 3, yRadius: 3).fill()
            NSBezierPath(
                roundedRect: bounds.insetBy(dx: 1, dy: 1),
                xRadius: 2,
                yRadius: 2
            ).fill()
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        image.isTemplate = true
        return image
    }

    var body: some Scene {
        MenuBarExtra {
            MemoryPopover(monitor: monitor)
        } label: {
            Image(nsImage: Self.menuBarIcon(freePercentage: monitor.snapshot.freePercentage))
        }
        .menuBarExtraStyle(.window)
    }
}

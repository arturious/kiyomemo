import AppKit
import SwiftUI

struct MemoryPopover: View {
    @ObservedObject var monitor: MemoryMonitor
    @State private var refreshIsAnimating = false

    var body: some View {
        VStack(spacing: 0) {
            summary
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 8)

            Divider()

            breakdown
                .padding(.horizontal, 10)
                .padding(.vertical, 7)

            Divider()

            toolbar
                .padding(10)
        }
        .frame(width: 292)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: NSColor(white: 0.025, alpha: 0.86)))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.primary.opacity(0.32), lineWidth: 1)
        }
        .background {
            PopoverWindowReader { window in
                configurePopoverWindow(window)
                ToastPanelController.shared.anchorWindow = window
            }
        }
        .background {
            PhysicalKeyMonitor(
                onRefresh: {
                    animateRefresh()
                    monitor.refresh()
                },
                onClearCache: {
                    guard !monitor.cacheCleanupIsRunning, monitor.helperIsInstalled else { return }
                    monitor.cleanFileCache()
                }
            )
        }
        .onChange(of: monitor.lastMessage) { _, message in
            guard let message else { return }
            ToastPanelController.shared.show(message)
        }
    }

    private func configurePopoverWindow(_ window: NSWindow?) {
        guard let window else { return }
        window.backgroundColor = .clear
        window.isOpaque = false
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 16
        window.contentView?.layer?.masksToBounds = true
    }

    private var summary: some View {
        VStack(spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                memoryBadge("Used", value: monitor.snapshot.used)

                Spacer()

                memoryBadge("Free", value: monitor.snapshot.available)
            }

            asciiMemoryMeter
            memoryPressureBadge
        }
    }

    private func memoryBadge(_ title: String, value: UInt64) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .menuBarOutlineBadge()

            Text(value.shortByteCount)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var asciiMemoryMeter: some View {
        let usedPercentage = monitor.snapshot.usedPercentage
        let freePercentage = monitor.snapshot.freePercentage
        let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let characterWidth = ("#" as NSString).size(withAttributes: [.font: font]).width
        let fixedWidth = ("\(usedPercentage)% [] \(freePercentage)%" as NSString)
            .size(withAttributes: [.font: font])
            .width
        let availableWidth: CGFloat = 272
        let segmentCount = max(1, Int(floor((availableWidth - fixedWidth) / characterWidth)))
        let filledCount = min(
            segmentCount,
            max(0, Int((Double(usedPercentage) / 100 * Double(segmentCount)).rounded()))
        )

        var bar = AttributedString("\(usedPercentage)% [")
        var filled = AttributedString(String(repeating: "#", count: filledCount))
        filled.foregroundColor = .green.opacity(0.72)
        bar += filled
        bar += AttributedString(String(repeating: ".", count: segmentCount - filledCount))
        bar += AttributedString("] \(freePercentage)%")

        return Text(bar)
        .foregroundStyle(.secondary)
        .font(.system(size: 11, design: .monospaced))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var memoryPressureBadge: some View {
        HStack(spacing: 5) {
            Text("Pressure")
                .menuBarOutlineBadge()

            Text(memoryPressureTitle)
                .font(.system(size: 11))
                .foregroundStyle(memoryPressureColor)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var breakdown: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
            metricRow("Used", monitor.snapshot.used)
            metricRow("Wired", monitor.snapshot.wired)
            metricRow("Compressed", monitor.snapshot.compressed)
            metricRow("Purgeable", monitor.snapshot.purgeable)
        }
        .font(.system(size: 11))
    }

    private var memoryPressureTitle: String {
        switch monitor.memoryPressureLevel {
        case .normal:
            return "normal"
        case .warning:
            return "warning"
        case .critical:
            return "critical"
        }
    }

    private var memoryPressureColor: Color {
        switch monitor.memoryPressureLevel {
        case .normal:
            return .green.opacity(0.72)
        case .warning:
            return .yellow.opacity(0.82)
        case .critical:
            return .red.opacity(0.82)
        }
    }

    private var toolbar: some View {
        ZStack(alignment: .bottom) {
            HStack(alignment: .bottom, spacing: 6) {
                VStack(spacing: 3) {
                    shortcutHint("R")
                    refreshButton
                }

                Spacer()

                toolbarButton("Settings", isMuted: true) {
                    SettingsWindowController.shared.show(monitor: monitor)
                }
            }

            VStack(spacing: 3) {
                shortcutHint(systemName: "return")
                if monitor.helperIsInstalled {
                    clearCacheButton
                } else {
                    installHelperButton
                }
            }
        }
    }

    private var refreshButton: some View {
        Button {
            animateRefresh()
            monitor.refresh()
        } label: {
            Text("Refresh")
        }
        .buttonStyle(MenuBarBadgeButtonStyle(isHighlighted: refreshIsAnimating))
    }

    private func shortcutHint(_ key: String? = nil, systemName: String? = nil) -> some View {
        HStack(spacing: 3) {
            Text("Press")

            if let systemName {
                Image(systemName: systemName)
            } else if let key {
                Text(key)
            }
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary.opacity(0.7))
    }

    private func animateRefresh() {
        withAnimation(.easeOut(duration: 0.12)) {
            refreshIsAnimating = true
        }

        Task {
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.easeIn(duration: 0.18)) {
                refreshIsAnimating = false
            }
        }
    }

    private var clearCacheButton: some View {
        Button {
            monitor.cleanFileCache()
        } label: {
            HStack(spacing: 4) {
                if monitor.cacheCleanupIsRunning {
                    ProgressView()
                        .controlSize(.mini)
                        .frame(width: 10, height: 10)
                }

                Text(monitor.cacheCleanupIsRunning ? "Clearing..." : "Clear Cache")
            }
            .frame(width: 82)
        }
        .buttonStyle(MenuBarBadgeButtonStyle())
        .disabled(monitor.cacheCleanupIsRunning || !monitor.helperIsInstalled)
    }

    private var installHelperButton: some View {
        toolbarButton("Install Helper") {
            monitor.installHelper()
        }
        .disabled(monitor.helperInstallationIsRunning)
    }

    private func toolbarButton(
        _ title: String,
        isMuted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(MenuBarBadgeButtonStyle(isMuted: isMuted))
    }

    @ViewBuilder
    private func metricRow(_ title: String, _ value: UInt64) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value.shortByteCount)
        }
    }

}

private extension View {
    func menuBarOutlineBadge() -> some View {
        font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 6)
            .frame(height: 20)
            .foregroundStyle(.primary.opacity(0.82))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.primary.opacity(0.72), lineWidth: 1)
            }
    }
}

private struct PhysicalKeyMonitor: NSViewRepresentable {
    let onRefresh: () -> Void
    let onClearCache: () -> Void

    func makeNSView(context: Context) -> NSView {
        context.coordinator.install()
        return NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onRefresh = onRefresh
        context.coordinator.onClearCache = onClearCache
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onRefresh: onRefresh, onClearCache: onClearCache)
    }

    final class Coordinator {
        var onRefresh: () -> Void
        var onClearCache: () -> Void
        private var monitor: Any?

        init(onRefresh: @escaping () -> Void, onClearCache: @escaping () -> Void) {
            self.onRefresh = onRefresh
            self.onClearCache = onClearCache
        }

        func install() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty else {
                    return event
                }

                switch event.keyCode {
                case 15:
                    self.onRefresh()
                    return nil
                case 36, 76:
                    self.onClearCache()
                    return nil
                default:
                    return event
                }
            }
        }

        func uninstall() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

private struct PopoverWindowReader: NSViewRepresentable {
    let onWindowChange: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        WindowReportingView(onWindowChange: onWindowChange)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class WindowReportingView: NSView {
    let onWindowChange: (NSWindow?) -> Void

    init(onWindowChange: @escaping (NSWindow?) -> Void) {
        self.onWindowChange = onWindowChange
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange(window)
    }
}

@MainActor
private final class ToastPanelController {
    static let shared = ToastPanelController()

    weak var anchorWindow: NSWindow?

    private let panel: NSPanel
    private var dismissTask: Task<Void, Never>?

    private init() {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .moveToActiveSpace]
    }

    func show(_ message: String) {
        guard let anchorWindow else { return }
        dismissTask?.cancel()

        let hostingController = NSHostingController(rootView: ToastView(message: message))
        let fittingSize = hostingController.view.fittingSize
        let size = NSSize(width: max(fittingSize.width, 96), height: max(fittingSize.height, 32))
        panel.contentViewController = hostingController

        let finalFrame = NSRect(
            x: anchorWindow.frame.midX - size.width / 2,
            y: anchorWindow.frame.minY - size.height - 7,
            width: size.width,
            height: size.height
        )
        var initialFrame = finalFrame
        initialFrame.origin.y += 4

        panel.setFrame(initialFrame, display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(finalFrame, display: true)
            panel.animator().alphaValue = 1
        }

        dismissTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            hide()
        }
    }

    private func hide() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                self?.panel.orderOut(nil)
                self?.panel.alphaValue = 1
            }
        }
    }
}

private struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(Color(nsColor: NSColor(white: 0.045, alpha: 0.98)), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.primary.opacity(0.18), lineWidth: 1)
            }
    }
}

struct MenuBarBadgeButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var isHighlighted = false
    var isMuted = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 6)
            .frame(height: 20)
            .foregroundStyle(.primary.opacity(isMuted ? 0.52 : 0.82))
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed || isHighlighted ? Color.primary.opacity(0.12) : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(.primary.opacity(isMuted ? 0.42 : 0.72), lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(Rectangle())
    }
}

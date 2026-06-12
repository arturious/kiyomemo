import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var monitor: MemoryMonitor
    let close: () -> Void

    @FocusState private var intervalIsFocused: Bool
    @State private var intervalText = ""
    @StateObject private var launchAtLogin = LaunchAtLoginController.shared
    @StateObject private var dockSwipeQuit = DockSwipeQuitController.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("v\(currentVersion)")

                Spacer()

                Text("kiyomemo")
                    .italic()
            }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.top, 10)

            HStack {
                Text("Refresh interval")
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                TextField("", text: $intervalText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 46)
                    .padding(.horizontal, 6)
                    .frame(height: 22)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(.primary.opacity(0.72), lineWidth: 1)
                    }
                    .focused($intervalIsFocused)
                    .onSubmit {
                        applyInterval()
                        clearIntervalFocus()
                    }
                    .onChange(of: intervalText) { _, value in
                        intervalText = String(value.filter(\.isNumber).prefix(4))
                    }

                Text("seconds")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(12)

            Divider()

            settingRow("Menu bar icon") {
                settingOption("%", isSelected: monitor.menuBarBadgeContent == .percentage) {
                    monitor.updateMenuBarBadgeContent(.percentage)
                }

                settingOption("kiyo", isSelected: monitor.menuBarBadgeContent == .name) {
                    monitor.updateMenuBarBadgeContent(.name)
                }
            }

            Divider()

            settingRow("Icon color") {
                settingOption("Normal", isSelected: monitor.menuBarBadgeTone == .normal) {
                    monitor.updateMenuBarBadgeTone(.normal)
                }

                settingOption("Muted", isSelected: monitor.menuBarBadgeTone == .muted) {
                    monitor.updateMenuBarBadgeTone(.muted)
                }
            }

            Divider()

            settingRow("Launch at login") {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.checkbox)
            }

            if launchAtLogin.requiresApproval {
                HStack {
                    Text("Approval required in System Settings")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary.opacity(0.7))

                    Spacer()

                    Button("Open") {
                        launchAtLogin.openSystemSettings()
                    }
                    .buttonStyle(MenuBarBadgeButtonStyle(isMuted: true))
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            } else if let message = launchAtLogin.statusMessage {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }

            Divider()

            settingRow("Dock swipe to quit") {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { dockSwipeQuit.isEnabled },
                        set: { dockSwipeQuit.setEnabled($0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.checkbox)
            }

            DockSwipeTutorial(edge: dockSwipeQuit.dockEdge)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

            if dockSwipeQuit.isEnabled,
               (!dockSwipeQuit.accessibilityIsGranted ||
                !dockSwipeQuit.inputMonitoringIsGranted) {
                VStack(spacing: 6) {
                    if !dockSwipeQuit.accessibilityIsGranted {
                        permissionRow("Accessibility") {
                            dockSwipeQuit.openAccessibilitySettings()
                        }
                    }

                    if !dockSwipeQuit.inputMonitoringIsGranted {
                        permissionRow("Input Monitoring") {
                            dockSwipeQuit.openInputMonitoringSettings()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            Divider()

            settingRow("Updates") {
                Button {
                    SparkleUpdater.shared.checkForUpdates()
                } label: {
                    Text("Check for Updates")
                }
                .buttonStyle(MenuBarBadgeButtonStyle(isMuted: true))
            }

            Text("Updates install automatically after verification")
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            Spacer(minLength: 8)

            Divider()

            ZStack {
                Button {
                    applyInterval()
                    close()
                } label: {
                    Text("Close Settings")
                }
                .buttonStyle(MenuBarBadgeButtonStyle(isMuted: true))

                HStack {
                    Spacer()

                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Text("Quit")
                    }
                    .buttonStyle(MenuBarBadgeButtonStyle(isMuted: true))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 300, height: 608, alignment: .top)
        .onAppear {
            intervalText = String(monitor.refreshIntervalSeconds)
            launchAtLogin.refresh()
            dockSwipeQuit.refreshPermissions()
        }
        .onChange(of: intervalIsFocused) { _, isFocused in
            if !isFocused {
                applyInterval()
            }
        }
    }

    private func permissionRow(_ permission: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text("\(permission) required")
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.7))

            Spacer()

            Button("Open") {
                action()
            }
            .buttonStyle(MenuBarBadgeButtonStyle(isMuted: true))
        }
    }

    private func settingRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))

            Spacer()

            HStack(spacing: 6) {
                content()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func settingOption(
        _ title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary.opacity(isSelected ? 0.9 : 0.52))
                .padding(.horizontal, 6)
                .frame(height: 20)
                .background {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.primary.opacity(0.12) : .clear)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.primary.opacity(isSelected ? 0.72 : 0.42), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func applyInterval() {
        guard let seconds = Int(intervalText), seconds > 0 else {
            intervalText = String(monitor.refreshIntervalSeconds)
            return
        }

        monitor.updateRefreshInterval(seconds: seconds)
        intervalText = String(monitor.refreshIntervalSeconds)
    }

    private func clearIntervalFocus() {
        intervalIsFocused = false

        DispatchQueue.main.async {
            guard let window = NSApplication.shared.keyWindow else { return }
            window.makeFirstResponder(window.contentView)
        }
    }

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var panel: NSPanel?

    func show(monitor: MemoryMonitor) {
        if let panel {
            panel.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let panel = SettingsPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 608),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace]
        panel.delegate = self

        let effectView = NSVisualEffectView(frame: panel.contentView?.bounds ?? .zero)
        effectView.autoresizingMask = [.width, .height]
        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 12
        effectView.layer?.masksToBounds = true

        let tintView = NSView(frame: effectView.bounds)
        tintView.autoresizingMask = [.width, .height]
        tintView.wantsLayer = true
        tintView.layer?.backgroundColor = NSColor(white: 0.025, alpha: 0.86).cgColor
        effectView.addSubview(tintView)

        let hostingView = NSHostingView(
            rootView: SettingsView(monitor: monitor) { [weak self] in
                self?.close()
            }
        )
        hostingView.frame = effectView.bounds
        hostingView.autoresizingMask = [.width, .height]
        effectView.addSubview(hostingView)
        panel.contentView = effectView
        panel.center()
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    func windowWillClose(_ notification: Notification) {
        panel = nil
    }
}

private final class SettingsPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }
}

private struct DockSwipeTutorial: View {
    let edge: DockSwipeQuitController.DockEdge

    @State private var phase = 0
    @State private var swipeReachedEdge = false

    var body: some View {
        VStack(spacing: 9) {
            GeometryReader { geometry in
                let size = geometry.size

                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.primary.opacity(0.035))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.primary.opacity(0.2), lineWidth: 1)
                        }

                    dockPanel
                        .frame(
                            width: edge == .bottom ? 166 : 64,
                            height: edge == .bottom ? 66 : 158
                        )
                        .position(dockCenter(in: size))

                    ForEach(0..<3, id: \.self) { index in
                        appIcon(isRunning: index == 1)
                            .position(appPosition(index: index, in: size))
                    }

                    runningIndicator
                        .position(indicatorPosition(in: size))
                        .opacity(phase >= 3 ? 0 : 0.78)

                    Image(nsImage: NSCursor.arrow.image)
                        .resizable()
                        .renderingMode(.original)
                        .interpolation(.high)
                        .frame(width: 22, height: 29)
                        .position(cursorPosition(in: size))
                        .opacity(phase < 3 ? 1 : 0)

                    trackpadDemo
                        .frame(width: 104, height: 82)
                        .position(trackpadPosition(in: size))
                        .opacity(phase >= 1 ? 1 : 0.42)
                }
            }
            .frame(height: 174)
            .clipped()

            Text(instruction)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary.opacity(0.72))
        }
        .task {
            await runAnimation()
        }
    }

    private var dockPanel: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(.black.opacity(0.28))
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .stroke(.primary.opacity(0.3), lineWidth: 1)
            }
    }

    private var runningIndicator: some View {
        Circle()
            .fill(.primary.opacity(0.78))
            .frame(width: 6, height: 6)
    }

    private func appIcon(isRunning: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.primary.opacity(isRunning ? 0.17 : 0.075))
            .frame(width: 38, height: 38)
            .overlay {
                Text(".app")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary.opacity(isRunning ? 0.86 : 0.48))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        .primary.opacity(isRunning ? 0.72 : 0.25),
                        lineWidth: isRunning ? 1.5 : 1
                    )
            }
    }

    private var trackpadDemo: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.primary.opacity(0.025))

            ZStack {
                finger
                    .offset(x: -12)

                finger
                    .offset(x: 12)
            }
            .frame(width: 38, height: 18)
            .offset(trackpadFingerOffset)
            .opacity(phase == 2 ? 0.9 : 0)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.primary.opacity(0.36), lineWidth: 1)
        }
    }

    private var finger: some View {
        Circle()
            .fill(.primary.opacity(0.18))
            .frame(width: 14, height: 14)
            .overlay {
                Circle()
                    .stroke(.primary.opacity(0.62), lineWidth: 1)
            }
    }

    private var trackpadFingerOffset: CGSize {
        guard phase == 2, swipeReachedEdge else {
            return trackpadFingerStartOffset
        }

        switch edge {
        case .bottom:
            return CGSize(width: 0, height: 25)
        case .left:
            return CGSize(width: -27, height: 0)
        case .right:
            return CGSize(width: 27, height: 0)
        }
    }

    private var trackpadFingerStartOffset: CGSize {
        switch edge {
        case .bottom:
            return CGSize(width: 0, height: -22)
        case .left:
            return CGSize(width: 25, height: 0)
        case .right:
            return CGSize(width: -25, height: 0)
        }
    }

    private func dockCenter(in size: CGSize) -> CGPoint {
        switch edge {
        case .bottom:
            return CGPoint(x: 92, y: size.height - 40)
        case .left:
            return CGPoint(x: 38, y: size.height / 2)
        case .right:
            return CGPoint(x: size.width - 38, y: size.height / 2)
        }
    }

    private func appPosition(index: Int, in size: CGSize) -> CGPoint {
        let step = CGFloat(index - 1) * (edge == .bottom ? 50 : 48)
        switch edge {
        case .bottom:
            return CGPoint(x: 92 + step, y: size.height - 40)
        case .left:
            return CGPoint(x: 38, y: size.height / 2 + step)
        case .right:
            return CGPoint(x: size.width - 38, y: size.height / 2 + step)
        }
    }

    private func indicatorPosition(in size: CGSize) -> CGPoint {
        switch edge {
        case .bottom:
            return CGPoint(x: 92, y: size.height - 15)
        case .left:
            return CGPoint(x: 13, y: size.height / 2)
        case .right:
            return CGPoint(x: size.width - 13, y: size.height / 2)
        }
    }

    private func cursorPosition(in size: CGSize) -> CGPoint {
        guard phase >= 1 else {
            return CGPoint(x: size.width * 0.72, y: 36)
        }
        let app = appPosition(index: 1, in: size)
        return CGPoint(x: app.x + 8, y: app.y + 10)
    }

    private func trackpadPosition(in size: CGSize) -> CGPoint {
        switch edge {
        case .bottom:
            return CGPoint(x: size.width - 59, y: 55)
        case .left:
            return CGPoint(x: size.width - 69, y: size.height / 2)
        case .right:
            return CGPoint(x: 69, y: size.height / 2)
        }
    }

    private var instruction: String {
        switch phase {
        case 0:
            return "Hover an app in the Dock"
        case 1:
            return "Hover an app in the Dock"
        case 2:
            return "Swipe toward the screen edge"
        default:
            return "App closed"
        }
    }

    private func runAnimation() async {
        phase = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(950))
            withAnimation(.easeInOut(duration: 0.85)) {
                phase = 1
            }

            try? await Task.sleep(for: .milliseconds(1_150))
            swipeReachedEdge = false
            phase = 2

            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.easeInOut(duration: 1.05)) {
                swipeReachedEdge = true
            }

            try? await Task.sleep(for: .milliseconds(1_050))
            withAnimation(.easeOut(duration: 0.3)) {
                phase = 3
            }

            try? await Task.sleep(for: .milliseconds(1_000))
            if !Task.isCancelled {
                swipeReachedEdge = false
                phase = 0
            }
        }
    }
}

import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var monitor: MemoryMonitor
    let close: () -> Void

    @FocusState private var intervalIsFocused: Bool
    @State private var intervalText = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("kiyomemo")
                .font(.system(size: 13, weight: .medium).italic())
                .foregroundStyle(.secondary.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .trailing)
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
            .padding(10)
        }
        .frame(width: 300)
        .onAppear {
            intervalText = String(monitor.refreshIntervalSeconds)
        }
        .onChange(of: intervalIsFocused) { _, isFocused in
            if !isFocused {
                applyInterval()
            }
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
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 198),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.moveToActiveSpace, .transient]
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
        tintView.layer?.backgroundColor = NSColor(white: 0.025, alpha: 0.72).cgColor
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

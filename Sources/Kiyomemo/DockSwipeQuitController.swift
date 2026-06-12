import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class DockSwipeQuitController: ObservableObject {
    enum DockEdge: String {
        case bottom
        case left
        case right
    }

    static let shared = DockSwipeQuitController()

    private static let enabledKey = "dockSwipeQuitEnabled"
    private static let swipeThreshold: CGFloat = 45
    private static let maximumPointerMovement: CGFloat = 18

    @Published private(set) var isEnabled: Bool
    @Published private(set) var accessibilityIsGranted = AXIsProcessTrusted()
    @Published private(set) var inputMonitoringIsGranted = CGPreflightListenEventAccess()

    private var eventMonitor: Any?
    private var targetBundleIdentifier: String?
    private var gestureStartLocation: NSPoint?
    private var gestureDockEdge: DockEdge?
    private var accumulatedSwipe: CGFloat = 0
    private var gestureDidTrigger = false

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        if isEnabled, accessibilityIsGranted, inputMonitoringIsGranted {
            installEventMonitor()
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)

        if enabled {
            requestRequiredPermissions()
            if accessibilityIsGranted, inputMonitoringIsGranted {
                installEventMonitor()
            }
        } else {
            removeEventMonitor()
        }
    }

    func refreshPermissions() {
        accessibilityIsGranted = AXIsProcessTrusted()
        inputMonitoringIsGranted = CGPreflightListenEventAccess()
        if isEnabled, accessibilityIsGranted, inputMonitoringIsGranted {
            installEventMonitor()
        }
    }

    func openAccessibilitySettings() {
        openPrivacySettings(anchor: "Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        openPrivacySettings(anchor: "Privacy_ListenEvent")
    }

    var dockEdge: DockEdge {
        currentDockEdge()
    }

    private func requestRequiredPermissions() {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        accessibilityIsGranted = AXIsProcessTrustedWithOptions(options)
        inputMonitoringIsGranted = CGRequestListenEventAccess()
    }

    private func installEventMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) {
            [weak self] event in
            Task { @MainActor in
                self?.handleScrollEvent(event)
            }
        }
    }

    private func removeEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        eventMonitor = nil
        resetGesture()
    }

    private func handleScrollEvent(_ event: NSEvent) {
        guard isEnabled,
              event.hasPreciseScrollingDeltas,
              event.momentumPhase.isEmpty else {
            return
        }

        refreshPermissions()
        guard accessibilityIsGranted, inputMonitoringIsGranted else {
            resetGesture()
            return
        }

        if gestureStartLocation == nil,
           (event.phase.contains(.mayBegin) || event.phase.contains(.began)) {
            beginGesture(
                at: NSEvent.mouseLocation,
                accessibilityPoint: event.cgEvent?.location
            )
        }

        guard let startLocation = gestureStartLocation,
              let targetBundleIdentifier,
              let gestureDockEdge else {
            return
        }

        let currentLocation = NSEvent.mouseLocation
        let pointerMovement = hypot(
            currentLocation.x - startLocation.x,
            currentLocation.y - startLocation.y
        )
        guard pointerMovement <= Self.maximumPointerMovement else {
            resetGesture()
            return
        }

        // Convert the system's content-scrolling delta into the physical
        // two-finger direction, independent of Natural Scrolling.
        let directionMultiplier: CGFloat = event.isDirectionInvertedFromDevice ? -1 : 1
        let physicalDeltaX = event.scrollingDeltaX * directionMultiplier
        let physicalDeltaY = event.scrollingDeltaY * directionMultiplier

        switch gestureDockEdge {
        case .bottom:
            accumulatedSwipe += physicalDeltaY
        case .left:
            accumulatedSwipe += physicalDeltaX
        case .right:
            accumulatedSwipe -= physicalDeltaX
        }

        if !gestureDidTrigger, accumulatedSwipe >= Self.swipeThreshold {
            gestureDidTrigger = true
            quitApplication(bundleIdentifier: targetBundleIdentifier)
        }

        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            resetGesture()
        }
    }

    private func beginGesture(
        at location: NSPoint,
        accessibilityPoint: CGPoint?
    ) {
        resetGesture()
        let point = accessibilityPoint ?? CGPoint(
            x: location.x,
            y: (NSScreen.screens.first?.frame.maxY ?? 0) - location.y
        )
        guard let bundleIdentifier = dockApplicationBundleIdentifier(at: point) else {
            return
        }

        targetBundleIdentifier = bundleIdentifier
        gestureStartLocation = location
        gestureDockEdge = currentDockEdge()
    }

    private func dockApplicationBundleIdentifier(at accessibilityPoint: CGPoint) -> String? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(
            systemWideElement,
            Float(accessibilityPoint.x),
            Float(accessibilityPoint.y),
            &element
        ) == .success,
        let element,
        attributeString(kAXSubroleAttribute, from: element) == "AXApplicationDockItem" else {
            return nil
        }

        if let url = attributeURL(kAXURLAttribute, from: element),
           let bundleIdentifier = Bundle(url: url)?.bundleIdentifier {
            return bundleIdentifier
        }

        guard let title = attributeString(kAXTitleAttribute, from: element) else {
            return nil
        }
        return NSWorkspace.shared.runningApplications.first {
            $0.localizedName == title && $0.activationPolicy == .regular
        }?.bundleIdentifier
    }

    private func quitApplication(bundleIdentifier: String) {
        let protectedBundleIdentifiers = Set([
            Bundle.main.bundleIdentifier,
            "com.apple.dock",
            "com.apple.finder"
        ].compactMap { $0 })

        guard !protectedBundleIdentifiers.contains(bundleIdentifier),
              let application = NSRunningApplication.runningApplications(
                withBundleIdentifier: bundleIdentifier
              ).first else {
            return
        }
        application.terminate()
    }

    private func resetGesture() {
        targetBundleIdentifier = nil
        gestureStartLocation = nil
        gestureDockEdge = nil
        accumulatedSwipe = 0
        gestureDidTrigger = false
    }

    private func currentDockEdge() -> DockEdge {
        guard let value = CFPreferencesCopyAppValue(
            "orientation" as CFString,
            "com.apple.dock" as CFString
        ) as? String else {
            return .bottom
        }
        return DockEdge(rawValue: value) ?? .bottom
    }

    private func attributeString(
        _ attribute: String,
        from element: AXUIElement
    ) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success else {
            return nil
        }
        return value as? String
    }

    private func attributeURL(
        _ attribute: String,
        from element: AXUIElement
    ) -> URL? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success else {
            return nil
        }
        return value as? URL
    }

    private func openPrivacySettings(anchor: String) {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

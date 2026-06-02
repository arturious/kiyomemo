import Darwin
import Foundation

private let helperSocketPath = "/var/run/dev.kiyomemo.helper.sock"

enum MenuBarBadgeContent: String {
    case percentage
    case name
}

enum MenuBarBadgeTone: String {
    case normal
    case muted
}

enum MemoryPressureLevel {
    case normal
    case warning
    case critical

    static func read() -> MemoryPressureLevel {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else {
            return .normal
        }

        switch level {
        case 4:
            return .critical
        case 2:
            return .warning
        default:
            return .normal
        }
    }
}

struct MemorySnapshot {
    var total: UInt64 = ProcessInfo.processInfo.physicalMemory
    var free: UInt64 = 0
    var inactive: UInt64 = 0
    var speculative: UInt64 = 0
    var purgeable: UInt64 = 0
    var wired: UInt64 = 0
    var compressed: UInt64 = 0

    var available: UInt64 {
        min(total, free + inactive + speculative + purgeable)
    }

    var used: UInt64 {
        total - available
    }

    var freePercentage: Int {
        guard total > 0 else { return 0 }
        return Int((Double(available) / Double(total) * 100).rounded())
    }

    var usedPercentage: Int {
        100 - freePercentage
    }

    static func read() -> MemorySnapshot {
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return MemorySnapshot()
        }

        let page = UInt64(pageSize)
        return MemorySnapshot(
            free: UInt64(stats.free_count) * page,
            inactive: UInt64(stats.inactive_count) * page,
            speculative: UInt64(stats.speculative_count) * page,
            purgeable: UInt64(stats.purgeable_count) * page,
            wired: UInt64(stats.wire_count) * page,
            compressed: UInt64(stats.compressor_page_count) * page
        )
    }
}

@MainActor
final class MemoryMonitor: ObservableObject {
    private static let refreshIntervalKey = "refreshIntervalSeconds"
    private static let menuBarBadgeContentKey = "menuBarBadgeContent"
    private static let menuBarBadgeToneKey = "menuBarBadgeTone"

    @Published private(set) var snapshot = MemorySnapshot.read()
    @Published private(set) var refreshIntervalSeconds: Int
    @Published private(set) var menuBarBadgeContent: MenuBarBadgeContent
    @Published private(set) var menuBarBadgeTone: MenuBarBadgeTone
    @Published private(set) var memoryPressureLevel = MemoryPressureLevel.read()
    @Published private(set) var cacheCleanupIsRunning = false
    @Published private(set) var helperIsInstalled = false
    @Published private(set) var helperInstallationIsRunning = false
    @Published private(set) var lastMessage: String?

    private var timer: Timer?

    init() {
        let savedInterval = UserDefaults.standard.integer(forKey: Self.refreshIntervalKey)
        refreshIntervalSeconds = savedInterval > 0 ? savedInterval : 2
        menuBarBadgeContent = MenuBarBadgeContent(
            rawValue: UserDefaults.standard.string(forKey: Self.menuBarBadgeContentKey) ?? ""
        ) ?? .percentage
        menuBarBadgeTone = MenuBarBadgeTone(
            rawValue: UserDefaults.standard.string(forKey: Self.menuBarBadgeToneKey) ?? ""
        ) ?? .normal
        refresh()
        start()
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(refreshIntervalSeconds),
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func updateRefreshInterval(seconds: Int) {
        let interval = min(max(seconds, 1), 3_600)
        guard interval != refreshIntervalSeconds else { return }

        refreshIntervalSeconds = interval
        UserDefaults.standard.set(interval, forKey: Self.refreshIntervalKey)
        timer?.invalidate()
        timer = nil
        start()
    }

    func updateMenuBarBadgeContent(_ content: MenuBarBadgeContent) {
        menuBarBadgeContent = content
        UserDefaults.standard.set(content.rawValue, forKey: Self.menuBarBadgeContentKey)
    }

    func updateMenuBarBadgeTone(_ tone: MenuBarBadgeTone) {
        menuBarBadgeTone = tone
        UserDefaults.standard.set(tone.rawValue, forKey: Self.menuBarBadgeToneKey)
    }

    func refresh() {
        snapshot = .read()
        memoryPressureLevel = .read()
        helperIsInstalled = FileManager.default.fileExists(atPath: helperSocketPath)
    }

    func cleanFileCache() {
        guard !cacheCleanupIsRunning else { return }
        cacheCleanupIsRunning = true
        lastMessage = nil
        let before = snapshot.available

        Task.detached {
            do {
                let response = try Self.requestHelper("PURGE")
                await MainActor.run {
                    self.refresh()
                    self.cacheCleanupIsRunning = false
                    if response == "OK" {
                        let delta = self.snapshot.available > before
                            ? self.snapshot.available - before
                            : 0
                        self.lastMessage = "Cleared \(delta.shortByteCount)"
                    } else {
                        self.lastMessage = "Cleanup failed"
                    }
                }
            } catch {
                await MainActor.run {
                    self.cacheCleanupIsRunning = false
                    self.helperIsInstalled = false
                    self.lastMessage = "Install helper first"
                }
            }
        }
    }

    func installHelper() {
        guard !helperInstallationIsRunning else { return }
        guard let scriptURL = Bundle.main.resourceURL?
            .appendingPathComponent("install-helper.sh") else {
            lastMessage = "Installer not found"
            return
        }

        helperInstallationIsRunning = true
        lastMessage = nil

        Task.detached {
            let process = Process()
            let errorPipe = Pipe()
            let command = "/bin/zsh \(scriptURL.path.shellQuoted)"
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = [
                "-e",
                "do shell script \(command.appleScriptQuoted) with administrator privileges"
            ]
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let details = String(data: errorData, encoding: .utf8)
                try? await Task.sleep(for: .milliseconds(500))

                await MainActor.run {
                    self.helperInstallationIsRunning = false
                    self.refresh()
                    if process.terminationStatus == 0 {
                        self.lastMessage = "Helper installed"
                    } else if details?.localizedCaseInsensitiveContains("User canceled") == true {
                        self.lastMessage = "Installation canceled"
                    } else {
                        self.lastMessage = "Installation failed"
                    }
                }
            } catch {
                await MainActor.run {
                    self.helperInstallationIsRunning = false
                    self.lastMessage = "Installer failed"
                }
            }
        }
    }

    nonisolated private static func requestHelper(_ command: String) throws -> String {
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
        defer { close(descriptor) }

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let maxPathLength = MemoryLayout.size(ofValue: address.sun_path)
        guard helperSocketPath.utf8.count < maxPathLength else {
            throw POSIXError(.ENAMETOOLONG)
        }
        withUnsafeMutablePointer(to: &address.sun_path) { pathPointer in
            pathPointer.withMemoryRebound(to: CChar.self, capacity: maxPathLength) { destination in
                _ = helperSocketPath.withCString { source in
                    strncpy(destination, source, maxPathLength - 1)
                }
            }
        }

        let length = socklen_t(MemoryLayout<sa_family_t>.size + helperSocketPath.utf8.count + 1)
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(descriptor, $0, length)
            }
        }
        guard result == 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }

        let request = "\(command)\n"
        _ = request.withCString {
            write(descriptor, $0, strlen($0))
        }

        var buffer = [UInt8](repeating: 0, count: 512)
        let count = read(descriptor, &buffer, buffer.count)
        guard count > 0 else {
            throw POSIXError(.EIO)
        }
        return String(decoding: buffer.prefix(Int(count)), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "ERROR ", with: "")
    }
}

extension UInt64 {
    var shortByteCount: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .memory)
    }
}

private extension String {
    var shellQuoted: String {
        "'\(replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    var appleScriptQuoted: String {
        "\"\(replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}

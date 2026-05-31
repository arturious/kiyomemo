import Darwin
import Foundation

private let socketPath = "/var/run/dev.memorybar.helper.sock"

private func removeSocket() {
    unlink(socketPath)
}

private func makeServerSocket() throws -> Int32 {
    let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
    guard descriptor >= 0 else {
        throw POSIXError(.init(rawValue: errno) ?? .EIO)
    }

    removeSocket()
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)

    let maxPathLength = MemoryLayout.size(ofValue: address.sun_path)
    guard socketPath.utf8.count < maxPathLength else {
        close(descriptor)
        throw POSIXError(.ENAMETOOLONG)
    }

    withUnsafeMutablePointer(to: &address.sun_path) { pathPointer in
        pathPointer.withMemoryRebound(to: CChar.self, capacity: maxPathLength) { destination in
            _ = socketPath.withCString { source in
                strncpy(destination, source, maxPathLength - 1)
            }
        }
    }

    let length = socklen_t(MemoryLayout<sa_family_t>.size + socketPath.utf8.count + 1)
    let bindResult = withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            bind(descriptor, $0, length)
        }
    }
    guard bindResult == 0 else {
        let error = errno
        close(descriptor)
        throw POSIXError(.init(rawValue: error) ?? .EIO)
    }

    guard chmod(socketPath, 0o666) == 0, listen(descriptor, 4) == 0 else {
        let error = errno
        close(descriptor)
        removeSocket()
        throw POSIXError(.init(rawValue: error) ?? .EIO)
    }

    return descriptor
}

private func runPurge() -> String {
    let process = Process()
    let errorPipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/purge")
    process.standardError = errorPipe

    do {
        try process.run()
        process.waitUntilExit()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let details = String(data: errorData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if process.terminationStatus == 0 {
            return "OK\n"
        }
        return "ERROR \(details ?? "purge failed")\n"
    } catch {
        return "ERROR \(error.localizedDescription)\n"
    }
}

private func handle(_ client: Int32) {
    defer { close(client) }
    var buffer = [UInt8](repeating: 0, count: 64)
    let count = read(client, &buffer, buffer.count)
    guard count > 0 else { return }

    let request = String(decoding: buffer.prefix(Int(count)), as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let response = request == "PURGE" ? runPurge() : "ERROR unsupported command\n"
    _ = response.withCString {
        write(client, $0, strlen($0))
    }
}

signal(SIGTERM) { _ in
    removeSocket()
    exit(0)
}

do {
    let server = try makeServerSocket()
    defer {
        close(server)
        removeSocket()
    }

    while true {
        let client = accept(server, nil, nil)
        if client >= 0 {
            handle(client)
        }
    }
} catch {
    FileHandle.standardError.write(Data("MemoryBarHelper: \(error)\n".utf8))
    exit(1)
}

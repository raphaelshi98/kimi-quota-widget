import Darwin
import Foundation
import OSLog

@MainActor
final class KimiLocalServer {
    private var process: Process?
    private var activeConnection: ServerConnection?
    private var errorPipe: Pipe?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "KimiQuota", category: "LocalServer")

    func connection() async throws -> ServerConnection {
        if let activeConnection, process?.isRunning == true {
            return activeConnection
        }

        stop()
        guard let user = getpwuid(getuid()) else {
            throw KimiQuotaError.cliMissing
        }
        let home = URL(fileURLWithPath: String(cString: user.pointee.pw_dir), isDirectory: true)
        let executable = home.appendingPathComponent(".kimi-code/bin/kimi")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw KimiQuotaError.cliMissing
        }

        let port = try Self.availablePort()
        let baseURL = URL(string: "http://127.0.0.1:\(port)")!
        let child = Process()
        child.executableURL = executable
        child.currentDirectoryURL = home.appendingPathComponent(".kimi-code", isDirectory: true)
        child.environment = ProcessInfo.processInfo.environment.merging([
            "HOME": home.path,
            "KIMI_CODE_HOME": home.appendingPathComponent(".kimi-code", isDirectory: true).path
        ]) { _, new in new }
        child.arguments = ["web", "--no-open", "--port", String(port), "--log-level", "error"]
        child.standardInput = FileHandle.nullDevice
        child.standardOutput = FileHandle.nullDevice

        let errors = Pipe()
        child.standardError = errors
        errorPipe = errors
        let logger = self.logger
        errors.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let output = String(decoding: data, as: UTF8.self)
            for line in output.split(separator: "\n") {
                let text = String(line)
                let safe = text.range(of: "token|authorization", options: [.regularExpression, .caseInsensitive]) == nil
                    ? text
                    : "<已隐藏认证信息>"
                logger.error("Kimi CLI：\(safe, privacy: .public)")
            }
        }
        child.terminationHandler = { process in
            logger.error("Kimi CLI 服务退出，状态码：\(process.terminationStatus)")
        }

        do {
            try child.run()
            process = child
            for _ in 0..<60 {
                if !child.isRunning {
                    throw KimiQuotaError.serverUnavailable
                }
                if await Self.isReady(baseURL: baseURL) {
                    let tokenURL = home.appendingPathComponent(".kimi-code/server.token")
                    guard let value = try? String(contentsOf: tokenURL, encoding: .utf8) else {
                        throw KimiQuotaError.tokenUnavailable
                    }
                    let token = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !token.isEmpty else {
                        throw KimiQuotaError.tokenUnavailable
                    }
                    let result = ServerConnection(baseURL: baseURL, token: token)
                    activeConnection = result
                    return result
                }
                try await Task.sleep(nanoseconds: 250_000_000)
            }
            throw KimiQuotaError.serverUnavailable
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        activeConnection = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe = nil
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
    }

    private static func isReady(baseURL: URL) async -> Bool {
        let url = baseURL.appendingPathComponent("openapi.json")
        guard let (_, response) = try? await URLSession.shared.data(from: url) else {
            return false
        }
        return response is HTTPURLResponse
    }

    private static func availablePort() throws -> UInt16 {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw KimiQuotaError.serverUnavailable
        }
        defer { close(descriptor) }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { rebound in
                bind(descriptor, rebound, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            throw KimiQuotaError.serverUnavailable
        }

        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { rebound in
                getsockname(descriptor, rebound, &length)
            }
        }
        guard nameResult == 0 else {
            throw KimiQuotaError.serverUnavailable
        }
        return UInt16(bigEndian: address.sin_port)
    }
}

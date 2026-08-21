import Foundation

/// 安全执行命令行工具的封装
/// 使用 Process + 参数数组，绝不拼接 shell 字符串
enum CommandRunner {
    /// 命令执行结果
    struct Result {
        let exitCode: Int32
        let standardOutput: String
        let standardError: String
        let duration: TimeInterval

        var isSuccess: Bool { exitCode == 0 }
    }

    /// 执行命令
    /// - Parameters:
    ///   - executablePath: 可执行文件的完整路径
    ///   - arguments: 参数数组（每个参数单独传入，防止 shell 注入）
    ///   - timeout: 超时时间（秒）
    /// - Returns: 执行结果
    static func run(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval = 10
    ) throws -> Result {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw CommandError.executableNotFound(path: executablePath)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let startTime = Date()

        do {
            try process.run()
        } catch {
            throw CommandError.executionFailed(underlying: error)
        }

        // 带超时的等待
        let semaphore = DispatchSemaphore(value: 0)
        var timeoutReached = false

        DispatchQueue.global().async {
            let waitResult = semaphore.wait(timeout: .now() + timeout)
            if waitResult == .timedOut {
                timeoutReached = true
                process.terminate()
            }
        }

        process.terminationHandler = { _ in
            semaphore.signal()
        }

        semaphore.wait()
        let duration = Date().timeIntervalSince(startTime)

        if timeoutReached {
            throw CommandError.timeout(seconds: timeout)
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return Result(
            exitCode: process.terminationStatus,
            standardOutput: stdout.trimmingCharacters(in: .whitespacesAndNewlines),
            standardError: stderr.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: duration
        )
    }

    /// 执行命令（异步版本）
    static func runAsync(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval = 10
    ) async throws -> Result {
        try await Task.detached {
            try run(executablePath: executablePath, arguments: arguments, timeout: timeout)
        }.value
    }
}

// MARK: - Errors

enum CommandError: LocalizedError {
    case executableNotFound(path: String)
    case executionFailed(underlying: Error)
    case timeout(seconds: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let path):
            return "Executable not found: \(path)"
        case .executionFailed(let error):
            return "Execution failed: \(error.localizedDescription)"
        case .timeout(let seconds):
            return "Command timed out after \(seconds) seconds"
        }
    }
}

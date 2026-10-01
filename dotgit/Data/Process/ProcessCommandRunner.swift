import Foundation

struct ProcessCommandRunner: CommandRunning {
    // MARK: - Private

    private let baseEnvironment: [String: String]
    private let temporaryDirectory: URL

    // MARK: - Init

    init(baseEnvironment: [String: String], temporaryDirectory: URL) {
        self.baseEnvironment = baseEnvironment
        self.temporaryDirectory = temporaryDirectory
    }

    // MARK: - CommandRunning

    @concurrent
    func run(_ request: CommandRequest) async throws(CommandError) -> CommandResult {
        guard Task.isCancelled == false else {
            throw .cancelled
        }
        guard FileManager.default.isExecutableFile(atPath: request.executablePath) else {
            throw .executableMissing(request.executablePath)
        }

        let identifier = UUID().uuidString
        let outputURL = temporaryDirectory.appending(path: "dotgit-\(identifier).out")
        let errorURL = temporaryDirectory.appending(path: "dotgit-\(identifier).err")

        defer {
            try? FileManager.default.removeItem(at: outputURL)
            try? FileManager.default.removeItem(at: errorURL)
        }

        do {
            try Self.createEmptyFiles(at: [outputURL, errorURL])
        } catch {
            throw CommandError.outputUnreadable
        }

        let process = Process()
        process.executableURL = URL(filePath: request.executablePath)
        process.arguments = request.arguments
        process.currentDirectoryURL = request.workingDirectory
        process.environment = baseEnvironment.merging(request.extraEnvironment) { _, new in new }

        guard let outputHandle = try? FileHandle(forWritingTo: outputURL),
              let errorHandle = try? FileHandle(forWritingTo: errorURL)
        else {
            throw CommandError.outputUnreadable
        }

        process.standardOutput = outputHandle
        process.standardError = errorHandle

        do {
            try process.run()
        } catch {
            try? outputHandle.close()
            try? errorHandle.close()
            throw CommandError.launchFailed(error.localizedDescription)
        }

        process.waitUntilExit()
        try? outputHandle.close()
        try? errorHandle.close()

        let standardOutput = (try? String(contentsOf: outputURL, encoding: .utf8)) ?? ""
        let standardError = (try? String(contentsOf: errorURL, encoding: .utf8)) ?? ""

        return CommandResult(
            exitCode: process.terminationStatus,
            standardOutput: standardOutput,
            standardError: standardError
        )
    }

    // MARK: - Helpers

    private static func createEmptyFiles(at urls: [URL]) throws {
        for url in urls {
            try Data().write(to: url, options: .atomic)
        }
    }
}

import Foundation

struct CommandRequest: Equatable {
    let executablePath: String
    let arguments: [String]
    let workingDirectory: URL?
    let extraEnvironment: [String: String]

    init(
        executablePath: String,
        arguments: [String],
        workingDirectory: URL? = nil,
        extraEnvironment: [String: String] = [:]
    ) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.extraEnvironment = extraEnvironment
    }
}

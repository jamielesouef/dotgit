import Foundation

protocol CommandRunning: Sendable {
    func run(_ request: CommandRequest) async throws(CommandError) -> CommandResult
}

import Foundation
@testable import homerun_app

actor StubSSHHostResolver: SSHHostResolving {
    // MARK: - Configuration

    var hostNames: [String: String] = [:]

    // MARK: - Configuration helpers

    func setHostName(_ hostName: String, forAlias alias: String) {
        hostNames[alias] = hostName
    }

    // MARK: - SSHHostResolving

    func hostName(forAlias alias: String) async -> String? {
        hostNames[alias]
    }
}

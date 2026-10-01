import Foundation

struct StartupStep: Equatable, Identifiable {
    let check: StartupCheck
    let status: StartupStepStatus
    let detail: String

    var id: StartupCheck {
        check
    }
}

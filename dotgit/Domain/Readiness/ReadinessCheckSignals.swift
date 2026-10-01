import Foundation

struct ReadinessCheckSignals {
    let unpushedTags: [String]
    let missingConfigurationTemplates: [String]
    let hasSetupInstructions: Bool
}

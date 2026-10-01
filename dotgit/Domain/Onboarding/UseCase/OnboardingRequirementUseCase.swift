import Foundation

enum OnboardingRequirementUseCase {
    static func requirements(for availability: ToolAvailability) -> [OnboardingRequirement] {
        var requirements: [OnboardingRequirement] = []

        if availability.isGitAvailable == false {
            requirements.append(.gitMissing)
        }

        switch (availability.isGitHubCLIAvailable, availability.gitHubAccounts.isEmpty) {
        case (false, _):
            requirements.append(.gitHubCLIMissing)
        case (true, true):
            requirements.append(.gitHubCLINotAuthenticated)
        case (true, false):
            break
        }

        return requirements
    }

    static func capabilities(for availability: ToolAvailability) -> Set<AppCapability> {
        var capabilities: Set<AppCapability> = []

        if availability.isGitAvailable {
            capabilities.insert(.gitSync)
        }

        guard availability.isGitHubCLIAuthenticated else {
            return capabilities
        }

        capabilities.insert(.gitHubAccountManagement)
        capabilities.insert(.gitHubAccountFallback)

        return capabilities
    }

    static func canSkipOnboarding(availability: ToolAvailability, hasCompletedOnboarding: Bool) -> Bool {
        guard availability.isGitAvailable else {
            return false
        }
        guard hasCompletedOnboarding == false else {
            return true
        }

        return requirements(for: availability).isEmpty
    }
}

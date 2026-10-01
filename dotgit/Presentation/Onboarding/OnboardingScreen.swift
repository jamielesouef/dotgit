import SwiftUI

struct OnboardingScreen: View {
    // MARK: - Constants

    private enum Constants {
        static let width: CGFloat = 520
    }

    // MARK: - Environment

    @Environment(\.onboardingService) private var service

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            header
            content
            footer
        }
        .padding(AppSpacing.xlarge)
        .frame(width: Constants.width)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            Label(String(localized: "dotgit"), systemImage: "figure.baseball")
                .font(.largeTitle.weight(.semibold))

            Text(String(localized: "A quick check of the tools dotgit uses on this Mac."))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Load state

    @ViewBuilder
    private var content: some View {
        switch service.loadState {
        case let .checking(steps):
            StartupChecklist(steps: steps)
        case let .blocked(requirements):
            requirementList(requirements)
        case let .optional(requirements):
            requirementList(requirements)
        case .ready:
            Label(String(localized: "Everything dotgit needs is here."), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }

    private func requirementList(_ requirements: [OnboardingRequirement]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.regular) {
            ForEach(requirements) { requirement in
                VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                    Label(requirement.title, systemImage: requirement.isBlocking ? "xmark.octagon.fill" : "info.circle")
                        .font(.headline)
                        .foregroundStyle(requirement.isBlocking ? Color.red : Color.secondary)

                    Text(requirement.explanation)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if requirement == .gitHubCLINotAuthenticated {
                        Button(String(localized: "Sign in with gh")) {
                            Task {
                                await service.signIn()
                            }
                        }
                    }
                }
            }

            capabilitySummary
        }
    }

    private var capabilitySummary: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            Text(String(localized: "Available now"))
                .font(.subheadline.weight(.semibold))

            ForEach(AppCapability.allCases, id: \.rawValue) { capability in
                Label(
                    capability.title,
                    systemImage: service.capabilities.contains(capability) ? "checkmark.circle" : "circle.dashed"
                )
                .font(.caption)
                .foregroundStyle(service.capabilities.contains(capability) ? Color.primary : Color.secondary)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if let signInError = service.signInError {
                Text(signInError.message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            Button(String(localized: "Check again")) {
                Task {
                    await service.refresh()
                }
            }

            Button(String(localized: "Continue")) {
                service.markCompleted()
            }
            .buttonStyle(.borderedProminent)
            .disabled(service.availability.isGitAvailable == false)
        }
    }
}

#if DEBUG
    #Preview("Everything present") {
        OnboardingScreen()
            .environment(\.onboardingService, PreviewGraph.populated.onboarding)
    }

    #Preview("gh missing") {
        OnboardingScreen()
            .environment(
                \.onboardingService,
                PreviewGraph.make(repositories: [], paths: [:], snapshots: [:], gitHubAvailable: false).onboarding
            )
    }

    #Preview("Nothing checked yet") {
        OnboardingScreen()
            .environment(\.onboardingService, PreviewGraph.empty.onboarding)
    }
#endif

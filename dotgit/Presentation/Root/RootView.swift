import SwiftUI

struct RootView: View {
    // MARK: - Environment

    @Environment(\.onboardingService) private var onboarding

    // MARK: - View

    var body: some View {
        content
            .task {
                await onboarding.start()
            }
    }

    // MARK: - Load state

    @ViewBuilder
    private var content: some View {
        switch onboarding.loadState {
        case let .checking(steps):
            LaunchView(steps: steps)
        case .blocked,
             .optional,
             .ready:
            checked
        }
    }

    @ViewBuilder
    private var checked: some View {
        if onboarding.showsOnboarding {
            OnboardingScreen()
        } else {
            MainSplitView()
        }
    }
}

#if DEBUG
    #Preview("Ready") {
        RootView()
            .environment(\.onboardingService, PreviewGraph.populated.onboarding)
            .environment(\.repositoriesService, PreviewGraph.populated.repositories)
            .frame(width: 900, height: 600)
    }
#endif

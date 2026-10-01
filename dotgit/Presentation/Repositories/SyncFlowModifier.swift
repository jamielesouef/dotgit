import SwiftUI

struct SyncFlowModifier: ViewModifier {
    // MARK: - Environment

    @Environment(\.syncService) private var sync

    // MARK: - State

    @State private var isShowingReview = false
    @State private var isShowingRun = false

    // MARK: - View

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isShowingReview) {
                SyncReviewSheet()
            }
            .sheet(isPresented: $isShowingRun) {
                SyncRunSheet()
            }
            .onChange(of: sync.phase, initial: true) {
                isShowingReview = sync.reviewPlan != nil
                isShowingRun = sync.isRunningOrFinished
            }
            .onChange(of: isShowingReview) {
                guard isShowingReview == false else {
                    return
                }

                sync.cancelReview()
            }
            .onChange(of: isShowingRun) {
                guard isShowingRun == false else {
                    return
                }

                sync.dismissSummary()
            }
    }
}

extension View {
    func syncFlow() -> some View {
        modifier(SyncFlowModifier())
    }
}

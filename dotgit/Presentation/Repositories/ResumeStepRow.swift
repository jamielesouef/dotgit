import SwiftUI

struct ResumeStepRow: View {
    // MARK: - State

    @State private var isSelected = false

    // MARK: - Inputs

    let step: ResumeStep
    let onSelectionChange: (Bool) -> Void

    // MARK: - View

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            Toggle(isOn: $isSelected) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
            .disabled(step.action.isActionable == false)

            VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                Text(step.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)

                Text(step.action.summary)
                    .font(.caption)
                    .foregroundStyle(step.action.isActionable ? Color.secondary : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)

                if let handoff = step.handoff {
                    Text(String(localized: "Last left on \(handoff.branch) at \(handoff.shortCommit)"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.medium)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: AppSpacing.small))
        .onChange(of: step.isSelected, initial: true) {
            isSelected = step.isSelected
        }
        .onChange(of: isSelected) {
            onSelectionChange(isSelected)
        }
    }
}

#if DEBUG
    #Preview("Each action") {
        VStack(spacing: AppSpacing.small) {
            ResumeStepRow(
                step: ResumeStep(
                    identifier: "a",
                    name: "app",
                    action: .clone(URL(filePath: "/Users/preview/Developer/app")),
                    handoff: RepositoryHandoff(branch: "feature/login", commit: "abc1234def", recordedAt: .now),
                    isSelected: true
                ),
                onSelectionChange: { _ in }
            )
            ResumeStepRow(
                step: ResumeStep(
                    identifier: "b",
                    name: "tooling",
                    action: .fastForward(4),
                    handoff: nil,
                    isSelected: true
                ),
                onSelectionChange: { _ in }
            )
            ResumeStepRow(
                step: ResumeStep(
                    identifier: "c",
                    name: "an-extremely-long-repository-name-that-wraps-onto-several-lines",
                    action: .blockedByLocalChanges(7),
                    handoff: nil,
                    isSelected: false
                ),
                onSelectionChange: { _ in }
            )
        }
        .padding()
        .frame(width: 520)
    }
#endif

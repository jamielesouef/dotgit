import AppKit
import SwiftUI

struct RepositoryDropTargetView: View {
    // MARK: - Constants

    private enum Constants {
        static let cornerRadius: CGFloat = 12
        static let borderWidth: CGFloat = 2
        static let dashLength: CGFloat = 6
        static let symbolSize: CGFloat = 44
        static let tintOpacity: CGFloat = 0.1
    }

    // MARK: - View

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(nsColor: .windowBackgroundColor))

            panel

            label
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel(String(localized: "Drop to track this repository"))
    }

    // MARK: - Panel

    private var panel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .fill(.tint.opacity(Constants.tintOpacity))

            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .strokeBorder(
                    .tint,
                    style: StrokeStyle(lineWidth: Constants.borderWidth, dash: [Constants.dashLength])
                )
        }
        .padding(AppSpacing.small)
    }

    // MARK: - Label

    private var label: some View {
        VStack(spacing: AppSpacing.small) {
            Image(systemName: "viewfinder")
                .font(.system(size: Constants.symbolSize))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text(String(localized: "Drop to track this repository"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.regular)
    }
}

#if DEBUG
    #Preview("Covering content underneath") {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            ForEach(0 ..< 12, id: \.self) { index in
                Text(verbatim: "A repository row that should be hidden \(index)")
                    .font(.callout)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(AppSpacing.regular)
        .overlay {
            RepositoryDropTargetView()
        }
        .frame(width: 620, height: 460)
    }

    #Preview("Narrow and short") {
        RepositoryDropTargetView()
            .frame(width: 240, height: 180)
    }
#endif

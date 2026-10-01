import SwiftUI

struct SnakeProgressView: View {
    // MARK: - Constants

    private enum Constants {
        static let defaultSize: CGFloat = 13
        static let lineWidth: CGFloat = 2
        static let shortestBody: CGFloat = 0.06
        static let restingBody: CGFloat = 0.25
        static let chaseDuration: Double = 1.1
        static let turnDuration: Double = 2.4
        static let pulseDuration: Double = 1.2
        static let dimmedOpacity: Double = 0.3
        static let fullTurn: Double = 360
    }

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State

    @State private var head: CGFloat = Constants.shortestBody
    @State private var tail: CGFloat = 0
    @State private var turn: Double = 0
    @State private var isDimmed = false

    // MARK: - Inputs

    var size: CGFloat = Constants.defaultSize

    // MARK: - View

    var body: some View {
        arc
            .frame(width: size, height: size)
            .onAppear(perform: startAnimating)
            .onChange(of: reduceMotion) { _, _ in
                startAnimating()
            }
            .accessibilityHidden(true)
    }

    // MARK: - Arc

    @ViewBuilder
    private var arc: some View {
        if reduceMotion {
            Circle()
                .trim(from: 0, to: Constants.restingBody)
                .stroke(.tint, style: strokeStyle)
                .opacity(isDimmed ? Constants.dimmedOpacity : 1)
        } else {
            Circle()
                .trim(from: tail, to: head)
                .stroke(.tint, style: strokeStyle)
                .rotationEffect(.degrees(turn))
        }
    }

    // MARK: - Helpers

    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: Constants.lineWidth, lineCap: .round)
    }

    private func startAnimating() {
        guard reduceMotion == false else {
            withAnimation(.easeInOut(duration: Constants.pulseDuration).repeatForever(autoreverses: true)) {
                isDimmed = true
            }

            return
        }

        withAnimation(.easeOut(duration: Constants.chaseDuration).repeatForever(autoreverses: false)) {
            head = 1
        }

        withAnimation(.easeIn(duration: Constants.chaseDuration).repeatForever(autoreverses: false)) {
            tail = 1 - Constants.shortestBody
        }

        withAnimation(.linear(duration: Constants.turnDuration).repeatForever(autoreverses: false)) {
            turn = Constants.fullTurn
        }
    }
}

#if DEBUG
    #Preview("Beside text, as the badge uses it") {
        HStack(spacing: AppSpacing.xsmall) {
            SnakeProgressView()

            Text(verbatim: "Reading")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.regular)
    }

    #Preview("Larger, so the chase is visible") {
        SnakeProgressView(size: 96)
            .padding(AppSpacing.xlarge)
    }
#endif

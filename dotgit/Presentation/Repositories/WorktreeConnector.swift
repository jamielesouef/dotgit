import SwiftUI

struct WorktreeConnector: Shape {
    // MARK: - Constants

    private enum Constants {
        static let elbowHeight: CGFloat = 9
    }

    // MARK: - Inputs

    let isLast: Bool

    // MARK: - Shape

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let elbow = min(Constants.elbowHeight, rect.maxY)

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: isLast ? elbow : rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: elbow))
        path.addLine(to: CGPoint(x: rect.maxX, y: elbow))

        return path
    }
}

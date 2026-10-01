import SwiftUI

struct MirroredToggle: View {
    // MARK: - State

    @State private var isOn = false

    // MARK: - Input

    let title: String
    let value: Bool
    let onValueChange: (Bool) -> Void

    // MARK: - View

    var body: some View {
        Toggle(title, isOn: $isOn)
            .onChange(of: value, initial: true) {
                isOn = value
            }
            .onChange(of: isOn) {
                onValueChange(isOn)
            }
    }
}

#if DEBUG
    #Preview("On and off") {
        Form {
            MirroredToggle(title: "Show Derived Data in the review", value: true) { _ in }
            MirroredToggle(title: "Show Simulator runtimes in the review", value: false) { _ in }
        }
        .formStyle(.grouped)
    }

    #Preview("Long text") {
        Form {
            MirroredToggle(
                title: "Show every Simulator runtime in the review, including ones an installed Xcode still depends on",
                value: true
            ) { _ in }
        }
        .formStyle(.grouped)
    }

    #Preview("Owner stores the change") {
        @Previewable @State var stored = false

        Form {
            MirroredToggle(title: "Show Derived Data in the review", value: stored) { stored = $0 }

            Text(verbatim: "Stored: \(stored)")
                .font(.caption)
        }
        .formStyle(.grouped)
    }
#endif

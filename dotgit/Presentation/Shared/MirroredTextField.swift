import SwiftUI

struct MirroredTextField<Value: Equatable>: View {
    // MARK: - State

    @State private var text = ""

    // MARK: - Input

    let placeholder: String
    let value: Value
    let format: (Value) -> String
    let parse: (String) -> Value
    let onValueChange: (Value) -> Void

    // MARK: - View

    var body: some View {
        TextField(placeholder, text: $text)
            .onChange(of: value, initial: true) {
                guard let replacement = TextFieldMirrorUseCase.replacementText(
                    for: value,
                    current: text,
                    parse: parse,
                    format: format
                ) else {
                    return
                }

                text = replacement
            }
            .onChange(of: text) {
                guard let changed = TextFieldMirrorUseCase.changedValue(from: text, current: value, parse: parse) else {
                    return
                }

                onValueChange(changed)
            }
    }
}

// MARK: - Plain text

extension MirroredTextField where Value == String {
    init(_ placeholder: String, value: String, onValueChange: @escaping (String) -> Void) {
        self.init(
            placeholder: placeholder,
            value: value,
            format: { $0 },
            parse: { $0 },
            onValueChange: onValueChange
        )
    }
}

#if DEBUG
    #Preview("Plain and empty") {
        @Previewable @State var path = "Developer/work/dotgit"
        @Previewable @State var empty = ""

        Form {
            MirroredTextField("dotgit", value: path) { path = $0 }
                .textFieldStyle(.roundedBorder)
            MirroredTextField("dotgit", value: empty) { empty = $0 }
                .textFieldStyle(.roundedBorder)
        }
        .formStyle(.grouped)
    }

    #Preview("List keeps a trailing comma while typing") {
        @Previewable @State var names = ["API_HOST", "API_TOKEN"]

        Form {
            MirroredTextField(
                placeholder: "API_HOST, API_TOKEN",
                value: names,
                format: ReadinessFieldUseCase.text(for:),
                parse: ReadinessFieldUseCase.names(from:)
            ) { names = $0 }
                .textFieldStyle(.roundedBorder)

            Text(verbatim: names.joined(separator: " | "))
                .font(.caption)
        }
        .formStyle(.grouped)
    }

    #Preview("Long text") {
        @Previewable @State var path = "Developer/clients/a-client-with-a-very-long-name/mobile/ios/the-main-app-repository"

        Form {
            MirroredTextField("repository", value: path) { path = $0 }
                .textFieldStyle(.roundedBorder)
        }
        .formStyle(.grouped)
        .frame(width: 360)
    }
#endif

import Foundation

enum TextFieldMirrorUseCase {
    // MARK: - Inbound

    static func replacementText<Value: Equatable>(
        for value: Value,
        current text: String,
        parse: (String) -> Value,
        format: (Value) -> String
    ) -> String? {
        guard parse(text) != value else {
            return nil
        }

        return format(value)
    }

    // MARK: - Outbound

    static func changedValue<Value: Equatable>(
        from text: String,
        current value: Value,
        parse: (String) -> Value
    ) -> Value? {
        let parsed = parse(text)

        guard parsed != value else {
            return nil
        }

        return parsed
    }
}

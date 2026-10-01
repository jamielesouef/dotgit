import Testing
@testable import dotgit

@Suite("TextFieldMirrorUseCase", .tags(.domain))
struct TextFieldMirrorUseCaseTests {
    // MARK: - Inbound

    @Test("leaves the text alone when it already means the stored value")
    func keepsEquivalentText() {
        let replacement = TextFieldMirrorUseCase.replacementText(
            for: ["API_HOST"],
            current: "API_HOST, ",
            parse: ReadinessFieldUseCase.names(from:),
            format: ReadinessFieldUseCase.text(for:)
        )

        #expect(replacement == nil)
    }

    @Test("replaces the text when the stored value changed elsewhere")
    func replacesStaleText() {
        let replacement = TextFieldMirrorUseCase.replacementText(
            for: ["API_HOST", "API_TOKEN"],
            current: "API_HOST",
            parse: ReadinessFieldUseCase.names(from:),
            format: ReadinessFieldUseCase.text(for:)
        )

        #expect(replacement == "API_HOST, API_TOKEN")
    }

    // MARK: - Outbound

    @Test("sends nothing when the text still means the stored value")
    func sendsNothingForEquivalentText() {
        let changed = TextFieldMirrorUseCase.changedValue(
            from: "",
            current: String?.none,
            parse: ReadinessFieldUseCase.optionalValue(from:)
        )

        #expect(changed == nil)
    }

    @Test("sends the parsed value when the text means something new")
    func sendsNewValue() {
        let changed = TextFieldMirrorUseCase.changedValue(
            from: "README.md",
            current: String?.none,
            parse: ReadinessFieldUseCase.optionalValue(from:)
        )

        #expect(changed == .some("README.md"))
    }
}

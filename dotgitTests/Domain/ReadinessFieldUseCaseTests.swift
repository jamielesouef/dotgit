import Testing
@testable import dotgit

@Suite("ReadinessFieldUseCase", .tags(.domain))
struct ReadinessFieldUseCaseTests {
    // MARK: - Optional text

    @Test("an empty field stores no path")
    func emptyTextIsNil() {
        #expect(ReadinessFieldUseCase.optionalValue(from: "") == nil)
        #expect(ReadinessFieldUseCase.text(for: String?.none) == "")
    }

    @Test("a path round-trips unchanged")
    func pathRoundTrips() {
        #expect(ReadinessFieldUseCase.optionalValue(from: "docs/SETUP.md") == "docs/SETUP.md")
        #expect(ReadinessFieldUseCase.text(for: "docs/SETUP.md") == "docs/SETUP.md")
    }

    // MARK: - Comma-separated list

    @Test("splits on commas, trims, and drops empty names")
    func parsesNames() {
        #expect(ReadinessFieldUseCase.names(from: " API_HOST ,, API_TOKEN, ") == ["API_HOST", "API_TOKEN"])
    }

    @Test("joins names with a comma and a space")
    func formatsNames() {
        #expect(ReadinessFieldUseCase.text(for: ["API_HOST", "API_TOKEN"]) == "API_HOST, API_TOKEN")
        #expect(ReadinessFieldUseCase.text(for: [String]()) == "")
    }
}

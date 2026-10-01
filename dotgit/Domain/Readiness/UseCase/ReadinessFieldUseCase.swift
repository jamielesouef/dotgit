import Foundation

enum ReadinessFieldUseCase {
    // MARK: - Optional text

    static func text(for value: String?) -> String {
        value ?? ""
    }

    static func optionalValue(from text: String) -> String? {
        text.isEmpty ? nil : text
    }

    // MARK: - Comma-separated list

    static func text(for names: [String]) -> String {
        names.joined(separator: ", ")
    }

    static func names(from text: String) -> [String] {
        text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.isEmpty == false }
    }
}

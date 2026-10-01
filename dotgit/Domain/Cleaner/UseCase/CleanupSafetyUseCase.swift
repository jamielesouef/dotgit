import Foundation

enum CleanupSafetyUseCase {
    private static let protectedPathFragments = [
        "/applications/xcode",
        "xcode.app/",
        "xcode-beta.app/",
        "/library/developer/commandlinetools",
        "/system/",
        "/library/developer/sdks"
    ]

    static func isDeletable(path: String) -> Bool {
        let lowercased = path.lowercased()

        guard lowercased.hasSuffix("/") == false || lowercased.count > 1 else {
            return false
        }
        guard lowercased != "/", lowercased.isEmpty == false else {
            return false
        }
        guard lowercased.contains(".app/contents/developer") == false else {
            return false
        }

        return protectedPathFragments.contains { lowercased.contains($0) } == false
    }

    static func isDeletable(_ entry: DerivedDataEntry) -> Bool {
        isDeletable(path: entry.url.path(percentEncoded: false))
    }

    static func isDeletable(_ runtime: SimulatorRuntime) -> Bool {
        guard runtime.isDeletable else {
            return false
        }
        guard let path = runtime.path else {
            return true
        }

        return isDeletable(path: path)
    }
}

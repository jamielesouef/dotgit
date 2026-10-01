import Testing
@testable import dotgit

@Suite("GitStatusParser", .tags(.data))
struct GitStatusParserTests {
    @Test("separates untracked paths from tracked changes")
    func separatesUntracked() {
        let output = " M Sources/App.swift\0?? Notes.md\0"
        let status = GitStatusParser.parse(porcelainZ: output)

        #expect(status.trackedChanges == [GitFileChange(path: "Sources/App.swift", status: .modified)])
        #expect(status.untrackedPaths == ["Notes.md"])
    }

    @Test("records a deletion as a tracked change so a WIP commit can include it")
    func recordsDeletion() {
        let status = GitStatusParser.parse(porcelainZ: " D Removed.swift\0")

        #expect(status.trackedChanges == [GitFileChange(path: "Removed.swift", status: .deleted)])
    }

    @Test("reads the original path that follows a rename entry")
    func readsRenameOriginal() {
        let status = GitStatusParser.parse(porcelainZ: "R  New.swift\0Old.swift\0 M Other.swift\0")

        #expect(status.trackedChanges.first == GitFileChange(
            path: "New.swift",
            status: .renamed,
            originalPath: "Old.swift"
        ))
        #expect(status.trackedChanges.count == 2)
        #expect(status.trackedChanges.last?.path == "Other.swift")
    }

    @Test("reports a conflict rather than the nearest-fit change", arguments: ["UU", "AA", "DU"])
    func reportsConflict(code: String) {
        let status = GitStatusParser.parse(porcelainZ: "\(code) Conflicted.swift\0")

        #expect(status.trackedChanges.first?.status == .conflicted)
    }

    @Test("ignores entries git marked as ignored")
    func ignoresIgnoredEntries() {
        let status = GitStatusParser.parse(porcelainZ: "!! build/output.o\0")

        #expect(status.isClean)
    }

    @Test("treats empty output as a clean working tree")
    func treatsEmptyAsClean() {
        #expect(GitStatusParser.parse(porcelainZ: "") == .clean)
    }
}

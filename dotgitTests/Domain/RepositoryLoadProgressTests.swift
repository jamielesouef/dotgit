import Foundation
import Testing
@testable import dotgit

@Suite("RepositoryLoadProgress", .tags(.domain))
struct RepositoryLoadProgressTests {
    @Test("has no fraction to show before it knows how many repositories there are")
    func hasNoFractionWhileOpening() {
        #expect(RepositoryLoadProgress.opening.fractionCompleted == nil)
        #expect(RepositoryLoadProgress.opening.detail == nil)
    }

    @Test("tracks which repositories are being read and how many are done")
    func tracksReadingAndCompleted() {
        let progress = RepositoryLoadProgress.starting(total: 4)
            .startingToRead("app")
            .startingToRead("web")
            .finishedReading("app")

        #expect(progress.completed == 1)
        #expect(progress.reading == ["web"])
        #expect(progress.fractionCompleted == 0.25)
    }

    @Test("removes one reading entry when two repositories share a name")
    func removesOneOfTwoSameNames() {
        let progress = RepositoryLoadProgress.starting(total: 2)
            .startingToRead("app")
            .startingToRead("app")
            .finishedReading("app")

        #expect(progress.reading == ["app"])
    }

    @Test("never counts past the total")
    func neverCountsPastTotal() {
        let progress = RepositoryLoadProgress.starting(total: 1)
            .finishedReading("app")
            .finishedReading("app")

        #expect(progress.completed == 1)
        #expect(progress.fractionCompleted == 1)
    }
}

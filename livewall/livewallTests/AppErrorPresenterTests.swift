import Testing
@testable import livewall

@MainActor
struct AppErrorPresenterTests {

    @Test
    func dedupsIdenticalErrors() {
        let presenter = AppErrorPresenter()
        let error = AppError(title: "Boom", message: "Something failed", recoverySuggestion: nil)

        presenter.present(error)
        let firstID = presenter.currentError?.id

        presenter.present(error)
        let secondID = presenter.currentError?.id

        // Same identity instance — dedup short-circuited the second present.
        #expect(firstID != nil)
        #expect(firstID == secondID)
    }

    @Test
    func presentsDistinctErrors() {
        let presenter = AppErrorPresenter()
        let first = AppError(title: "A", message: "alpha", recoverySuggestion: nil)
        let second = AppError(title: "B", message: "beta", recoverySuggestion: nil)

        presenter.present(first)
        let firstID = presenter.currentError?.id

        presenter.present(second)
        let secondID = presenter.currentError?.id

        #expect(firstID != nil)
        #expect(secondID != nil)
        #expect(firstID != secondID)
        #expect(presenter.currentError?.title == "B")
    }

    @Test
    func allowsRepresentAfterDismiss() {
        let presenter = AppErrorPresenter()
        let error = AppError(title: "Same", message: "again", recoverySuggestion: nil)

        presenter.present(error)
        #expect(presenter.currentError != nil)

        presenter.dismiss()
        #expect(presenter.currentError == nil)

        presenter.present(error)
        #expect(presenter.currentError != nil)
        #expect(presenter.currentError?.title == "Same")
    }
}

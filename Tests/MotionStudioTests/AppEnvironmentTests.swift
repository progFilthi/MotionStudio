import XCTest
@testable import MotionStudio

/// Tests for the application-level error-reporting path.
@MainActor
final class AppEnvironmentTests: XCTestCase {
    private struct SampleLocalizedError: LocalizedError {
        let errorDescription: String?
        let failureReason: String?
    }

    private struct SamplePlainError: Error {}

    func testReportingLocalizedErrorShowsItsWording() {
        let environment = AppEnvironment()
        let error = SampleLocalizedError(
            errorDescription: "Import failed",
            failureReason: "The file could not be read."
        )

        environment.report(error, while: "importing media")

        XCTAssertEqual(environment.presentedError?.title, "Import failed")
        XCTAssertEqual(environment.presentedError?.message, "The file could not be read.")
    }

    func testReportingPlainErrorShowsFallbackWording() {
        let environment = AppEnvironment()

        environment.report(SamplePlainError(), while: "testing")

        XCTAssertEqual(environment.presentedError?.title, "Something went wrong")
        XCTAssertFalse(environment.presentedError?.message.isEmpty ?? true)
    }

    func testIsPresentingErrorTracksPresentation() {
        let environment = AppEnvironment()

        XCTAssertFalse(environment.isPresentingError)
        environment.report(SamplePlainError(), while: "testing")
        XCTAssertTrue(environment.isPresentingError)
    }

    func testDismissClearsPresentation() {
        let environment = AppEnvironment()
        environment.report(SamplePlainError(), while: "testing")

        environment.dismissError()

        XCTAssertNil(environment.presentedError)
        XCTAssertFalse(environment.isPresentingError)
    }

    func testAlertVisibilityBindingCanOnlyDismiss() {
        let environment = AppEnvironment()
        environment.report(SamplePlainError(), while: "testing")

        // Setting the binding to `true` must not create an empty
        // presentation; presentations are created only by `report`.
        environment.isPresentingError = true
        XCTAssertNotNil(environment.presentedError)

        environment.isPresentingError = false
        XCTAssertNil(environment.presentedError)
    }
}

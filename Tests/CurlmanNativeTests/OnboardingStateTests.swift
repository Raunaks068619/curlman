import XCTest
@testable import CurlmanNative

@MainActor
final class OnboardingStateTests: XCTestCase {
    func testNewInstallationCanCompleteOnboarding() throws {
        let defaults = try makeDefaults()
        let state = OnboardingState(defaults: defaults)

        XCTAssertFalse(state.isComplete)
        state.complete()
        XCTAssertTrue(OnboardingState(defaults: defaults).isComplete)
    }

    func testExistingInstallationIsNotForcedThroughOnboarding() throws {
        let defaults = try makeDefaults()
        let state = OnboardingState(defaults: defaults)

        state.prepareForLaunch(isExistingInstallation: true)

        XCTAssertTrue(state.isComplete)
    }

    func testWelcomeCanBeShownAgain() throws {
        let defaults = try makeDefaults()
        let state = OnboardingState(defaults: defaults)
        state.complete()

        state.startOver()

        XCTAssertFalse(state.isComplete)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "OnboardingStateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

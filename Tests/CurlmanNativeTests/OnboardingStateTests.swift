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

    func testTwoPageNavigationIsDeterministic() throws {
        let state = OnboardingState(defaults: try makeDefaults())

        XCTAssertEqual(state.page, .introduction)
        state.continueToSetup()
        XCTAssertEqual(state.page, .setup)
        state.returnToIntroduction()
        XCTAssertEqual(state.page, .introduction)
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
        XCTAssertEqual(state.page, .introduction)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "OnboardingStateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

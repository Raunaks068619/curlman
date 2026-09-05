import XCTest
@testable import CurlmanNative

@MainActor
final class OnboardingStateTests: XCTestCase {
    func testNewInstallationCompletesLearnByDoingFlow() throws {
        let defaults = try makeDefaults()
        let state = OnboardingState(defaults: defaults)

        XCTAssertFalse(state.isComplete)
        XCTAssertEqual(state.currentStep, .welcome)

        state.continueFromWelcome()
        XCTAssertEqual(state.currentStep, .shortcut)

        state.recordShortcutInvocation(panelWasVisible: true)
        XCTAssertTrue(state.didHideWithShortcut)
        XCTAssertEqual(state.currentStep, .shortcut)

        state.recordShortcutInvocation(panelWasVisible: false)
        XCTAssertEqual(state.currentStep, .request)

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
        XCTAssertEqual(state.currentStep, .welcome)
        XCTAssertFalse(state.didHideWithShortcut)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "OnboardingStateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

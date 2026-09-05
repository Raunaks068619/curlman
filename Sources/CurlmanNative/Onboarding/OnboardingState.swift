import Foundation

enum OnboardingPage: Int, CaseIterable, Sendable {
    case introduction
    case setup
}

@MainActor
final class OnboardingState: ObservableObject {
    @Published private(set) var isComplete: Bool
    @Published private(set) var page: OnboardingPage = .introduction

    private static let completionKey = "onboardingCompletedV1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isComplete = defaults.bool(forKey: Self.completionKey)
    }

    func prepareForLaunch(isExistingInstallation: Bool) {
        guard defaults.object(forKey: Self.completionKey) == nil,
              isExistingInstallation else { return }
        complete()
    }

    func complete() {
        isComplete = true
        defaults.set(true, forKey: Self.completionKey)
    }

    func continueToSetup() {
        page = .setup
    }

    func returnToIntroduction() {
        page = .introduction
    }

    func startOver() {
        page = .introduction
        isComplete = false
        defaults.set(false, forKey: Self.completionKey)
    }
}

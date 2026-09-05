import Foundation

@MainActor
final class OnboardingState: ObservableObject {
    @Published private(set) var isComplete: Bool

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

    func startOver() {
        isComplete = false
        defaults.set(false, forKey: Self.completionKey)
    }
}

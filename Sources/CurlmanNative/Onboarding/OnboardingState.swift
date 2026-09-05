import Foundation

enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome
    case shortcut
    case request
}

@MainActor
final class OnboardingState: ObservableObject {
    @Published private(set) var isComplete: Bool
    @Published private(set) var currentStep: OnboardingStep = .welcome
    @Published private(set) var didHideWithShortcut = false

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

    func continueFromWelcome() {
        guard !isComplete else { return }
        currentStep = .shortcut
    }

    func recordShortcutInvocation(panelWasVisible: Bool) {
        guard !isComplete, currentStep == .shortcut else { return }
        if panelWasVisible {
            didHideWithShortcut = true
        } else if didHideWithShortcut {
            currentStep = .request
        }
    }

    func complete() {
        isComplete = true
        defaults.set(true, forKey: Self.completionKey)
    }

    func startOver() {
        isComplete = false
        currentStep = .welcome
        didHideWithShortcut = false
        defaults.set(false, forKey: Self.completionKey)
    }
}

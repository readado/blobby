import SwiftUI

struct GameBanner: Equatable {
    enum Kind {
        case info
        case warning
        case success
        case danger
    }

    let text: String
    let kind: Kind
}

final class GameModel: ObservableObject {
    private let defaults: UserDefaults
    @Published var contentmentValue: Double = 0.55
    @Published var contentmentText = "content"
    @Published var lives = 3
    @Published var snacksEaten = 0
    @Published var predatorsAvoided = 0
    @Published var snacksTowardHeart = 0
    @Published var bestSnacks: Int
    @Published var bestAvoided: Int
    let snacksPerHeart = 50
    @Published var banner: GameBanner?
    @Published var isGameOver = false
    @Published var isSettingsPresented = false
    @Published var isTutorialPresented: Bool
    @Published var isAppActive = true

    var isGameplayPaused: Bool {
        !isAppActive || isTutorialPresented || isSettingsPresented || isGameOver
    }

    /// Shows on-screen move / shelter / snack / puff controls. Defaults on when
    /// VoiceOver or Switch Control is running; always available from Settings.
    @Published var assistiveControlsEnabled: Bool {
        didSet { defaults.set(assistiveControlsEnabled, forKey: "assistiveControlsEnabled") }
    }

    @Published var soundEnabled: Bool {
        didSet {
            defaults.set(soundEnabled, forKey: "soundEnabled")
            GameFeedback.shared.updatePreferences(soundEnabled: soundEnabled, hapticsEnabled: hapticsEnabled)
        }
    }

    @Published var hapticsEnabled: Bool {
        didSet {
            defaults.set(hapticsEnabled, forKey: "hapticsEnabled")
            GameFeedback.shared.updatePreferences(soundEnabled: soundEnabled, hapticsEnabled: hapticsEnabled)
        }
    }

    @Published var calmMotionEnabled: Bool {
        didSet {
            defaults.set(calmMotionEnabled, forKey: "calmMotionEnabled")
        }
    }

    var restartAction: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        bestSnacks = defaults.integer(forKey: "bestSnacks")
        bestAvoided = defaults.integer(forKey: "bestAvoided")
        soundEnabled = defaults.object(forKey: "soundEnabled") as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: "hapticsEnabled") as? Bool ?? true
        calmMotionEnabled = defaults.object(forKey: "calmMotionEnabled") as? Bool ?? UIAccessibility.isReduceMotionEnabled
        let a11yControlsPreferred = UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning
        assistiveControlsEnabled = defaults.object(forKey: "assistiveControlsEnabled") as? Bool ?? a11yControlsPreferred
        // Once-only onboarding; Settings → How to play can reopen it.
        #if DEBUG
        if ProcessInfo.processInfo.environment["BLOBBY_FORCE_TUTORIAL"] == "1" {
            isTutorialPresented = true
        } else {
            isTutorialPresented = !defaults.bool(forKey: "didSeeBlobbyTutorialV2")
        }
        #else
        isTutorialPresented = !defaults.bool(forKey: "didSeeBlobbyTutorialV2")
        #endif
    }

    func dismissTutorial() {
        defaults.set(true, forKey: "didSeeBlobbyTutorialV2")
        isTutorialPresented = false
    }

    func presentTutorial() {
        isSettingsPresented = false
        isTutorialPresented = true
    }

    /// When the system Reduce Motion setting turns on, force Calm Motion.
    /// Turning Reduce Motion off leaves the player's Calm Motion preference alone.
    func applySystemReduceMotion(_ reduceMotion: Bool) {
        if reduceMotion, !calmMotionEnabled {
            calmMotionEnabled = true
        }
    }

    func restart() {
        restartAction?()
    }

    func saveRecords() {
        bestSnacks = max(bestSnacks, snacksEaten)
        bestAvoided = max(bestAvoided, predatorsAvoided)
        defaults.set(bestSnacks, forKey: "bestSnacks")
        defaults.set(bestAvoided, forKey: "bestAvoided")
    }
}

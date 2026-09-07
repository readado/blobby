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
        isTutorialPresented = !defaults.bool(forKey: "didSeeBlobbyTutorialV2")
    }

    func dismissTutorial() {
        defaults.set(true, forKey: "didSeeBlobbyTutorialV2")
        isTutorialPresented = false
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

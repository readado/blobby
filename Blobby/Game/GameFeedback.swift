import AVFoundation
import UIKit

final class GameFeedback {
    static let shared = GameFeedback()

    private var ambiencePlayer: AVAudioPlayer?
    private var effectPlayers: [AVAudioPlayer] = []
    private var soundEnabled = true
    private var hapticsEnabled = true
    private var isAppActive = true
    #if DEBUG
    private(set) var deathHapticCount = 0
    #endif

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func startAmbience() {
        guard soundEnabled, isAppActive,
              ambiencePlayer?.isPlaying != true,
              let url = Bundle.main.url(forResource: "deep_ambience", withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.numberOfLoops = -1
        player.volume = 0.22
        player.prepareToPlay()
        player.play()
        ambiencePlayer = player
    }

    func ateFood() {
        play("eat", volume: 0.55)
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55)
        }
    }

    func predatorWarning() {
        play("predator_warning", volume: 0.5)
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    func closeCall() {
        play("close_call", volume: 0.62)
        if hapticsEnabled && isAppActive {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.8)
        }
    }

    func gameOver() {
        play("close_call", volume: 0.62)
        guard hapticsEnabled, isAppActive else { return }
        // A system error pattern distinguishes the final life from a close call.
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #if DEBUG
        deathHapticCount += 1
        #endif
    }

    func setAppActive(_ active: Bool) {
        isAppActive = active
        if active {
            startAmbience()
        } else {
            ambiencePlayer?.pause()
            effectPlayers.forEach { $0.stop() }
            effectPlayers.removeAll()
        }
    }

    func reachedSafety() {
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.35)
        }
    }

    func restarted() {
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.45)
        }
    }

    func updatePreferences(soundEnabled: Bool, hapticsEnabled: Bool) {
        self.soundEnabled = soundEnabled
        self.hapticsEnabled = hapticsEnabled
        if soundEnabled {
            startAmbience()
        } else {
            ambiencePlayer?.stop()
            effectPlayers.forEach { $0.stop() }
            effectPlayers.removeAll()
        }
    }

    private func play(_ name: String, volume: Float) {
        guard soundEnabled, isAppActive else { return }
        effectPlayers.removeAll { !$0.isPlaying }
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.volume = volume
        player.prepareToPlay()
        player.play()
        effectPlayers.append(player)
    }
}

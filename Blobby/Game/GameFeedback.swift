import AVFoundation
import CoreHaptics
import UIKit

final class GameFeedback {
    static let shared = GameFeedback()

    private var ambiencePlayer: AVAudioPlayer?
    // Small round-robin pools of preloaded players, so rapid eating never
    // allocates an AVAudioPlayer mid-game and overlapping bites still mix.
    private var effectPools: [String: [AVAudioPlayer]] = [:]
    private var effectPoolCursor: [String: Int] = [:]
    private static let pooledEffects = ["eat", "predator_warning", "close_call"]
    private var soundEnabled = true
    private var hapticsEnabled = true
    private var isAppActive = true
    private var didWarmUp = false
    private var warmUpScheduled = false

    // Prepared once so the first beat of a pattern is never dropped by a
    // just-allocated generator.
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let notifier = UINotificationFeedbackGenerator()
    private var hapticEngine: CHHapticEngine?

    #if DEBUG
    private(set) var deathHapticCount = 0
    #endif

    private init() {
        // Category only here. Do not preload WAV pools or start Core Haptics
        // on the first frame — that was stalling launch on device.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }

    /// Decode effect WAVs + spin up haptics after the first frames have drawn.
    func warmUpIfNeeded() {
        guard !didWarmUp, !warmUpScheduled else { return }
        warmUpScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.didWarmUp else { return }
            self.didWarmUp = true
            Self.pooledEffects.forEach { _ = self.poolFor($0) }
            self.prepareHaptics()
        }
    }

    private func prepareHaptics() {
        softImpact.prepare()
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        rigidImpact.prepare()
        notifier.prepare()

        #if targetEnvironment(simulator)
        // The simulator reports haptic capability but cannot play patterns
        // ("Player start failed" 2003329396); the UIKit generator fallback
        // covers gameOver() there. A physical iPhone takes the engine path.
        #else
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        if hapticEngine == nil {
            hapticEngine = try? CHHapticEngine()
            hapticEngine?.resetHandler = { [weak self] in
                try? self?.hapticEngine?.start()
            }
        }
        try? hapticEngine?.start()
        #endif
    }

    func startAmbience() {
        guard soundEnabled, isAppActive,
              ambiencePlayer?.isPlaying != true,
              let url = Bundle.main.url(forResource: "deep_ambience", withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        player.numberOfLoops = -1
        player.volume = 0.22
        player.prepareToPlay()
        player.play()
        ambiencePlayer = player
    }

    func pauseAmbience() {
        ambiencePlayer?.pause()
    }

    func ateFood() {
        warmUpIfNeeded()
        play("eat", volume: 0.55)
        if hapticsEnabled {
            softImpact.impactOccurred(intensity: 0.55)
        }
    }

    func predatorWarning() {
        warmUpIfNeeded()
        play("predator_warning", volume: 0.5)
        if hapticsEnabled {
            notifier.notificationOccurred(.warning)
        }
    }

    func closeCall() {
        warmUpIfNeeded()
        play("close_call", volume: 0.62)
        if hapticsEnabled && isAppActive {
            heavyImpact.impactOccurred(intensity: 0.8)
        }
    }

    func gameOver() {
        warmUpIfNeeded()
        play("close_call", volume: 0.62)
        guard hapticsEnabled, isAppActive else { return }
        playDeathPattern()
        #if DEBUG
        deathHapticCount += 1
        #endif
    }

    /// Three-beat death pattern: heavy hit, rigid echo, then a decaying rumble.
    /// Core Haptics preferred; falls back to a scheduled UIKit generator
    /// sequence when the engine is unavailable or fails to start.
    private func playDeathPattern() {
        if let engine = hapticEngine, (try? engine.start()) != nil,
           let pattern = try? CHHapticPattern(events: [
               CHHapticEvent(eventType: .hapticTransient, parameters: [
                   CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                   CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
               ], relativeTime: 0),
               CHHapticEvent(eventType: .hapticTransient, parameters: [
                   CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                   CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
               ], relativeTime: 0.12),
               CHHapticEvent(eventType: .hapticContinuous, parameters: [
                   CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                   CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25),
                   CHHapticEventParameter(parameterID: .attackTime, value: 0.02),
                   CHHapticEventParameter(parameterID: .decayTime, value: 0.38),
                   CHHapticEventParameter(parameterID: .sustained, value: 0)
               ], relativeTime: 0.28, duration: 0.4)
           ], parameters: []),
           let player = try? engine.makePlayer(with: pattern),
           (try? player.start(atTime: CHHapticTimeImmediate)) != nil {
            return
        }

        heavyImpact.impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self, self.hapticsEnabled, self.isAppActive else { return }
            self.rigidImpact.impactOccurred(intensity: 0.7)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak self] in
            guard let self, self.hapticsEnabled, self.isAppActive else { return }
            self.notifier.notificationOccurred(.error)
        }
    }

    /// Single soft bump when the triple-shake puff activates.
    func puffed() {
        warmUpIfNeeded()
        if hapticsEnabled && isAppActive {
            mediumImpact.impactOccurred(intensity: 0.6)
        }
    }

    func setAppActive(_ active: Bool) {
        isAppActive = active
        if !active {
            ambiencePlayer?.pause()
            stopEffects()
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }

    func reachedSafety() {
        warmUpIfNeeded()
        if hapticsEnabled {
            lightImpact.impactOccurred(intensity: 0.35)
        }
    }

    func restarted() {
        warmUpIfNeeded()
        if hapticsEnabled {
            softImpact.impactOccurred(intensity: 0.45)
        }
    }

    func updatePreferences(soundEnabled: Bool, hapticsEnabled: Bool) {
        self.soundEnabled = soundEnabled
        self.hapticsEnabled = hapticsEnabled
        if hapticsEnabled {
            warmUpIfNeeded()
        }
        if soundEnabled, isAppActive {
            // Caller decides when ambience is appropriate (not during heavy launch).
        } else {
            ambiencePlayer?.stop()
            ambiencePlayer = nil
            stopEffects()
        }
    }

    private func stopEffects() {
        effectPools.values.flatMap { $0 }.forEach { $0.stop() }
    }

    private func play(_ name: String, volume: Float) {
        guard soundEnabled, isAppActive else { return }
        let pool = poolFor(name)
        guard !pool.isEmpty else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        let index = (effectPoolCursor[name] ?? 0) % pool.count
        effectPoolCursor[name] = index + 1
        let player = pool[index]
        if player.isPlaying {
            player.currentTime = 0
        }
        player.volume = volume
        player.play()
    }

    private func poolFor(_ name: String) -> [AVAudioPlayer] {
        if let pool = effectPools[name] { return pool }
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return [] }
        let pool = (0..<3).compactMap { _ -> AVAudioPlayer? in
            let player = try? AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            return player
        }
        effectPools[name] = pool
        return pool
    }
}

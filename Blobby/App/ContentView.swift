import CoreMotion
import SpriteKit
import SwiftUI

/// Detects violent device shakes via gravity-free acceleration. A peak is
/// ≥2.4g, with at least 180ms between peaks so one swing is not three.
/// Peaks are forwarded as generic pulses; the scene owns the 3-in-2.2s window.
final class ShakeDetector {
    private let motionManager = CMMotionManager()
    private var lastPeakTime: TimeInterval = 0
    var onPulse: (() -> Void)?

    func start() {
        guard motionManager.isDeviceMotionAvailable, !motionManager.isDeviceMotionActive else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let a = motion.userAcceleration
            let magnitude = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
            let now = CACurrentMediaTime()
            guard magnitude >= 2.4, now - self.lastPeakTime >= 0.18 else { return }
            self.lastPeakTime = now
            self.onPulse?()
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }
}

/// Sits invisibly over the scene purely to receive `.motionShake` events;
/// `SpriteView` is not first responder. This is the simulator/accessibility
/// shake path (Device → Shake). If Core Motion is unavailable or denied,
/// this path keeps working.
private struct ShakeCatcher: UIViewRepresentable {
    var onShake: () -> Void

    func makeUIView(context: Context) -> ShakeCatchingView {
        let view = ShakeCatchingView()
        view.onShake = onShake
        return view
    }

    func updateUIView(_ uiView: ShakeCatchingView, context: Context) {
        uiView.onShake = onShake
    }
}

private final class ShakeCatchingView: UIView {
    var onShake: (() -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            becomeFirstResponder()
        }
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            onShake?()
        }
        super.motionEnded(motion, with: event)
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var systemTextSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var model: GameModel
    @State private var scene: GameScene
    @State private var shakeDetector = ShakeDetector()

    private var readinessViewport: CGSize? {
        #if DEBUG
        if ProcessInfo.processInfo.environment["BLOBBY_COMPACT_CHECK"] == "1" {
            return CGSize(width: 320, height: 568)
        }
        #endif
        return nil
    }

    private var textSize: DynamicTypeSize {
        #if DEBUG
        if ProcessInfo.processInfo.environment["BLOBBY_LARGE_TEXT_CHECK"] == "1" {
            return .accessibility3
        }
        #endif
        return systemTextSize
    }

    /// Show system status during modals; hide for immersive play.
    private var hideStatusBar: Bool {
        !(model.isTutorialPresented || model.isGameOver || model.isSettingsPresented)
    }

    init() {
        #if DEBUG
        // Readiness checks never overwrite the player's preferences or records.
        let verification = ProcessInfo.processInfo.environment["BLOBBY_VERIFY"] == "1"
        let model = GameModel(defaults: verification
            ? UserDefaults(suiteName: "com.example.Blobby.readiness")! : .standard)
        #else
        let model = GameModel()
        #endif
        _model = StateObject(wrappedValue: model)
        _scene = State(initialValue: GameScene(model: model))
    }

    var body: some View {
        ZStack {
            Color(red: 0.01, green: 0.04, blue: 0.09)
                .ignoresSafeArea()

            SpriteView(scene: scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()
                .accessibilityLabel("Blobby’s deep-sea habitat")
                .accessibilityHint("Drag anywhere to guide Blobby, or use the assistive actions and on-screen controls.")
                .accessibilityAction(named: "Move up") { scene.assistNudge(dx: 0, dy: 1) }
                .accessibilityAction(named: "Move down") { scene.assistNudge(dx: 0, dy: -1) }
                .accessibilityAction(named: "Move left") { scene.assistNudge(dx: -1, dy: 0) }
                .accessibilityAction(named: "Move right") { scene.assistNudge(dx: 1, dy: 0) }
                .accessibilityAction(named: "Go to shelter") { scene.assistGuideToShelter() }
                .accessibilityAction(named: "Go to nearest snack") { scene.assistGuideToNearestFood() }
                .accessibilityAction(named: "Puff up") { scene.assistPuff() }

            ShakeCatcher(onShake: { [scene] in scene.registerShakePulse() })
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            GameChromeView(model: model, scene: scene)
        }
        .frame(width: readinessViewport?.width, height: readinessViewport?.height)
        .environment(\.dynamicTypeSize, textSize)
        .persistentSystemOverlays(hideStatusBar ? .hidden : .automatic)
        .statusBarHidden(hideStatusBar)
        .onChange(of: reduceMotion, initial: true) { _, value in
            model.applySystemReduceMotion(value)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            model.isAppActive = phase == .active
            GameFeedback.shared.setAppActive(model.isAppActive)
            shakeDetector.onPulse = { [scene] in scene.registerShakePulse() }
            updateShakeDetector()
            // scene.isPaused only stops the update loop; the view itself must
            // stop rendering or Metal rejects GPU work submitted while
            // backgrounded (the IOGPUMetalError flood).
            scene.view?.isPaused = phase == .background
        }
        .onChange(of: model.isGameplayPaused, initial: true) { _, _ in
            // Pause the scene, not the view: the habitat must still draw behind overlays.
            scene.isPaused = model.isGameplayPaused
            scene.resetFrameClock()
            updateShakeDetector()
            if !model.isGameplayPaused {
                GameFeedback.shared.startAmbience()
            }
        }
    }

    /// Core Motion at 60Hz is wasted (and competes with first-frame work) while
    /// the tutorial / settings / Game Over overlays are up.
    private func updateShakeDetector() {
        if model.isAppActive, !model.isGameplayPaused {
            shakeDetector.start()
        } else {
            shakeDetector.stop()
        }
    }
}

#Preview {
    ContentView()
}

import SpriteKit
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var systemTextSize
    @StateObject private var model: GameModel
    @State private var scene: GameScene

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
                .accessibilityHint("Drag anywhere to guide Blobby toward food or the coral shelter.")

            GameChromeView(model: model)
        }
        .frame(width: readinessViewport?.width, height: readinessViewport?.height)
        .environment(\.dynamicTypeSize, textSize)
        .persistentSystemOverlays(.hidden)
        .statusBarHidden()
        .onChange(of: scenePhase, initial: true) { _, phase in
            model.isAppActive = phase == .active
            GameFeedback.shared.setAppActive(model.isAppActive)
        }
        .onChange(of: model.isGameplayPaused, initial: true) { _, _ in
            // Pause the scene, not the view: the habitat must still draw behind overlays.
            scene.isPaused = model.isGameplayPaused
            scene.resetFrameClock()
        }
    }
}

#Preview {
    ContentView()
}

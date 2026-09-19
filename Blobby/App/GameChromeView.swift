import SpriteKit
import SwiftUI

struct GameChromeView: View {
    @ObservedObject var model: GameModel
    var scene: GameScene
    @Namespace private var glassNamespace
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled

    private var showAssistivePad: Bool {
        model.assistiveControlsEnabled || voiceOverEnabled || switchControlEnabled
    }

    private var prefersSolidChrome: Bool {
        reduceTransparency || contrast == .increased
    }

    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                if !model.isTutorialPresented && !model.isGameOver {
                    topChrome
                }
                Spacer(minLength: 0)
                if !model.isTutorialPresented && !model.isGameOver && showAssistivePad {
                    AssistiveControlsPad(scene: scene, prefersSolid: prefersSolidChrome)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .safeAreaPadding(.top, 8)
            .safeAreaPadding(.bottom, 10)

            if model.isTutorialPresented {
                TutorialOverlay(model: model, prefersSolid: prefersSolidChrome)
                    .transition(overlayTransition)
            }

            if model.isGameOver {
                GameOverOverlay(model: model, prefersSolid: prefersSolidChrome)
                    .transition(overlayTransition)
            }
        }
        .animation(model.calmMotionEnabled ? nil : .smooth(duration: 0.28), value: model.isTutorialPresented)
        .animation(model.calmMotionEnabled ? nil : .smooth(duration: 0.28), value: model.isGameOver)
        .animation(model.calmMotionEnabled ? nil : .smooth(duration: 0.22), value: showAssistivePad)
        .onChange(of: reduceMotion, initial: true) { _, value in
            model.applySystemReduceMotion(value)
        }
        .onChange(of: voiceOverEnabled, initial: true) { _, enabled in
            if enabled { model.assistiveControlsEnabled = true }
        }
        .onChange(of: switchControlEnabled, initial: true) { _, enabled in
            if enabled { model.assistiveControlsEnabled = true }
        }
        .sheet(isPresented: $model.isSettingsPresented) {
            SettingsView(model: model)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var overlayTransition: AnyTransition {
        model.calmMotionEnabled
            ? .opacity
            : .opacity.combined(with: .scale(scale: 0.97))
    }

    @ViewBuilder
    private var topChrome: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                HabitatStatusView(model: model, prefersSolid: prefersSolidChrome)
                    .chromeSurface(
                        prefersSolid: prefersSolidChrome,
                        solid: Color(red: 0.03, green: 0.14, blue: 0.18).opacity(contrast == .increased ? 1 : 0.94),
                        glassTint: Color(red: 0.05, green: 0.20, blue: 0.25),
                        shape: .rect(cornerRadius: 22),
                        padding: EdgeInsets(top: 12, leading: 15, bottom: 12, trailing: 15)
                    )

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    Button {
                        scene.assistPuff()
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.body.weight(.semibold))
                            .frame(width: 48, height: 48)
                    }
                    .chromeButton(prefersSolid: prefersSolidChrome)
                    .accessibilityLabel("Puff Blobby up")
                    .accessibilityHint("Doubles Blobby’s size for a few seconds. Same as a vigorous triple shake.")

                    Button {
                        model.isSettingsPresented = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.body.weight(.semibold))
                            .frame(width: 48, height: 48)
                    }
                    .chromeButton(prefersSolid: prefersSolidChrome)
                    .accessibilityLabel("Game settings")
                }
            }

            if let banner = model.banner {
                bannerChrome(banner)
                    .transition(
                        model.calmMotionEnabled
                            ? .opacity
                            : .opacity.combined(with: .scale(scale: 0.94, anchor: .top))
                    )
            }
        }
    }

    @ViewBuilder
    private func bannerChrome(_ banner: GameBanner) -> some View {
        let content = BannerView(banner: banner)
            .chromeSurface(
                prefersSolid: prefersSolidChrome,
                solid: banner.solidFill,
                glassTint: banner.tint.opacity(0.22),
                shape: .capsule,
                padding: EdgeInsets(top: 9, leading: 14, bottom: 9, trailing: 14)
            )
        if #available(iOS 26, *), !prefersSolidChrome {
            content.glassEffectID("statusBanner", in: glassNamespace)
        } else {
            content
        }
    }
}

// MARK: - Assistive pad

private struct AssistiveControlsPad: View {
    let scene: GameScene
    var prefersSolid: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                assistButton("Shelter", systemImage: "house.fill") {
                    scene.assistGuideToShelter()
                }
                assistButton("Snack", systemImage: "fork.knife") {
                    scene.assistGuideToNearestFood()
                }
                assistButton("Puff", systemImage: "arrow.up.left.and.arrow.down.right") {
                    scene.assistPuff()
                }
            }
            HStack(spacing: 10) {
                Spacer(minLength: 0)
                VStack(spacing: 8) {
                    nudgeButton(systemImage: "chevron.up", dx: 0, dy: 1, label: "Move up")
                    HStack(spacing: 8) {
                        nudgeButton(systemImage: "chevron.left", dx: -1, dy: 0, label: "Move left")
                        nudgeButton(systemImage: "chevron.down", dx: 0, dy: -1, label: "Move down")
                        nudgeButton(systemImage: "chevron.right", dx: 1, dy: 0, label: "Move right")
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .chromeSurface(
            prefersSolid: prefersSolid,
            solid: Color(red: 0.03, green: 0.12, blue: 0.16).opacity(0.96),
            glassTint: Color(red: 0.05, green: 0.18, blue: 0.22),
            shape: .rect(cornerRadius: 24),
            padding: .init()
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Assistive Blobby controls")
    }

    private func assistButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(red: 0.94, green: 0.42, blue: 0.58))
    }

    private func nudgeButton(systemImage: String, dx: CGFloat, dy: CGFloat, label: String) -> some View {
        Button {
            scene.assistNudge(dx: dx, dy: dy)
        } label: {
            Image(systemName: systemImage)
                .font(.body.weight(.bold))
                .frame(width: 48, height: 48)
        }
        .chromeButton(prefersSolid: prefersSolid)
        .accessibilityLabel(label)
    }
}

// MARK: - Status

private struct HabitatStatusView: View {
    @ObservedObject var model: GameModel
    var prefersSolid: Bool
    @ScaledMetric(relativeTo: .body) private var heartSize: CGFloat = 15

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                statusText
                hearts
            }
            VStack(alignment: .leading, spacing: 8) {
                statusText
                hearts
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var statusText: some View {
        VStack(alignment: .leading, spacing: 5) {
            ViewThatFits(in: .horizontal) {
                Text("Blobby is \(model.contentmentText)")
                    .font(.headline)
                    .lineLimit(1)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Blobby is")
                        .font(.headline)
                    Text(model.contentmentText)
                        .font(.headline)
                }
            }
            .foregroundStyle(hudPrimary)
            .fixedSize(horizontal: false, vertical: true)

            ProgressView(value: model.contentmentValue)
                .tint(Color(red: 0.97, green: 0.43, blue: 0.61))
                .frame(maxWidth: 150)
                .accessibilityLabel("Contentment")
                .accessibilityValue("\(Int(model.contentmentValue * 100)) percent")
            if model.lives < 3 {
                Text("\(model.snacksTowardHeart)/\(model.snacksPerHeart) snacks · +1 heart")
                    .font(.caption2)
                    .foregroundStyle(hudSecondary)
                    .accessibilityLabel("Snacks needed to restore a heart: \(model.snacksPerHeart - model.snacksTowardHeart)")
            }
        }
    }

    private var hearts: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < model.lives ? "heart.fill" : "heart")
                    .foregroundStyle(Color(red: 1, green: 0.48, blue: 0.64))
            }
        }
        .font(.system(size: heartSize, weight: .semibold))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lives")
        .accessibilityValue("\(model.lives) remaining")
    }

    private var hudPrimary: Color {
        prefersSolid ? Color.primary : Color.white
    }

    private var hudSecondary: Color {
        prefersSolid ? Color.secondary : Color.white.opacity(0.85)
    }
}

private struct BannerView: View {
    let banner: GameBanner

    var body: some View {
        Label(banner.text, systemImage: banner.symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

private extension GameBanner {
    var symbol: String {
        switch kind {
        case .info: "water.waves"
        case .warning: "exclamationmark.triangle.fill"
        case .success: "checkmark.circle.fill"
        case .danger: "heart.slash.fill"
        }
    }

    var tint: Color {
        switch kind {
        case .info: .cyan
        case .warning: .orange
        case .success: .mint
        case .danger: .red
        }
    }

    var solidFill: Color {
        switch kind {
        case .info: Color(red: 0.05, green: 0.28, blue: 0.34)
        case .warning: Color(red: 0.42, green: 0.22, blue: 0.05)
        case .success: Color(red: 0.05, green: 0.32, blue: 0.24)
        case .danger: Color(red: 0.42, green: 0.10, blue: 0.14)
        }
    }
}

// MARK: - Tutorial / Game Over (sticky CTAs)

private struct TutorialOverlay: View {
    @ObservedObject var model: GameModel
    var prefersSolid: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isAccessibilityText: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
            GeometryReader { geometry in
                let cardWidth = min(420, geometry.size.width - (isAccessibilityText ? 16 : 32))
                let cardHeight = geometry.size.height - (isAccessibilityText ? 24 : 48)
                VStack(spacing: 0) {
                    ScrollView {
                        tutorialBody
                            .padding(.horizontal, isAccessibilityText ? 16 : 24)
                            .padding(.top, isAccessibilityText ? 16 : 24)
                            .padding(.bottom, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollBounceBehavior(.basedOnSize)

                    tutorialButton
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, isAccessibilityText ? 16 : 24)
                        .padding(.top, 8)
                        .padding(.bottom, isAccessibilityText ? 16 : 22)
                        .background(stickyFooterBackground)
                }
                .frame(width: cardWidth, height: cardHeight, alignment: .top)
                .chromeSurface(
                    prefersSolid: prefersSolid,
                    solid: Color(red: 0.07, green: 0.18, blue: 0.22),
                    glassTint: Color.teal.opacity(0.14),
                    shape: .rect(cornerRadius: 30),
                    padding: .init()
                )
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(isAccessibilityText ? 8 : 16)
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityElement(children: .contain)
    }

    private var tutorialBody: some View {
        VStack(alignment: .leading, spacing: isAccessibilityText ? 16 : 22) {
            Text("Welcome to the deep")
                .font(.title2.bold())
                .foregroundStyle(prefersSolid ? Color.primary : Color.white)
                .fixedSize(horizontal: false, vertical: true)

            TutorialRow(number: 1, text: "Drag anywhere, or use the on-screen controls, to guide Blobby.")
            TutorialRow(number: 2, text: "Eat the little creatures you encounter.")
            TutorialRow(number: 3, text: "Hide in the coral crevice when warned.")
            Text("Missing a heart? Eat \(model.snacksPerHeart) snacks to earn it back, up to 3 hearts. Shake the phone three times, or tap Puff, to puff Blobby up.")
                .font(.footnote)
                .foregroundStyle(prefersSolid ? Color.secondary : Color.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stickyFooterBackground: some View {
        (prefersSolid ? Color(red: 0.07, green: 0.18, blue: 0.22) : Color.black.opacity(0.35))
            .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private var tutorialButton: some View {
        if #available(iOS 26, *), !prefersSolid {
            Button("Let’s blob") {
                model.dismissTutorial()
                GameFeedback.shared.restarted()
            }
            .buttonStyle(.glassProminent)
            .tint(Color(red: 0.94, green: 0.42, blue: 0.58))
            .controlSize(.large)
        } else {
            Button("Let’s blob") {
                model.dismissTutorial()
                GameFeedback.shared.restarted()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.94, green: 0.42, blue: 0.58))
            .controlSize(.large)
        }
    }
}

private struct TutorialRow: View {
    let number: Int
    let text: String
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(minWidth: 32, minHeight: 32)
                .background(Color(red: 0.94, green: 0.42, blue: 0.58), in: Circle())
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
                .foregroundStyle(reduceTransparency ? Color.primary : Color.white)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number). \(text)")
    }
}

private struct GameOverOverlay: View {
    @ObservedObject var model: GameModel
    var prefersSolid: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.76).ignoresSafeArea()
            GeometryReader { geometry in
                let cardWidth = min(360, geometry.size.width - 48)
                let cardHeight = min(geometry.size.height - 48, geometry.size.height * 0.9)
                VStack(spacing: 0) {
                    ScrollView {
                        gameOverBody
                            .padding(.horizontal, 28)
                            .padding(.top, 28)
                            .padding(.bottom, 16)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxHeight: .infinity)

                    restartButton
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 28)
                        .padding(.top, 10)
                        .padding(.bottom, 26)
                        .background(
                            prefersSolid ? Color(red: 0.22, green: 0.10, blue: 0.14) : Color.black.opacity(0.35)
                        )
                }
                .frame(width: cardWidth, height: cardHeight, alignment: .top)
                .chromeSurface(
                    prefersSolid: prefersSolid,
                    solid: Color(red: 0.22, green: 0.10, blue: 0.14),
                    glassTint: Color.pink.opacity(0.12),
                    shape: .rect(cornerRadius: 30),
                    padding: .init()
                )
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(24)
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityElement(children: .contain)
    }

    private var gameOverBody: some View {
        VStack(spacing: 18) {
            Image("SadBlobby")
                .resizable()
                .scaledToFit()
                .frame(width: 190, height: 165)
                .accessibilityLabel("Sad Blobby looking straight ahead with a droopy frown")
            Text("Game Over")
                .font(.largeTitle.bold())
                .foregroundStyle(prefersSolid ? Color.primary : Color.white)
            Text("Blobby didn’t make it this time.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 8) {
                Text("Snacks eaten: \(model.snacksEaten)")
                Text("Predators avoided: \(model.predatorsAvoided)")
                Text("Best: \(model.bestSnacks) snacks · \(model.bestAvoided) avoided")
                    .font(.caption)
                    .foregroundStyle(prefersSolid ? Color.secondary : Color.white.opacity(0.78))
            }
            .font(.subheadline)
            .foregroundStyle(prefersSolid ? Color.primary : Color.white)
        }
    }

    @ViewBuilder
    private var restartButton: some View {
        if #available(iOS 26, *), !prefersSolid {
            Button("Restart", systemImage: "arrow.clockwise") {
                model.restart()
            }
            .buttonStyle(.glassProminent)
            .tint(Color(red: 0.94, green: 0.42, blue: 0.58))
            .controlSize(.large)
        } else {
            Button("Restart", systemImage: "arrow.clockwise") {
                model.restart()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.94, green: 0.42, blue: 0.58))
            .controlSize(.large)
        }
    }
}

// MARK: - Settings

private struct SettingsView: View {
    @ObservedObject var model: GameModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Feedback") {
                    Toggle("Sound", systemImage: "speaker.wave.2.fill", isOn: $model.soundEnabled)
                    Toggle("Haptics", systemImage: "iphone.radiowaves.left.and.right", isOn: $model.hapticsEnabled)
                }

                Section("Accessibility") {
                    Toggle("Calm motion", systemImage: "figure.mind.and.body", isOn: $model.calmMotionEnabled)
                    Text("Reduces decorative bobbing and interface transitions while keeping gameplay movement intact. Turns on automatically with Reduce Motion.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Toggle("Assistive controls", systemImage: "circle.grid.cross", isOn: $model.assistiveControlsEnabled)
                    Text("On-screen move, shelter, snack, and puff controls. Also appears when VoiceOver or Switch Control is on.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Help") {
                    Button("How to play", systemImage: "questionmark.circle") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            model.presentTutorial()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Chrome materials

private enum ChromeShape {
    case capsule
    case rect(cornerRadius: CGFloat)
}

private extension View {
    @ViewBuilder
    func chromeSurface(
        prefersSolid: Bool,
        solid: Color,
        glassTint: Color,
        shape: ChromeShape,
        padding: EdgeInsets
    ) -> some View {
        let padded = self.padding(padding)
        if prefersSolid {
            switch shape {
            case .capsule:
                padded.background(solid, in: Capsule())
            case .rect(let radius):
                padded.background(solid, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
        } else if #available(iOS 26, *) {
            switch shape {
            case .capsule:
                padded.glassEffect(.regular.tint(glassTint), in: .capsule)
            case .rect(let radius):
                padded.glassEffect(.regular.tint(glassTint), in: .rect(cornerRadius: radius))
            }
        } else {
            switch shape {
            case .capsule:
                padded.background(.ultraThinMaterial, in: Capsule())
            case .rect(let radius):
                padded.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
        }
    }

    @ViewBuilder
    func chromeButton(prefersSolid: Bool) -> some View {
        if prefersSolid {
            self
                .buttonStyle(.bordered)
                .tint(.white)
        } else if #available(iOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self
                .buttonStyle(.plain)
                .background(.ultraThinMaterial, in: Circle())
        }
    }
}

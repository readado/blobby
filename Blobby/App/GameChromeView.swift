import SwiftUI

struct GameChromeView: View {
    @ObservedObject var model: GameModel
    @Namespace private var glassNamespace

    var body: some View {
        ZStack {
            VStack(spacing: 10) {
                topChrome
                Spacer()
            }
            .padding(.horizontal, 16)
            .safeAreaPadding(.top, 8)

            if model.isTutorialPresented {
                TutorialOverlay(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }

            if model.isGameOver {
                GameOverOverlay(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(model.calmMotionEnabled ? nil : .smooth(duration: 0.28), value: model.isTutorialPresented)
        .animation(model.calmMotionEnabled ? nil : .smooth(duration: 0.28), value: model.isGameOver)
        .sheet(isPresented: $model.isSettingsPresented) {
            SettingsView(model: model)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var topChrome: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        HabitatStatusView(model: model)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 12)
                            .glassEffect(
                                .regular.tint(Color(red: 0.05, green: 0.20, blue: 0.25)),
                                in: .rect(cornerRadius: 22)
                            )

                        Spacer(minLength: 0)

                        Button {
                            model.isSettingsPresented = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 48, height: 48)
                        }
                        .buttonStyle(.glass)
                        .accessibilityLabel("Game settings")
                    }

                    if let banner = model.banner {
                        BannerView(banner: banner)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .glassEffect(
                                .regular.tint(banner.tint.opacity(0.22)),
                                in: .capsule
                            )
                            .glassEffectID("statusBanner", in: glassNamespace)
                            .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .top)))
                    }
                }
            }
        } else {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    HabitatStatusView(model: model)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                    Spacer(minLength: 0)

                    Button {
                        model.isSettingsPresented = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 48, height: 48)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Game settings")
                }

                if let banner = model.banner {
                    BannerView(banner: banner)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .top)))
                }
            }
        }
    }
}

private struct HabitatStatusView: View {
    @ObservedObject var model: GameModel

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
            Text("Blobby is \(model.contentmentText)")
                .font(.headline)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            ProgressView(value: model.contentmentValue)
                .tint(Color(red: 0.97, green: 0.43, blue: 0.61))
                .frame(maxWidth: 150)
                .accessibilityLabel("Contentment")
                .accessibilityValue("\(Int(model.contentmentValue * 100)) percent")
            if model.lives < 3 {
                Text("\(model.snacksTowardHeart)/\(model.snacksPerHeart) snacks · +1 heart")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
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
        .font(.system(size: 15, weight: .semibold))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lives")
        .accessibilityValue("\(model.lives) remaining")
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
}

private struct TutorialOverlay: View {
    @ObservedObject var model: GameModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
            GeometryReader { geometry in
                ScrollView {
                    tutorialCard
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geometry.size.height)
                }
            }
        }
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder
    private var tutorialCard: some View {
        let content = VStack(alignment: .leading, spacing: 22) {
            Text("Welcome to the deep")
                .font(.title2.bold())
                .foregroundStyle(.primary)

            TutorialRow(number: 1, text: "Drag anywhere to gently guide Blobby.")
            TutorialRow(number: 2, text: "Eat the little creatures you encounter.")
            TutorialRow(number: 3, text: "Hide in the coral crevice when warned.")
            Text("Missing a heart? Eat \(model.snacksPerHeart) snacks to earn it back. You can have up to 3 hearts.")
                .font(.footnote)

            tutorialButton
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .frame(maxWidth: 390)

        if #available(iOS 26, *) {
            content
                .glassEffect(
                    .regular.tint(Color.teal.opacity(0.14)),
                    in: .rect(cornerRadius: 30)
                )
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
    }

    @ViewBuilder
    private var tutorialButton: some View {
        if #available(iOS 26, *) {
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

    var body: some View {
        HStack(spacing: 14) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color(red: 0.94, green: 0.42, blue: 0.58), in: Circle())
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct GameOverOverlay: View {
    @ObservedObject var model: GameModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.76).ignoresSafeArea()
            GeometryReader { geometry in
                ScrollView {
                    gameOverCard
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geometry.size.height)
                }
            }
        }
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder
    private var gameOverCard: some View {
        let content = VStack(spacing: 18) {
            Image("SadBlobby")
                .resizable()
                .scaledToFit()
                .frame(width: 190, height: 165)
                .accessibilityLabel("Sad Blobby looking straight ahead with a droopy frown")
            Text("Game Over")
                .font(.largeTitle.bold())
            Text("Blobby didn’t make it this time.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 8) {
                Text("Snacks eaten: \(model.snacksEaten)")
                Text("Predators avoided: \(model.predatorsAvoided)")
                Text("Best: \(model.bestSnacks) snacks · \(model.bestAvoided) avoided")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            restartButton
                .frame(maxWidth: .infinity)
        }
        .padding(28)
        .frame(maxWidth: 360)

        if #available(iOS 26, *) {
            content
                .glassEffect(
                    .regular.tint(Color.pink.opacity(0.12)),
                    in: .rect(cornerRadius: 30)
                )
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
    }

    @ViewBuilder
    private var restartButton: some View {
        if #available(iOS 26, *) {
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
                    Text("Reduces decorative bobbing and interface transitions while keeping gameplay movement intact.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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

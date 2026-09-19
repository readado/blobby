import SpriteKit
import UIKit

final class GameScene: SKScene {
    private enum PredatorPhase {
        case idle
        case warning
        case approaching
    }

    private let model: GameModel
    private lazy var blobby = BlobbyNode()
    private lazy var shelter = ShelterNode()
    private let seafloor = SKShapeNode()
    /// Solid until the painted background is attached after the first frame.
    /// Decoding that texture during `didMove` was stalling the first present.
    private let backgroundArt = SKSpriteNode(
        color: UIColor(red: 0.01, green: 0.045, blue: 0.10, alpha: 1),
        size: .zero
    )

    private var foodNodes: [FoodNode] = []
    private let snowEmitter = SKEmitterNode()
    private var predator: PredatorNode?
    private var giant: GiantPasserbyNode?
    private var giantTimer: TimeInterval = .random(in: 10...18)
    private var targetPoint = CGPoint.zero
    private var previousUpdateTime: TimeInterval = 0
    private var foodTimer: TimeInterval = 0
    private var predatorTimer = TimeInterval.random(in: 22...28)
    private var elapsedPlayTime: TimeInterval = 0
    private var wasSheltered = false
    private var predatorPhase = PredatorPhase.idle
    private var predatorPhaseTime: TimeInterval = 0
    private var incomingPredatorKind = PredatorKind.allCases.randomElement() ?? .toothfish
    private var contentment: CGFloat = 55
    private var lives = 3
    private var predatorHasStruck = false
    private var shelterRewarded = false
    private var shakePulseTimes: [TimeInterval] = []
    private var puffTimeRemaining: TimeInterval = 0
    private var lastContentmentPublish: TimeInterval = -.infinity
    #if DEBUG
    private var isVerifying = false
    #endif

    override init(size: CGSize) {
        model = GameModel()
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
    }

    init(model: GameModel, size: CGSize = UIScreen.main.bounds.size) {
        self.model = model
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = .zero
    }

    override convenience init() {
        self.init(size: UIScreen.main.bounds.size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.01, green: 0.045, blue: 0.10, alpha: 1)
        view.preferredFramesPerSecond = 60
        // Keep the first frames light: build the habitat, then warm audio/haptics
        // on the next run-loop turn so Metal can present once without waiting on WAV decode.
        buildHabitat()
        layoutScene()
        targetPoint = blobby.position
        model.restartAction = { [weak self] in self?.restartGame() }
        GameFeedback.shared.updatePreferences(
            soundEnabled: model.soundEnabled,
            hapticsEnabled: model.hapticsEnabled
        )
        DispatchQueue.main.async { [weak self] in
            guard self != nil else { return }
            GameFeedback.shared.warmUpIfNeeded()
            // Ambience after a beat so texture upload + first present aren't competing.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                GameFeedback.shared.startAmbience()
            }
        }
        #if DEBUG
        if ProcessInfo.processInfo.environment["BLOBBY_VERIFY"] == "1" {
            // Verification needs audio/haptics ready immediately.
            GameFeedback.shared.warmUpIfNeeded()
            GameFeedback.shared.startAmbience()
            verifyGameplay()
        }
        #endif
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard oldSize != .zero else { return }
        layoutScene()
    }

    private func buildHabitat() {
        removeAllChildren()

        backgroundArt.anchorPoint = .zero
        backgroundArt.zPosition = -30
        addChild(backgroundArt)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let texture = SKTexture(imageNamed: "DeepBackground")
            texture.filteringMode = .linear
            self.backgroundArt.texture = texture
        }

        let distantGlow = SKShapeNode(circleOfRadius: 190)
        distantGlow.fillColor = UIColor(red: 0.02, green: 0.18, blue: 0.24, alpha: 0.18)
        distantGlow.strokeColor = .clear
        distantGlow.position = CGPoint(x: size.width * 0.78, y: size.height * 0.7)
        distantGlow.zPosition = -20
        addChild(distantGlow)

        seafloor.fillColor = UIColor(red: 0.02, green: 0.08, blue: 0.10, alpha: 0.28)
        seafloor.strokeColor = UIColor(red: 0.16, green: 0.40, blue: 0.42, alpha: 0.30)
        seafloor.lineWidth = 3
        seafloor.zPosition = -3
        addChild(seafloor)

        configureSnowEmitter()
        addChild(snowEmitter)

        shelter.zPosition = 2
        addChild(shelter)

        blobby.zPosition = 10
        addChild(blobby)

        updateHUD()
    }

    private func layoutScene() {
        backgroundArt.position = .zero
        backgroundArt.size = size

        let floorPath = CGMutablePath()
        floorPath.move(to: CGPoint(x: 0, y: 0))
        floorPath.addLine(to: CGPoint(x: 0, y: 100))
        floorPath.addCurve(
            to: CGPoint(x: size.width, y: 92),
            control1: CGPoint(x: size.width * 0.32, y: 124),
            control2: CGPoint(x: size.width * 0.67, y: 72)
        )
        floorPath.addLine(to: CGPoint(x: size.width, y: 0))
        floorPath.closeSubpath()
        seafloor.path = floorPath

        shelter.position = CGPoint(x: 94, y: max(150, size.height * 0.21))

        snowEmitter.position = CGPoint(x: size.width / 2, y: size.height / 2)
        snowEmitter.particlePositionRange = CGVector(dx: size.width, dy: size.height)

        if blobby.position == .zero {
            blobby.position = CGPoint(x: size.width * 0.48, y: size.height * 0.52)
        } else {
            blobby.position = clamped(blobby.position)
        }
        updateHUD()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let point = touches.first?.location(in: self) {
            guard !model.isGameplayPaused else { return }
            targetPoint = distance(point, shelterCenter) < 82 ? shelterCenter : clamped(point)
            blobby.lookToward(point)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !model.isGameplayPaused else { return }
        if let point = touches.first?.location(in: self) {
            targetPoint = distance(point, shelterCenter) < 82 ? shelterCenter : clamped(point)
            blobby.lookToward(point)
        }
    }

    func resetFrameClock() {
        previousUpdateTime = 0
    }

    // MARK: - Assistive guidance (non-drag alternatives)

    /// Nudge Blobby’s target in a cardinal direction (VoiceOver / on-screen pad).
    func assistNudge(dx: CGFloat, dy: CGFloat) {
        guard !model.isGameplayPaused else { return }
        let step: CGFloat = 78
        let next = CGPoint(
            x: blobby.position.x + dx * step,
            y: blobby.position.y + dy * step
        )
        targetPoint = clamped(next)
        blobby.lookToward(targetPoint)
    }

    func assistGuideToShelter() {
        guard !model.isGameplayPaused else { return }
        targetPoint = shelterCenter
        blobby.lookToward(targetPoint)
        announceAccessibility("Guiding Blobby to the coral shelter")
    }

    func assistGuideToNearestFood() {
        guard !model.isGameplayPaused else { return }
        guard let nearest = foodNodes.min(by: {
            distance($0.position, blobby.position) < distance($1.position, blobby.position)
        }) else {
            setBanner("No snacks nearby", kind: .info, clearsAfter: 1.6)
            return
        }
        targetPoint = clamped(nearest.position)
        blobby.lookToward(targetPoint)
        announceAccessibility("Guiding Blobby toward a snack")
    }

    /// Button / accessibility alternative to the triple-shake puff.
    func assistPuff() {
        activatePuffIfNeeded(afterRegisteringPulse: false)
    }

    // MARK: - Triple-shake puff

    var puffScale: CGFloat { blobby.puffScale }

    /// Called for each shake pulse: a UIEvent `.motionShake` (simulator /
    /// accessibility) or a ≥2.4g accelerometer peak from Core Motion
    /// (device). Three pulses inside 2.2s puff Blobby to 2× for 4 seconds.
    /// Debouncing peaks within one swing is the caller's job.
    func registerShakePulse() {
        activatePuffIfNeeded(afterRegisteringPulse: true)
    }

    func activatePuffIfNeeded() {
        activatePuffIfNeeded(afterRegisteringPulse: false)
    }

    private func activatePuffIfNeeded(afterRegisteringPulse: Bool) {
        guard !model.isGameplayPaused else { return }
        guard puffTimeRemaining <= 0 else { return }
        if afterRegisteringPulse {
            let now = CACurrentMediaTime()
            shakePulseTimes = shakePulseTimes.filter { now - $0 <= 2.2 }
            shakePulseTimes.append(now)
            guard shakePulseTimes.count >= 3 else { return }
            shakePulseTimes.removeAll()
        }
        puffTimeRemaining = 4.0
        blobby.puffUp()
        setBanner("Puffed up!", kind: .success, clearsAfter: 1.6)
        GameFeedback.shared.puffed()
    }

    private func cancelPuff() {
        puffTimeRemaining = 0
        shakePulseTimes.removeAll()
        blobby.cancelPuff()
    }

    override func update(_ currentTime: TimeInterval) {
        #if DEBUG
        if !isVerifying, ProcessInfo.processInfo.environment["BLOBBY_UI_STATE"] != nil { return }
        #endif
        guard !model.isGameplayPaused else {
            resetFrameClock()
            return
        }
        if previousUpdateTime == 0 { previousUpdateTime = currentTime }
        let dt = min(currentTime - previousUpdateTime, 1.0 / 20.0)
        previousUpdateTime = currentTime

        let frameDelta = CGFloat(dt)
        updateSnow()
        elapsedPlayTime += dt
        if puffTimeRemaining > 0 {
            puffTimeRemaining -= dt
            if puffTimeRemaining <= 0 {
                puffTimeRemaining = 0
                blobby.endPuff()
            }
        }
        updateBlobby(dt: frameDelta, time: currentTime)
        updateFood(dt: frameDelta, time: currentTime)
        updatePredator(dt: frameDelta)
        updateGiant(dt: frameDelta)
        updateHUD()
    }

    /// Ambient giants drift behind everything and never touch gameplay.
    /// Calm motion disables new spawns; an in-flight giant simply finishes
    /// its slow crossing.
    private func updateGiant(dt: CGFloat) {
        if let giant {
            giant.position.x += giant.direction * giant.swimSpeed * dt
            let margin = giant.halfWidth + 80
            let offLeft = giant.direction < 0 && giant.position.x < -margin
            let offRight = giant.direction > 0 && giant.position.x > size.width + margin
            if offLeft || offRight {
                giant.removeFromParent()
                self.giant = nil
            }
            return
        }
        giantTimer -= TimeInterval(dt)
        if giantTimer <= 0 {
            giantTimer = .random(in: 40...75)
            if !model.calmMotionEnabled {
                spawnGiant()
            }
        }
    }

    private func spawnGiant() {
        let movingLeft = Bool.random()
        let passerby = GiantPasserbyNode(
            kind: GiantKind.allCases.randomElement() ?? .spermWhale,
            movingLeft: movingLeft
        )
        passerby.position = CGPoint(
            x: movingLeft ? size.width + passerby.halfWidth + 40 : -(passerby.halfWidth + 40),
            y: .random(in: size.height * 0.38...size.height * 0.62)
        )
        passerby.zPosition = -15
        giant = passerby
        addChild(passerby)
    }

    private func updateBlobby(dt: CGFloat, time: TimeInterval) {
        // A stale targetPoint (e.g. from an old session) must respect the
        // current chrome-safe, puff-aware playfield too.
        targetPoint = clamped(targetPoint)
        let dx = targetPoint.x - blobby.position.x
        let dy = targetPoint.y - blobby.position.y
        let distance = hypot(dx, dy)
        if distance > 5 {
            let speed = min(105, 32 + distance * 0.75)
            blobby.position.x += dx / distance * speed * dt
            blobby.position.y += dy / distance * speed * dt
        }
        blobby.position.y += CGFloat(sin(time * 1.35)) * 4 * dt
        blobby.position = clamped(blobby.position)
        let safe = isBlobbySheltered
        if safe != wasSheltered {
            wasSheltered = safe
            if safe {
                GameFeedback.shared.reachedSafety()
                setBanner("Safe and snug", kind: .success, announce: true)
            } else if predatorPhase != .idle {
                setBanner(incomingPredatorKind.warningText, kind: .warning, announce: true)
            } else {
                setBanner("Time for a snack", kind: .info, clearsAfter: 2)
            }
        }
        blobby.updateMotion(
            time: time,
            isSheltered: isBlobbySheltered,
            calmMotion: model.calmMotionEnabled
        )
    }

    private func updateSnow() {
        // The emitter moves itself; we only thin the snowfall for calm motion.
        let rate: CGFloat = model.calmMotionEnabled ? 0.2 : 0.6
        if snowEmitter.particleBirthRate != rate {
            snowEmitter.particleBirthRate = rate
        }
    }

    /// One GPU-driven emitter replaces the old 42 hand-moved shape nodes.
    /// Dot texture is drawn procedurally; ~42 flakes alive at any time.
    private func configureSnowEmitter() {
        let dot = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        snowEmitter.particleTexture = SKTexture(image: dot)
        snowEmitter.particleBirthRate = model.calmMotionEnabled ? 0.2 : 0.6
        snowEmitter.particleLifetime = 70
        snowEmitter.particleLifetimeRange = 20
        snowEmitter.particleSpeed = 14
        snowEmitter.particleSpeedRange = 8
        snowEmitter.emissionAngle = -.pi / 2
        snowEmitter.emissionAngleRange = 0.12
        snowEmitter.particleAlpha = 0.27
        snowEmitter.particleAlphaRange = 0.15
        snowEmitter.particleScale = 0.28
        snowEmitter.particleScaleRange = 0.16
        snowEmitter.zPosition = -5
        // A full 70s warmup allocates the whole lifetime of flakes on the
        // first frame and was the launch hitch on device. A short warmup
        // is enough for the habitat not to start empty.
        snowEmitter.advanceSimulationTime(1.2)
    }

    private func updateFood(dt: CGFloat, time: TimeInterval) {
        foodTimer -= TimeInterval(dt)
        if foodTimer <= 0, foodNodes.count < 7 {
            spawnFood()
            foodTimer = .random(in: 1.0...2.1)
        }

        for food in foodNodes {
            let previousPosition = food.position
            food.update(deltaTime: dt, currentTime: CGFloat(time))
            if food.kind != .shrimp,
               foodNodes.contains(where: {
                   $0 !== food && $0.kind != .shrimp &&
                   abs($0.position.x - food.position.x) < 62
               }) {
                food.position = previousPosition
            }

            if distance(food.position, blobby.mouthPositionInScene) < 31 * blobby.puffScale {
                contentment = min(100, contentment + 8)
                model.snacksEaten += 1
                if lives < 3 {
                    model.snacksTowardHeart += 1
                    if model.snacksTowardHeart == model.snacksPerHeart {
                        lives += 1
                        model.snacksTowardHeart = 0
                        showReactionText("Extra life!", color: .systemPink, fontSize: 20)
                        GameFeedback.shared.reachedSafety()
                    }
                }
                blobby.celebrate()
                GameFeedback.shared.ateFood()
                spawnMealBubbles()
                showReactionText(
                    "nom nom",
                    color: UIColor(red: 0.64, green: 1, blue: 0.86, alpha: 1)
                )
                food.removeFromParent()
            } else if food.position.x < -35 || food.hasExpired {
                food.removeFromParent()
            }
        }
        foodNodes.removeAll { $0.parent == nil }

        contentment = max(0, contentment - dt * 0.18)
    }

    private func spawnFood() {
        let kind = FoodKind.allCases.randomElement() ?? .shrimp
        let minY = max(130, size.height * 0.18)
        let maxY = max(minY + 20, size.height - 150)
        let food = FoodNode(kind: kind)
        switch kind {
        case .shrimp:
            food.position = CGPoint(x: size.width + 30, y: .random(in: minY...maxY))
        case .crab:
            food.position = CGPoint(x: size.width + 30, y: .random(in: 105...119))
        case .urchin:
            food.position = CGPoint(
                x: .random(in: max(190, size.width * 0.42)...max(210, size.width - 35)),
                y: .random(in: 103...116)
            )
        case .shellfish:
            food.position = CGPoint(
                x: .random(in: max(180, size.width * 0.38)...max(205, size.width - 32)),
                y: .random(in: 103...116)
            )
        }
        if kind != .shrimp {
            let left = max(210, size.width * 0.48)
            let right = max(left, size.width - 32)
            if kind != .crab {
                let candidates = stride(from: left, through: right, by: CGFloat(66)).shuffled()
                guard let x = candidates.first(where: { candidate in
                    foodNodes.allSatisfy { $0.kind == .shrimp || abs($0.position.x - candidate) >= 64 }
                }) else { return }
                food.position.x = x
            } else if foodNodes.contains(where: {
                $0.kind != .shrimp && abs($0.position.x - food.position.x) < 64
            }) {
                return
            }
        }
        food.zPosition = 6
        foodNodes.append(food)
        addChild(food)
    }

    private func updatePredator(dt: CGFloat) {
        switch predatorPhase {
        case .idle:
            predatorTimer -= TimeInterval(dt)
            if predatorTimer <= 0 { beginWarning() }

        case .warning:
            predatorPhaseTime -= TimeInterval(dt)
            if predatorPhaseTime <= 0 { launchPredator() }

        case .approaching:
            guard let predator else { return }
            predator.position.x -= predator.swimSpeed * dt
            predator.position.y += sin(predator.position.x * 0.012) * 7 * dt

            if !predatorHasStruck,
               predator.position.x <= blobby.position.x + 130 {
                predatorHasStruck = true
                if isBlobbySheltered {
                    shelterRewarded = true
                    setBanner("Safe and snug", kind: .success)
                } else {
                    registerCloseCall()
                }
            }

            if predator.position.x < -200 {
                endPredatorVisit()
            }
        }
    }

    private func beginWarning() {
        incomingPredatorKind = PredatorKind.allCases.randomElement() ?? .toothfish
        predatorPhase = .warning
        // Allow the entire trip at Blobby's slower approach speed, plus reaction time.
        predatorPhaseTime = max(5, Double(distance(blobby.position, shelterCenter)) / 70 + 2)
        setBanner(isBlobbySheltered ? "Safe and snug" : incomingPredatorKind.warningText,
                  kind: isBlobbySheltered ? .success : .warning,
                  announce: true)
        shelter.setActive(true, calmMotion: model.calmMotionEnabled)
        GameFeedback.shared.predatorWarning()
    }

    private func launchPredator() {
        predatorPhase = .approaching
        let fish = PredatorNode(kind: incomingPredatorKind)
        fish.position = CGPoint(x: size.width + 150, y: .random(in: size.height * 0.32...size.height * 0.72))
        fish.zPosition = 8
        predator = fish
        addChild(fish)
    }

    private func endPredatorVisit() {
        predator?.removeFromParent()
        predator = nil
        predatorPhase = .idle
        let difficulty = min(1, elapsedPlayTime / 240)
        predatorTimer = .random(in: (22 - difficulty * 10)...(28 - difficulty * 10))
        predatorHasStruck = false
        if shelterRewarded {
            contentment = min(100, contentment + 5)
            model.predatorsAvoided += 1
        }
        shelterRewarded = false
        shelter.setActive(false, calmMotion: model.calmMotionEnabled)
        setBanner("The coast is clear", kind: .info, clearsAfter: 2.5, announce: true)
    }

    private func registerCloseCall() {
        guard !model.isGameOver else { return }
        lives = max(0, lives - 1)
        shelterRewarded = false
        contentment = max(0, contentment - 20)
        blobby.getScared()
        if lives > 0 { GameFeedback.shared.closeCall() }
        showReactionText(
            "Yowza!",
            color: UIColor(red: 1, green: 0.70, blue: 0.30, alpha: 1),
            fontSize: 20
        )
        setBanner("That was close!", kind: .danger, announce: true)
        updateHUD()

        if lives == 0 {
            showGameOver()
        }
    }

    private func showGameOver() {
        guard !model.isGameOver else { return }
        GameFeedback.shared.gameOver()
        cancelPuff()
        removeAction(forKey: "clearBanner")
        predator?.removeFromParent()
        predator = nil
        shelter.setActive(false, calmMotion: model.calmMotionEnabled)
        model.isGameOver = true
        model.saveRecords()
        model.banner = nil
        announceAccessibility("Game Over. Snacks eaten \(model.snacksEaten). Predators avoided \(model.predatorsAvoided).")
    }

    private func restartGame() {
        removeAllActions()
        children.filter { $0.name == "mealEffect" }.forEach { $0.removeFromParent() }
        foodNodes.forEach { $0.removeFromParent() }
        foodNodes.removeAll()
        predator?.removeFromParent()
        predator = nil
        giant?.removeFromParent()
        giant = nil
        giantTimer = .random(in: 10...18)

        lives = 3
        contentment = 55
        predatorPhase = .idle
        predatorTimer = .random(in: 22...28)
        elapsedPlayTime = 0
        wasSheltered = false
        model.snacksEaten = 0
        model.predatorsAvoided = 0
        model.snacksTowardHeart = 0
        predatorPhaseTime = 0
        predatorHasStruck = false
        shelterRewarded = false
        foodTimer = 0
        previousUpdateTime = 0
        lastContentmentPublish = -.infinity
        model.isGameOver = false

        shelter.setActive(false, calmMotion: model.calmMotionEnabled)
        setBanner("A fresh start", kind: .info, clearsAfter: 1.8, announce: true)
        cancelPuff()

        blobby.resetPose()
        blobby.position = CGPoint(x: size.width * 0.48, y: size.height * 0.52)
        targetPoint = blobby.position
        GameFeedback.shared.restarted()
        updateHUD()
    }

    private func spawnMealBubbles() {
        let origin = blobby.mouthPositionInScene
        for index in 0..<3 {
            let bubble = SKShapeNode(circleOfRadius: CGFloat(3 + index))
            bubble.name = "mealEffect"
            bubble.fillColor = UIColor(red: 0.55, green: 0.94, blue: 1, alpha: 0.14)
            bubble.strokeColor = UIColor(red: 0.68, green: 0.97, blue: 1, alpha: 0.75)
            bubble.lineWidth = 1
            bubble.position = CGPoint(x: origin.x + CGFloat(index * 5), y: origin.y + CGFloat(index * 2))
            bubble.zPosition = 25
            addChild(bubble)

            let rise = SKAction.moveBy(x: CGFloat.random(in: -10...12), y: CGFloat(34 + index * 9), duration: 0.65)
            rise.timingMode = .easeOut
            bubble.run(.sequence([
                .group([rise, .fadeOut(withDuration: 0.65), .scale(to: 1.45, duration: 0.65)]),
                .removeFromParent()
            ]))
        }
    }

    private func showReactionText(_ text: String, color: UIColor, fontSize: CGFloat = 15) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.name = "mealEffect"
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        label.position = CGPoint(
            x: blobby.mouthPositionInScene.x,
            y: blobby.mouthPositionInScene.y + 24
        )
        label.zPosition = 30
        label.setScale(0.72)
        addChild(label)

        let floatUp = SKAction.moveBy(x: 8, y: 30, duration: 0.75)
        floatUp.timingMode = .easeOut
        label.run(.sequence([
            .group([
                floatUp,
                .scale(to: 1, duration: 0.22),
                .sequence([.wait(forDuration: 0.34), .fadeOut(withDuration: 0.41)])
            ]),
            .removeFromParent()
        ]))
    }

    private func setBanner(
        _ text: String,
        kind: GameBanner.Kind,
        clearsAfter delay: TimeInterval? = nil,
        announce: Bool = false
    ) {
        removeAction(forKey: "clearBanner")
        model.banner = GameBanner(text: text, kind: kind)
        if announce {
            announceAccessibility(text)
        }
        guard let delay else { return }

        let expectedText = text
        run(
            .sequence([
                .wait(forDuration: delay),
                .run { [weak self] in
                    guard self?.model.banner?.text == expectedText else { return }
                    self?.model.banner = nil
                }
            ]),
            withKey: "clearBanner"
        )
    }

    private func announceAccessibility(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private var shelterCenter: CGPoint {
        CGPoint(x: shelter.position.x + 2, y: shelter.position.y - 17)
    }

    private var isBlobbySheltered: Bool {
        let dx = (blobby.position.x - shelterCenter.x) / 40
        let dy = (blobby.position.y - shelterCenter.y) / 30
        return dx * dx + dy * dy <= 1
    }

    private func updateHUD() {
        // The contentment bar decays continuously, so publishing every frame
        // rebuilt the Liquid Glass HUD at 60Hz. Publish at ~8Hz at most, or
        // immediately when the displayed percent changes.
        let nextValue = Double(contentment / 100)
        let percentChanged = Int(nextValue * 100) != Int(model.contentmentValue * 100)
        if percentChanged || elapsedPlayTime - lastContentmentPublish >= 0.125 {
            if model.contentmentValue != nextValue {
                model.contentmentValue = nextValue
            }
            lastContentmentPublish = elapsedPlayTime
        }
        if model.contentmentText != contentmentDescription {
            model.contentmentText = contentmentDescription
        }
        if model.lives != lives {
            model.lives = lives
        }
    }

    private var contentmentDescription: String {
        switch contentment {
        case 75...: return "delighted"
        case 45..<75: return "content"
        case 20..<45: return "peckish"
        default: return "hungry"
        }
    }

    /// Playable-area clamp. The top inset tracks the real chrome (safe area +
    /// status capsule + gear) instead of a magic constant, and every inset
    /// grows with the puff so a 2× Blobby can never reach the gear, hide under
    /// the HUD, or clip the seafloor.
    private func clamped(_ point: CGPoint) -> CGPoint {
        let puff = blobby.puffScale
        let sideInset = 48 * puff
        let topInset = (view?.safeAreaInsets.top ?? 0) + 72 * puff
        let bottomInset = 95 * puff
        return CGPoint(
            x: min(max(point.x, sideInset), max(sideInset, size.width - sideInset)),
            y: min(max(point.y, bottomInset), max(bottomInset, size.height - topInset))
        )
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    #if DEBUG
    /// Set BLOBBY_VERIFY=1 in a Debug launch to exercise the real scene transitions.
    private func verifyGameplay() {
        isVerifying = true
        defer { isVerifying = false }
        let defaults = UserDefaults(suiteName: "com.example.Blobby.readiness")!
        let reloaded = GameModel(defaults: defaults)
        if ProcessInfo.processInfo.environment["BLOBBY_VERIFY_PERSISTENCE"] == "1" {
            assert(!reloaded.soundEnabled && !reloaded.hapticsEnabled && reloaded.calmMotionEnabled)
            // The tutorial is once-only until dismissed.
            assert(reloaded.isTutorialPresented == !defaults.bool(forKey: "didSeeBlobbyTutorialV2"))
            assert(reloaded.bestSnacks >= model.snacksPerHeart + 10)
            assert(reloaded.bestAvoided >= 1)
            NSLog("BLOBBY_PERSISTENCE_CHECKS_PASSED")
        }
        let originalTutorial = model.isTutorialPresented
        let originalActive = model.isAppActive
        model.isTutorialPresented = false
        model.isAppActive = true
        model.soundEnabled = false
        model.hapticsEnabled = true
        GameFeedback.shared.setAppActive(true)
        restartGame()
        registerCloseCall()
        assert(lives == 2)
        func eatSnack() {
            foodTimer = 100
            let food = FoodNode(kind: .shrimp)
            food.position = blobby.mouthPositionInScene
            foodNodes.append(food)
            addChild(food)
            updateFood(dt: 0, time: 0)
        }
        for _ in 0..<(model.snacksPerHeart - 1) { eatSnack() }
        assert(lives == 2 && model.snacksTowardHeart == model.snacksPerHeart - 1)
        eatSnack()
        assert(lives == 3 && model.snacksTowardHeart == 0 && model.snacksEaten == model.snacksPerHeart)
        for _ in 0..<10 { eatSnack() }
        assert(lives == 3 && model.snacksTowardHeart == 0)

        blobby.position = clamped(CGPoint(x: size.width, y: size.height))
        beginWarning()
        assert(predatorPhaseTime >= Double(distance(blobby.position, shelterCenter)) / 70 + 2)
        blobby.position = shelterCenter
        assert(isBlobbySheltered)
        launchPredator()
        predator?.position.x = blobby.position.x
        updatePredator(dt: 0)
        endPredatorVisit()
        assert(lives == 3 && model.predatorsAvoided == 1)

        // A dismissed settings sheet and app interruption must not consume game time.
        for pauseReason in 0..<3 {
            if pauseReason == 0 { model.isSettingsPresented = true }
            if pauseReason == 1 { model.isAppActive = false }
            if pauseReason == 2 { model.isTutorialPresented = true }
            let savedTime = elapsedPlayTime
            let savedPosition = blobby.position
            let savedTimer = predatorTimer
            update(100)
            update(200)
            assert(elapsedPlayTime == savedTime && blobby.position == savedPosition)
            assert(predatorTimer == savedTimer && lives == 3)
            model.isSettingsPresented = false
            model.isAppActive = true
            model.isTutorialPresented = false
            update(300)
            assert(elapsedPlayTime == savedTime)
            update(300.02)
            assert(elapsedPlayTime > savedTime)
        }

        let deathCount = GameFeedback.shared.deathHapticCount
        registerCloseCall()
        registerCloseCall()
        assert(lives == 1 && !model.isGameOver)
        registerCloseCall()
        assert(lives == 0 && model.isGameOver)
        assert(GameFeedback.shared.deathHapticCount == deathCount + 1)
        registerCloseCall()
        showGameOver()
        assert(GameFeedback.shared.deathHapticCount == deathCount + 1)
        let savedTime = elapsedPlayTime
        update(400)
        assert(elapsedPlayTime == savedTime)
        assert(model.bestSnacks >= model.snacksPerHeart + 10 && model.bestAvoided >= 1)
        model.hapticsEnabled = false
        GameFeedback.shared.gameOver()
        assert(GameFeedback.shared.deathHapticCount == deathCount + 1)
        model.calmMotionEnabled = true
        model.dismissTutorial()
        model.restart()
        assert(!model.isGameOver && model.lives == 3)
        assert(children.allSatisfy { $0.name != "mealEffect" })

        registerCloseCall()
        assert(model.snacksTowardHeart == 0)
        for _ in 0..<25 { eatSnack() }
        registerCloseCall()
        assert(lives == 1 && model.snacksTowardHeart == 25)
        for _ in 0..<25 { eatSnack() }
        assert(lives == 2 && model.snacksTowardHeart == 0)
        restartGame()

        for _ in 0..<50 { spawnFood() }
        let bottomFood = foodNodes.filter { $0.kind != .shrimp }
        for (index, food) in bottomFood.enumerated() {
            for other in bottomFood.dropFirst(index + 1) {
                assert(abs(food.position.x - other.position.x) >= 62)
            }
        }
        // These checks use a separate preferences suite, never the player's records.
        restartGame()
        assert(lives == 3 && model.snacksEaten == 0 && model.predatorsAvoided == 0)
        assert(model.snacksTowardHeart == 0 && foodNodes.isEmpty && predator == nil)
        assert(!model.isGameOver && elapsedPlayTime == 0 && predatorTimer >= 22)
        for (value, text) in [(CGFloat(80), "delighted"), (55, "content"), (30, "peckish"), (10, "hungry")] {
            contentment = value
            updateHUD()
            assert(model.contentmentText == text)
        }
        restartGame()
        // Triple-shake puff. A real violent shake arrives via Core Motion
        // peaks and Device → Shake arrives via motionEnded; both funnel into
        // registerShakePulse(), so three rapid pulses stand in for them here.
        // The death haptic itself is device-only (Core Haptics with a UIKit
        // fallback); only its once-per-Game-Over count is asserted above.
        assert(puffScale == 1)
        registerShakePulse()
        registerShakePulse()
        registerShakePulse()
        assert(puffScale == 2)
        registerShakePulse() // a fourth shake during the puff is ignored
        assert(puffScale == 2)
        var verifyClock: TimeInterval = 1000
        for _ in 0..<246 { // 4.1s of game time at 60fps
            verifyClock += 1.0 / 60.0
            update(verifyClock)
        }
        assert(puffScale == 1)
        // Button / accessibility puff path (no shake required).
        assistPuff()
        assert(puffScale == 2)
        cancelPuff()
        assert(puffScale == 1)
        assistGuideToShelter()
        assert(distance(targetPoint, shelterCenter) < 1)
        assistNudge(dx: 1, dy: 0)
        assert(targetPoint.x > blobby.position.x - 1)
        // Ambient giants are visual-only: spawning one and letting it drift
        // must not touch lives, food, or timers.
        spawnGiant()
        assert(giant != nil)
        for _ in 0..<120 { // 2s of game time
            verifyClock += 1.0 / 60.0
            update(verifyClock)
        }
        assert(lives == 3 && !model.isGameOver)
        assert(giant == nil || giant!.parent === self)
        restartGame()
        assert(giant == nil)
        model.isTutorialPresented = originalTutorial
        model.isAppActive = originalActive
        NSLog("BLOBBY_GAMEPLAY_CHECKS_PASSED")
        if let fixture = ProcessInfo.processInfo.environment["BLOBBY_UI_STATE"] {
            model.isTutorialPresented = fixture == "tutorial"
            if fixture == "hungry" || fixture == "peckish" || fixture == "delighted" {
                model.contentmentText = fixture
                model.lives = 2
                model.snacksTowardHeart = 49
                model.banner = GameBanner(text: PredatorKind.sixgillShark.warningText, kind: .warning)
            }
            if fixture == "giant" {
                spawnGiant()
                giant?.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            }
        }
        if ProcessInfo.processInfo.environment["BLOBBY_RESULTS_PREVIEW"] == "1" {
            model.snacksEaten = 20
            model.predatorsAvoided = 1
            model.lives = 0
            model.isTutorialPresented = false
            model.isGameOver = true
            model.banner = nil
        }
    }
    #endif
}

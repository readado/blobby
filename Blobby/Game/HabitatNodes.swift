import SpriteKit

enum FoodKind: CaseIterable {
    case shrimp
    case crab
    case urchin
    case shellfish

    var textureName: String {
        switch self {
        case .shrimp: return "Shrimp"
        case .crab: return "Crab"
        case .urchin: return "Urchin"
        case .shellfish: return "Shellfish"
        }
    }

    var displaySize: CGSize {
        switch self {
        case .shrimp: return CGSize(width: 70, height: 70)
        case .crab: return CGSize(width: 64, height: 64)
        case .urchin: return CGSize(width: 53, height: 53)
        case .shellfish: return CGSize(width: 57, height: 57)
        }
    }

    var glowColor: UIColor {
        switch self {
        case .shrimp: return UIColor(red: 1, green: 0.48, blue: 0.61, alpha: 1)
        case .crab: return UIColor(red: 1, green: 0.38, blue: 0.22, alpha: 1)
        case .urchin: return UIColor(red: 0.67, green: 0.42, blue: 1, alpha: 1)
        case .shellfish: return UIColor(red: 1, green: 0.78, blue: 0.42, alpha: 1)
        }
    }
}

final class FoodNode: SKNode {
    let kind: FoodKind
    private let driftSpeed = CGFloat.random(in: 42...68)
    private let phase = CGFloat.random(in: 0...(2 * .pi))
    private let sprite: SKSpriteNode
    private var age: CGFloat = 0

    var hasExpired: Bool {
        age > (kind == .shrimp || kind == .crab ? 18 : 22)
    }

    init(kind: FoodKind) {
        self.kind = kind
        let texture = SKTexture(imageNamed: kind.textureName)
        texture.filteringMode = .linear
        sprite = SKSpriteNode(texture: texture, size: kind.displaySize)
        super.init()

        let glow = SKShapeNode(circleOfRadius: kind.displaySize.width * 0.31)
        glow.fillColor = kind.glowColor.withAlphaComponent(0.08)
        glow.strokeColor = kind.glowColor.withAlphaComponent(0.20)
        glow.lineWidth = 1
        glow.zPosition = -1
        addChild(glow)
        addChild(sprite)

        if kind == .shrimp {
            sprite.run(.repeatForever(.sequence([
                .scaleX(to: 0.92, duration: 0.20),
                .scaleX(to: 1.03, duration: 0.24),
                .scaleX(to: 1, duration: 0.16)
            ])))
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(deltaTime: CGFloat, currentTime: CGFloat) {
        age += deltaTime
        switch kind {
        case .shrimp:
            position.x -= driftSpeed * deltaTime
            position.y += sin(currentTime * 2.1 + phase) * 10 * deltaTime
            zRotation = sin(currentTime * 1.8 + phase) * 0.035
        case .crab:
            position.x -= 18 * deltaTime
            position.y += sin(currentTime * 5 + phase) * 2 * deltaTime
            zRotation = sin(currentTime * 4 + phase) * 0.025
        case .urchin:
            position.x -= 1.2 * deltaTime
            zRotation += 0.045 * deltaTime
        case .shellfish:
            position.x -= 2.5 * deltaTime
            yScale = 1 + sin(currentTime * 1.4 + phase) * 0.025
        }
    }
}

final class MarineSnowNode: SKShapeNode {
    let fallSpeed = CGFloat.random(in: 7...22)
    let driftSpeed = CGFloat.random(in: -2...5)

    init(sceneSize: CGSize) {
        super.init()
        path = CGPath(
            ellipseIn: CGRect(
                x: -1,
                y: -1,
                width: .random(in: 1.2...3.5),
                height: .random(in: 1.2...3.5)
            ),
            transform: nil
        )
        fillColor = UIColor.white.withAlphaComponent(.random(in: 0.12...0.42))
        strokeColor = .clear
        position = CGPoint(x: .random(in: 0...sceneSize.width), y: .random(in: 0...sceneSize.height))
        zPosition = -5
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class ShelterNode: SKNode {
    private let art: SKSpriteNode
    private let glow = SKShapeNode(ellipseOf: CGSize(width: 214, height: 152))

    override init() {
        let texture = SKTexture(imageNamed: "CoralShelter")
        texture.filteringMode = .linear
        art = SKSpriteNode(texture: texture, size: CGSize(width: 275, height: 184))
        super.init()

        glow.fillColor = UIColor(red: 0.20, green: 0.95, blue: 0.79, alpha: 0.07)
        glow.strokeColor = UIColor(red: 0.37, green: 1, blue: 0.84, alpha: 0.25)
        glow.lineWidth = 2
        glow.position = CGPoint(x: 0, y: -8)
        glow.alpha = 0
        glow.zPosition = -2
        addChild(glow)

        art.position = CGPoint(x: 0, y: 10)
        addChild(art)

        let creviceHint = SKShapeNode(ellipseOf: CGSize(width: 88, height: 56))
        creviceHint.fillColor = .clear
        creviceHint.strokeColor = UIColor(red: 0.50, green: 1, blue: 0.86, alpha: 0)
        creviceHint.lineWidth = 2
        creviceHint.position = CGPoint(x: 2, y: -17)
        creviceHint.zPosition = 2
        creviceHint.name = "creviceHint"
        addChild(creviceHint)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setActive(_ active: Bool) {
        glow.removeAllActions()
        guard let creviceHint = childNode(withName: "creviceHint") as? SKShapeNode else { return }
        creviceHint.removeAllActions()

        if active {
            glow.alpha = 0.72
            creviceHint.strokeColor = UIColor(red: 0.50, green: 1, blue: 0.86, alpha: 0.56)
            let pulse = SKAction.sequence([
                .fadeAlpha(to: 0.30, duration: 0.65),
                .fadeAlpha(to: 0.78, duration: 0.65)
            ])
            glow.run(.repeatForever(pulse))
            creviceHint.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.36, duration: 0.65),
                .fadeAlpha(to: 1, duration: 0.65)
            ])))
        } else {
            glow.alpha = 0
            creviceHint.strokeColor = .clear
        }
    }
}

enum PredatorKind: CaseIterable {
    case toothfish
    case anglerfish
    case sixgillShark

    var textureName: String {
        switch self {
        case .toothfish: return "Predator"
        case .anglerfish: return "Anglerfish"
        case .sixgillShark: return "SixgillShark"
        }
    }

    var displaySize: CGSize {
        switch self {
        case .toothfish: return CGSize(width: 310, height: 175)
        case .anglerfish: return CGSize(width: 295, height: 197)
        case .sixgillShark: return CGSize(width: 344, height: 194)
        }
    }

    var speedRange: ClosedRange<CGFloat> {
        switch self {
        case .toothfish: return 92...118
        case .anglerfish: return 78...96
        case .sixgillShark: return 112...136
        }
    }

    var warningText: String {
        switch self {
        case .toothfish: return "Toothfish nearby — hide!"
        case .anglerfish: return "Anglerfish nearby — hide!"
        case .sixgillShark: return "Sixgill shark nearby — hide!"
        }
    }
}

final class PredatorNode: SKNode {
    let kind: PredatorKind
    let swimSpeed: CGFloat

    init(kind: PredatorKind) {
        self.kind = kind
        swimSpeed = .random(in: kind.speedRange)
        super.init()
        let texture = SKTexture(imageNamed: kind.textureName)
        texture.filteringMode = .linear
        let art = SKSpriteNode(texture: texture, size: kind.displaySize)
        addChild(art)
        art.run(.repeatForever(.sequence([
            .rotate(toAngle: 0.018, duration: kind == .sixgillShark ? 0.62 : 0.45, shortestUnitArc: true),
            .rotate(toAngle: -0.018, duration: kind == .sixgillShark ? 0.62 : 0.45, shortestUnitArc: true)
        ])))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

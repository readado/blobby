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

final class ShelterNode: SKNode {
    private let art: SKSpriteNode
    private let glow = SKShapeNode(ellipseOf: CGSize(width: 214, height: 152))
    private let hideLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

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

        hideLabel.text = "Hide!"
        hideLabel.fontSize = 17
        hideLabel.fontColor = UIColor(red: 0.75, green: 1, blue: 0.90, alpha: 1)
        hideLabel.position = CGPoint(x: 0, y: 108)
        hideLabel.zPosition = 3
        hideLabel.alpha = 0
        addChild(hideLabel)

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

    func setActive(_ active: Bool, calmMotion: Bool = false) {
        glow.removeAllActions()
        hideLabel.removeAllActions()
        guard let creviceHint = childNode(withName: "creviceHint") as? SKShapeNode else { return }
        creviceHint.removeAllActions()

        if active {
            glow.lineWidth = 3
            glow.strokeColor = UIColor(red: 0.37, green: 1, blue: 0.84, alpha: 0.6)
            glow.alpha = 0.9
            creviceHint.strokeColor = UIColor(red: 0.50, green: 1, blue: 0.86, alpha: 0.9)
            hideLabel.fontColor = UIColor(red: 0.85, green: 1, blue: 0.94, alpha: 1)
            hideLabel.alpha = 1
            if calmMotion {
                // Static high-contrast cue — no looping fade when Reduce Motion / Calm Motion is on.
                glow.alpha = 1
                creviceHint.alpha = 1
                hideLabel.alpha = 1
            } else {
                let pulse = SKAction.sequence([
                    .fadeAlpha(to: 0.5, duration: 0.5),
                    .fadeAlpha(to: 0.9, duration: 0.5)
                ])
                glow.run(.repeatForever(pulse))
                creviceHint.run(.repeatForever(.sequence([
                    .fadeAlpha(to: 0.45, duration: 0.5),
                    .fadeAlpha(to: 1, duration: 0.5)
                ])))
                hideLabel.run(.repeatForever(.sequence([
                    .fadeAlpha(to: 0.55, duration: 0.5),
                    .fadeAlpha(to: 1, duration: 0.5)
                ])))
            }
        } else {
            glow.alpha = 0
            creviceHint.strokeColor = .clear
            hideLabel.alpha = 0
        }
    }
}

// MARK: - Ambient background giants

enum GiantKind: CaseIterable {
    case spermWhale
    case submarine
}

/// A huge, distant silhouette drifting slowly behind the habitat. Purely
/// decorative: it never interacts with gameplay. The silhouette is drawn once
/// into a single image (so overlapping parts don't double-darken) and softened
/// with a blur to read as far away. (SKEffectNode + CIFilter was avoided:
/// it renders empty in the simulator.)
final class GiantPasserbyNode: SKSpriteNode {
    let kind: GiantKind
    let direction: CGFloat
    let swimSpeed: CGFloat
    let halfWidth: CGFloat

    init(kind: GiantKind, movingLeft: Bool) {
        self.kind = kind
        direction = movingLeft ? -1 : 1
        swimSpeed = kind == .submarine ? .random(in: 20...30) : .random(in: 15...23)
        // Drawn slightly larger than needed, then scaled to fit within the
        // screen so the whole creature stays readable.
        let scale: CGFloat = kind == .submarine ? 0.78 : 0.7
        halfWidth = (kind == .submarine ? 250 : 265) * scale
        let texture = GiantPasserbyNode.makeTexture(kind: kind)
        super.init(texture: texture, color: .clear, size: texture.size())
        alpha = 0.42
        xScale = (movingLeft ? 1 : -1) * scale
        yScale = scale
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Shapes are laid out facing left, centered on the origin, then shifted
    /// into a padded y-down canvas and filled in one pass.
    private static func makeTexture(kind: GiantKind) -> SKTexture {
        let pad: CGFloat = 20
        let canvas: CGSize
        let center: CGPoint
        let silhouette = CGMutablePath()
        let lights = CGMutablePath()
        switch kind {
        case .spermWhale:
            canvas = CGSize(width: 540 + pad * 2, height: 190 + pad * 2)
            center = CGPoint(x: 270 + pad, y: 95 + pad)
            silhouette.addRoundedRect(in: CGRect(x: -250, y: -70, width: 190, height: 140), cornerWidth: 55, cornerHeight: 55) // blocky head
            silhouette.addEllipse(in: CGRect(x: -130, y: -60, width: 260, height: 120)) // midbody
            silhouette.addRoundedRect(in: CGRect(x: 120, y: -13, width: 90, height: 26), cornerWidth: 12, cornerHeight: 12) // tail stock
            silhouette.addEllipse(in: CGRect(x: -95, y: -88, width: 56, height: 22)) // pectoral fin
            silhouette.move(to: CGPoint(x: 195, y: 8)) // fluke
            silhouette.addLine(to: CGPoint(x: 258, y: 32))
            silhouette.addLine(to: CGPoint(x: 236, y: 0))
            silhouette.addLine(to: CGPoint(x: 258, y: -32))
            silhouette.addLine(to: CGPoint(x: 195, y: -8))
            silhouette.closeSubpath()

        case .submarine:
            canvas = CGSize(width: 520 + pad * 2, height: 170 + pad * 2)
            center = CGPoint(x: 260 + pad, y: 70 + pad)
            silhouette.addRoundedRect(in: CGRect(x: -200, y: -45, width: 400, height: 90), cornerWidth: 45, cornerHeight: 45) // hull
            silhouette.addRoundedRect(in: CGRect(x: -40, y: 38, width: 92, height: 58), cornerWidth: 14, cornerHeight: 14) // sail
            silhouette.addRoundedRect(in: CGRect(x: -2, y: 92, width: 12, height: 26), cornerWidth: 5, cornerHeight: 5) // periscope
            silhouette.addRoundedRect(in: CGRect(x: -2, y: 112, width: 34, height: 11), cornerWidth: 5, cornerHeight: 5)
            silhouette.move(to: CGPoint(x: 185, y: 28)) // tail fins
            silhouette.addLine(to: CGPoint(x: 248, y: 58))
            silhouette.addLine(to: CGPoint(x: 225, y: 0))
            silhouette.addLine(to: CGPoint(x: 248, y: -58))
            silhouette.addLine(to: CGPoint(x: 185, y: -28))
            silhouette.closeSubpath()
            for index in 0..<4 {
                lights.addEllipse(in: CGRect(x: -129 + index * 70, y: -7, width: 18, height: 18))
            }
        }

        // SpriteKit-style y-up coords -> y-down image canvas.
        var flip = CGAffineTransform(translationX: center.x, y: center.y).scaledBy(x: 1, y: -1)
        let image = UIGraphicsImageRenderer(size: canvas).image { ctx in
            let cg = ctx.cgContext
            cg.addPath(silhouette.copy(using: &flip) ?? silhouette)
            cg.setFillColor(UIColor(red: 0.0, green: 0.03, blue: 0.07, alpha: 1).cgColor)
            cg.fillPath()
            cg.addPath(lights.copy(using: &flip) ?? lights)
            cg.setFillColor(UIColor(red: 0.55, green: 0.85, blue: 0.95, alpha: 1).cgColor)
            cg.fillPath()
        }

        var finalImage = image
        if let input = CIImage(image: image),
           let blur = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 4]),
           let output = blur.outputImage,
           let cgImage = CIContext().createCGImage(output, from: CGRect(origin: .zero, size: canvas)) {
            finalImage = UIImage(cgImage: cgImage)
        }
        return SKTexture(image: finalImage)
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

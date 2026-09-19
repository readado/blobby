import SpriteKit

final class BlobbyNode: SKNode {
    private let neutralTexture = SKTexture(imageNamed: "BlobbyNeutral")
    private let eatingTexture = SKTexture(imageNamed: "BlobbyEating")
    private let scaredTexture = SKTexture(imageNamed: "BlobbyScared")
    private let hidingTexture = SKTexture(imageNamed: "BlobbyHiding")
    private let sprite: SKSpriteNode
    private let artContainer = SKNode()
    private let softGlow = SKShapeNode(ellipseOf: CGSize(width: 92, height: 68))
    private var facing: CGFloat = 1
    /// Logical puff multiplier (1 or 2). Kept separate from the node's scale
    /// animation so gameplay (eat radius, clamps) reads a stable value even
    /// while the ease in/out is still running.
    private(set) var puffScale: CGFloat = 1

    var mouthPositionInScene: CGPoint {
        convert(CGPoint(x: 46 * facing, y: -5), to: parent ?? self)
    }

    override init() {
        sprite = SKSpriteNode(texture: neutralTexture)
        super.init()

        softGlow.fillColor = UIColor(red: 0.98, green: 0.45, blue: 0.66, alpha: 0.10)
        softGlow.strokeColor = UIColor(red: 0.50, green: 0.95, blue: 1, alpha: 0.15)
        softGlow.lineWidth = 2
        softGlow.zPosition = -1
        addChild(artContainer)
        artContainer.addChild(softGlow)

        sprite.size = CGSize(width: 132, height: 132)
        sprite.texture?.filteringMode = .linear
        artContainer.addChild(sprite)

        let name = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        name.text = "Blobby"
        name.fontSize = 13
        name.fontColor = .white
        name.position = CGPoint(x: 0, y: -60)
        name.zPosition = 2
        // Soft shadow so the name stays readable over bright coral.
        let nameShadow = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        nameShadow.text = "Blobby"
        nameShadow.fontSize = 13
        nameShadow.fontColor = UIColor.black.withAlphaComponent(0.55)
        nameShadow.position = CGPoint(x: 0.8, y: -61.2)
        nameShadow.zPosition = 1
        addChild(nameShadow)
        addChild(name)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func lookToward(_ point: CGPoint) {
        guard abs(point.x - position.x) > 8 else { return }
        let nextFacing: CGFloat = point.x >= position.x ? 1 : -1
        if nextFacing != facing {
            facing = nextFacing
            artContainer.xScale = facing
        }
    }

    func updateMotion(time: TimeInterval, isSheltered: Bool, calmMotion: Bool) {
        // The idle bob lives on the art container so it never fights the
        // puff scale animation on the node itself.
        let pulse = calmMotion ? 1 : 1 + CGFloat(sin(time * 2)) * 0.015
        artContainer.yScale = pulse
        alpha = isSheltered ? 0.88 : 1

        if isSheltered {
            sprite.removeAction(forKey: "expression")
            sprite.setScale(1)
            sprite.zRotation = 0
        }
        if sprite.action(forKey: "expression") == nil {
            sprite.texture = isSheltered ? hidingTexture : neutralTexture
            sprite.size = isSheltered
                ? CGSize(width: 88, height: 88)
                : CGSize(width: 132, height: 132)
        }
    }

    func celebrate() {
        sprite.removeAction(forKey: "expression")
        sprite.texture = eatingTexture
        sprite.size = CGSize(width: 136, height: 136)
        sprite.run(.sequence([
            .scale(to: 1.10, duration: 0.10),
            .scale(to: 0.96, duration: 0.10),
            .scale(to: 1.04, duration: 0.10),
            .wait(forDuration: 0.28),
            .run { [weak self] in
                self?.sprite.texture = self?.neutralTexture
                self?.sprite.size = CGSize(width: 132, height: 132)
            },
            .scale(to: 1, duration: 0.12)
        ]), withKey: "expression")
    }

    func getScared() {
        sprite.removeAction(forKey: "expression")
        sprite.texture = scaredTexture
        sprite.size = CGSize(width: 136, height: 136)
        let shake = SKAction.sequence([
            .rotate(byAngle: 0.10, duration: 0.05),
            .rotate(byAngle: -0.20, duration: 0.10),
            .rotate(byAngle: 0.10, duration: 0.05)
        ])
        sprite.run(.sequence([
            .repeat(shake, count: 3),
            .wait(forDuration: 0.45),
            .run { [weak self] in
                self?.sprite.texture = self?.neutralTexture
                self?.sprite.size = CGSize(width: 132, height: 132)
            }
        ]), withKey: "expression")
    }

    func puffUp() {
        guard puffScale != 2 else { return }
        puffScale = 2
        removeAction(forKey: "puff")
        let grow = SKAction.scale(to: 2, duration: 0.18)
        grow.timingMode = .easeOut
        run(grow, withKey: "puff")
    }

    func endPuff() {
        guard puffScale != 1 else { return }
        puffScale = 1
        removeAction(forKey: "puff")
        let shrink = SKAction.scale(to: 1, duration: 0.22)
        shrink.timingMode = .easeIn
        run(shrink, withKey: "puff")
    }

    func cancelPuff() {
        puffScale = 1
        removeAction(forKey: "puff")
        setScale(1)
    }

    func resetPose() {
        removeAllActions()
        sprite.removeAllActions()
        facing = 1
        puffScale = 1
        xScale = 1
        yScale = 1
        artContainer.xScale = 1
        artContainer.yScale = 1
        sprite.setScale(1)
        sprite.zRotation = 0
        sprite.texture = neutralTexture
        sprite.size = CGSize(width: 132, height: 132)
        zRotation = 0
        alpha = 1
    }
}

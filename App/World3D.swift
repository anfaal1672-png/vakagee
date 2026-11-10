import SceneKit
import UIKit
import GameCore

/// 3D の世界(道・ゲート・群衆・ボス・カメラ)。
/// ルールは一切持たず、GameScene から言われた通りに見た目を動かすだけ。
final class World3D {
    enum Look { case normal, negative, nan }

    /// 2D 側の距離(ポイント)を 3D の長さに直す係数
    static let unit: Float = 0.03
    /// プレイヤーが左右に動ける幅(中心からの距離)
    static let laneLimit: Float = 2.2
    static let roadWidth: CGFloat = 5.8

    let scene = SCNScene()
    weak var view: SCNView?
    let cameraNode = SCNNode()

    private let cameraRig = SCNNode()
    private let cameraBase = SCNVector3(0, 7.2, 10.5)
    private let track = SCNNode()
    private let road = SCNNode()
    private let ground = SCNNode()
    private var dashes: [SCNNode] = []
    private var decos: [SCNNode] = []

    private let player = SCNNode()
    private let bodies = SCNNode()
    private var prototype = SCNNode()
    private var followers: [SCNNode] = []
    private var countLabel = SCNNode()
    private var skinID = ""
    private var look: Look = .normal

    private final class RowVisual {
        var left: SCNNode?
        var right: SCNNode?
        var enemy: SCNNode?
    }
    private var rowVisuals: [RowVisual] = []
    private var boss = SCNNode()
    private var bossBody = SCNNode()
    private var bossHPLabel = SCNNode()
    private var bossZ: Float = 0

    // MARK: - 初期化

    init() {
        // カメラ(斜め後ろ上から見下ろす)
        let camera = SCNCamera()
        camera.fieldOfView = 62
        camera.zNear = 0.5
        camera.zFar = 260
        cameraNode.camera = camera
        cameraNode.position = cameraBase
        cameraNode.look(at: SCNVector3(0, 0.6, -9))
        cameraRig.addChildNode(cameraNode)
        scene.rootNode.addChildNode(cameraRig)

        // 光
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 550
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 900
        sun.castsShadow = true
        sun.shadowColor = UIColor(white: 0, alpha: 0.4)
        sun.shadowRadius = 4
        sun.shadowMapSize = CGSize(width: 1024, height: 1024)
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-1.05, 0.5, 0)
        scene.rootNode.addChildNode(sunNode)

        // 地面と道
        let groundPlane = SCNPlane(width: 400, height: 500)
        groundPlane.materials = [Models.material(.green)]
        ground.geometry = groundPlane
        ground.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        ground.position = SCNVector3(0, -0.06, -150)
        scene.rootNode.addChildNode(ground)

        let roadBox = SCNBox(width: World3D.roadWidth, height: 0.1, length: 500, chamferRadius: 0)
        roadBox.materials = [Models.material(.darkGray)]
        road.geometry = roadBox
        road.position = SCNVector3(0, -0.05, -200)
        scene.rootNode.addChildNode(road)

        for side in [Float(-1), Float(1)] {
            let curb = SCNBox(width: 0.25, height: 0.3, length: 500, chamferRadius: 0.05)
            curb.materials = [Models.material(.white)]
            let node = SCNNode(geometry: curb)
            node.position = SCNVector3(side * (Float(World3D.roadWidth) / 2 + 0.12), 0.05, -200)
            scene.rootNode.addChildNode(node)
        }

        // センターライン
        for _ in 0..<28 {
            let dash = SCNBox(width: 0.16, height: 0.02, length: 1.6, chamferRadius: 0)
            dash.materials = [Models.material(.white)]
            let node = SCNNode(geometry: dash)
            node.castsShadow = false
            dashes.append(node)
            scene.rootNode.addChildNode(node)
        }

        // 道ばたの飾り(ちょうちんと竹)
        for i in 0..<20 {
            let node = i % 2 == 0 ? World3D.makeLantern() : World3D.makeBamboo()
            decos.append(node)
            scene.rootNode.addChildNode(node)
        }

        scene.rootNode.addChildNode(track)

        player.addChildNode(bodies)
        scene.rootNode.addChildNode(player)

        scene.fogStartDistance = 60
        scene.fogEndDistance = 150
        setDecor(offset: 0)
        applyLook(.normal, level: 1)
    }

    private static func makeLantern() -> SCNNode {
        let root = SCNNode()
        Models.add(root, SCNCylinder(radius: 0.06, height: 3.2), UIColor(white: 0.2, alpha: 1), y: 1.6)
        Models.add(root, Models.sphere(0.45), UIColor(red: 0.95, green: 0.15, blue: 0.1, alpha: 1), y: 3.2, sy: 0.85)
        Models.add(root, SCNCylinder(radius: 0.2, height: 0.1), UIColor(red: 1, green: 0.8, blue: 0.1, alpha: 1), y: 3.6)
        Models.add(root, SCNCylinder(radius: 0.2, height: 0.1), UIColor(red: 1, green: 0.8, blue: 0.1, alpha: 1), y: 2.8)
        return root.flattenedClone()
    }

    private static func makeBamboo() -> SCNNode {
        let root = SCNNode()
        let green = UIColor(red: 0.3, green: 0.7, blue: 0.25, alpha: 1)
        Models.add(root, SCNCylinder(radius: 0.1, height: 4.4), green, y: 2.2)
        Models.add(root, SCNCylinder(radius: 0.08, height: 3.4), green, x: 0.35, y: 1.7, z: 0.2)
        Models.add(root, Models.sphere(0.5), UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1), y: 4.5, sy: 0.5)
        return root.flattenedClone()
    }

    // MARK: - 色と見た目の切り替え

    func applyLook(_ newLook: Look, level: Int) {
        look = newLook
        let sky: UIColor
        let groundColor: UIColor
        let roadColor: UIColor
        switch newLook {
        case .normal:
            let h = CGFloat((level * 47) % 360) / 360
            sky = UIColor(hue: h, saturation: 0.45, brightness: 1.0, alpha: 1)
            groundColor = UIColor(hue: (h + 0.33).truncatingRemainder(dividingBy: 1), saturation: 0.55, brightness: 0.85, alpha: 1)
            roadColor = UIColor(hue: (h + 0.5).truncatingRemainder(dividingBy: 1), saturation: 0.25, brightness: 0.3, alpha: 1)
        case .negative:
            sky = UIColor(red: 0.1, green: 0.0, blue: 0.2, alpha: 1)
            groundColor = UIColor(red: 0.35, green: 0.0, blue: 0.45, alpha: 1)
            roadColor = UIColor(red: 0.0, green: 0.7, blue: 0.55, alpha: 1)
        case .nan:
            sky = .black
            groundColor = UIColor(white: 0.05, alpha: 1)
            roadColor = UIColor(white: 0.16, alpha: 1)
        }
        scene.background.contents = sky
        scene.fogColor = sky
        ground.geometry?.firstMaterial?.diffuse.contents = groundColor
        road.geometry?.firstMaterial?.diffuse.contents = roadColor

        // 裏世界では全員ひっくり返る。NaN では骨組みだけになる。
        bodies.eulerAngles = SCNVector3(0, 0, newLook == .negative ? Float.pi : 0)
        bodies.position = SCNVector3(0, newLook == .negative ? 1.0 : 0, 0)
        cameraRig.eulerAngles.z = newLook == .negative ? 0.12 : 0
        let wire = newLook == .nan
        bodies.enumerateHierarchy { node, _ in
            node.geometry?.materials.forEach { $0.fillMode = wire ? .lines : .fill }
        }
        bodies.removeAction(forKey: "nan")
        bodies.opacity = 1
        if wire {
            let jitter = SCNAction.sequence([
                SCNAction.run { node in
                    node.position = SCNVector3(Float.random(in: -0.15...0.15), Float.random(in: 0...0.2), Float.random(in: -0.15...0.15))
                    node.opacity = CGFloat.random(in: 0.45...1)
                },
                SCNAction.wait(duration: 0.05)
            ])
            bodies.runAction(SCNAction.repeatForever(jitter), forKey: "nan")
        }
    }

    // MARK: - スクロール

    /// 道ばたの飾りとセンターラインを流す。offset は 3D の長さ。
    func setDecor(offset: Float) {
        let dashSpan: Float = 4
        for (i, node) in dashes.enumerated() {
            let z = -Float(i) * dashSpan + World3D.wrap(offset, dashSpan) + 10
            node.position = SCNVector3(0, 0.02, z)
        }
        let decoSpan: Float = 9
        let total = decoSpan * Float(decos.count / 2)
        for (i, node) in decos.enumerated() {
            let side: Float = i % 2 == 0 ? -1 : 1
            let base = -Float(i / 2) * decoSpan - (i % 2 == 0 ? 0 : decoSpan / 2)
            let z = World3D.wrap(base + offset, total) - total + 14
            node.position = SCNVector3(side * (Float(World3D.roadWidth) / 2 + 1.3), 0, z)
        }
    }

    private static func wrap(_ v: Float, _ span: Float) -> Float {
        let r = v.truncatingRemainder(dividingBy: span)
        return r < 0 ? r + span : r
    }

    /// scroll は 2D 側の距離(ポイント)
    func setScroll(_ scroll: CGFloat) {
        track.position = SCNVector3(0, 0, Float(scroll) * World3D.unit)
    }

    func setPlayerX(_ x: Float) {
        player.position.x = x
    }

    // MARK: - プレイヤーと群衆

    func setSkin(_ id: String) {
        guard id != skinID else { return }
        skinID = id
        prototype = Models.character(id).flattenedClone()
        rebuildBodies(count: max(followers.count, 0))
    }

    private func makeRunner(index: Int) -> SCNNode {
        let node = prototype.clone()
        // 1 人ずつ材質を持たせる(NaN のときだけ骨組み表示にするため)
        if let geometry = node.geometry?.copy() as? SCNGeometry {
            geometry.materials = geometry.materials.map { ($0.copy() as? SCNMaterial) ?? $0 }
            node.geometry = geometry
        }
        let phase = Double(index % 5) * 0.04
        let hop = SCNAction.sequence([
            SCNAction.wait(duration: phase),
            SCNAction.repeatForever(SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.22, z: 0, duration: 0.13),
                SCNAction.moveBy(x: 0, y: -0.22, z: 0, duration: 0.13)
            ]))
        ])
        node.runAction(hop)
        let wobble = SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.rotateBy(x: 0, y: 0, z: 0.16, duration: 0.13),
            SCNAction.rotateBy(x: 0, y: 0, z: -0.32, duration: 0.26),
            SCNAction.rotateBy(x: 0, y: 0, z: 0.16, duration: 0.13)
        ]))
        node.runAction(wobble)
        return node
    }

    private func rebuildBodies(count: Int) {
        bodies.childNodes.forEach { $0.removeFromParentNode() }
        followers = []
        let leader = makeRunner(index: 0)
        leader.scale = SCNVector3(1.25, 1.25, 1.25)
        bodies.addChildNode(leader)
        for i in 0..<count {
            let node = makeRunner(index: i + 1)
            // ひまわりの種の並び(中心から外へ)
            let angle = Float(i + 1) * 2.4
            let radius = 0.36 * Float(i + 1).squareRoot() + 0.25
            node.position = SCNVector3(cos(angle) * radius, 0, sin(angle) * radius * 0.9)
            node.scale = SCNVector3(0.8, 0.8, 0.8)
            bodies.addChildNode(node)
            followers.append(node)
        }
        let wire = look == .nan
        if wire {
            bodies.enumerateHierarchy { node, _ in
                node.geometry?.materials.forEach { $0.fillMode = .lines }
            }
        }
    }

    /// 頭上の数字と、取り巻きの人数を更新する。
    func setCount(text: String, color: UIColor, crowd: Int) {
        if countLabel.parent == nil {
            countLabel = Models.label(text, height: 0.95, maxWidth: 4.6, color: color, billboard: true)
            countLabel.position = SCNVector3(0, 2.3, 0)
            player.addChildNode(countLabel)
        } else {
            Models.setLabel(countLabel, text, height: 0.95, maxWidth: 4.6, color: color)
        }
        let n = min(max(crowd, 0), 30)
        if n != followers.count {
            rebuildBodies(count: n)
        }
    }

    func punchCount() {
        countLabel.removeAction(forKey: "punch")
        countLabel.scale = SCNVector3(1, 1, 1)
        countLabel.runAction(SCNAction.sequence([
            SCNAction.scale(to: 1.6, duration: 0.06),
            SCNAction.scale(to: 1.0, duration: 0.14)
        ]), forKey: "punch")
    }

    /// プレイヤーの画面上の位置(ビュー座標、左上原点)
    func playerViewPoint() -> CGPoint {
        guard let view = view else { return .zero }
        let p = view.projectPoint(SCNVector3(player.position.x, 1.2, player.position.z))
        return CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
    }

    // MARK: - タイトル画面

    func showIdle(skin: String, level: Int) {
        clearTrack()
        setSkin(skin)
        resetPlayer()
        applyLook(.normal, level: level)
        countLabel.removeFromParentNode()
        rebuildBodies(count: 6)
        cameraRig.removeAction(forKey: "orbit")
        cameraRig.eulerAngles = SCNVector3(0, 0, 0)
        let swing = SCNAction.sequence([
            SCNAction.rotateBy(x: 0, y: 0.5, z: 0, duration: 3),
            SCNAction.rotateBy(x: 0, y: -1.0, z: 0, duration: 6),
            SCNAction.rotateBy(x: 0, y: 0.5, z: 0, duration: 3)
        ])
        swing.timingMode = .easeInEaseOut
        cameraRig.runAction(SCNAction.repeatForever(swing), forKey: "orbit")
    }

    private func resetPlayer() {
        player.removeAllActions()
        player.position = SCNVector3(0, 0, 0)
        player.eulerAngles = SCNVector3(0, 0, 0)
        player.scale = SCNVector3(1, 1, 1)
        player.opacity = 1
        player.isHidden = false
        bodies.removeAllActions()
        bodies.scale = SCNVector3(1, 1, 1)
    }

    private func clearTrack() {
        track.childNodes.forEach { $0.removeFromParentNode() }
        rowVisuals = []
        boss = SCNNode()
        track.position = SCNVector3(0, 0, 0)
    }

    // MARK: - レベルの組み立て

    private static func gateColor(_ kind: GateOp.Kind) -> UIColor {
        switch kind {
        case .good: return UIColor(red: 0.16, green: 0.56, blue: 1.0, alpha: 1)
        case .bad: return UIColor(red: 1.0, green: 0.22, blue: 0.22, alpha: 1)
        case .mystery: return UIColor(red: 0.62, green: 0.3, blue: 0.95, alpha: 1)
        case .glitch: return UIColor(red: 0.05, green: 0.4, blue: 0.15, alpha: 1)
        }
    }

    private func makeGate(_ op: GateOp, x: Float) -> SCNNode {
        let root = SCNNode()
        root.position = SCNVector3(x, 0, 0)
        let width = World3D.roadWidth / 2 - 0.2
        let panel = SCNBox(width: width, height: 2.6, length: 0.12, chamferRadius: 0.05)
        let m = Models.material(World3D.gateColor(op.kind))
        m.transparency = 0.62
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
        panel.materials = [m]
        let panelNode = SCNNode(geometry: panel)
        panelNode.position = SCNVector3(0, 1.4, 0)
        panelNode.renderingOrder = 10
        panelNode.castsShadow = false
        root.addChildNode(panelNode)

        // 枠
        let frameColor = UIColor.white
        Models.add(root, SCNBox(width: width + 0.16, height: 0.16, length: 0.22, chamferRadius: 0.04), frameColor, y: 2.78)
        for side in [Float(-1), Float(1)] {
            Models.add(root, SCNCylinder(radius: 0.09, height: 2.8), frameColor, x: side * Float(width) / 2, y: 1.4)
        }

        let label = Models.label(op.label, height: 1.25, maxWidth: width - 0.3, color: op.kind == .glitch ? .green : .white, billboard: false)
        label.position = SCNVector3(0, 1.45, 0.12)
        label.eulerAngles = SCNVector3(-0.32, 0, 0)
        root.addChildNode(label)

        if op.kind == .glitch {
            root.runAction(SCNAction.repeatForever(SCNAction.sequence([
                SCNAction.moveBy(x: 0.12, y: 0, z: 0, duration: 0.03),
                SCNAction.moveBy(x: -0.2, y: 0.08, z: 0, duration: 0.03),
                SCNAction.moveBy(x: 0.08, y: -0.08, z: 0, duration: 0.03),
                SCNAction.wait(duration: 0.25)
            ])))
        }
        return root
    }

    func buildLevel(
        spec: LevelSpec,
        rowDistances: [CGFloat],
        bossDistance: CGFloat,
        bossHPText: String,
        skin: String
    ) {
        cameraRig.removeAction(forKey: "orbit")
        cameraRig.eulerAngles = SCNVector3(0, 0, 0)
        cameraNode.removeAllActions()
        cameraNode.position = cameraBase
        clearTrack()
        setSkin(skin)
        resetPlayer()

        let lane = Float(World3D.roadWidth) / 4
        let minion = Models.boss(emoji: spec.bossEmoji).flattenedClone()

        for (i, row) in spec.rows.enumerated() {
            let visual = RowVisual()
            let holder = SCNNode()
            holder.position = SCNVector3(0, 0, -Float(rowDistances[i]) * World3D.unit)
            switch row {
            case .gates(let l, let r):
                let left = makeGate(l, x: -lane)
                let right = makeGate(r, x: lane)
                holder.addChildNode(left)
                holder.addChildNode(right)
                visual.left = left
                visual.right = right
            case .enemy(let side, let value):
                let group = SCNNode()
                group.position = SCNVector3(side == .left ? -lane : lane, 0, 0)
                let spots: [(Float, Float)] = [(-0.8, 0), (0, 0.2), (0.8, 0), (-0.4, 0.9), (0.4, 0.9)]
                for (j, spot) in spots.enumerated() {
                    let m = minion.clone()
                    m.position = SCNVector3(spot.0, 0, spot.1)
                    m.runAction(SCNAction.sequence([
                        SCNAction.wait(duration: Double(j) * 0.06),
                        SCNAction.repeatForever(SCNAction.sequence([
                            SCNAction.moveBy(x: 0, y: 0.3, z: 0, duration: 0.16),
                            SCNAction.moveBy(x: 0, y: -0.3, z: 0, duration: 0.16)
                        ]))
                    ]))
                    group.addChildNode(m)
                }
                let label = Models.label(
                    "−" + JPNumber.format(value), height: 1.0, maxWidth: 2.6,
                    color: UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 1), billboard: true
                )
                label.position = SCNVector3(0, 2.0, 0.3)
                group.addChildNode(label)
                holder.addChildNode(group)
                visual.enemy = group
            }
            track.addChildNode(holder)
            rowVisuals.append(visual)
        }

        // ボス
        bossZ = -Float(bossDistance) * World3D.unit
        boss = SCNNode()
        boss.position = SCNVector3(0, 0, bossZ)
        bossBody = Models.boss(emoji: spec.bossEmoji).flattenedClone()
        bossBody.scale = SCNVector3(4.2, 4.2, 4.2)
        bossBody.runAction(SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.scale(to: 4.5, duration: 0.35),
            SCNAction.scale(to: 4.0, duration: 0.35)
        ])))
        boss.addChildNode(bossBody)
        let name = Models.label(spec.bossName, height: 0.7, maxWidth: 6.4, color: .white, billboard: true)
        name.position = SCNVector3(0, 7.4, 0)
        boss.addChildNode(name)
        bossHPLabel = Models.label(bossHPText, height: 1.1, maxWidth: 6.4, color: UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 1), billboard: true)
        bossHPLabel.position = SCNVector3(0, 6.4, 0)
        boss.addChildNode(bossHPLabel)
        // 足場
        let stage = SCNCylinder(radius: 4.2, height: 0.12)
        stage.materials = [Models.material(UIColor(red: 1, green: 0.8, blue: 0.1, alpha: 1))]
        let stageNode = SCNNode(geometry: stage)
        stageNode.position = SCNVector3(0, 0.02, 0)
        boss.addChildNode(stageNode)
        track.addChildNode(boss)
    }

    // MARK: - 行の演出

    func passGate(row: Int, left: Bool) {
        guard row < rowVisuals.count else { return }
        let visual = rowVisuals[row]
        let chosen = left ? visual.left : visual.right
        let other = left ? visual.right : visual.left
        other?.opacity = 0.2
        chosen?.runAction(SCNAction.sequence([
            SCNAction.scale(to: 1.25, duration: 0.06),
            SCNAction.scale(to: 1.0, duration: 0.12),
            SCNAction.fadeOpacity(to: 0.25, duration: 0.2)
        ]), forKey: "pass")
    }

    func rearmGate(row: Int) {
        guard row < rowVisuals.count else { return }
        for node in [rowVisuals[row].left, rowVisuals[row].right] {
            node?.removeAction(forKey: "pass")
            node?.opacity = 1
            node?.scale = SCNVector3(1, 1, 1)
        }
    }

    func scatterEnemy(row: Int) {
        guard row < rowVisuals.count, let group = rowVisuals[row].enemy else { return }
        rowVisuals[row].enemy = nil
        for child in group.childNodes {
            child.removeAllActions()
            let fly = SCNAction.group([
                SCNAction.moveBy(x: CGFloat.random(in: -6...6), y: CGFloat.random(in: 4...9), z: CGFloat.random(in: -8...2), duration: 0.5),
                SCNAction.rotateBy(x: CGFloat.random(in: -8...8), y: 0, z: CGFloat.random(in: -8...8), duration: 0.5),
                SCNAction.fadeOut(duration: 0.5)
            ])
            child.runAction(fly)
        }
        group.runAction(SCNAction.sequence([SCNAction.wait(duration: 0.55), SCNAction.removeFromParentNode()]))
    }

    // MARK: - エフェクト

    func shake(_ power: Float, duration: TimeInterval) {
        cameraNode.removeAction(forKey: "shake")
        let steps = max(2, Int(duration / 0.03))
        var actions: [SCNAction] = []
        for i in 0..<steps {
            let fade = 1 - Float(i) / Float(steps)
            let p = SCNVector3(
                cameraBase.x + Float.random(in: -power...power) * fade,
                cameraBase.y + Float.random(in: -power...power) * fade,
                cameraBase.z
            )
            actions.append(SCNAction.move(to: p, duration: 0.03))
        }
        actions.append(SCNAction.move(to: cameraBase, duration: 0.03))
        cameraNode.runAction(SCNAction.sequence(actions), forKey: "shake")
    }

    /// 四角い粒が飛び散る
    func burst(atPlayer: Bool, color: UIColor, amount: Int) {
        let system = SCNParticleSystem()
        system.loops = false
        system.birthRate = CGFloat(amount) / 0.05
        system.emissionDuration = 0.05
        system.particleLifeSpan = 0.7
        system.particleLifeSpanVariation = 0.3
        system.particleSize = 0.22
        system.particleSizeVariation = 0.12
        system.particleColor = color
        system.particleColorVariation = SCNVector4(0.08, 0.2, 0.1, 0)
        system.particleVelocity = 9
        system.particleVelocityVariation = 5
        system.spreadingAngle = 180
        system.acceleration = SCNVector3(0, -14, 0)
        system.particleAngularVelocity = 400
        system.particleAngularVelocityVariation = 300
        system.blendMode = .alpha
        let node = SCNNode()
        if atPlayer {
            node.position = SCNVector3(player.position.x, 1.0, player.position.z)
        } else {
            node.position = SCNVector3(0, 3.5, bossZ + track.position.z + 1.5)
        }
        scene.rootNode.addChildNode(node)
        node.addParticleSystem(system)
        node.runAction(SCNAction.sequence([SCNAction.wait(duration: 1.6), SCNAction.removeFromParentNode()]))
    }

    /// 壁抜けバグ用: 一瞬で反対側へ
    func warpFlash() {
        bodies.runAction(SCNAction.sequence([
            SCNAction.scale(to: 0.2, duration: 0.03),
            SCNAction.scale(to: 1.4, duration: 0.06),
            SCNAction.scale(to: 1.0, duration: 0.08)
        ]))
    }

    // MARK: - ボス戦・全滅

    /// 溜めてから突進する。合計 `chargeDuration` 秒。
    static let chargeDuration: TimeInterval = 0.97

    func playerCharge() {
        let target = SCNVector3(0, 0, bossZ + track.position.z + 3.6)
        let windUp = SCNAction.moveBy(x: 0, y: 0, z: 1.6, duration: 0.3)
        windUp.timingMode = .easeOut
        let dash = SCNAction.move(to: target, duration: 0.22)
        dash.timingMode = .easeIn
        player.runAction(SCNAction.sequence([SCNAction.wait(duration: 0.45), windUp, dash]))
        // カメラも少し寄る
        let zoom = SCNAction.move(to: SCNVector3(cameraBase.x, cameraBase.y - 1.2, cameraBase.z - 2.5), duration: 0.9)
        zoom.timingMode = .easeInEaseOut
        cameraNode.runAction(zoom, forKey: "zoom")
    }

    func setBossHP(_ text: String) {
        Models.setLabel(bossHPLabel, text, height: 1.1, maxWidth: 6.4, color: UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 1))
    }

    /// ボスが吹っ飛ぶ。comesBack なら空から落ちてきて転がっていく(わざと残したバグ)。
    func bossDefeated(comesBack: Bool) {
        bossBody.removeAllActions()
        let side: CGFloat = Bool.random() ? 1 : -1
        let fly = SCNAction.group([
            SCNAction.moveBy(x: side * 14, y: 26, z: -40, duration: 0.9),
            SCNAction.rotateBy(x: 9, y: 4, z: side * 12, duration: 0.9)
        ])
        var steps: [SCNAction] = [SCNAction.wait(duration: 0.12), fly]
        if comesBack {
            let dropX = Float.random(in: -1.5...1.5)
            // ボスはコース(track)の子なので、カメラの手前に来るよう位置を換算する
            let dropZ = 2.5 - track.position.z
            let drop = SCNAction.run { node in
                node.position = SCNVector3(dropX, 30, dropZ)
                node.eulerAngles = SCNVector3(0, 0, 0)
            }
            let fall = SCNAction.moveBy(x: 0, y: -30, z: 0, duration: 0.45)
            fall.timingMode = .easeIn
            let bounce = SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 3, z: 1.5, duration: 0.18),
                SCNAction.moveBy(x: 0, y: -3, z: 1.5, duration: 0.18)
            ])
            let rollAway = SCNAction.group([
                SCNAction.moveBy(x: side * 16, y: 0, z: 6, duration: 0.9),
                SCNAction.rotateBy(x: 0, y: 0, z: -side * 10, duration: 0.9)
            ])
            steps.append(contentsOf: [SCNAction.wait(duration: 0.5), drop, fall, bounce, rollAway])
        }
        steps.append(SCNAction.removeFromParentNode())
        boss.runAction(SCNAction.sequence(steps))
    }

    func bossLaugh() {
        bossBody.removeAllActions()
        bossBody.runAction(SCNAction.repeat(SCNAction.sequence([
            SCNAction.scale(to: 5.2, duration: 0.1),
            SCNAction.scale(to: 4.2, duration: 0.1)
        ]), count: 5))
    }

    func playerFlung() {
        let side: CGFloat = Bool.random() ? 1 : -1
        player.runAction(SCNAction.sequence([
            SCNAction.wait(duration: 0.08),
            SCNAction.group([
                SCNAction.moveBy(x: side * 7, y: 9, z: 16, duration: 0.8),
                SCNAction.rotateBy(x: 10, y: 0, z: side * 9, duration: 0.8)
            ]),
            SCNAction.hide()
        ]))
    }

    func playerVanish() {
        player.runAction(SCNAction.sequence([
            SCNAction.group([
                SCNAction.scale(to: 0.05, duration: 0.4),
                SCNAction.rotateBy(x: 0, y: 12, z: 0, duration: 0.4)
            ]),
            SCNAction.hide()
        ]))
    }
}

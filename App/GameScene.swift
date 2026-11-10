import SpriteKit
import UIKit
import GameCore

final class RowState {
    let index: Int
    let row: Row
    /// スタート地点からの距離(ポイント)
    let y: CGFloat
    var armed = true
    var consumed = false

    init(index: Int, row: Row, y: CGFloat) {
        self.index = index
        self.row = row
        self.y = y
    }
}

final class GameScene: SKScene {
    enum Phase { case title, playing, cinematic, result }
    enum Modal { case none, shop, debug }
    enum WorldState { case normal, negative, nan }

    // MARK: - 設定(ViewController から渡される)
    /// 3D の世界。この 2D シーンはその上に重なる透明な UI 層。
    var world: World3D!
    var safeTop: CGFloat = 50
    var safeBottom: CGFloat = 34

    // MARK: - 全体の状態
    var phase: Phase = .title
    var modal: Modal = .none
    var save = Store.load()
    let audio = AudioEngine.shared
    var runtimeRNG = SeededRNG(seed: UInt64(Date().timeIntervalSince1970 * 1000))
    var didSetup = false
    var now: TimeInterval = 0
    var lastUpdate: TimeInterval = 0
    var inputLockUntil: TimeInterval = 0

    // MARK: - レイヤー
    let shakeRoot = SKNode()
    let fxLayer = SKNode()
    let hudLayer = SKNode()
    let uiLayer = SKNode()
    let topFx = SKNode()
    let modalLayer = SKNode()

    var bgOffset: CGFloat = 0

    // MARK: - プレイ中の状態
    var spec = LevelGenerator.make(level: 1)
    var count: Double = 1
    var bossHP: Double = 1
    var combo = 0
    var maxCombo = 0
    var scroll: CGFloat = 0
    var rows: [RowState] = []
    var bossY: CGFloat = 0
    var playerX: CGFloat = 195
    var worldState: WorldState = .normal
    var maxUnitSeen = 0
    var hitStop: Double = 0
    var hasMoved = false

    // わざと残してあるバグ用の状態
    var wrapsLeft = 2
    var edgePush: CGFloat = 0
    var backstepsLeft = 2
    var backstepTimer: Double = 0
    var flickAccum: CGFloat = 0
    var flickStart: TimeInterval = 0
    var debugBossOneHP = false
    var versionTaps = 0

    var crowdSize = -1

    // MARK: - HUD
    let levelLabel = PopLabel("LEVEL 1", size: 20)
    let coinLabel = PopLabel("🪙 0", size: 20)
    let comboLabel = PopLabel("", size: 30, color: .gold)
    let targetLabel = PopLabel("", size: 18)
    let progressFill = SKSpriteNode(color: .gold, size: CGSize(width: 10, height: 10))
    var hintNode: SKNode?

    // MARK: - リザルト
    var resultReward = 0
    var resultBonus = 0
    var coinTaps = 0
    var coinTapDeadline: TimeInterval = 0
    var resultCoinLabel: PopLabel?
    var resultIsNaN = false

    var W: CGFloat { size.width }
    var H: CGFloat { size.height }
    /// コース上の基準位置(ポイント)。画面の大きさには依存しない。
    var playerY: CGFloat { 200 }
    var bossScreenY: CGFloat { 580 }
    var skinEmoji: String { SkinCatalog.skin(id: save.selectedSkin).emoji }

    // MARK: - セットアップ

    override func didMove(to view: SKView) {
        guard !didSetup else { return }
        didSetup = true
        anchorPoint = .zero

        backgroundColor = .clear
        fxLayer.zPosition = 20
        shakeRoot.addChild(fxLayer)
        addChild(shakeRoot)
        hudLayer.zPosition = 30
        uiLayer.zPosition = 40
        topFx.zPosition = 50
        modalLayer.zPosition = 60
        addChild(hudLayer)
        addChild(uiLayer)
        addChild(topFx)
        addChild(modalLayer)

        buildHUD()

        audio.enabled = save.soundOn
        audio.start()
        showTitle()
    }

    func buildHUD() {
        let top = H - safeTop - 18
        levelLabel.position = CGPoint(x: 70, y: top)
        hudLayer.addChild(levelLabel)
        coinLabel.position = CGPoint(x: W - 80, y: top)
        hudLayer.addChild(coinLabel)

        let barWidth = W - 40
        let back = SKSpriteNode(color: SKColor(white: 0, alpha: 0.35), size: CGSize(width: barWidth, height: 10))
        back.anchorPoint = CGPoint(x: 0, y: 0.5)
        back.position = CGPoint(x: 20, y: top - 26)
        hudLayer.addChild(back)
        progressFill.size = CGSize(width: barWidth, height: 10)
        progressFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        progressFill.position = back.position
        progressFill.xScale = 0
        hudLayer.addChild(progressFill)

        targetLabel.position = CGPoint(x: W / 2, y: top - 50)
        hudLayer.addChild(targetLabel)

        comboLabel.position = CGPoint(x: W / 2, y: top - 96)
        comboLabel.isHidden = true
        hudLayer.addChild(comboLabel)
        refreshHUD()
    }

    // MARK: - 毎フレーム

    override func update(_ currentTime: TimeInterval) {
        now = currentTime
        var dt = lastUpdate == 0 ? 0 : currentTime - lastUpdate
        lastUpdate = currentTime
        if dt > 0.05 { dt = 0.05 }
        if dt < 0 { dt = 0 }

        scrollBackground(dt)
        guard phase == .playing else { return }

        if hitStop > 0 {
            hitStop -= dt
            return
        }

        var direction: CGFloat = 1
        if backstepTimer > 0 {
            backstepTimer -= dt
            direction = -1.4
        }
        let previous = scroll
        scroll = max(0, scroll + CGFloat(spec.speed) * direction * CGFloat(dt))

        for rn in rows {
            let before = rn.y - previous - playerY
            let after = rn.y - scroll - playerY
            if before > 0 && after <= 0 {
                if rn.armed { pass(rn) }
            } else if before <= 0 && after > 0 {
                // 【仕込みバグ】戻ったときにゲートが「未通過」に戻ってしまう
                rearm(rn)
            }
            if phase != .playing { break }
        }

        layoutWorld()
        if phase == .playing && bossY - scroll <= bossScreenY {
            beginBoss()
        }
    }

    func layoutWorld() {
        world.setScroll(scroll)
        world.setPlayerX(playerWorldX)
        let total = max(1, bossY - bossScreenY)
        progressFill.xScale = min(1, max(0, scroll / total))
    }

    /// 2D 側の横位置を 3D の横位置に直す
    var playerWorldX: Float {
        let half = W / 2 - 36
        return Float((playerX - W / 2) / max(half, 1)) * World3D.laneLimit
    }

    /// プレイヤーが画面のどこに見えているか(この 2D シーンの座標)
    func playerPoint() -> CGPoint {
        guard let view = world.view, view.bounds.width > 0 else {
            return CGPoint(x: W / 2, y: playerY)
        }
        let p = world.playerViewPoint()
        let scale = W / view.bounds.width
        return CGPoint(x: min(max(p.x * scale, 60), W - 60), y: min(max(H - p.y * scale, 120), H - 200))
    }

    func scrollBackground(_ dt: Double) {
        var v: CGFloat = 110
        if phase == .playing {
            v = CGFloat(spec.speed) * (backstepTimer > 0 ? -1.4 : 1)
            if hitStop > 0 { v = 0 }
        } else if phase == .cinematic {
            v = 0
        }
        bgOffset += v * CGFloat(dt)
        world.setDecor(offset: Float(bgOffset) * World3D.unit)
    }

    var worldLook: World3D.Look {
        switch worldState {
        case .normal: return .normal
        case .negative: return .negative
        case .nan: return .nan
        }
    }

    // MARK: - 入力

    /// その位置にあるボタンの ID。重なっている場合は `accept` が真になる最初のものを返す。
    func buttonID(at point: CGPoint, accept: (String) -> Bool) -> String? {
        for hit in nodes(at: point) {
            var node: SKNode? = hit
            while let n = node {
                if let name = n.name, name.hasPrefix("btn:") {
                    let id = String(name.dropFirst(4))
                    if accept(id) { return id }
                }
                node = n.parent
            }
        }
        return nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        flickAccum = 0
        flickStart = touch.timestamp
        edgePush = 0
        if phase == .playing && modal == .none { return }
        handleTap(touch.location(in: self))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard phase == .playing, modal == .none, let touch = touches.first else { return }
        let p = touch.location(in: self)
        let q = touch.previousLocation(in: self)
        movePlayer(by: (p.x - q.x) * 1.35)

        // 下に素早くフリック → 巻き戻りバグ
        let dy = p.y - q.y
        if dy < 0 {
            if touch.timestamp - flickStart > 0.2 {
                flickStart = touch.timestamp
                flickAccum = 0
            }
            flickAccum += -dy
            if flickAccum > 140 {
                flickAccum = 0
                tryBackstep()
            }
        } else if dy > 0 {
            flickAccum = 0
            flickStart = touch.timestamp
        }
    }

    func handleTap(_ point: CGPoint) {
        switch modal {
        case .shop:
            let id = buttonID(at: point) { $0 == "shopclose" || $0.hasPrefix("skin:") }
            if id == "shopclose" {
                audio.play(.tap)
                closeModal()
            } else if let id = id, id.hasPrefix("skin:") {
                buySkin(String(id.dropFirst(5)))
            }
            return
        case .debug:
            handleDebug(buttonID(at: point) { $0.hasPrefix("dbg:") })
            return
        case .none:
            break
        }

        let id = buttonID(at: point) { !$0.hasPrefix("skin:") && !$0.hasPrefix("dbg:") && $0 != "shopclose" }

        switch phase {
        case .title:
            if id == "shop" {
                audio.play(.tap)
                showShop()
            } else if id == "sound" {
                toggleSound()
            } else if id == "version" {
                versionTap()
            } else {
                startLevel()
            }
        case .result:
            if id == "cointap" {
                tapCoin(point)
                return
            }
            guard now >= inputLockUntil else { return }
            if id == "next" {
                startLevel()
            } else if id == "shop" {
                audio.play(.tap)
                showShop()
            } else if id == "home" {
                audio.play(.tap)
                showTitle()
            }
        case .playing, .cinematic:
            break
        }
    }

    // MARK: - ちょっとした道具

    func after(_ delay: TimeInterval, _ block: @escaping () -> Void) {
        run(.sequence([.wait(forDuration: delay), .run(block)]))
    }

    func refreshHUD() {
        levelLabel.text = "LEVEL \(save.level)"
        coinLabel.text = "🪙 \(JPNumber.format(Double(save.coins)))"
        coinLabel.fit(maxWidth: 150)
    }
}

import SpriteKit
import GameCore

extension GameScene {
    // MARK: - レベル開始

    func startLevel() {
        removeAllActions()
        uiLayer.removeAllChildren()
        topFx.removeAllChildren()
        fxLayer.removeAllChildren()
        worldLayer.removeAllChildren()
        shakeRoot.removeAllActions()
        shakeRoot.position = .zero
        resultCoinLabel = nil

        spec = LevelGenerator.make(level: save.level)
        phase = .playing
        count = spec.startCount
        bossHP = debugBossOneHP ? 1 : spec.bossHP
        debugBossOneHP = false
        combo = 0
        maxCombo = 0
        scroll = 0
        hitStop = 0
        wrapsLeft = 2
        backstepsLeft = 2
        backstepTimer = 0
        edgePush = 0
        flickAccum = 0
        playerX = W / 2
        maxUnitSeen = JPNumber.unitIndex(count)
        worldState = .normal
        audio.setBGMRate(1.0)

        // 行を並べる
        rows = []
        let firstY = H + 160
        let spacing = CGFloat(spec.rowSpacing)
        for (i, row) in spec.rows.enumerated() {
            let rn = makeRowNode(row, y: firstY + CGFloat(i) * spacing)
            rows.append(rn)
            worldLayer.addChild(rn.node)
        }

        // ボス
        bossY = firstY + CGFloat(spec.rows.count) * spacing + 260
        bossNode = SKNode()
        let body = Kit.emoji(spec.bossEmoji, size: 150)
        body.name = "body"
        bossNode.addChild(body)
        body.run(.repeatForever(.sequence([
            .scale(to: 1.08, duration: 0.35),
            .scale(to: 0.96, duration: 0.35)
        ])))
        let nameLabel = PopLabel(spec.bossName, size: 20)
        nameLabel.position = CGPoint(x: 0, y: 128)
        nameLabel.fit(maxWidth: W - 40)
        bossNode.addChild(nameLabel)
        bossHPLabel = PopLabel("HP " + JPNumber.format(bossHP), size: 34, color: .hotRed)
        bossHPLabel.position = CGPoint(x: 0, y: 98)
        bossHPLabel.fit(maxWidth: W - 60)
        bossNode.addChild(bossHPLabel)
        worldLayer.addChild(bossNode)

        // プレイヤー
        playerNode.removeAllActions()
        playerNode.removeFromParent()
        playerNode.setScale(1)
        playerNode.alpha = 1
        playerNode.zRotation = 0
        playerEmoji.text = skinEmoji
        worldLayer.addChild(playerNode)
        crowdSize = -1
        applyWorldState()
        refreshCount(pop: false)
        refreshCombo()
        refreshHUD()
        layoutWorld()
        hudLayer.isHidden = false

        // 最初のレベルだけ操作説明
        hintNode?.removeFromParent()
        hintNode = nil
        if !hasMoved {
            let hint = PopLabel("👈 指を左右に動かす 👉", size: 22)
            hint.position = CGPoint(x: W / 2, y: playerY - 90)
            hint.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.3, duration: 0.4),
                .fadeAlpha(to: 1, duration: 0.4)
            ])))
            hudLayer.addChild(hint)
            hintNode = hint
        }

        banner("LEVEL \(spec.level)", color: .white, size: 54, y: H * 0.62, hold: 0.5)
        banner("ボスの HP は \(JPNumber.format(bossHP))", color: .gold, size: 24, y: H * 0.62 - 56, hold: 0.9)
        audio.play(.start)
        Haptics.light()
    }

    // MARK: - 行の見た目

    func gateColor(_ kind: GateOp.Kind) -> SKColor {
        switch kind {
        case .good: return .skyBlue
        case .bad: return .hotRed
        case .mystery: return SKColor(red: 0.62, green: 0.3, blue: 0.95, alpha: 1)
        case .glitch: return SKColor(red: 0.05, green: 0.25, blue: 0.1, alpha: 1)
        }
    }

    func makeGatePanel(_ op: GateOp, centerX: CGFloat) -> SKNode {
        let size = CGSize(width: W / 2 - 10, height: 92)
        let root = SKNode()
        root.position = CGPoint(x: centerX, y: 0)
        let body = Kit.rect(size, color: gateColor(op.kind).withAlphaComponent(0.72), radius: 10)
        body.strokeColor = .white
        body.lineWidth = 4
        root.addChild(body)
        let label = PopLabel(op.label, size: 36, color: op.kind == .glitch ? .green : .white)
        label.fit(maxWidth: size.width - 20)
        root.addChild(label)
        if op.kind == .glitch {
            // 壊れかけのゲートはガタガタ震える
            root.run(.repeatForever(.sequence([
                .moveBy(x: 4, y: 0, duration: 0.03),
                .moveBy(x: -7, y: 2, duration: 0.03),
                .moveBy(x: 3, y: -2, duration: 0.03),
                .wait(forDuration: 0.25)
            ])))
        }
        return root
    }

    func makeRowNode(_ row: Row, y: CGFloat) -> RowNode {
        let rn = RowNode(row: row, y: y)
        switch row {
        case .gates(let l, let r):
            let lp = makeGatePanel(l, centerX: W / 4)
            let rp = makeGatePanel(r, centerX: W * 3 / 4)
            rn.leftPanel = lp
            rn.rightPanel = rp
            rn.node.addChild(lp)
            rn.node.addChild(rp)
            let pole = SKSpriteNode(color: .white, size: CGSize(width: 8, height: 110))
            pole.position = CGPoint(x: W / 2, y: 0)
            rn.node.addChild(pole)
        case .enemy(let side, let value):
            let cx = side == .left ? W / 4 : W * 3 / 4
            let group = SKNode()
            group.position = CGPoint(x: cx, y: 0)
            let offsets: [CGPoint] = [
                CGPoint(x: -48, y: 0), CGPoint(x: 0, y: 6), CGPoint(x: 48, y: 0),
                CGPoint(x: -24, y: -30), CGPoint(x: 24, y: -30)
            ]
            for (i, o) in offsets.enumerated() {
                let e = Kit.emoji(spec.bossEmoji, size: 40)
                e.position = o
                e.run(.repeatForever(.sequence([
                    .wait(forDuration: Double(i) * 0.07),
                    .moveBy(x: 0, y: 8, duration: 0.15),
                    .moveBy(x: 0, y: -8, duration: 0.15)
                ])))
                group.addChild(e)
            }
            let label = PopLabel("−" + JPNumber.format(value), size: 30, color: .hotRed)
            label.position = CGPoint(x: 0, y: 46)
            label.fit(maxWidth: W / 2 - 24)
            group.addChild(label)
            rn.leftPanel = group
            rn.node.addChild(group)
        }
        return rn
    }

    // MARK: - プレイヤーの移動

    func movePlayer(by dx: CGFloat) {
        if !hasMoved && abs(dx) > 1 {
            hasMoved = true
            hintNode?.removeFromParent()
            hintNode = nil
        }
        let minX: CGFloat = 36
        let maxX = W - 36
        var nx = playerX + dx
        var wrapTo: Bool? = nil
        if nx < minX {
            edgePush += minX - nx
            nx = minX
            if edgePush > 70 { wrapTo = true }
        } else if nx > maxX {
            edgePush += nx - maxX
            nx = maxX
            if edgePush > 70 { wrapTo = false }
        } else {
            edgePush = 0
        }
        playerX = nx
        playerNode.position.x = nx
        if let toRight = wrapTo {
            tryWrap(toRight: toRight)
        }
    }

    /// 【仕込みバグ】壁に押し付け続けると突き抜けて反対側から出てくる。なぜか数が 2 倍になる。
    func tryWrap(toRight: Bool) {
        edgePush = 0
        guard wrapsLeft > 0 else { return }
        wrapsLeft -= 1
        playerX = toRight ? W - 36 : 36
        playerNode.position.x = playerX
        let before = count
        count = GameRules.wrapDupe(count)
        glitchFlash()
        audio.play(.glitch)
        banner("壁抜けバグ発生!? ×2", color: .neon, size: 30, y: H * 0.5, hold: 0.5)
        countChanged(before: before, text: "×2 (バグ)", silent: true)
    }

    /// 【仕込みバグ】下に素早くフリックすると少しだけ巻き戻る。通過済みのゲートをもう一度くぐれる。
    func tryBackstep() {
        guard backstepsLeft > 0, backstepTimer <= 0, scroll > 200 else { return }
        backstepsLeft -= 1
        backstepTimer = 0.55
        glitchFlash()
        audio.play(.glitch)
        Haptics.medium()
        banner("⏪ 巻き戻りバグ ⏪", color: .neon, size: 30, y: H * 0.5, hold: 0.4)
    }

    // MARK: - 行の通過

    func pass(_ rn: RowNode) {
        let isLeft = playerX < W / 2
        switch rn.row {
        case .gates(let l, let r):
            rn.armed = false
            var op = isLeft ? l : r
            var text = op.label
            if op == .mystery {
                op = GameRules.resolveMystery(&runtimeRNG)
                text = "？ → " + op.label
            }
            let chosen = isLeft ? rn.leftPanel : rn.rightPanel
            let other = isLeft ? rn.rightPanel : rn.leftPanel
            other?.alpha = 0.25
            chosen?.run(.sequence([
                .scale(to: 1.25, duration: 0.06),
                .scale(to: 1.0, duration: 0.12),
                .fadeAlpha(to: 0.35, duration: 0.2)
            ]))
            let before = count
            count = GameRules.apply(op, to: count)
            countChanged(before: before, text: text, silent: false)

        case .enemy(let side, let value):
            guard !rn.consumed, (side == .left) == isLeft else { return }
            rn.consumed = true
            rn.leftPanel?.run(.sequence([
                .group([.scale(to: 1.8, duration: 0.18), .fadeOut(withDuration: 0.18)]),
                .removeFromParent()
            ]))
            burst(at: CGPoint(x: playerX, y: playerY + 40), emoji: "💥", amount: 6)
            let before = count
            count = GameRules.hitEnemy(count: count, enemy: value)
            countChanged(before: before, text: "−" + JPNumber.format(value), silent: false)
        }
    }

    func rearm(_ rn: RowNode) {
        guard case .gates = rn.row, !rn.armed else { return }
        rn.armed = true
        for panel in [rn.leftPanel, rn.rightPanel] {
            panel?.removeAllActions()
            panel?.alpha = 1
            panel?.setScale(1)
        }
    }

    // MARK: - 数が変わったとき

    func countChanged(before: Double, text: String, silent: Bool) {
        let grew = count.isNaN ? true : abs(count) > abs(before)
        combo = GameRules.nextCombo(current: combo, before: before, after: count)
        maxCombo = max(maxCombo, combo)

        floatText(
            text,
            at: CGPoint(x: min(max(playerX, 90), W - 90), y: playerY + 120),
            color: grew ? .gold : .hotRed,
            size: 40
        )

        if grew {
            if !silent { audio.play(combo >= 3 ? .big : .good) }
            Haptics.medium()
            hitStop = 0.035
            burst(at: CGPoint(x: playerX, y: playerY + 30), emoji: "✨", amount: min(4 + combo, 12))
        } else {
            if !silent { audio.play(.bad) }
            Haptics.error()
            hitStop = 0.07
            shake(9, duration: 0.25)
        }

        refreshCount(pop: true)
        updateWorldState()

        let unit = JPNumber.unitIndex(count)
        if unit > maxUnitSeen {
            maxUnitSeen = unit
            let name = JPNumber.format(count) == "∞" ? "無限" : JPNumber.units[unit]
            banner("\(name) 突破!!", color: .gold, size: 62, y: H * 0.56, hold: 0.6)
            audio.play(.unit)
            Haptics.success()
            shake(6, duration: 0.3)
            flash(.gold, alpha: 0.35)
        }
        refreshCombo()

        if GameRules.isDead(count) {
            die()
        }
    }

    func refreshCount(pop: Bool) {
        countLabel.text = JPNumber.format(count)
        countLabel.fit(maxWidth: 170)
        switch worldState {
        case .normal: countLabel.color = .white
        case .negative: countLabel.color = .neon
        case .nan: countLabel.color = .magenta
        }
        if pop { countLabel.punch(1.5) }

        // 取り巻きの数(桁が増えるほど増える)
        let magnitude = count.isNaN ? 1e6 : abs(count)
        let n = min(12, Int(log10(max(magnitude, 1)) * 1.5) + Int(min(magnitude, 4)) - 1)
        if n != crowdSize {
            crowdSize = n
            rebuildCrowd(max(0, n))
        }
    }

    func rebuildCrowd(_ n: Int) {
        crowdNode.removeAllChildren()
        let offsets: [CGPoint] = [
            CGPoint(x: -30, y: -28), CGPoint(x: 30, y: -28), CGPoint(x: 0, y: -44),
            CGPoint(x: -56, y: -44), CGPoint(x: 56, y: -44), CGPoint(x: -28, y: -66),
            CGPoint(x: 28, y: -66), CGPoint(x: -78, y: -66), CGPoint(x: 78, y: -66),
            CGPoint(x: 0, y: -86), CGPoint(x: -52, y: -90), CGPoint(x: 52, y: -90)
        ]
        let symbol = worldState == .nan ? "❓" : skinEmoji
        for i in 0..<min(n, offsets.count) {
            let e = Kit.emoji(symbol, size: 26)
            e.position = offsets[i]
            e.yScale = worldState == .negative ? -1 : 1
            e.run(.repeatForever(.sequence([
                .wait(forDuration: Double(i % 4) * 0.05),
                .moveBy(x: 0, y: 6, duration: 0.12),
                .moveBy(x: 0, y: -6, duration: 0.12)
            ])))
            crowdNode.addChild(e)
        }
    }

    func refreshCombo() {
        if combo >= 2 {
            comboLabel.isHidden = false
            comboLabel.text = "COMBO ×\(combo)"
            comboLabel.punch(min(2.0, 1.3 + CGFloat(combo) * 0.05))
        } else {
            comboLabel.isHidden = true
        }
    }

    // MARK: - 裏世界と NaN

    func updateWorldState() {
        let next: WorldState = count.isNaN ? .nan : (count < 0 ? .negative : .normal)
        guard next != worldState else { return }
        worldState = next
        applyWorldState()
        crowdSize = -1
        refreshCount(pop: false)
        glitchFlash()
        switch next {
        case .negative:
            banner("裏世界 突入", color: .neon, size: 54, y: H * 0.5, hold: 0.8)
            banner("※ここでは引き算が正義", color: .white, size: 20, y: H * 0.5 - 52, hold: 1.0)
            audio.play(.negative)
            audio.setBGMRate(0.72)
            shake(14, duration: 0.4)
        case .nan:
            banner("数ではなくなった", color: .magenta, size: 44, y: H * 0.5, hold: 0.9)
            banner("NaN は誰にも負けない(はず)", color: .white, size: 20, y: H * 0.5 - 50, hold: 1.1)
            audio.play(.nan)
            audio.setBGMRate(1.55)
            shake(14, duration: 0.4)
        case .normal:
            banner("表世界に生還", color: .gold, size: 44, y: H * 0.5, hold: 0.7)
            audio.play(.unit)
            audio.setBGMRate(1.0)
        }
    }

    func applyWorldState() {
        applyColors()
        flipNode.yScale = worldState == .negative ? -1 : 1
        flipNode.removeAction(forKey: "nan")
        flipNode.position = .zero
        flipNode.alpha = 1
        if worldState == .nan {
            let jitter = SKAction.sequence([
                .run { [weak self] in
                    self?.flipNode.position = CGPoint(x: CGFloat.random(in: -7...7), y: CGFloat.random(in: -5...5))
                    self?.flipNode.alpha = CGFloat.random(in: 0.4...1)
                },
                .wait(forDuration: 0.05)
            ])
            flipNode.run(.repeatForever(jitter), withKey: "nan")
        }
    }

    // MARK: - 全滅

    func die() {
        phase = .cinematic
        audio.play(.lose)
        audio.setBGMRate(1.0)
        Haptics.error()
        shake(16, duration: 0.5)
        burst(at: playerNode.position, emoji: skinEmoji, amount: 10)
        playerNode.run(.group([
            .scale(to: 0.1, duration: 0.4),
            .rotate(byAngle: 9, duration: 0.4),
            .fadeOut(withDuration: 0.4)
        ]))
        banner("ちょうど 0 で全滅", color: .hotRed, size: 40, y: H * 0.5, hold: 0.7)
        after(1.0) { [weak self] in
            self?.showResult(win: false, wiped: true)
        }
    }

    // MARK: - ボス戦

    func beginBoss() {
        phase = .cinematic
        scroll = bossY - bossScreenY
        layoutWorld()
        hintNode?.removeFromParent()
        hintNode = nil
        audio.play(.boss)
        Haptics.heavy()
        banner("VS", color: .hotRed, size: 90, y: H * 0.45, hold: 0.25)

        let target = CGPoint(x: W / 2, y: bossScreenY - 135)
        let windUp = SKAction.moveBy(x: 0, y: -40, duration: 0.3)
        windUp.timingMode = .easeOut
        let dash = SKAction.group([
            .move(to: target, duration: 0.22),
            .scale(to: 1.35, duration: 0.22)
        ])
        dash.timingMode = .easeIn
        playerNode.run(.sequence([
            .wait(forDuration: 0.45),
            windUp,
            dash,
            .run { [weak self] in self?.resolveBoss() }
        ]))
    }

    func resolveBoss() {
        let win = GameRules.beatsBoss(count: count, bossHP: bossHP)
        audio.play(.hit)
        audio.setBGMRate(1.0)
        Haptics.heavy()
        flash(.white, alpha: 0.9)
        shake(22, duration: 0.55)
        burst(at: CGPoint(x: W / 2, y: bossScreenY - 40), emoji: "💥", amount: 14)

        if win {
            bossHPLabel.text = "HP 0"
            bossHPLabel.punch(1.8)
            bossNode.removeAllActions()
            let side: CGFloat = Bool.random() ? 1 : -1
            let flyAway = SKAction.group([
                .moveBy(x: side * 320, y: 900, duration: 0.85),
                .rotate(byAngle: side * 16, duration: 0.85),
                .scale(to: 0.35, duration: 0.85)
            ])
            // 【仕込みバグ】吹っ飛んだボスがたまに画面の下から帰ってくる
            let comesBack = runtimeRNG.chance(0.4)
            let width = W
            let height = H
            let ending: SKAction = comesBack
                ? SKAction.sequence([
                    .wait(forDuration: 0.5),
                    .run { [weak self] in
                        self?.bossNode.position = CGPoint(x: CGFloat.random(in: 60...(width - 60)), y: -120)
                        self?.bossNode.setScale(0.8)
                    },
                    .group([
                        .moveBy(x: 0, y: height + 400, duration: 1.3),
                        .rotate(byAngle: 10, duration: 1.3)
                    ]),
                    .removeFromParent()
                ])
                : SKAction.removeFromParent()
            // ヒットストップのあとに吹っ飛ぶ
            bossNode.run(.sequence([.wait(forDuration: 0.12), flyAway, ending]))
            after(0.35) { [weak self] in self?.celebrate() }
        } else {
            let side: CGFloat = Bool.random() ? 1 : -1
            playerNode.run(.sequence([
                .wait(forDuration: 0.1),
                .group([
                    .moveBy(x: side * 260, y: -700, duration: 0.7),
                    .rotate(byAngle: side * 14, duration: 0.7),
                    .scale(to: 0.4, duration: 0.7)
                ])
            ]))
            bossNode.run(.repeat(.sequence([
                .scale(to: 1.25, duration: 0.1),
                .scale(to: 1.0, duration: 0.1)
            ]), count: 4))
            audio.play(.lose)
            banner("力不足…", color: .hotRed, size: 54, y: H * 0.45, hold: 0.6)
            after(1.0) { [weak self] in
                self?.showResult(win: false, wiped: false)
            }
        }
    }

    func celebrate() {
        audio.play(.win)
        Haptics.success()
        confetti(46)
        shake(10, duration: 0.4)
        after(0.75) { [weak self] in
            self?.showResult(win: true, wiped: false)
        }
    }
}

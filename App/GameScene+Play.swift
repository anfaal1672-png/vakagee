import SpriteKit
import UIKit
import GameCore

extension GameScene {
    // MARK: - レベル開始

    func startLevel() {
        removeAllActions()
        uiLayer.removeAllChildren()
        topFx.removeAllChildren()
        fxLayer.removeAllChildren()
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
        let firstY: CGFloat = 1000
        let spacing = CGFloat(spec.rowSpacing)
        for (i, row) in spec.rows.enumerated() {
            rows.append(RowState(index: i, row: row, y: firstY + CGFloat(i) * spacing))
        }
        bossY = firstY + CGFloat(spec.rows.count) * spacing + 260

        world.buildLevel(
            spec: spec,
            rowDistances: rows.map { $0.y - playerY },
            bossDistance: bossY - playerY,
            bossHPText: "HP " + JPNumber.format(bossHP),
            skin: save.selectedSkin
        )
        world.applyLook(.normal, level: spec.level)

        crowdSize = -1
        refreshCount(pop: false)
        refreshCombo()
        refreshHUD()
        layoutWorld()
        hudLayer.isHidden = false
        comboLabel.isHidden = true

        // 最初のレベルだけ操作説明
        hintNode?.removeFromParent()
        hintNode = nil
        if !hasMoved {
            let hint = PopLabel("👈 指を左右に動かす 👉", size: 22)
            hint.position = CGPoint(x: W / 2, y: safeBottom + 70)
            hint.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.3, duration: 0.4),
                .fadeAlpha(to: 1, duration: 0.4)
            ])))
            hudLayer.addChild(hint)
            hintNode = hint
        }

        banner("LEVEL \(spec.level)", color: .white, size: 54, y: H * 0.62, hold: 0.5)
        banner("VS \(spec.bossName)", color: .gold, size: 24, y: H * 0.62 - 56, hold: 0.9)
        audio.play(.start)
        Haptics.light()
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
        world.setPlayerX(playerWorldX)
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
        world.setPlayerX(playerWorldX)
        world.warpFlash()
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

    func pass(_ rn: RowState) {
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
            world.passGate(row: rn.index, left: isLeft)
            let before = count
            count = GameRules.apply(op, to: count)
            countChanged(before: before, text: text, silent: false)

        case .enemy(let side, let value):
            guard !rn.consumed, (side == .left) == isLeft else { return }
            rn.consumed = true
            world.scatterEnemy(row: rn.index)
            world.burst(atPlayer: true, color: .red, amount: 30)
            let before = count
            count = GameRules.hitEnemy(count: count, enemy: value)
            countChanged(before: before, text: "−" + JPNumber.format(value), silent: false)
        }
    }

    func rearm(_ rn: RowState) {
        guard case .gates = rn.row, !rn.armed else { return }
        rn.armed = true
        world.rearmGate(row: rn.index)
    }

    // MARK: - 数が変わったとき

    func countChanged(before: Double, text: String, silent: Bool) {
        let grew = count.isNaN ? true : abs(count) > abs(before)
        combo = GameRules.nextCombo(current: combo, before: before, after: count)
        maxCombo = max(maxCombo, combo)

        let anchor = playerPoint()
        floatText(
            text,
            at: CGPoint(x: min(max(anchor.x, 90), W - 90), y: anchor.y + 130),
            color: grew ? .gold : .hotRed,
            size: 44
        )

        if grew {
            if !silent { audio.play(combo >= 3 ? .big : .good) }
            Haptics.medium()
            hitStop = 0.035
            world.burst(atPlayer: true, color: .yellow, amount: min(16 + combo * 4, 60))
        } else {
            if !silent { audio.play(.bad) }
            Haptics.error()
            hitStop = 0.07
            shake(9, duration: 0.25)
            world.burst(atPlayer: true, color: .red, amount: 20)
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
        let color: UIColor
        switch worldState {
        case .normal: color = .white
        case .negative: color = .neon
        case .nan: color = .magenta
        }
        // 取り巻きの人数(桁が増えるほど増える)
        let magnitude = count.isNaN ? 1e8 : abs(count)
        let n = min(30, Int(log10(max(magnitude, 1)) * 3) + Int(min(magnitude, 6)) - 1)
        crowdSize = max(0, n)
        world.setCount(text: JPNumber.format(count), color: color, crowd: crowdSize)
        if pop { world.punchCount() }

        // ボスに届いているかを常に見せる
        let enough = GameRules.beatsBoss(count: count, bossHP: bossHP)
        targetLabel.text = "🎯 ボス HP \(JPNumber.format(bossHP))" + (enough ? " ✅" : "")
        targetLabel.color = enough ? .neon : .white
        targetLabel.fit(maxWidth: W - 40)
    }

    func refreshCombo() {
        if combo >= 2 {
            comboLabel.isHidden = false
            comboLabel.text = combo >= 5 ? "🔥COMBO ×\(combo)🔥" : "COMBO ×\(combo)"
            comboLabel.fit(maxWidth: W - 60)
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
        world.applyLook(worldLook, level: spec.level)
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

    // MARK: - 全滅

    func die() {
        phase = .cinematic
        audio.play(.lose)
        audio.setBGMRate(1.0)
        Haptics.error()
        shake(16, duration: 0.5)
        world.burst(atPlayer: true, color: .white, amount: 60)
        world.playerVanish()
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
        world.playerCharge()
        after(World3D.chargeDuration) { [weak self] in
            self?.resolveBoss()
        }
    }

    func resolveBoss() {
        let win = GameRules.beatsBoss(count: count, bossHP: bossHP)
        audio.play(.hit)
        audio.setBGMRate(1.0)
        Haptics.heavy()
        flash(.white, alpha: 0.9)
        shake(22, duration: 0.55)
        world.burst(atPlayer: false, color: .orange, amount: 120)

        if win {
            world.setBossHP("HP 0")
            // 【仕込みバグ】吹っ飛んだボスがたまに空から帰ってくる
            world.bossDefeated(comesBack: runtimeRNG.chance(0.4))
            after(0.35) { [weak self] in self?.celebrate() }
        } else {
            world.playerFlung()
            world.bossLaugh()
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

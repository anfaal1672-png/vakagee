import SpriteKit
import GameCore

extension GameScene {
    static let appVersion = "v1.0.0"

    // MARK: - タイトル

    func showTitle() {
        removeAllActions()
        phase = .title
        modal = .none
        modalLayer.removeAllChildren()
        uiLayer.removeAllChildren()
        topFx.removeAllChildren()
        fxLayer.removeAllChildren()
        hintNode?.removeFromParent()
        hintNode = nil
        hudLayer.isHidden = true
        worldState = .normal
        spec = LevelGenerator.make(level: save.level)
        world.showIdle(skin: save.selectedSkin, level: save.level)
        audio.setBGMRate(1.0)

        // 下から積み上げる位置と、上から吊るす位置
        // 画面の下 3 分の 1 には 3D の餃子たちが映るので、文字はそこを避ける
        let buttonsY = safeBottom + 62
        let infoY = H - safeTop - 50
        let logoTopY = H - safeTop - 132
        let logoBottomY = logoTopY - 100
        let subY = logoBottomY - 80
        let tickerY = subY - 30
        let startY = (tickerY + H * 0.31) / 2

        let rays = Kit.sunburst(radius: H, rays: 14, color: SKColor(white: 1, alpha: 0.16))
        rays.position = CGPoint(x: W / 2, y: logoBottomY)
        rays.run(.repeatForever(.rotate(byAngle: 1, duration: 4)))
        uiLayer.addChild(rays)

        let logoTop = PopLabel("インフレ", size: 70, color: .gold)
        logoTop.position = CGPoint(x: W / 2, y: logoTopY)
        logoTop.zRotation = -0.05
        uiLayer.addChild(logoTop)
        let logoBottom = PopLabel("餃子", size: 110, color: .white)
        logoBottom.position = CGPoint(x: W / 2, y: logoBottomY)
        logoBottom.zRotation = 0.04
        uiLayer.addChild(logoBottom)
        for (i, l) in [logoTop, logoBottom].enumerated() {
            l.run(.repeatForever(.sequence([
                .wait(forDuration: Double(i) * 0.15),
                .scale(to: 1.07, duration: 0.3),
                .scale(to: 1.0, duration: 0.3)
            ])))
        }

        let sub = PopLabel("〜 数字がデカいほうが勝つ 〜", size: 20)
        sub.position = CGPoint(x: W / 2, y: subY)
        uiLayer.addChild(sub)

        // うさんくさい宣伝文句(全部うそ)
        let claims = [
            "★★★★★ レビュー 9999万件(うそ)",
            "全世界 80億人が熱狂(してない)",
            "IQ 300 以上しかクリアできない(できる)",
            "今だけ無料(ずっと無料)",
            "バグは仕様です"
        ]
        let ticker = PopLabel(claims[0], size: 15, color: SKColor(white: 1, alpha: 0.9))
        ticker.position = CGPoint(x: W / 2, y: tickerY)
        ticker.fit(maxWidth: W - 30)
        uiLayer.addChild(ticker)
        var claimIndex = 0
        ticker.run(.repeatForever(.sequence([
            .wait(forDuration: 1.8),
            .fadeOut(withDuration: 0.15),
            .run { [weak ticker] in
                guard let ticker = ticker else { return }
                claimIndex = (claimIndex + 1) % claims.count
                ticker.text = claims[claimIndex]
                ticker.fit(maxWidth: 360)
            },
            .fadeIn(withDuration: 0.15)
        ])))

        let start = PopLabel("タップでスタート", size: 34, color: .gold)
        start.position = CGPoint(x: W / 2, y: startY)
        start.run(.repeatForever(.sequence([
            .scale(to: 1.12, duration: 0.35),
            .scale(to: 1.0, duration: 0.35)
        ])))
        uiLayer.addChild(start)

        let info = PopLabel("LEVEL \(save.level)   最高記録 \(JPNumber.format(save.bestCount))個", size: 18)
        info.fit(maxWidth: W - 40)
        info.position = CGPoint(x: W / 2, y: infoY)
        uiLayer.addChild(info)

        let shop = Kit.button(id: "shop", text: "🛒 ショップ", size: CGSize(width: 170, height: 56), color: .skyBlue, fontSize: 22)
        shop.position = CGPoint(x: W / 2 - 95, y: buttonsY)
        uiLayer.addChild(shop)
        let sound = Kit.button(
            id: "sound",
            text: save.soundOn ? "🔊 おと ON" : "🔇 おと OFF",
            size: CGSize(width: 170, height: 56),
            color: SKColor(white: 0.25, alpha: 1),
            fontSize: 22
        )
        sound.position = CGPoint(x: W / 2 + 95, y: buttonsY)
        uiLayer.addChild(sound)

        let coins = PopLabel("🪙 \(JPNumber.format(Double(save.coins)))", size: 22, color: .gold)
        coins.position = CGPoint(x: W / 2, y: H - safeTop - 20)
        uiLayer.addChild(coins)

        // 【仕込みバグ】ここを 7 回タップすると消し忘れのデバッグメニューが開く
        let versionHit = Kit.rect(CGSize(width: 120, height: 26), color: .clear)
        versionHit.name = "btn:version"
        versionHit.position = CGPoint(x: W / 2, y: safeBottom + 10)
        let version = PopLabel(GameScene.appVersion, size: 13, color: SKColor(white: 1, alpha: 0.7))
        versionHit.addChild(version)
        uiLayer.addChild(versionHit)
    }

    func toggleSound() {
        save.soundOn.toggle()
        Store.save(save)
        audio.enabled = save.soundOn
        audio.play(.tap)
        showTitle()
    }

    func versionTap() {
        versionTaps += 1
        Haptics.light()
        if versionTaps >= 7 {
            versionTaps = 0
            showDebug()
        }
    }

    // MARK: - リザルト

    func showResult(win: Bool, wiped: Bool) {
        phase = .result
        inputLockUntil = now + 0.35
        hudLayer.isHidden = true
        uiLayer.removeAllChildren()
        comboLabel.isHidden = true

        let finalCount = count
        resultIsNaN = finalCount.isNaN
        var newRecord = false
        if win {
            resultReward = GameRules.reward(level: spec.level, count: finalCount, bossHP: bossHP, maxCombo: maxCombo)
            newRecord = save.recordClear(level: spec.level, count: finalCount)
        } else {
            resultReward = GameRules.consolation(level: spec.level)
        }
        resultBonus = 0
        coinTaps = 0
        coinTapDeadline = now + 2.0
        save.addCoins(resultReward)
        Store.save(save)

        let dim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.55), size: CGSize(width: W + 80, height: H + 80))
        dim.position = CGPoint(x: W / 2, y: H / 2)
        dim.alpha = 0
        dim.run(.fadeIn(withDuration: 0.15))
        uiLayer.addChild(dim)

        if win {
            let rays = Kit.sunburst(radius: H, rays: 16, color: SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 0.35))
            rays.position = CGPoint(x: W / 2, y: H * 0.72)
            rays.run(.repeatForever(.rotate(byAngle: 1, duration: 2.2)))
            uiLayer.addChild(rays)
        }

        // 見出し
        let titleText: String
        if win {
            if resultIsNaN {
                titleText = "NaN の勝ち!?"
            } else if worldState == .negative {
                titleText = "裏・大勝利!!"
            } else {
                let options = ["大勝利!!", "恭喜發財!!", "圧倒的勝利!!", "餃子の勝ち!!", "天下無敵!!"]
                titleText = options[runtimeRNG.int(0, options.count - 1)]
            }
        } else {
            titleText = wiped ? "全滅…" : "惨敗…"
        }
        let title = PopLabel(titleText, size: 64, color: win ? .gold : .hotRed)
        title.fit(maxWidth: W - 30)
        let base = title.xScale
        title.position = CGPoint(x: W / 2, y: H * 0.72)
        title.setScale(base * 4)
        title.run(.sequence([.scale(to: base * 0.9, duration: 0.12), .scale(to: base, duration: 0.08)]))
        if win {
            title.run(.repeatForever(.sequence([
                .wait(forDuration: 0.5),
                .scale(to: base * 1.08, duration: 0.25),
                .scale(to: base, duration: 0.25)
            ])))
        }
        uiLayer.addChild(title)

        // 【仕込みバグ】たまに見出しが文字化けする
        if runtimeRNG.chance(0.08) {
            title.text = "螟ｧ蜍晏茜縺ｧ縺?"
            title.run(.sequence([
                .wait(forDuration: 0.7),
                .run { [weak title] in title?.text = titleText }
            ]))
        }

        // 内訳
        var lines: [String] = []
        if win {
            lines.append("\(skinEmoji) \(JPNumber.format(finalCount))個  vs  HP \(JPNumber.format(bossHP))")
            lines.append("最大コンボ ×\(maxCombo)")
            if newRecord { lines.append("🏆 新記録!! 🏆") }
        } else if wiped {
            lines.append("ちょうど 0 個になった")
            lines.append("(マイナスなら生きてたのに)")
        } else {
            lines.append("\(skinEmoji) \(JPNumber.format(finalCount))個  vs  HP \(JPNumber.format(bossHP))")
            lines.append("あと \(JPNumber.format(max(0, bossHP - abs(finalCount))))個 足りない")
        }
        for (i, text) in lines.enumerated() {
            let l = PopLabel(text, size: 22, color: text.contains("新記録") ? .gold : .white)
            l.fit(maxWidth: W - 40)
            l.position = CGPoint(x: W / 2, y: H * 0.72 - 90 - CGFloat(i) * 36)
            l.alpha = 0
            l.run(.sequence([.wait(forDuration: 0.15 + Double(i) * 0.1), .fadeIn(withDuration: 0.15)]))
            uiLayer.addChild(l)
        }

        // バグ探しのヒントになる「うわさ」
        let rumors = [
            "マイナスは終わりではないらしい",
            "壁の向こうに行った餃子がいるらしい",
            "下に弾くと時間が戻るらしい",
            "コインは叩くと増えるらしい",
            "バージョン表記を連打した人がいるらしい",
            "マイナスの √ は誰も計算できないらしい",
            "ちょうど 0 だけは本当にダメらしい"
        ]
        let rumor = PopLabel("💬 うわさ: " + rumors[runtimeRNG.int(0, rumors.count - 1)], size: 15)
        rumor.fit(maxWidth: W - 30)
        rumor.position = CGPoint(x: W / 2, y: H - safeTop - 28)
        rumor.alpha = 0
        rumor.run(.sequence([.wait(forDuration: 0.6), .fadeIn(withDuration: 0.3)]))
        uiLayer.addChild(rumor)

        // コイン(数え上げ中に連打すると増える。直していない)
        let coinHit = Kit.rect(CGSize(width: 300, height: 84), color: .clear)
        coinHit.name = "btn:cointap"
        coinHit.position = CGPoint(x: W / 2, y: H * 0.40)
        uiLayer.addChild(coinHit)
        let coin = PopLabel("🪙 +0", size: 46, color: .gold)
        coinHit.addChild(coin)
        resultCoinLabel = coin
        let reward = resultReward
        let isNaN = resultIsNaN
        let countUp = SKAction.customAction(withDuration: 1.1) { [weak self] node, elapsed in
            guard let self = self, let label = node as? PopLabel else { return }
            let t = min(1, Double(elapsed) / 1.1)
            let shown = Int(Double(reward) * t) + self.resultBonus
            label.text = "🪙 +\(shown)"
        }
        coin.run(.sequence([
            .wait(forDuration: 0.3),
            countUp,
            .run { [weak self, weak coin] in
                guard let self = self, let coin = coin else { return }
                if isNaN {
                    coin.text = "🪙 +NaN (換金不可)"
                    coin.fit(maxWidth: self.W - 40)
                } else {
                    coin.text = "🪙 +\(reward + self.resultBonus)"
                }
                coin.punch(1.5)
                self.audio.play(.coin)
            }
        ]))

        // ボタン
        let next = Kit.button(
            id: "next",
            text: win ? "次のレベルへ ▶" : "もう一回!!",
            size: CGSize(width: W - 70, height: 92),
            color: win ? SKColor(red: 0.1, green: 0.75, blue: 0.3, alpha: 1) : .hotRed,
            fontSize: 34
        )
        next.position = CGPoint(x: W / 2, y: safeBottom + 170)
        next.run(.repeatForever(.sequence([
            .scale(to: 1.05, duration: 0.3),
            .scale(to: 1.0, duration: 0.3)
        ])))
        uiLayer.addChild(next)

        let shop = Kit.button(id: "shop", text: "🛒 ショップ", size: CGSize(width: 160, height: 52), color: .skyBlue, fontSize: 20)
        shop.position = CGPoint(x: W / 2 - 90, y: safeBottom + 70)
        uiLayer.addChild(shop)
        let home = Kit.button(id: "home", text: "🏠 タイトル", size: CGSize(width: 160, height: 52), color: SKColor(white: 0.25, alpha: 1), fontSize: 20)
        home.position = CGPoint(x: W / 2 + 90, y: safeBottom + 70)
        uiLayer.addChild(home)

        refreshHUD()
    }

    /// 【仕込みバグ】コインの数え上げ中にコインを連打すると、叩いた分だけ増える。
    func tapCoin(_ point: CGPoint) {
        guard now < coinTapDeadline, resultReward > 0 else { return }
        let beforeBonus = GameRules.coinTapBonus(reward: resultReward, taps: coinTaps)
        coinTaps += 1
        let afterBonus = GameRules.coinTapBonus(reward: resultReward, taps: coinTaps)
        let gained = afterBonus - beforeBonus
        guard gained > 0 else { return }
        resultBonus = afterBonus
        save.addCoins(gained)
        Store.save(save)
        audio.play(.coin)
        Haptics.light()
        resultCoinLabel?.punch(1.25)
        let l = PopLabel("+\(gained)", size: 26, color: .gold)
        l.position = CGPoint(x: point.x + CGFloat.random(in: -30...30), y: point.y + 30)
        topFx.addChild(l)
        l.run(.sequence([
            .group([.moveBy(x: 0, y: 70, duration: 0.5), .fadeOut(withDuration: 0.5)]),
            .removeFromParent()
        ]))
    }

    // MARK: - ショップ

    func showShop() {
        modal = .shop
        modalLayer.removeAllChildren()

        let dim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.8), size: CGSize(width: W + 80, height: H + 80))
        dim.position = CGPoint(x: W / 2, y: H / 2)
        modalLayer.addChild(dim)

        let title = PopLabel("ショップ", size: 36, color: .gold)
        title.position = CGPoint(x: W / 2, y: H - safeTop - 40)
        modalLayer.addChild(title)
        let coins = PopLabel("🪙 \(JPNumber.format(Double(save.coins)))", size: 24)
        coins.position = CGPoint(x: W / 2, y: H - safeTop - 82)
        modalLayer.addChild(coins)

        let cell = CGSize(width: (W - 48) / 2, height: 96)
        let topY = H - safeTop - 160
        for (i, skin) in SkinCatalog.all.enumerated() {
            let column = CGFloat(i % 2)
            let row = CGFloat(i / 2)
            let owned = save.ownedSkins.contains(skin.id)
            let selected = save.selectedSkin == skin.id
            let color: SKColor
            if selected {
                color = SKColor(red: 0.1, green: 0.7, blue: 0.3, alpha: 1)
            } else if owned {
                color = .skyBlue
            } else if save.coins >= skin.price {
                color = SKColor(red: 0.95, green: 0.6, blue: 0.1, alpha: 1)
            } else {
                color = SKColor(white: 0.3, alpha: 1)
            }
            let root = SKNode()
            root.name = "btn:skin:" + skin.id
            root.position = CGPoint(
                x: 16 + cell.width / 2 + column * (cell.width + 16),
                y: topY - row * (cell.height + 14)
            )
            let body = Kit.rect(cell, color: color, radius: 16)
            body.strokeColor = .white
            body.lineWidth = selected ? 6 : 3
            root.addChild(body)
            let icon = Kit.emoji(skin.emoji, size: 46)
            icon.position = CGPoint(x: -cell.width / 2 + 40, y: 0)
            root.addChild(icon)
            let name = PopLabel(skin.name, size: 18)
            name.position = CGPoint(x: 26, y: 18)
            name.fit(maxWidth: cell.width - 84)
            root.addChild(name)
            let status = selected ? "使用中" : (owned ? "タップで使う" : "🪙 \(JPNumber.format(Double(skin.price)))")
            let statusLabel = PopLabel(status, size: 16, color: owned ? .white : .gold)
            statusLabel.position = CGPoint(x: 26, y: -18)
            statusLabel.fit(maxWidth: cell.width - 84)
            root.addChild(statusLabel)
            modalLayer.addChild(root)
        }

        let close = Kit.button(id: "shopclose", text: "とじる", size: CGSize(width: 220, height: 64), color: .hotRed, fontSize: 26)
        close.position = CGPoint(x: W / 2, y: safeBottom + 60)
        modalLayer.addChild(close)
    }

    func buySkin(_ id: String) {
        switch save.buyOrSelect(skinID: id) {
        case .bought:
            Store.save(save)
            audio.play(.win)
            Haptics.success()
            showShop()
            confetti(24)
        case .selected:
            Store.save(save)
            audio.play(.good)
            Haptics.light()
            showShop()
        case .notEnough:
            audio.play(.bad)
            Haptics.error()
            let l = PopLabel("コインが足りない", size: 28, color: .hotRed)
            l.position = CGPoint(x: W / 2, y: H / 2)
            l.zPosition = 5
            modalLayer.addChild(l)
            l.run(.sequence([
                .scale(to: 1.3, duration: 0.08),
                .scale(to: 1.0, duration: 0.08),
                .wait(forDuration: 0.5),
                .fadeOut(withDuration: 0.2),
                .removeFromParent()
            ]))
        case .unknown:
            break
        }
        if phase == .title {
            world.showIdle(skin: save.selectedSkin, level: save.level)
        }
    }

    func closeModal() {
        modal = .none
        modalLayer.removeAllChildren()
        refreshHUD()
        if phase == .title {
            showTitle()
        }
    }

    // MARK: - 消し忘れたデバッグメニュー(わざと)

    func showDebug() {
        modal = .debug
        modalLayer.removeAllChildren()
        audio.play(.glitch)
        glitchFlash()

        let dim = SKSpriteNode(color: SKColor(red: 0, green: 0.1, blue: 0, alpha: 0.92), size: CGSize(width: W + 80, height: H + 80))
        dim.position = CGPoint(x: W / 2, y: H / 2)
        modalLayer.addChild(dim)

        let title = PopLabel("DEBUG MENU", size: 38, color: .green)
        title.position = CGPoint(x: W / 2, y: H * 0.78)
        modalLayer.addChild(title)
        let note = PopLabel("※リリース前に必ず消すこと!!", size: 18, color: .hotRed)
        note.position = CGPoint(x: W / 2, y: H * 0.78 - 44)
        modalLayer.addChild(note)

        let items: [(String, String)] = [
            ("dbg:coins", "🪙 コイン +10000"),
            ("dbg:boss", "👊 次のボスの HP を 1 にする"),
            ("dbg:skip", "⏭ レベルを 1 つ飛ばす"),
            ("dbg:close", "とじる")
        ]
        for (i, item) in items.enumerated() {
            let b = Kit.button(
                id: item.0,
                text: item.1,
                size: CGSize(width: W - 60, height: 66),
                color: SKColor(red: 0.05, green: 0.35, blue: 0.1, alpha: 1),
                fontSize: 22
            )
            b.position = CGPoint(x: W / 2, y: H * 0.60 - CGFloat(i) * 86)
            modalLayer.addChild(b)
        }
    }

    func handleDebug(_ id: String?) {
        guard let id = id else { return }
        switch id {
        case "dbg:coins":
            save.addCoins(10000)
            Store.save(save)
            audio.play(.coin)
            debugToast("コイン +10000")
        case "dbg:boss":
            debugBossOneHP = true
            audio.play(.good)
            debugToast("次のボスは HP 1")
        case "dbg:skip":
            save.level += 1
            save.bestLevel = max(save.bestLevel, save.level)
            Store.save(save)
            audio.play(.good)
            debugToast("LEVEL \(save.level) へ")
        case "dbg:close":
            audio.play(.tap)
            closeModal()
        default:
            break
        }
    }

    func debugToast(_ text: String) {
        Haptics.light()
        let l = PopLabel(text, size: 24, color: .green)
        l.position = CGPoint(x: W / 2, y: H * 0.17)
        modalLayer.addChild(l)
        l.run(.sequence([
            .wait(forDuration: 0.6),
            .fadeOut(withDuration: 0.2),
            .removeFromParent()
        ]))
    }
}

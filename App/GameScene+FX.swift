import SpriteKit

extension GameScene {
    func shake(_ power: CGFloat, duration: TimeInterval) {
        world.shake(Float(power) * 0.035, duration: duration)
        shakeRoot.removeAction(forKey: "shake")
        let steps = max(2, Int(duration / 0.03))
        var actions: [SKAction] = []
        for i in 0..<steps {
            let fade = 1 - CGFloat(i) / CGFloat(steps)
            let p = CGPoint(
                x: CGFloat.random(in: -power...power) * fade,
                y: CGFloat.random(in: -power...power) * fade
            )
            actions.append(.move(to: p, duration: 0.03))
        }
        actions.append(.move(to: .zero, duration: 0.03))
        shakeRoot.run(.sequence(actions), withKey: "shake")
    }

    func flash(_ color: SKColor, alpha: CGFloat) {
        let n = SKSpriteNode(color: color, size: CGSize(width: W + 80, height: H + 80))
        n.position = CGPoint(x: W / 2, y: H / 2)
        n.alpha = alpha
        topFx.addChild(n)
        n.run(.sequence([.fadeOut(withDuration: 0.22), .removeFromParent()]))
    }

    /// 画面が壊れたっぽく見せる帯
    func glitchFlash() {
        let colors: [SKColor] = [.cyan, .magenta, .green, .white]
        for i in 0..<7 {
            let h = CGFloat.random(in: 6...46)
            let bar = SKSpriteNode(color: colors[i % colors.count], size: CGSize(width: W + 40, height: h))
            bar.position = CGPoint(x: W / 2 + CGFloat.random(in: -30...30), y: CGFloat.random(in: 0...H))
            bar.alpha = 0.55
            bar.blendMode = .add
            topFx.addChild(bar)
            bar.run(.sequence([
                .wait(forDuration: Double(i) * 0.02),
                .moveBy(x: CGFloat.random(in: -40...40), y: 0, duration: 0.05),
                .fadeOut(withDuration: 0.12),
                .removeFromParent()
            ]))
        }
    }

    func floatText(_ text: String, at point: CGPoint, color: SKColor, size: CGFloat) {
        let l = PopLabel(text, size: size, color: color)
        l.fit(maxWidth: W - 40)
        let base = l.xScale
        l.position = point
        l.setScale(base * 0.4)
        fxLayer.addChild(l)
        let pop = SKAction.scale(to: base * 1.15, duration: 0.08)
        let settle = SKAction.scale(to: base, duration: 0.08)
        let rise = SKAction.moveBy(x: 0, y: 90, duration: 0.7)
        rise.timingMode = .easeOut
        l.run(.group([
            .sequence([pop, settle]),
            rise,
            .sequence([.wait(forDuration: 0.45), .fadeOut(withDuration: 0.25), .removeFromParent()])
        ]))
    }

    /// ドーンと出る巨大文字
    func banner(_ text: String, color: SKColor, size: CGFloat, y: CGFloat, hold: TimeInterval) {
        let l = PopLabel(text, size: size, color: color)
        l.fit(maxWidth: W - 30)
        let base = l.xScale
        l.position = CGPoint(x: W / 2, y: y)
        l.setScale(base * 3)
        l.alpha = 0
        l.zRotation = CGFloat.random(in: -0.08...0.08)
        topFx.addChild(l)
        let slam = SKAction.group([.scale(to: base * 0.9, duration: 0.1), .fadeIn(withDuration: 0.06)])
        let bounce = SKAction.scale(to: base, duration: 0.08)
        l.run(.sequence([
            slam,
            bounce,
            .wait(forDuration: hold),
            .group([.scale(to: base * 1.3, duration: 0.18), .fadeOut(withDuration: 0.18)]),
            .removeFromParent()
        ]))
    }

    func burst(at point: CGPoint, emoji: String, amount: Int) {
        guard amount > 0 else { return }
        for _ in 0..<amount {
            let e = Kit.emoji(emoji, size: CGFloat.random(in: 16...30))
            e.position = point
            fxLayer.addChild(e)
            let angle = CGFloat.random(in: 0...(CGFloat.pi * 2))
            let dist = CGFloat.random(in: 50...150)
            let move = SKAction.moveBy(x: cos(angle) * dist, y: sin(angle) * dist, duration: 0.45)
            move.timingMode = .easeOut
            e.run(.sequence([
                .group([move, .rotate(byAngle: CGFloat.random(in: -4...4), duration: 0.45), .fadeOut(withDuration: 0.45)]),
                .removeFromParent()
            ]))
        }
    }

    func confetti(_ amount: Int) {
        let pieces = ["🎉", "🧧", "🪙", "✨", "🎊", "🥟", "💰", "🏮"]
        for i in 0..<amount {
            let e = Kit.emoji(pieces[i % pieces.count], size: CGFloat.random(in: 20...38))
            e.position = CGPoint(x: CGFloat.random(in: 0...W), y: H + CGFloat.random(in: 20...260))
            topFx.addChild(e)
            let duration = Double.random(in: 1.1...2.2)
            e.run(.sequence([
                .group([
                    .moveBy(x: CGFloat.random(in: -70...70), y: -(H + 360), duration: duration),
                    .rotate(byAngle: CGFloat.random(in: -8...8), duration: duration)
                ]),
                .removeFromParent()
            ]))
        }
    }
}

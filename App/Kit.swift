import SpriteKit

enum Fonts {
    static let bold = "HiraginoSans-W6"
}

extension SKColor {
    static let gold = SKColor(red: 1.0, green: 0.84, blue: 0.1, alpha: 1)
    static let hotRed = SKColor(red: 1.0, green: 0.22, blue: 0.22, alpha: 1)
    static let skyBlue = SKColor(red: 0.16, green: 0.56, blue: 1.0, alpha: 1)
    static let neon = SKColor(red: 0.1, green: 1.0, blue: 0.7, alpha: 1)

    static func hue(_ h: CGFloat, s: CGFloat, b: CGFloat) -> SKColor {
        SKColor(hue: h - floor(h), saturation: s, brightness: b, alpha: 1)
    }
}

/// 影つきの太文字ラベル。
final class PopLabel: SKNode {
    private let shadow = SKLabelNode(fontNamed: Fonts.bold)
    private let main = SKLabelNode(fontNamed: Fonts.bold)
    private var baseScale: CGFloat = 1

    init(_ text: String, size: CGFloat, color: SKColor = .white) {
        super.init()
        for label in [shadow, main] {
            label.text = text
            label.fontSize = size
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
        }
        shadow.fontColor = SKColor(white: 0, alpha: 0.8)
        shadow.position = CGPoint(x: size * 0.06, y: -size * 0.07)
        main.fontColor = color
        addChild(shadow)
        addChild(main)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var text: String {
        get { main.text ?? "" }
        set {
            main.text = newValue
            shadow.text = newValue
        }
    }

    var color: SKColor {
        get { main.fontColor ?? .white }
        set { main.fontColor = newValue }
    }

    /// 横幅が収まらないときだけ縮める。
    func fit(maxWidth: CGFloat) {
        removeAction(forKey: "punch")
        let w = main.frame.width
        baseScale = (w > maxWidth && w > 0) ? maxWidth / w : 1
        setScale(baseScale)
    }

    /// ぷるんと跳ねる。
    func punch(_ amount: CGFloat = 1.4) {
        removeAction(forKey: "punch")
        let base = baseScale
        let up = SKAction.scale(to: base * amount, duration: 0.06)
        let down = SKAction.scale(to: base, duration: 0.14)
        down.timingMode = .easeOut
        run(.sequence([up, down]), withKey: "punch")
    }
}

enum Kit {
    static func emoji(_ text: String, size: CGFloat) -> SKLabelNode {
        let l = SKLabelNode(text: text)
        l.fontSize = size
        l.verticalAlignmentMode = .center
        l.horizontalAlignmentMode = .center
        return l
    }

    static func rect(_ size: CGSize, color: SKColor, radius: CGFloat = 0) -> SKShapeNode {
        let n = SKShapeNode(rectOf: size, cornerRadius: radius)
        n.fillColor = color
        n.strokeColor = .clear
        n.lineWidth = 0
        return n
    }

    static func button(id: String, text: String, size: CGSize, color: SKColor, fontSize: CGFloat = 24) -> SKNode {
        let root = SKNode()
        root.name = "btn:" + id
        let radius = min(20, size.height / 2)
        let shadow = rect(size, color: SKColor(white: 0, alpha: 0.4), radius: radius)
        shadow.position = CGPoint(x: 0, y: -6)
        root.addChild(shadow)
        let body = rect(size, color: color, radius: radius)
        body.strokeColor = .white
        body.lineWidth = 4
        root.addChild(body)
        let label = PopLabel(text, size: fontSize)
        label.fit(maxWidth: size.width - 24)
        root.addChild(label)
        return root
    }

    /// 勝利演出の後光。
    static func sunburst(radius: CGFloat, rays: Int, color: SKColor) -> SKShapeNode {
        let path = CGMutablePath()
        let step = CGFloat.pi * 2 / CGFloat(rays)
        for i in 0..<rays {
            let a0 = CGFloat(i) * step
            let a1 = a0 + step * 0.5
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: cos(a0) * radius, y: sin(a0) * radius))
            path.addLine(to: CGPoint(x: cos(a1) * radius, y: sin(a1) * radius))
            path.closeSubpath()
        }
        let n = SKShapeNode(path: path)
        n.fillColor = color
        n.strokeColor = .clear
        n.lineWidth = 0
        return n
    }
}

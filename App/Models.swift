import SceneKit
import UIKit

/// 3D モデルはすべて球・箱・円柱などの組み合わせでコードから作る。モデルファイルは使わない。
/// どのキャラも足元が原点、+Z(カメラ側)を向いている。
enum Models {
    // MARK: - 部品

    static func material(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.specular.contents = UIColor(white: 1, alpha: 0.35)
        m.shininess = 0.4
        return m
    }

    @discardableResult
    static func add(
        _ parent: SCNNode,
        _ geometry: SCNGeometry,
        _ color: UIColor,
        x: Float = 0, y: Float = 0, z: Float = 0,
        sx: Float = 1, sy: Float = 1, sz: Float = 1,
        rx: Float = 0, ry: Float = 0, rz: Float = 0
    ) -> SCNNode {
        geometry.materials = [material(color)]
        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(x, y, z)
        node.scale = SCNVector3(sx, sy, sz)
        node.eulerAngles = SCNVector3(rx, ry, rz)
        parent.addChildNode(node)
        return node
    }

    static func sphere(_ r: CGFloat) -> SCNSphere {
        let s = SCNSphere(radius: r)
        s.segmentCount = 20
        return s
    }

    /// 黒目 2 つ(白いハイライトつき)
    static func eyes(_ parent: SCNNode, y: Float, z: Float, dx: Float, r: CGFloat = 0.06, angry: Bool = false) {
        for side in [Float(-1), Float(1)] {
            add(parent, sphere(r), .black, x: side * dx, y: y, z: z)
            add(parent, sphere(r * 0.4), .white, x: side * dx + Float(r) * 0.3, y: y + Float(r) * 0.4, z: z + Float(r) * 0.7)
            if angry {
                let brow = SCNBox(width: r * 3.2, height: r * 0.7, length: r * 0.8, chamferRadius: 0)
                add(parent, brow, .black, x: side * dx, y: y + Float(r) * 1.5, z: z + Float(r) * 0.3, rz: side * -0.45)
            }
        }
    }

    static func feet(_ parent: SCNNode, dx: Float, color: UIColor) {
        for side in [Float(-1), Float(1)] {
            add(parent, sphere(0.1), color, x: side * dx, y: 0.07, z: 0.04, sy: 0.7, sz: 1.3)
        }
    }

    static let cream = UIColor(red: 1.0, green: 0.93, blue: 0.78, alpha: 1)
    static let brown = UIColor(red: 0.55, green: 0.33, blue: 0.14, alpha: 1)

    // MARK: - プレイヤー(スキン)

    static func character(_ skinID: String) -> SCNNode {
        let root = SCNNode()
        switch skinID {
        case "onigiri":
            add(root, SCNCone(topRadius: 0.14, bottomRadius: 0.5, height: 0.8), .white, y: 0.5, sz: 0.7)
            add(root, SCNBox(width: 0.5, height: 0.3, length: 0.6, chamferRadius: 0.03), UIColor(white: 0.08, alpha: 1), y: 0.28)
            eyes(root, y: 0.6, z: 0.22, dx: 0.12)
            feet(root, dx: 0.2, color: brown)

        case "frog":
            let green = UIColor(red: 0.25, green: 0.78, blue: 0.3, alpha: 1)
            add(root, sphere(0.44), green, y: 0.42, sy: 0.85)
            add(root, sphere(0.3), UIColor(red: 0.85, green: 0.95, blue: 0.7, alpha: 1), y: 0.34, z: 0.2, sy: 0.8)
            for side in [Float(-1), Float(1)] {
                add(root, sphere(0.15), .white, x: side * 0.2, y: 0.8, z: 0.12)
                add(root, sphere(0.07), .black, x: side * 0.2, y: 0.82, z: 0.25)
            }
            feet(root, dx: 0.28, color: green)

        case "duck":
            let yellow = UIColor(red: 1.0, green: 0.85, blue: 0.1, alpha: 1)
            add(root, sphere(0.4), yellow, y: 0.4, sy: 0.85, sz: 1.1)
            add(root, sphere(0.27), yellow, y: 0.88, z: 0.12)
            add(root, SCNCone(topRadius: 0.02, bottomRadius: 0.11, height: 0.22), .orange, y: 0.84, z: 0.42, sy: 1, rx: Float.pi / 2)
            eyes(root, y: 0.95, z: 0.34, dx: 0.11, r: 0.045)
            feet(root, dx: 0.18, color: .orange)

        case "moai":
            let stone = UIColor(white: 0.55, alpha: 1)
            add(root, SCNBox(width: 0.55, height: 1.0, length: 0.5, chamferRadius: 0.1), stone, y: 0.52)
            add(root, SCNBox(width: 0.14, height: 0.36, length: 0.2, chamferRadius: 0.04), UIColor(white: 0.48, alpha: 1), y: 0.55, z: 0.3)
            add(root, SCNBox(width: 0.5, height: 0.1, length: 0.16, chamferRadius: 0.02), UIColor(white: 0.4, alpha: 1), y: 0.8, z: 0.24)
            add(root, SCNBox(width: 0.26, height: 0.05, length: 0.1, chamferRadius: 0), UIColor(white: 0.3, alpha: 1), y: 0.28, z: 0.26)
            eyes(root, y: 0.7, z: 0.26, dx: 0.14, r: 0.04)

        case "ojisan":
            let skin = UIColor(red: 1.0, green: 0.82, blue: 0.66, alpha: 1)
            add(root, SCNCapsule(capRadius: 0.28, height: 0.72), UIColor(red: 0.2, green: 0.25, blue: 0.45, alpha: 1), y: 0.4)
            add(root, SCNBox(width: 0.08, height: 0.3, length: 0.04, chamferRadius: 0), .red, y: 0.46, z: 0.28)
            add(root, sphere(0.27), skin, y: 0.95)
            // 横だけ残った髪
            add(root, SCNTorus(ringRadius: 0.25, pipeRadius: 0.06), UIColor(white: 0.75, alpha: 1), y: 0.98, z: -0.04)
            add(root, SCNBox(width: 0.22, height: 0.04, length: 0.05, chamferRadius: 0), UIColor(white: 0.25, alpha: 1), y: 0.86, z: 0.26)
            eyes(root, y: 0.98, z: 0.24, dx: 0.1, r: 0.04)
            feet(root, dx: 0.14, color: .black)

        case "paper":
            add(root, SCNTube(innerRadius: 0.16, outerRadius: 0.4, height: 0.6), .white, y: 0.42)
            add(root, SCNCylinder(radius: 0.16, height: 0.62), UIColor(red: 0.75, green: 0.6, blue: 0.4, alpha: 1), y: 0.42)
            add(root, SCNBox(width: 0.5, height: 0.02, length: 0.4, chamferRadius: 0), .white, x: 0.3, y: 0.12, z: 0.1)
            eyes(root, y: 0.46, z: 0.39, dx: 0.14)
            feet(root, dx: 0.18, color: brown)

        case "poop":
            let gold = UIColor(red: 1.0, green: 0.78, blue: 0.1, alpha: 1)
            add(root, sphere(0.45), gold, y: 0.22, sy: 0.5)
            add(root, sphere(0.35), gold, y: 0.5, sy: 0.55)
            add(root, sphere(0.24), gold, y: 0.74, sy: 0.6)
            add(root, SCNCone(topRadius: 0, bottomRadius: 0.12, height: 0.24), gold, y: 0.96)
            eyes(root, y: 0.5, z: 0.32, dx: 0.14)

        default: // 餃子
            add(root, sphere(0.5), cream, y: 0.4, sy: 0.64, sz: 0.62)
            // 焼き目
            add(root, sphere(0.4), UIColor(red: 0.9, green: 0.62, blue: 0.28, alpha: 1), y: 0.3, z: -0.08, sy: 0.5, sz: 0.62)
            // ひだ
            for i in -3...3 {
                let t = Float(i) / 3
                add(root, sphere(0.085), UIColor(red: 0.98, green: 0.88, blue: 0.68, alpha: 1), x: t * 0.42, y: 0.72 - t * t * 0.22, z: 0)
            }
            eyes(root, y: 0.42, z: 0.29, dx: 0.15)
            feet(root, dx: 0.2, color: brown)
        }
        return root
    }

    // MARK: - ボス(足元が原点、高さ約 1)

    static func boss(emoji: String) -> SCNNode {
        let root = SCNNode()
        switch emoji {
        case "🦀":
            let red = UIColor(red: 0.95, green: 0.25, blue: 0.2, alpha: 1)
            add(root, sphere(0.5), red, y: 0.4, sx: 1.3, sy: 0.6)
            for side in [Float(-1), Float(1)] {
                add(root, SCNCylinder(radius: 0.06, height: 0.5), red, x: side * 0.7, y: 0.6, rz: side * -0.7)
                add(root, sphere(0.2), red, x: side * 0.92, y: 0.86, sy: 0.8)
                add(root, SCNCylinder(radius: 0.03, height: 0.3), red, x: side * 0.2, y: 0.8)
                for leg in 0..<3 {
                    add(root, SCNCylinder(radius: 0.04, height: 0.4), red, x: side * 0.6, y: 0.18, z: Float(leg) * 0.18 - 0.18, rz: side * 0.9)
                }
            }
            eyes(root, y: 0.98, z: 0.04, dx: 0.2, r: 0.08, angry: true)

        case "🐷":
            let pink = UIColor(red: 1.0, green: 0.65, blue: 0.72, alpha: 1)
            add(root, sphere(0.5), pink, y: 0.5)
            add(root, SCNCylinder(radius: 0.17, height: 0.14), UIColor(red: 1.0, green: 0.5, blue: 0.6, alpha: 1), y: 0.46, z: 0.5, rx: Float.pi / 2)
            for side in [Float(-1), Float(1)] {
                add(root, SCNCone(topRadius: 0, bottomRadius: 0.13, height: 0.24), pink, x: side * 0.3, y: 0.96, rz: side * -0.4)
                add(root, sphere(0.03), .black, x: side * 0.06, y: 0.46, z: 0.58)
            }
            eyes(root, y: 0.66, z: 0.42, dx: 0.18, r: 0.06, angry: true)
            feet(root, dx: 0.26, color: pink)

        case "🗿":
            let stone = UIColor(white: 0.5, alpha: 1)
            add(root, SCNBox(width: 0.7, height: 1.1, length: 0.6, chamferRadius: 0.12), stone, y: 0.56)
            add(root, SCNBox(width: 0.18, height: 0.42, length: 0.26, chamferRadius: 0.05), UIColor(white: 0.42, alpha: 1), y: 0.58, z: 0.36)
            add(root, SCNBox(width: 0.64, height: 0.12, length: 0.2, chamferRadius: 0.02), UIColor(white: 0.35, alpha: 1), y: 0.86, z: 0.3)
            add(root, SCNBox(width: 0.34, height: 0.06, length: 0.1, chamferRadius: 0), UIColor(white: 0.25, alpha: 1), y: 0.28, z: 0.31)
            eyes(root, y: 0.76, z: 0.31, dx: 0.18, r: 0.045)

        case "🦖":
            let green = UIColor(red: 0.3, green: 0.65, blue: 0.3, alpha: 1)
            add(root, SCNCapsule(capRadius: 0.32, height: 0.9), green, y: 0.48, rx: 0.25)
            add(root, SCNBox(width: 0.42, height: 0.34, length: 0.6, chamferRadius: 0.1), green, y: 0.98, z: 0.28)
            add(root, SCNBox(width: 0.36, height: 0.05, length: 0.4, chamferRadius: 0), .white, y: 0.86, z: 0.4)
            add(root, SCNCone(topRadius: 0, bottomRadius: 0.22, height: 0.8), green, y: 0.3, z: -0.55, rx: -Float.pi / 2.4)
            for side in [Float(-1), Float(1)] {
                // 短すぎる腕
                add(root, SCNCylinder(radius: 0.035, height: 0.16), green, x: side * 0.24, y: 0.62, z: 0.32, rx: Float.pi / 2.5)
            }
            eyes(root, y: 1.1, z: 0.5, dx: 0.14, r: 0.05, angry: true)
            feet(root, dx: 0.2, color: green)

        case "🐙":
            let purple = UIColor(red: 0.7, green: 0.35, blue: 0.85, alpha: 1)
            add(root, sphere(0.42), purple, y: 0.68, sy: 1.15)
            for i in 0..<8 {
                let a = Float(i) / 8 * Float.pi * 2
                add(root, SCNCapsule(capRadius: 0.07, height: 0.55), purple, x: cos(a) * 0.36, y: 0.2, z: sin(a) * 0.36, rx: sin(a) * 0.7, rz: -cos(a) * 0.7)
            }
            add(root, sphere(0.07), UIColor(red: 0.5, green: 0.2, blue: 0.6, alpha: 1), y: 0.5, z: 0.4)
            eyes(root, y: 0.74, z: 0.36, dx: 0.16, r: 0.07, angry: true)

        case "👽":
            let green = UIColor(red: 0.6, green: 0.95, blue: 0.5, alpha: 1)
            add(root, SCNCapsule(capRadius: 0.14, height: 0.6), green, y: 0.3)
            add(root, sphere(0.36), green, y: 0.82, sy: 1.15)
            for side in [Float(-1), Float(1)] {
                add(root, sphere(0.13), .black, x: side * 0.15, y: 0.82, z: 0.27, sx: 0.8, sy: 1.3, sz: 0.5, rz: side * 0.4)
                add(root, SCNCylinder(radius: 0.03, height: 0.4), green, x: side * 0.24, y: 0.36, rz: side * 0.5)
            }
            // 観光客なのでカメラを持っている
            add(root, SCNBox(width: 0.18, height: 0.12, length: 0.1, chamferRadius: 0.02), UIColor(white: 0.15, alpha: 1), y: 0.36, z: 0.18)

        case "🤖":
            let steel = UIColor(red: 0.6, green: 0.66, blue: 0.72, alpha: 1)
            add(root, SCNBox(width: 0.6, height: 0.55, length: 0.4, chamferRadius: 0.05), steel, y: 0.4)
            add(root, SCNBox(width: 0.46, height: 0.36, length: 0.36, chamferRadius: 0.05), steel, y: 0.9)
            add(root, SCNCylinder(radius: 0.02, height: 0.2), steel, y: 1.16)
            add(root, sphere(0.05), .red, y: 1.28)
            add(root, SCNBox(width: 0.34, height: 0.1, length: 0.04, chamferRadius: 0), .black, y: 0.92, z: 0.18)
            add(root, sphere(0.04), .red, x: -0.08, y: 0.92, z: 0.2)
            // 電池残量 3%
            add(root, SCNBox(width: 0.3, height: 0.12, length: 0.03, chamferRadius: 0), .black, y: 0.42, z: 0.2)
            add(root, SCNBox(width: 0.03, height: 0.08, length: 0.035, chamferRadius: 0), .red, x: -0.12, y: 0.42, z: 0.2)
            for side in [Float(-1), Float(1)] {
                add(root, SCNBox(width: 0.12, height: 0.44, length: 0.12, chamferRadius: 0.03), steel, x: side * 0.4, y: 0.42)
                add(root, SCNBox(width: 0.16, height: 0.14, length: 0.24, chamferRadius: 0.03), steel, x: side * 0.16, y: 0.07)
            }

        case "🧟":
            let skin = UIColor(red: 0.55, green: 0.7, blue: 0.5, alpha: 1)
            add(root, SCNCapsule(capRadius: 0.26, height: 0.7), UIColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 1), y: 0.38)
            add(root, sphere(0.27), skin, y: 0.92)
            for side in [Float(-1), Float(1)] {
                add(root, SCNBox(width: 0.1, height: 0.1, length: 0.5, chamferRadius: 0.03), skin, x: side * 0.24, y: 0.58, z: 0.36)
            }
            add(root, SCNBox(width: 0.2, height: 0.05, length: 0.05, chamferRadius: 0), .black, y: 0.82, z: 0.25, rz: 0.2)
            eyes(root, y: 0.96, z: 0.23, dx: 0.1, r: 0.05)
            feet(root, dx: 0.14, color: .black)

        case "🐲":
            let red = UIColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1)
            let gold = UIColor(red: 1.0, green: 0.8, blue: 0.15, alpha: 1)
            add(root, sphere(0.45), red, y: 0.46, sy: 1.05)
            add(root, sphere(0.3), gold, y: 0.4, z: 0.22, sy: 1.1)
            add(root, SCNBox(width: 0.4, height: 0.3, length: 0.5, chamferRadius: 0.1), red, y: 1.0, z: 0.2)
            for side in [Float(-1), Float(1)] {
                add(root, SCNCone(topRadius: 0, bottomRadius: 0.07, height: 0.3), gold, x: side * 0.14, y: 1.28, z: 0.1, rz: side * -0.3)
                add(root, SCNBox(width: 0.7, height: 0.5, length: 0.04, chamferRadius: 0), gold, x: side * 0.7, y: 0.75, z: -0.1, rz: side * 0.5)
                add(root, sphere(0.03), .black, x: side * 0.08, y: 1.0, z: 0.46)
            }
            add(root, SCNCone(topRadius: 0, bottomRadius: 0.2, height: 0.7), red, y: 0.2, z: -0.5, rx: -Float.pi / 2.3)
            eyes(root, y: 1.1, z: 0.4, dx: 0.13, r: 0.05, angry: true)
            feet(root, dx: 0.22, color: red)

        default: // 🐔
            add(root, sphere(0.48), .white, y: 0.5, sy: 1.05)
            for i in -1...1 {
                add(root, sphere(0.12), .red, y: 1.06 - abs(Float(i)) * 0.05, z: Float(i) * 0.13)
            }
            add(root, SCNCone(topRadius: 0, bottomRadius: 0.11, height: 0.26), .orange, y: 0.62, z: 0.52, rx: Float.pi / 2)
            add(root, sphere(0.08), .red, y: 0.46, z: 0.46, sy: 1.4)
            for side in [Float(-1), Float(1)] {
                add(root, sphere(0.26), UIColor(white: 0.92, alpha: 1), x: side * 0.44, y: 0.5, sx: 0.35, sz: 0.9)
            }
            eyes(root, y: 0.76, z: 0.4, dx: 0.17, r: 0.06, angry: true)
            feet(root, dx: 0.2, color: .orange)
        }
        return root
    }

    // MARK: - 文字

    static func textImage(_ text: String, color: UIColor) -> UIImage {
        let size: CGFloat = 96
        let font = UIFont(name: "HiraginoSans-W7", size: size) ?? UIFont.systemFont(ofSize: size, weight: .black)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .strokeColor: UIColor.black,
            .strokeWidth: -5.0
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let textSize = string.size()
        let pad: CGFloat = 16
        let imageSize = CGSize(width: ceil(textSize.width) + pad * 2, height: ceil(textSize.height) + pad * 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: imageSize, format: format).image { _ in
            string.draw(at: CGPoint(x: pad, y: pad))
        }
    }

    /// 文字を貼った板。`setLabel` で書き換えられる。
    static func label(_ text: String, height: CGFloat, maxWidth: CGFloat, color: UIColor, billboard: Bool) -> SCNNode {
        let node = SCNNode()
        node.renderingOrder = 20
        if billboard {
            let constraint = SCNBillboardConstraint()
            constraint.freeAxes = .all
            node.constraints = [constraint]
        }
        setLabel(node, text, height: height, maxWidth: maxWidth, color: color)
        return node
    }

    static func setLabel(_ node: SCNNode, _ text: String, height: CGFloat, maxWidth: CGFloat, color: UIColor) {
        let image = textImage(text, color: color)
        var h = height
        var w = height * image.size.width / max(image.size.height, 1)
        if w > maxWidth {
            h *= maxWidth / w
            w = maxWidth
        }
        let plane = SCNPlane(width: w, height: h)
        let m = SCNMaterial()
        m.diffuse.contents = image
        m.lightingModel = .constant
        m.isDoubleSided = true
        m.writesToDepthBuffer = false
        plane.materials = [m]
        node.geometry = plane
    }
}

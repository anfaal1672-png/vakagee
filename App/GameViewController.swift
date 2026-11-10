import UIKit
import SceneKit
import SpriteKit

/// 下に 3D(SceneKit)、その上に透明な 2D の UI(SpriteKit)を重ねる。
final class GameViewController: UIViewController {
    private let world = World3D()
    private let scnView = SCNView()
    private let skView = SKView()
    private var gameScene: GameScene?

    override func loadView() {
        let root = UIView()
        root.backgroundColor = .black
        view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        scnView.frame = view.bounds
        scnView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scnView.scene = world.scene
        scnView.pointOfView = world.cameraNode
        scnView.backgroundColor = .black
        scnView.antialiasingMode = .multisampling2X
        scnView.isUserInteractionEnabled = false
        scnView.rendersContinuously = true
        scnView.isPlaying = true
        view.addSubview(scnView)
        world.view = scnView

        skView.frame = view.bounds
        skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        skView.allowsTransparency = true
        skView.backgroundColor = .clear
        skView.isMultipleTouchEnabled = false
        view.addSubview(skView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard gameScene == nil else { return }
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        // UI は横幅を常に 390 として扱い、縦は端末の比率に合わせる
        let logicalWidth: CGFloat = 390
        let scale = logicalWidth / bounds.width
        let scene = GameScene(size: CGSize(width: logicalWidth, height: bounds.height * scale))
        let insets = view.safeAreaInsets
        scene.world = world
        scene.safeTop = max(insets.top, 20) * scale
        scene.safeBottom = max(insets.bottom, 12) * scale
        scene.scaleMode = .aspectFill
        skView.presentScene(scene)
        gameScene = scene
    }

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    // 下フリック(巻き戻りバグの操作)でホームに戻りにくくする
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .bottom }
}

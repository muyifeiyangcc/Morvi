import UIKit

class BaseSceneController: UIViewController {
    private let page: ScenePage
    private let topLayer = CustomTopLayerView()
    private let surfaceView = DesignSurfaceView()

    init(page: ScenePage) {
        self.page = page
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = .white
        let canvasView = ReferenceCanvasView(page: page)
        view.addSubview(surfaceView)
        surfaceView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            surfaceView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            surfaceView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            surfaceView.topAnchor.constraint(equalTo: view.topAnchor),
            surfaceView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        installDecorativeLayerIfNeeded()
        surfaceView.contentView.addSubview(canvasView)
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            canvasView.leadingAnchor.constraint(equalTo: surfaceView.contentView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: surfaceView.contentView.trailingAnchor),
            canvasView.topAnchor.constraint(equalTo: surfaceView.contentView.topAnchor),
            canvasView.bottomAnchor.constraint(equalTo: surfaceView.contentView.bottomAnchor)
        ])
        installTopLayer()
    }

    func makeDecorativeLayer() -> UIView? {
        nil
    }

    private func installDecorativeLayerIfNeeded() {
        guard let decorativeLayer = makeDecorativeLayer() else { return }
        surfaceView.contentView.addSubview(decorativeLayer)
        decorativeLayer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            decorativeLayer.leadingAnchor.constraint(equalTo: surfaceView.contentView.leadingAnchor),
            decorativeLayer.trailingAnchor.constraint(equalTo: surfaceView.contentView.trailingAnchor),
            decorativeLayer.topAnchor.constraint(equalTo: surfaceView.contentView.topAnchor),
            decorativeLayer.bottomAnchor.constraint(equalTo: surfaceView.contentView.bottomAnchor)
        ])
    }

    private func installTopLayer() {
        let statusBarHeight = normalizedStatusBarHeight()
        topLayer.configure(
            title: navigationTitleText(),
            usesFredokaTitle: usesFredokaNavigationTitle(),
            statusBarHeight: statusBarHeight,
            showsBackIcon: page != .entry
        )
        surfaceView.contentView.addSubview(topLayer)
        topLayer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topLayer.leadingAnchor.constraint(equalTo: surfaceView.contentView.leadingAnchor),
            topLayer.trailingAnchor.constraint(equalTo: surfaceView.contentView.trailingAnchor),
            topLayer.topAnchor.constraint(equalTo: surfaceView.contentView.topAnchor),
            topLayer.heightAnchor.constraint(equalToConstant: CustomTopLayerView.totalHeight(statusBarHeight: statusBarHeight))
        ])
        topLayer.backArea.addTarget(self, action: #selector(returnToPreviousScene), for: .touchUpInside)
    }

    private func normalizedStatusBarHeight() -> CGFloat {
        let rawHeight = view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? view.safeAreaInsets.top
        if rawHeight > 0 {
            return rawHeight > 24 ? 44 : 20
        }
        return UIScreen.main.bounds.height >= 812 ? 44 : 20
    }

    private func navigationTitleText() -> String? {
        switch page {
        case .signIn:
            return "Sign in"
        case .signUp:
            return "Sign up"
        case .resetAccess:
            return "Forgot password"
        case .settings:
            return "Settings"
        case .wallet:
            return "Wallet"
        case .directDialogue, .voiceDialogue:
            return "Victoria"
        case .assistantDialogue:
            return "Recot Bot"
        case .restrictedList:
            return "Blacklist"
        case .agreement:
            return "EULA"
        default:
            return nil
        }
    }

    private func usesFredokaNavigationTitle() -> Bool {
        navigationTitleText() == "Sign in"
    }

    @objc private func returnToPreviousScene() {
        guard let stack = navigationController?.viewControllers, stack.count > 1 else { return }
        navigationController?.popViewController(animated: true)
    }
}

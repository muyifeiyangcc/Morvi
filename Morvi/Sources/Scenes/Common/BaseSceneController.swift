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
        topLayer.showsBackIcon = page != .entry
        surfaceView.contentView.addSubview(topLayer)
        topLayer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topLayer.leadingAnchor.constraint(equalTo: surfaceView.contentView.leadingAnchor),
            topLayer.trailingAnchor.constraint(equalTo: surfaceView.contentView.trailingAnchor),
            topLayer.topAnchor.constraint(equalTo: surfaceView.contentView.topAnchor),
            topLayer.heightAnchor.constraint(equalToConstant: 140)
        ])
        topLayer.backArea.addTarget(self, action: #selector(returnToPreviousScene), for: .touchUpInside)
    }

    @objc private func returnToPreviousScene() {
        guard let stack = navigationController?.viewControllers, stack.count > 1 else { return }
        navigationController?.popViewController(animated: true)
    }
}

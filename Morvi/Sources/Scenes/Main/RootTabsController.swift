import UIKit

final class RootTabsController: UIViewController {
    private var currentPage: ScenePage
    private var canvasView: ReferenceCanvasView?
    private let dockView = FloatingDockView()
    private var surfaceView = DesignSurfaceView()

    init(initialPage: ScenePage = .home) {
        self.currentPage = initialPage
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
        renderCurrentPage()
    }

    private func renderCurrentPage() {
        view.subviews.forEach { $0.removeFromSuperview() }
        surfaceView = DesignSurfaceView()
        let newCanvasView = ReferenceCanvasView(page: currentPage)
        view.addSubview(surfaceView)
        surfaceView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            surfaceView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            surfaceView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            surfaceView.topAnchor.constraint(equalTo: view.topAnchor),
            surfaceView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        surfaceView.contentView.addSubview(newCanvasView)
        newCanvasView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            newCanvasView.leadingAnchor.constraint(equalTo: surfaceView.contentView.leadingAnchor),
            newCanvasView.trailingAnchor.constraint(equalTo: surfaceView.contentView.trailingAnchor),
            newCanvasView.topAnchor.constraint(equalTo: surfaceView.contentView.topAnchor),
            newCanvasView.bottomAnchor.constraint(equalTo: surfaceView.contentView.bottomAnchor)
        ])
        canvasView = newCanvasView
        installTopLayer()
        installPageAreas()
        installDockView()
    }

    private func installTopLayer() {
        let topLayer = CustomTopLayerView()
        surfaceView.contentView.addSubview(topLayer)
        topLayer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topLayer.leadingAnchor.constraint(equalTo: surfaceView.contentView.leadingAnchor),
            topLayer.trailingAnchor.constraint(equalTo: surfaceView.contentView.trailingAnchor),
            topLayer.topAnchor.constraint(equalTo: surfaceView.contentView.topAnchor),
            topLayer.heightAnchor.constraint(equalToConstant: 140)
        ])
        topLayer.backArea.addTarget(self, action: #selector(handleTopLeadingTap), for: .touchUpInside)
        topLayer.trailingArea.addTarget(self, action: #selector(handleTopTrailingTap), for: .touchUpInside)
    }

    private func installPageAreas() {
        switch currentPage {
        case .home:
            installHitAreas([
                HitArea(frame: CGRect(x: 20, y: 58, width: 68, height: 68)) { [weak self] in self?.show(.personalDetail) },
                HitArea(frame: CGRect(x: 20, y: 458, width: 335, height: 52)) { [weak self] in self?.show(.feelingEditor) },
                HitArea(frame: CGRect(x: 20, y: 536, width: 145, height: 145)) { [weak self] in self?.switchTo(.discover) },
                HitArea(frame: CGRect(x: 178, y: 536, width: 178, height: 145)) { [weak self] in self?.show(.assistantDialogue) }
            ])
        case .discover:
            installHitAreas([
                HitArea(frame: CGRect(x: 20, y: 142, width: 50, height: 70)) { [weak self] in self?.show(.uploadEmpty) },
                HitArea(frame: CGRect(x: 20, y: 286, width: 335, height: 360)) { [weak self] in self?.show(.galleryDetail) },
                HitArea(frame: CGRect(x: 98, y: 142, width: 50, height: 70)) { [weak self] in self?.show(.publicPersona) },
                HitArea(frame: CGRect(x: 100, y: 656, width: 118, height: 44)) { [weak self] in self?.show(.repliesPanel) }
            ])
        case .dialogueList:
            installHitAreas([
                HitArea(frame: CGRect(x: 20, y: 146, width: 164, height: 186)) { [weak self] in self?.show(.directDialogue) },
                HitArea(frame: CGRect(x: 192, y: 146, width: 164, height: 186)) { [weak self] in self?.show(.directDialogue) },
                HitArea(frame: CGRect(x: 20, y: 342, width: 164, height: 186)) { [weak self] in self?.show(.directDialogue) },
                HitArea(frame: CGRect(x: 192, y: 342, width: 164, height: 186)) { [weak self] in self?.show(.directDialogue) }
            ])
        case .persona:
            installHitAreas([
                HitArea(frame: CGRect(x: 252, y: 245, width: 106, height: 44)) { [weak self] in self?.show(.profileEditor) },
                HitArea(frame: CGRect(x: 205, y: 245, width: 42, height: 44)) { [weak self] in self?.show(.settings) },
                HitArea(frame: CGRect(x: 20, y: 364, width: 162, height: 232)) { [weak self] in self?.show(.galleryDetail) },
                HitArea(frame: CGRect(x: 192, y: 364, width: 164, height: 164)) { [weak self] in self?.show(.galleryDetail) },
                HitArea(frame: CGRect(x: 192, y: 538, width: 164, height: 180)) { [weak self] in self?.show(.galleryDetail) }
            ])
        default:
            break
        }
    }

    private func installDockView() {
        surfaceView.contentView.addSubview(dockView)
        dockView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dockView.leadingAnchor.constraint(equalTo: surfaceView.contentView.leadingAnchor, constant: 20),
            dockView.trailingAnchor.constraint(equalTo: surfaceView.contentView.trailingAnchor, constant: -20),
            dockView.bottomAnchor.constraint(equalTo: surfaceView.contentView.bottomAnchor, constant: -28),
            dockView.heightAnchor.constraint(equalToConstant: 76)
        ])
        dockView.selectedItem = dockItem(for: currentPage)
        dockView.didSelect = { [weak self] item in
            self?.switchTo(self?.page(for: item) ?? .home)
        }
    }

    private func switchTo(_ page: ScenePage) {
        currentPage = page
        renderCurrentPage()
    }

    private func dockItem(for page: ScenePage) -> FloatingDockView.Item {
        switch page {
        case .discover:
            return .discover
        case .dialogueList:
            return .dialogue
        case .persona:
            return .persona
        default:
            return .home
        }
    }

    private func page(for item: FloatingDockView.Item) -> ScenePage {
        switch item {
        case .home:
            return .home
        case .discover:
            return .discover
        case .dialogue:
            return .dialogueList
        case .persona:
            return .persona
        }
    }

    private func show(_ page: ScenePage) {
        navigationController?.pushViewController(RouteFactory.controller(for: page), animated: true)
    }

    @objc private func handleTopLeadingTap() {
        if currentPage == .home {
            show(.personalDetail)
        }
    }

    @objc private func handleTopTrailingTap() {
        if currentPage == .persona {
            show(.settings)
        }
    }
}

import UIKit

final class RootTabsController: UIViewController {
    private var currentPage: ScenePage
    private var selectedMoodIndex = 0
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
        let newCanvasView = ReferenceCanvasView(page: currentPage, selectedMoodIndex: selectedMoodIndex)
        newCanvasView.didRequestPage = { [weak self] page in
            self?.show(page)
        }
        newCanvasView.didRequestOverlayPage = { [weak self] page in
            self?.showOverlay(page)
        }
        view.addSubview(surfaceView)
        surfaceView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            surfaceView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            surfaceView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            surfaceView.topAnchor.constraint(equalTo: view.topAnchor),
            surfaceView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        installDecorativeBackgroundIfNeeded()
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

    private func installDecorativeBackgroundIfNeeded() {
        guard currentPage == .home else { return }
        let decorativeView = DecorativeGradientView()
        surfaceView.contentView.addSubview(decorativeView)
        decorativeView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            decorativeView.leadingAnchor.constraint(equalTo: surfaceView.contentView.leadingAnchor),
            decorativeView.trailingAnchor.constraint(equalTo: surfaceView.contentView.trailingAnchor),
            decorativeView.topAnchor.constraint(equalTo: surfaceView.contentView.topAnchor),
            decorativeView.bottomAnchor.constraint(equalTo: surfaceView.contentView.bottomAnchor)
        ])
    }

    private func installTopLayer() {
        let topLayer = CustomTopLayerView()
        let statusBarHeight = normalizedStatusBarHeight()
        topLayer.configure(
            title: navigationTitleText(),
            statusBarHeight: statusBarHeight,
            showsBackIcon: false
        )
        surfaceView.contentView.addSubview(topLayer)
        topLayer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topLayer.leadingAnchor.constraint(equalTo: surfaceView.contentView.leadingAnchor),
            topLayer.trailingAnchor.constraint(equalTo: surfaceView.contentView.trailingAnchor),
            topLayer.topAnchor.constraint(equalTo: surfaceView.contentView.topAnchor),
            topLayer.heightAnchor.constraint(equalToConstant: CustomTopLayerView.totalHeight(statusBarHeight: statusBarHeight))
        ])
        topLayer.backArea.addTarget(self, action: #selector(handleTopLeadingTap), for: .touchUpInside)
        topLayer.trailingArea.addTarget(self, action: #selector(handleTopTrailingTap), for: .touchUpInside)
    }

    private func normalizedStatusBarHeight() -> CGFloat {
        let rawHeight = view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? view.safeAreaInsets.top
        if rawHeight > 0 {
            return rawHeight > 24 ? 44 : 20
        }
        return UIScreen.main.bounds.height >= 812 ? 44 : 20
    }

    private func navigationTitleText() -> String? {
        switch currentPage {
        case .discover:
            return "Discover"
        case .dialogueList:
            return "Chat"
        default:
            return nil
        }
    }

    private func installPageAreas() {
        switch currentPage {
        case .home:
            installHitAreas([
                HitArea(frame: CGRect(x: 20, y: 340, width: 100, height: 100)) { [weak self] in self?.selectMood(at: 0) },
                HitArea(frame: CGRect(x: 132, y: 340, width: 100, height: 100)) { [weak self] in self?.selectMood(at: 1) },
                HitArea(frame: CGRect(x: 244, y: 340, width: 100, height: 100)) { [weak self] in self?.selectMood(at: 2) },
                HitArea(frame: CGRect(x: 20, y: 458, width: 335, height: 52)) { [weak self] in self?.showOverlay(.feelingEditor) },
                HitArea(frame: CGRect(x: 20, y: 536, width: 145, height: 145)) { [weak self] in self?.show(.discover) },
                HitArea(frame: CGRect(x: 178, y: 536, width: 178, height: 145)) { [weak self] in self?.show(.assistantDialogue) }
            ])
        case .discover:
            break
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

    private func selectMood(at index: Int) {
        selectedMoodIndex = index
        renderCurrentPage()
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
        case .weeklyFeeling:
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
            return .weeklyFeeling
        case .dialogue:
            return .dialogueList
        case .persona:
            return .persona
        }
    }

    private func show(_ page: ScenePage) {
        navigationController?.pushViewController(RouteFactory.controller(for: page), animated: true)
    }

    private func showOverlay(_ page: ScenePage) {
        let overlayView = ReferenceCanvasView(page: page, selectedMoodIndex: selectedMoodIndex)
        overlayView.tag = 9102
        view.viewWithTag(9102)?.removeFromSuperview()
        view.addSubview(overlayView)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        if page == .feelingEditor
            || page == .uploadEmpty
            || page == .uploadFilled
            || page == .restrictPanel
            || page == .repliesPanel {
            overlayView.didTapOutsideContent = { [weak self] in
                self?.dismissActiveOverlay()
            }
        }
        overlayView.didRequestOverlayPage = { [weak self] targetPage in
            self?.showOverlay(targetPage)
        }
    }

    private func dismissActiveOverlay() {
        view.viewWithTag(9102)?.removeFromSuperview()
    }

    @objc private func handleTopLeadingTap() {
    }

    @objc private func handleTopTrailingTap() {
        if currentPage == .persona {
            show(.settings)
        }
    }
}

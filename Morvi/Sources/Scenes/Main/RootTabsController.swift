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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSessionDidChange),
            name: AccountSessionCenter.sessionDidChangeNotification,
            object: nil
        )
        renderCurrentPage()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleSessionDidChange() {
        guard currentPage == .home else { return }
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
        newCanvasView.didRequestSubjectOverlayPage = { [weak self] page, subjectKey in
            self?.showOverlay(page, restrictionSubjectKey: subjectKey)
        }
        newCanvasView.didChooseMood = { [weak self] index in
            self?.selectMood(at: index)
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
        guard currentPage != .persona && currentPage != .weeklyFeeling else { return }
        let topLayer = CustomTopLayerView()
        let statusBarHeight = normalizedStatusBarHeight()
        topLayer.configure(
            title: navigationTitleText(),
            statusBarHeight: statusBarHeight,
            showsBackIcon: false,
            titleLeading: currentPage == .dialogueList ? 20 : 96
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
        return 44
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
            break
        case .discover:
            break
        case .dialogueList:
            break
        case .persona:
            break
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
            self?.handleDockSelection(item)
        }
    }

    private func handleDockSelection(_ item: FloatingDockView.Item) {
        if requiresSignedInForDockItem(item),
           AccountSessionCenter.shared.isSignedIn == false {
            showOverlay(.accessGate)
            dockView.selectedItem = dockItem(for: currentPage)
            return
        }
        switchTo(page(for: item))
    }

    private func requiresSignedInForDockItem(_ item: FloatingDockView.Item) -> Bool {
        item == .discover || item == .dialogue
    }

    private func switchTo(_ page: ScenePage) {
        currentPage = page
        renderCurrentPage()
    }

    func resetAfterSignOut() {
        currentPage = .home
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
        if AccountSessionCenter.shared.requiresSignedInGate(for: page),
           AccountSessionCenter.shared.isSignedIn == false {
            showOverlay(.accessGate)
            return
        }
        navigationController?.pushViewController(RouteFactory.controller(for: page), animated: true)
    }

    private func showOverlay(_ page: ScenePage, restrictionSubjectKey: String? = nil) {
        if AccountSessionCenter.shared.requiresSignedInGate(for: page),
           AccountSessionCenter.shared.isSignedIn == false {
            showOverlay(.accessGate)
            return
        }
        let overlayView = ReferenceCanvasView(
            page: page,
            selectedMoodIndex: selectedMoodIndex,
            restrictionSubjectKey: restrictionSubjectKey
        )
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
            || page == .reportPanel
            || page == .repliesPanel
            || page == .profileEditor {
            overlayView.didTapOutsideContent = { [weak self] in
                self?.dismissActiveOverlay()
            }
        }
        overlayView.didRequestOverlayPage = { [weak self] targetPage in
            self?.showOverlay(targetPage)
        }
        overlayView.didRequestSubjectOverlayPage = { [weak self] targetPage, subjectKey in
            self?.showOverlay(targetPage, restrictionSubjectKey: subjectKey)
        }
        overlayView.didCompleteSignOut = { [weak self] in
            self?.resetAfterSignOut()
        }
        overlayView.didCompleteAccountRemoval = { [weak self] in
            self?.resetAfterSignOut()
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

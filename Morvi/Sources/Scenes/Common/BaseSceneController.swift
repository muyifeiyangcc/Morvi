import UIKit

class BaseSceneController: UIViewController {
    private let page: ScenePage
    private let topLayer = CustomTopLayerView()
    private let surfaceView = DesignSurfaceView()
    weak var canvasView: ReferenceCanvasView?

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
        self.canvasView = canvasView
        canvasView.didRequestPage = { [weak self] targetPage in
            if AccountSessionCenter.shared.requiresSignedInGate(for: targetPage),
               AccountSessionCenter.shared.isSignedIn == false {
                self?.showCanvasOverlay(.accessGate)
                return
            }
            self?.navigationController?.pushViewController(RouteFactory.controller(for: targetPage), animated: true)
        }
        canvasView.didRequestOverlayPage = { [weak self] targetPage in
            self?.showCanvasOverlay(targetPage)
        }
        view.addSubview(surfaceView)
        surfaceView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            surfaceView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            surfaceView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            surfaceView.topAnchor.constraint(equalTo: view.topAnchor),
            surfaceView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        installFullScreenBackdropIfNeeded()
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
        installKeyboardDismissGesture()
    }

    func makeDecorativeLayer() -> UIView? {
        nil
    }

    private func installFullScreenBackdropIfNeeded() {
        guard page == .galleryDetail || page == .publicPersona else { return }
        let image = UIImage(named: "discover_feed_cover")
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        surfaceView.insertSubview(imageView, belowSubview: surfaceView.contentView)
        imageView.translatesAutoresizingMaskIntoConstraints = false

        var constraints: [NSLayoutConstraint]
        if page == .publicPersona {
            constraints = [
                imageView.leadingAnchor.constraint(equalTo: surfaceView.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor),
                imageView.topAnchor.constraint(equalTo: surfaceView.topAnchor, constant: -2)
            ]
            if let image, image.size.width > 0 {
                constraints.append(imageView.heightAnchor.constraint(
                    equalTo: imageView.widthAnchor,
                    multiplier: image.size.height / image.size.width
                ))
            }
        } else {
            constraints = [
                imageView.topAnchor.constraint(equalTo: surfaceView.topAnchor),
                imageView.bottomAnchor.constraint(equalTo: surfaceView.bottomAnchor),
                imageView.centerXAnchor.constraint(equalTo: surfaceView.centerXAnchor)
            ]
            if let image, image.size.height > 0 {
                constraints.append(imageView.widthAnchor.constraint(
                    equalTo: imageView.heightAnchor,
                    multiplier: image.size.width / image.size.height
                ))
            } else {
                constraints.append(contentsOf: [
                    imageView.leadingAnchor.constraint(equalTo: surfaceView.leadingAnchor),
                    imageView.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor)
                ])
            }
        }
        NSLayoutConstraint.activate(constraints)
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
            statusBarHeight: statusBarHeight,
            showsBackIcon: page != .entry || navigationController?.presentingViewController != nil,
            trailingIconName: trailingNavigationIconName()
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
        topLayer.trailingArea.addTarget(self, action: #selector(handleTrailingNavigationTap), for: .touchUpInside)
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
        case .discover:
            return "Discover"
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

    private func trailingNavigationIconName() -> String? {
        switch page {
        case .galleryDetail, .publicPersona, .directDialogue, .voiceDialogue:
            return "gallery_navigation_more"
        default:
            return nil
        }
    }

    private func installKeyboardDismissGesture() {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboardFromBlankArea))
        gesture.cancelsTouchesInView = false
        gesture.delegate = self
        view.addGestureRecognizer(gesture)
    }

    @objc private func dismissKeyboardFromBlankArea() {
        view.endEditing(true)
    }

    @objc private func returnToPreviousScene() {
        guard let navigationController else { return }
        if navigationController.viewControllers.count > 1 {
            navigationController.popViewController(animated: true)
            return
        }
        if navigationController.presentingViewController != nil {
            navigationController.dismiss(animated: true)
        }
    }

    @objc private func handleTrailingNavigationTap() {
        switch page {
        case .galleryDetail, .publicPersona, .directDialogue, .voiceDialogue:
            showCanvasOverlay(.restrictPanel)
        default:
            break
        }
    }

    private func showCanvasOverlay(_ page: ScenePage) {
        if AccountSessionCenter.shared.requiresSignedInGate(for: page),
           AccountSessionCenter.shared.isSignedIn == false {
            showCanvasOverlay(.accessGate)
            return
        }
        let overlayView = ReferenceCanvasView(page: page)
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
                self?.dismissCanvasOverlay()
            }
        }
        overlayView.didRequestOverlayPage = { [weak self] targetPage in
            self?.showCanvasOverlay(targetPage)
        }
        overlayView.didCompleteSignOut = { [weak self] in
            self?.completeSignOutFlow()
        }
    }

    private func dismissCanvasOverlay() {
        view.viewWithTag(9102)?.removeFromSuperview()
    }

    private func completeSignOutFlow() {
        guard let navigationController else { return }
        if let rootTabsController = navigationController.viewControllers.first as? RootTabsController {
            rootTabsController.resetAfterSignOut()
            navigationController.popToRootViewController(animated: false)
            return
        }
        navigationController.setViewControllers([RootTabsController()], animated: false)
    }
}

extension BaseSceneController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UIControl {
            return false
        }
        if touch.view is UITextView {
            return false
        }
        if touch.view?.isDescendant(of: topLayer) == true {
            return false
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureBelongsToScrollableArea(gestureRecognizer) || gestureBelongsToScrollableArea(otherGestureRecognizer)
    }

    private func gestureBelongsToScrollableArea(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        var touchedView = gestureRecognizer.view
        while let candidate = touchedView {
            if candidate is UIScrollView {
                return true
            }
            touchedView = candidate.superview
        }
        return false
    }
}

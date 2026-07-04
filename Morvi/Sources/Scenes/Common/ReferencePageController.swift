import UIKit

class ReferencePageController: BaseSceneController {
    private let page: ScenePage
    private let areasBuilder: ((ReferencePageController) -> [HitArea])?
    private weak var progressOverlayView: MorviProgressOverlayView?

    init(page: ScenePage, areas: ((ReferencePageController) -> [HitArea])? = nil) {
        self.page = page
        self.areasBuilder = areas
        super.init(page: page)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func makeDecorativeLayer() -> UIView? {
        switch page {
        case .discover, .wallet, .assistantDialogue, .settings, .restrictedList:
            return DecorativeGradientView(palette: .topLeftGlow)
        default:
            return nil
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard view.viewWithTag(9001) == nil else { return }
        let marker = UIView(frame: .zero)
        marker.tag = 9001
        marker.isHidden = true
        view.addSubview(marker)
        installHitAreas(areasBuilder?(self) ?? [])
    }

    func push(_ page: ScenePage) {
        if AccountSessionCenter.shared.requiresSignedInGate(for: page),
           AccountSessionCenter.shared.isSignedIn == false {
            showOverlay(.accessGate)
            return
        }
        navigationController?.pushViewController(RouteFactory.controller(for: page), animated: true)
    }

    func submitSignUp() {
        let entries = textFields(in: view)
            .map { field -> (field: UITextField, frame: CGRect) in
                (field, field.convert(field.bounds, to: view))
            }
            .sorted { $0.frame.minY < $1.frame.minY }
            .map(\.field)

        guard entries.count >= 3 else {
            MorviToastView.show("Please enter email", in: view)
            return
        }

        let emailText = trimmedText(entries[0])
        let passwordText = trimmedText(entries[1])
        let repeatedPasswordText = trimmedText(entries[2])

        guard emailText.isEmpty == false else {
            MorviToastView.show("Please enter email", in: view)
            return
        }
        guard passwordText.isEmpty == false else {
            MorviToastView.show("Please enter password", in: view)
            return
        }
        guard repeatedPasswordText.isEmpty == false else {
            MorviToastView.show("Please enter the password again", in: view)
            return
        }
        guard passwordText == repeatedPasswordText else {
            MorviToastView.show("Passwords do not match", in: view)
            return
        }

        view.endEditing(true)
        showProgressOverlay()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try AccountSessionCenter.shared.registerLocalAccount(
                    email: emailText,
                    secretText: passwordText
                )
                DispatchQueue.main.async {
                    self?.hideProgressOverlay {
                        self?.closeAuthFlowAfterRegistration()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.hideProgressOverlay {
                        guard let view = self?.view else { return }
                        MorviToastView.show("Registration failed", in: view)
                    }
                }
            }
        }
    }

    func showOverlay(_ page: ScenePage) {
        if AccountSessionCenter.shared.requiresSignedInGate(for: page),
           AccountSessionCenter.shared.isSignedIn == false {
            showOverlay(.accessGate)
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
            || page == .reportPanel
            || page == .repliesPanel {
            overlayView.didTapOutsideContent = { [weak self] in
                self?.view.viewWithTag(9102)?.removeFromSuperview()
            }
        }
        overlayView.didRequestOverlayPage = { [weak self] targetPage in
            self?.showOverlay(targetPage)
        }
    }

    func enterMainFlow() {
        AccountSessionCenter.shared.activateLocalAccount()
        if navigationController?.presentingViewController != nil {
            navigationController?.dismiss(animated: true)
            return
        }
        navigationController?.setViewControllers([RootTabsController()], animated: true)
    }

    private func trimmedText(_ field: UITextField) -> String {
        (field.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func showProgressOverlay() {
        let overlay = MorviProgressOverlayView()
        progressOverlayView = overlay
        overlay.show(in: view)
    }

    private func hideProgressOverlay(completion: @escaping () -> Void) {
        guard let progressOverlayView else {
            completion()
            return
        }
        progressOverlayView.dismiss(completion: completion)
        self.progressOverlayView = nil
    }

    private func closeAuthFlowAfterRegistration() {
        if navigationController?.presentingViewController != nil {
            navigationController?.dismiss(animated: true)
            return
        }
        navigationController?.setViewControllers([RootTabsController()], animated: true)
    }

    private func textFields(in rootView: UIView) -> [UITextField] {
        var results: [UITextField] = []
        if let textField = rootView as? UITextField {
            results.append(textField)
        }
        rootView.subviews.forEach { childView in
            results.append(contentsOf: textFields(in: childView))
        }
        return results
    }
}

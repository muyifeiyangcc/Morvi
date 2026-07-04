import UIKit
import Photos
import PhotosUI

class ReferencePageController: BaseSceneController {
    private struct RegistrationDraft {
        let emailText: String
        let secretText: String
    }

    private static var registrationDraft: RegistrationDraft?
    private static var registrationAvatarAsset: String?
    private static var shouldShowRegistrationSuccessToast = false

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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if page == .entry,
           Self.shouldShowRegistrationSuccessToast {
            Self.shouldShowRegistrationSuccessToast = false
            MorviToastView.show("Registration successful", in: view)
        }
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
        Self.registrationDraft = RegistrationDraft(emailText: emailText, secretText: passwordText)
        Self.registrationAvatarAsset = nil
        push(.personalDetail)
    }

    func submitSignIn() {
        let entries = textFields(in: view)
            .map { field -> (field: UITextField, frame: CGRect) in
                (field, field.convert(field.bounds, to: view))
            }
            .sorted { $0.frame.minY < $1.frame.minY }
            .map(\.field)

        guard entries.count >= 2 else {
            MorviToastView.show("Please enter email", in: view)
            return
        }

        let emailText = trimmedText(entries[0])
        let secretText = trimmedText(entries[1])

        guard emailText.isEmpty == false else {
            MorviToastView.show("Please enter email", in: view)
            return
        }
        guard secretText.isEmpty == false else {
            MorviToastView.show("Please enter password", in: view)
            return
        }

        view.endEditing(true)
        showProgressOverlay()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let didPass: Bool
            do {
                didPass = try AccountSessionCenter.shared.signInLocalAccount(
                    email: emailText,
                    secretText: secretText
                )
            } catch {
                DispatchQueue.main.async {
                    self?.hideProgressOverlay {
                        guard let view = self?.view else { return }
                        MorviToastView.show("Login failed", in: view)
                    }
                }
                return
            }

            DispatchQueue.main.async {
                self?.hideProgressOverlay {
                    guard didPass else {
                        guard let view = self?.view else { return }
                        MorviToastView.show("Invalid email or password", in: view)
                        return
                    }
                    self?.finishAuthFlow(successToastText: "Login successful")
                }
            }
        }
    }

    func chooseRegistrationAvatar() {
        view.endEditing(true)
        showProgressOverlay()
        handlePhotoLibraryAccess(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    private func handlePhotoLibraryAccess(_ status: PHAuthorizationStatus) {
        switch status {
        case .authorized, .limited:
            presentRegistrationAvatarPicker()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] updatedStatus in
                DispatchQueue.main.async {
                    self?.handlePhotoLibraryAccess(updatedStatus)
                }
            }
        case .denied, .restricted:
            hideProgressOverlay { [weak self] in
                self?.showPhotoLibrarySettingsGuide()
            }
        @unknown default:
            hideProgressOverlay { [weak self] in
                self?.showPhotoLibrarySettingsGuide()
            }
        }
    }

    private func presentRegistrationAvatarPicker() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true) { [weak self] in
            self?.hideProgressOverlay {}
        }
    }

    private func showPhotoLibrarySettingsGuide() {
        let alert = UIAlertController(
            title: "Photo access required",
            message: "Please allow photo access in Settings to select an avatar.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(settingsURL)
        })
        present(alert, animated: true)
    }

    func submitPersonalDetail() {
        let entries = textFields(in: view)
            .map { field -> (field: UITextField, frame: CGRect) in
                (field, field.convert(field.bounds, to: view))
            }
            .sorted { $0.frame.minY < $1.frame.minY }
            .map(\.field)

        guard entries.count >= 4 else {
            MorviToastView.show("Please enter nickname", in: view)
            return
        }

        let nicknameText = trimmedText(entries[0])
        let genderText = trimmedText(entries[1])
        let birthdayText = trimmedText(entries[2])
        let locationText = trimmedText(entries[3])

        guard nicknameText.isEmpty == false else {
            MorviToastView.show("Please enter nickname", in: view)
            return
        }
        guard let avatarAsset = Self.registrationAvatarAsset else {
            MorviToastView.show("Please select avatar", in: view)
            return
        }
        guard let draft = Self.registrationDraft else {
            MorviToastView.show("Please enter password", in: view)
            return
        }

        view.endEditing(true)
        showProgressOverlay()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try AccountSessionCenter.shared.registerLocalAccount(
                    email: draft.emailText,
                    secretText: draft.secretText,
                    displayName: nicknameText,
                    genderText: genderText,
                    avatarAsset: avatarAsset,
                    birthDate: birthdayText.isEmpty ? nil : birthdayText,
                    locationText: locationText.isEmpty ? nil : locationText
                )
                DispatchQueue.main.async {
                    self?.hideProgressOverlay {
                        Self.registrationDraft = nil
                        Self.registrationAvatarAsset = nil
                        self?.returnToAuthRootAfterRegistration()
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
        overlayView.didCompleteSignOut = { [weak self] in
            self?.navigationController?.setViewControllers([RootTabsController()], animated: false)
        }
        overlayView.didCompleteAccountRemoval = { [weak self] in
            self?.navigationController?.setViewControllers([RootTabsController()], animated: false)
        }
    }

    func submitGuestSignIn() {
        showProgressOverlay()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try AccountSessionCenter.shared.signInAsGuest()
                DispatchQueue.main.async {
                    self?.hideProgressOverlay {
                        self?.finishAuthFlow(successToastText: "Login successful")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.hideProgressOverlay {
                        guard let view = self?.view else { return }
                        MorviToastView.show("Login failed", in: view)
                    }
                }
            }
        }
    }

    private func finishAuthFlow(successToastText: String? = nil) {
        if navigationController?.presentingViewController != nil {
            navigationController?.dismiss(animated: true) {
                if let successToastText {
                    MorviToastView.show(successToastText)
                }
            }
            return
        }
        navigationController?.setViewControllers([RootTabsController()], animated: true)
        if let successToastText {
            DispatchQueue.main.async {
                MorviToastView.show(successToastText)
            }
        }
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

    private func returnToAuthRootAfterRegistration() {
        guard let navigationController else { return }
        Self.shouldShowRegistrationSuccessToast = true
        navigationController.popToRootViewController(animated: true)
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

    private func storeAvatarImage(_ image: UIImage) throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.88) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let baseDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let avatarDirectory = baseDirectory
            .appendingPathComponent("Morvi", isDirectory: true)
            .appendingPathComponent("Avatars", isDirectory: true)
        try FileManager.default.createDirectory(
            at: avatarDirectory,
            withIntermediateDirectories: true
        )
        let fileName = "avatar-\(UUID().uuidString.lowercased()).jpg"
        let fileURL = avatarDirectory.appendingPathComponent(fileName)
        try imageData.write(to: fileURL, options: .atomic)
        return "local-avatar/\(fileName)"
    }
}

extension ReferencePageController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else {
            return
        }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self,
                  let image = object as? UIImage else { return }
            do {
                let avatarAsset = try self.storeAvatarImage(image)
                DispatchQueue.main.async {
                    Self.registrationAvatarAsset = avatarAsset
                    self.canvasView?.updateRegistrationAvatar(image)
                }
            } catch {
                DispatchQueue.main.async {
                    MorviToastView.show("Avatar save failed", in: self.view)
                }
            }
        }
    }
}

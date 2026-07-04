import UIKit
import Photos
import PhotosUI
import AuthenticationServices
import AVFoundation
import UniformTypeIdentifiers

class ReferencePageController: BaseSceneController {
    private struct RegistrationDraft {
        let emailText: String
        let secretText: String
    }

    private enum PhotoSelectionTarget {
        case registrationAvatar
        case workCover
    }

    private enum WorkMediaSource {
        case album
        case camera
    }

    private static var registrationDraft: RegistrationDraft?
    private static var registrationAvatarAsset: String?
    private static var shouldShowRegistrationSuccessToast = false

    private let page: ScenePage
    private let areasBuilder: ((ReferencePageController) -> [HitArea])?
    private weak var progressOverlayView: MorviProgressOverlayView?
    private var appleSignInController: ASAuthorizationController?
    private var photoSelectionTarget: PhotoSelectionTarget?
    private var pendingWorkMediaSource: WorkMediaSource?
    private let creativeRepository = SQLiteCreativeWorkRepository()

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

    override func viewDidLoad() {
        super.viewDidLoad()
        canvasView?.didRequestPrimaryAction = { [weak self] in
            guard let self else { return }
            switch self.page {
            case .signIn:
                self.submitSignIn()
            case .signUp:
                self.submitSignUp()
            case .resetAccess:
                self.submitResetAccess()
            case .personalDetail:
                self.submitPersonalDetail()
            default:
                break
            }
        }
        canvasView?.didRequestOverlayPage = { [weak self] targetPage in
            self?.showOverlay(targetPage)
        }
        canvasView?.didRequestSubjectOverlayPage = { [weak self] targetPage, subjectKey in
            self?.showOverlay(targetPage, restrictionSubjectKey: subjectKey)
        }
        canvasView?.didRequestSubjectPage = { [weak self] targetPage, subjectKey in
            self?.pushPage(targetPage, restrictionSubjectKey: subjectKey)
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

    func canContinueWithAgreementConsent() -> Bool {
        guard ReferenceCanvasView.hasAcceptedAgreementConsent else {
            MorviToastView.show("Please agree to User Agreement and Privacy Policy", in: view)
            return false
        }
        return true
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
        guard isValidEmailText(emailText) else {
            MorviToastView.show("Please enter a valid email address", in: view)
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
        guard isValidEmailText(emailText) else {
            MorviToastView.show("Please enter a valid email address", in: view)
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

    func submitResetAccess() {
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
        let secretText = trimmedText(entries[1])
        let repeatedSecretText = trimmedText(entries[2])

        guard emailText.isEmpty == false else {
            MorviToastView.show("Please enter email", in: view)
            return
        }
        guard isValidEmailText(emailText) else {
            MorviToastView.show("Please enter a valid email address", in: view)
            return
        }
        guard secretText.isEmpty == false else {
            MorviToastView.show("Please enter password", in: view)
            return
        }
        guard repeatedSecretText.isEmpty == false else {
            MorviToastView.show("Please enter the password again", in: view)
            return
        }
        guard secretText == repeatedSecretText else {
            MorviToastView.show("Passwords do not match", in: view)
            return
        }

        view.endEditing(true)
        showProgressOverlay()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let didUpdate: Bool
            do {
                didUpdate = try AccountSessionCenter.shared.resetLocalSecret(
                    email: emailText,
                    secretText: secretText
                )
            } catch {
                DispatchQueue.main.async {
                    self?.hideProgressOverlay {
                        guard let view = self?.view else { return }
                        MorviToastView.show("Password reset failed", in: view)
                    }
                }
                return
            }

            DispatchQueue.main.async {
                self?.hideProgressOverlay {
                    guard didUpdate else {
                        guard let view = self?.view else { return }
                        MorviToastView.show("Email not found", in: view)
                        return
                    }
                    self?.navigationController?.popViewController(animated: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        MorviToastView.show("Password reset successful")
                    }
                }
            }
        }
    }

    func chooseRegistrationAvatar() {
        view.endEditing(true)
        photoSelectionTarget = .registrationAvatar
        showProgressOverlay()
        handlePhotoLibraryAccess(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    private func handlePhotoLibraryAccess(_ status: PHAuthorizationStatus) {
        switch status {
        case .authorized, .limited:
            presentPhotoPicker()
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

    private func presentPhotoPicker() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        switch photoSelectionTarget {
        case .workCover:
            configuration.filter = .any(of: [.images, .videos])
        default:
            configuration.filter = .images
        }
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true) { [weak self] in
            self?.hideProgressOverlay {}
        }
    }

    private func handleCameraAccess(_ status: AVAuthorizationStatus) {
        switch status {
        case .authorized:
            handleMicrophoneAccess(AVCaptureDevice.authorizationStatus(for: .audio))
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] isAllowed in
                DispatchQueue.main.async {
                    if isAllowed {
                        self?.handleMicrophoneAccess(AVCaptureDevice.authorizationStatus(for: .audio))
                    } else {
                        self?.showCameraSettingsGuideAfterProgress()
                    }
                }
            }
        case .denied, .restricted:
            showCameraSettingsGuideAfterProgress()
        @unknown default:
            showCameraSettingsGuideAfterProgress()
        }
    }

    private func handleMicrophoneAccess(_ status: AVAuthorizationStatus) {
        switch status {
        case .authorized:
            presentWorkCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] isAllowed in
                DispatchQueue.main.async {
                    if isAllowed {
                        self?.presentWorkCamera()
                    } else {
                        self?.showCameraSettingsGuideAfterProgress()
                    }
                }
            }
        case .denied, .restricted:
            showCameraSettingsGuideAfterProgress()
        @unknown default:
            showCameraSettingsGuideAfterProgress()
        }
    }

    private func presentWorkCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            hideProgressOverlay { [weak self] in
                guard let view = self?.view else { return }
                MorviToastView.show("Camera unavailable", in: view)
            }
            return
        }

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        let availableTypes = UIImagePickerController.availableMediaTypes(for: .camera) ?? []
        let requestedTypes = [UTType.image.identifier, UTType.movie.identifier]
        picker.mediaTypes = requestedTypes.filter { availableTypes.contains($0) }
        picker.videoQuality = .typeHigh
        present(picker, animated: true) { [weak self] in
            self?.hideProgressOverlay {}
        }
    }

    private func showCameraSettingsGuideAfterProgress() {
        hideProgressOverlay { [weak self] in
            self?.showCameraSettingsGuide()
        }
    }

    private func showPhotoLibrarySettingsGuide() {
        let alert = UIAlertController(
            title: "Photo access required",
            message: "Please allow photo access in Settings to select an image.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(settingsURL)
        })
        present(alert, animated: true)
    }

    private func showCameraSettingsGuide() {
        let alert = UIAlertController(
            title: "Camera access required",
            message: "Please allow camera and microphone access in Settings to capture photos or videos.",
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

    func showOverlay(_ page: ScenePage, restrictionSubjectKey: String? = nil) {
        if AccountSessionCenter.shared.requiresSignedInGate(for: page),
           AccountSessionCenter.shared.isSignedIn == false {
            showOverlay(.accessGate)
            return
        }
        let overlayView = ReferenceCanvasView(page: page, restrictionSubjectKey: restrictionSubjectKey)
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
        overlayView.didRequestSubjectPage = { [weak self] targetPage, subjectKey in
            self?.pushPage(targetPage, restrictionSubjectKey: subjectKey)
        }
        overlayView.didRequestSubjectOverlayPage = { [weak self] targetPage, subjectKey in
            self?.showOverlay(targetPage, restrictionSubjectKey: subjectKey)
        }
        overlayView.didRequestUploadMediaSelection = { [weak self] in
            self?.chooseWorkCover()
        }
        overlayView.didSubmitUploadWork = { [weak self] draft in
            self?.submitWorkUpload(draft, overlayView: overlayView)
        }
        overlayView.didCompleteSignOut = { [weak self] in
            self?.navigationController?.setViewControllers([RootTabsController()], animated: false)
        }
        overlayView.didCompleteAccountRemoval = { [weak self] in
            self?.navigationController?.setViewControllers([RootTabsController()], animated: false)
        }
    }

    private func pushPage(_ page: ScenePage, restrictionSubjectKey: String?) {
        if AccountSessionCenter.shared.requiresSignedInGate(for: page),
           AccountSessionCenter.shared.isSignedIn == false {
            showOverlay(.accessGate)
            return
        }
        if page == .publicPersona,
           let restrictionSubjectKey,
           AccountSessionCenter.shared.canOpenPublicPersona(accountKey: restrictionSubjectKey) == false {
            MorviToastView.show("This profile is unavailable.", in: view)
            return
        }
        navigationController?.pushViewController(RouteFactory.controller(for: page), animated: true)
    }

    private func chooseWorkCover() {
        view.endEditing(true)
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Album", style: .default) { [weak self] _ in
            self?.beginWorkMediaSelection(from: .album)
        })
        sheet.addAction(UIAlertAction(title: "Camera", style: .default) { [weak self] _ in
            self?.beginWorkMediaSelection(from: .camera)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }

    private func beginWorkMediaSelection(from source: WorkMediaSource) {
        photoSelectionTarget = .workCover
        pendingWorkMediaSource = source
        showProgressOverlay()
        switch source {
        case .album:
            handlePhotoLibraryAccess(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        case .camera:
            handleCameraAccess(AVCaptureDevice.authorizationStatus(for: .video))
        }
    }

    private func submitWorkUpload(
        _ draft: ReferenceCanvasView.WorkUploadDraft,
        overlayView: ReferenceCanvasView
    ) {
        guard let accountKey = AccountSessionCenter.shared.activeAccountKey else {
            showOverlay(.accessGate)
            return
        }

        view.endEditing(true)
        showProgressOverlay()
        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak overlayView] in
            do {
                let now = LocalDateText.now()
                let record = CreativeWorkRecord(
                    stableKey: "work-local-\(UUID().uuidString.lowercased())",
                    ownerAccountKey: accountKey,
                    title: draft.titleText,
                    bodyText: draft.detailText,
                    mediaKind: draft.mediaKind,
                    mediaAsset: draft.mediaAsset,
                    coverAsset: draft.coverAsset,
                    mediaWidth: Double(draft.mediaSize.width),
                    mediaHeight: Double(draft.mediaSize.height),
                    durationSeconds: draft.durationSeconds,
                    visibilityCode: 0,
                    createdAt: now,
                    updatedAt: now
                )
                try self?.creativeRepository.saveWithThemeTitles(record, themeTitles: draft.themeTitles)
                DispatchQueue.main.async {
                    self?.hideProgressOverlay {
                        overlayView?.removeFromSuperview()
                        self?.canvasView?.reloadRenderedContent()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.hideProgressOverlay {
                        guard let view = self?.view else { return }
                        MorviToastView.show("Upload failed", in: view)
                    }
                }
            }
        }
    }

    func submitGuestSignIn() {
        guard canContinueWithAgreementConsent() else { return }
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

    func submitAppleSignIn() {
        guard canContinueWithAgreementConsent() else { return }
        view.endEditing(true)
        showProgressOverlay()
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        appleSignInController = controller
        controller.performRequests()
    }

    private func completeAppleSignIn(
        subjectText: String,
        emailText: String?,
        fullNameText: String?
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try AccountSessionCenter.shared.signInWithApple(
                    subjectText: subjectText,
                    emailText: emailText,
                    fullNameText: fullNameText
                )
                DispatchQueue.main.async {
                    self?.hideProgressOverlay {
                        self?.appleSignInController = nil
                        self?.finishAuthFlow(successToastText: "Login successful")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.hideProgressOverlay {
                        self?.appleSignInController = nil
                        guard let view = self?.view else { return }
                        MorviToastView.show("Apple login failed", in: view)
                    }
                }
            }
        }
    }

    private func failAppleSignIn() {
        appleSignInController = nil
        hideProgressOverlay { [weak self] in
            guard let view = self?.view else { return }
            MorviToastView.show("Apple login failed", in: view)
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

    private func isValidEmailText(_ text: String) -> Bool {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
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
        try storeLocalImage(image, folderName: "Avatars", filePrefix: "avatar", assetPrefix: "local-avatar")
    }

    private func storeWorkImage(_ image: UIImage) throws -> String {
        try storeLocalImage(image, folderName: "WorkMedia", filePrefix: "work", assetPrefix: "local-work")
    }

    private func storeWorkVideo(from sourceURL: URL) throws -> String {
        let baseDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let targetDirectory = baseDirectory
            .appendingPathComponent("Morvi", isDirectory: true)
            .appendingPathComponent("WorkMedia", isDirectory: true)
        try FileManager.default.createDirectory(
            at: targetDirectory,
            withIntermediateDirectories: true
        )
        let fileExtension = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let fileName = "work-video-\(UUID().uuidString.lowercased()).\(fileExtension)"
        let fileURL = targetDirectory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: fileURL)
        return "local-work-video/\(fileName)"
    }

    private func storedWorkVideoURL(for asset: String) -> URL? {
        let prefix = "local-work-video/"
        guard asset.hasPrefix(prefix) else { return nil }
        let fileName = String(asset.dropFirst(prefix.count))
        guard fileName.isEmpty == false,
              let baseDirectory = try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
              ) else {
            return nil
        }
        return baseDirectory
            .appendingPathComponent("Morvi", isDirectory: true)
            .appendingPathComponent("WorkMedia", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    private func makeVideoPreview(from videoURL: URL) throws -> UIImage {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let imageRef = try generator.copyCGImage(at: .zero, actualTime: nil)
        return UIImage(cgImage: imageRef)
    }

    private func videoDurationSeconds(for videoURL: URL) -> TimeInterval {
        CMTimeGetSeconds(AVAsset(url: videoURL).duration)
    }

    private func storeLocalImage(
        _ image: UIImage,
        folderName: String,
        filePrefix: String,
        assetPrefix: String
    ) throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.88) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let baseDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let targetDirectory = baseDirectory
            .appendingPathComponent("Morvi", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(
            at: targetDirectory,
            withIntermediateDirectories: true
        )
        let fileName = "\(filePrefix)-\(UUID().uuidString.lowercased()).jpg"
        let fileURL = targetDirectory.appendingPathComponent(fileName)
        try imageData.write(to: fileURL, options: .atomic)
        return "\(assetPrefix)/\(fileName)"
    }
}

extension ReferencePageController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        guard let provider = results.first?.itemProvider else {
            picker.dismiss(animated: true) { [weak self] in
                self?.photoSelectionTarget = nil
                self?.pendingWorkMediaSource = nil
            }
            return
        }

        if provider.canLoadObject(ofClass: UIImage.self) {
            picker.dismiss(animated: true)
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let self,
                      let image = object as? UIImage else { return }
                self.applyPickedImage(image)
            }
            return
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            picker.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                self.showProgressOverlay()
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] fileURL, _ in
                    guard let self else { return }
                    guard let fileURL else {
                        DispatchQueue.main.async {
                            self.hideProgressOverlay {
                                self.photoSelectionTarget = nil
                                self.pendingWorkMediaSource = nil
                                MorviToastView.show("Video save failed", in: self.view)
                            }
                        }
                        return
                    }
                    self.applyPickedVideo(fileURL)
                }
            }
            return
        }

        picker.dismiss(animated: true) { [weak self] in
            self?.photoSelectionTarget = nil
            self?.pendingWorkMediaSource = nil
        }
    }

    private func applyPickedImage(_ image: UIImage) {
        do {
            let target = photoSelectionTarget
            let storedAsset: String
            switch target {
            case .workCover:
                storedAsset = try storeWorkImage(image)
            default:
                storedAsset = try storeAvatarImage(image)
            }
            DispatchQueue.main.async {
                switch target {
                case .workCover:
                    (self.view.viewWithTag(9102) as? ReferenceCanvasView)?
                        .updateUploadMedia(
                            previewImage: image,
                            mediaAsset: storedAsset,
                            coverAsset: storedAsset,
                            mediaKind: 0
                        )
                default:
                    Self.registrationAvatarAsset = storedAsset
                    self.canvasView?.updateRegistrationAvatar(image)
                }
                self.photoSelectionTarget = nil
                self.pendingWorkMediaSource = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.photoSelectionTarget = nil
                self.pendingWorkMediaSource = nil
                MorviToastView.show("Image save failed", in: self.view)
            }
        }
    }

    private func applyPickedVideo(_ fileURL: URL) {
        do {
            let storedMediaAsset = try storeWorkVideo(from: fileURL)
            guard let storedVideoURL = storedWorkVideoURL(for: storedMediaAsset) else {
                throw CocoaError(.fileNoSuchFile)
            }
            let previewImage = try makeVideoPreview(from: storedVideoURL)
            let storedCoverAsset = try storeWorkImage(previewImage)
            let duration = videoDurationSeconds(for: storedVideoURL)
            DispatchQueue.main.async {
                self.hideProgressOverlay {
                    (self.view.viewWithTag(9102) as? ReferenceCanvasView)?
                        .updateUploadMedia(
                            previewImage: previewImage,
                            mediaAsset: storedMediaAsset,
                            coverAsset: storedCoverAsset,
                            mediaKind: 1,
                            durationSeconds: duration.isFinite ? duration : nil
                        )
                    self.photoSelectionTarget = nil
                    self.pendingWorkMediaSource = nil
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.hideProgressOverlay {
                    self.photoSelectionTarget = nil
                    self.pendingWorkMediaSource = nil
                    MorviToastView.show("Video save failed", in: self.view)
                }
            }
        }
    }
}

extension ReferencePageController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        let mediaType = info[.mediaType] as? String
        if mediaType == UTType.movie.identifier,
           let videoURL = info[.mediaURL] as? URL {
            picker.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                self.showProgressOverlay()
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    self?.applyPickedVideo(videoURL)
                }
            }
            return
        }

        picker.dismiss(animated: true)
        if let image = info[.originalImage] as? UIImage {
            applyPickedImage(image)
            return
        }

        photoSelectionTarget = nil
        pendingWorkMediaSource = nil
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        photoSelectionTarget = nil
        pendingWorkMediaSource = nil
    }
}

extension ReferencePageController: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        view.window ?? ASPresentationAnchor()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              credential.user.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            failAppleSignIn()
            return
        }

        let fullNameText = credential.fullName.map {
            PersonNameComponentsFormatter().string(from: $0)
        }
        completeAppleSignIn(
            subjectText: credential.user,
            emailText: credential.email,
            fullNameText: fullNameText
        )
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        failAppleSignIn()
    }
}

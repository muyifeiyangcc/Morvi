import UIKit
import Photos
import PhotosUI

final class RootTabsController: UIViewController {
    private var currentPage: ScenePage
    private var selectedMoodIndex = 0
    private var canvasView: ReferenceCanvasView?
    private let dockView = FloatingDockView()
    private var surfaceView = DesignSurfaceView()
    private weak var activeProfileEditOverlayView: ReferenceCanvasView?
    private var isOpeningSecondaryPage = false

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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCreativeWorkActivityDidChange),
            name: SQLiteCreativeWorkRepository.activityDidChangeNotification,
            object: nil
        )
        renderCurrentPage()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleSessionDidChange() {
        switch currentPage {
        case .home, .persona:
            renderCurrentPage()
        default:
            break
        }
    }

    @objc private func handleCreativeWorkActivityDidChange() {
        switch currentPage {
        case .home, .discover, .persona:
            renderCurrentPage()
        default:
            break
        }
    }

    private func renderCurrentPage() {
        view.subviews.forEach { $0.removeFromSuperview() }
        surfaceView = DesignSurfaceView()
        let newCanvasView = ReferenceCanvasView(page: currentPage, selectedMoodIndex: selectedMoodIndex)
        newCanvasView.didRequestPage = { [weak self] page in
            self?.show(page)
        }
        newCanvasView.didRequestSubjectPage = { [weak self] page, subjectKey in
            self?.show(page, restrictionSubjectKey: subjectKey)
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

    func showPersonaRoot() {
        currentPage = .persona
        renderCurrentPage()
        dockView.selectedItem = .persona
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

    private func show(_ page: ScenePage, restrictionSubjectKey: String? = nil) {
        guard isOpeningSecondaryPage == false else { return }
        if AccountSessionCenter.shared.requiresSignedInGate(for: page),
           AccountSessionCenter.shared.isSignedIn == false {
            showOverlay(.accessGate)
            return
        }
        if page == .persona {
            showPersonaRoot()
            return
        }
        let targetAccountKey = restrictionSubjectKey ?? RouteContextStore.currentTargetAccountKey()
        if page == .publicPersona,
           let targetAccountKey,
           AccountSessionCenter.shared.isActiveAccount(targetAccountKey) {
            showPersonaRoot()
            return
        }
        if page == .publicPersona,
           let targetAccountKey,
           AccountSessionCenter.shared.canOpenPublicPersona(accountKey: targetAccountKey) == false {
            MorviToastView.show("This profile is unavailable.", in: view)
            return
        }
        if let restrictionSubjectKey {
            RouteContextStore.setTargetAccountKey(restrictionSubjectKey)
        }
        guard navigationController?.topViewController === self else { return }
        isOpeningSecondaryPage = true
        navigationController?.pushViewController(RouteFactory.controller(for: page), animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.isOpeningSecondaryPage = false
        }
    }

    private func showOverlay(_ page: ScenePage, restrictionSubjectKey: String? = nil) {
        if AccountSessionCenter.shared.requiresSignedInGate(for: page),
           AccountSessionCenter.shared.isSignedIn == false {
            showOverlay(.accessGate)
            return
        }
        if let restrictionSubjectKey {
            RouteContextStore.setTargetAccountKey(restrictionSubjectKey)
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
        overlayView.didRequestSubjectPage = { [weak self] targetPage, subjectKey in
            self?.show(targetPage, restrictionSubjectKey: subjectKey)
        }
        overlayView.didRequestSubjectOverlayPage = { [weak self] targetPage, subjectKey in
            self?.showOverlay(targetPage, restrictionSubjectKey: subjectKey)
        }
        overlayView.didCompleteMoodEntry = { [weak self] in
            self?.dismissActiveOverlay()
            if self?.currentPage == .weeklyFeeling {
                self?.renderCurrentPage()
            }
        }
        if page == .profileEditor {
            activeProfileEditOverlayView = overlayView
            overlayView.didRequestProfileAvatarSelection = { [weak self, weak overlayView] in
                guard let overlayView else { return }
                self?.chooseProfileEditAvatar(from: overlayView)
            }
            overlayView.didSubmitProfileEdit = { [weak self, weak overlayView] draft in
                guard let overlayView else { return }
                self?.submitProfileEdit(draft, overlayView: overlayView)
            }
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
        activeProfileEditOverlayView = nil
    }

    private func chooseProfileEditAvatar(from overlayView: ReferenceCanvasView) {
        view.endEditing(true)
        overlayView.showBlockingProgress()
        handleProfilePhotoLibraryStatus(
            PHPhotoLibrary.authorizationStatus(for: .readWrite),
            overlayView: overlayView
        )
    }

    private func handleProfilePhotoLibraryStatus(
        _ status: PHAuthorizationStatus,
        overlayView: ReferenceCanvasView
    ) {
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self, weak overlayView] updatedStatus in
                DispatchQueue.main.async {
                    guard let overlayView else { return }
                    self?.handleProfilePhotoLibraryStatus(updatedStatus, overlayView: overlayView)
                }
            }
        case .authorized, .limited:
            presentProfilePhotoPicker(from: overlayView)
        default:
            overlayView.hideBlockingProgress { [weak self] in
                self?.showProfilePhotoPermissionGuide()
            }
        }
    }

    private func presentProfilePhotoPicker(from overlayView: ReferenceCanvasView) {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true) {
            overlayView.hideBlockingProgress()
        }
    }

    private func showProfilePhotoPermissionGuide() {
        let alertController = UIAlertController(
            title: nil,
            message: "Please allow photo access in Settings.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alertController.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(settingsURL)
        })
        present(alertController, animated: true)
    }

    private func submitProfileEdit(
        _ draft: ReferenceCanvasView.ProfileEditDraft,
        overlayView: ReferenceCanvasView
    ) {
        let displayName = draft.displayNameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard displayName.isEmpty == false else {
            MorviToastView.show("Please enter username.", in: view)
            return
        }
        guard let avatarAsset = draft.avatarAsset,
              avatarAsset.isEmpty == false,
              avatarAsset != "default_avatar" else {
            MorviToastView.show("Please select avatar.", in: view)
            return
        }

        overlayView.showBlockingProgress()
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                try AccountSessionCenter.shared.updateActiveEditableInfo(
                    displayName: displayName,
                    avatarAsset: avatarAsset
                )
            }
            DispatchQueue.main.async { [weak self, weak overlayView] in
                guard let self,
                      let overlayView else { return }
                overlayView.hideBlockingProgress {
                    switch result {
                    case .success:
                        overlayView.removeFromSuperview()
                        self.activeProfileEditOverlayView = nil
                        self.renderCurrentPage()
                        MorviToastView.show("Profile updated.", in: self.view)
                    case .failure:
                        MorviToastView.show("Profile update failed.", in: self.view)
                    }
                }
            }
        }
    }

    private func storeProfileAvatarImage(_ image: UIImage) throws -> String {
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
            .appendingPathComponent("Avatars", isDirectory: true)
        try FileManager.default.createDirectory(
            at: targetDirectory,
            withIntermediateDirectories: true
        )
        let fileName = "avatar-\(UUID().uuidString.lowercased()).jpg"
        let fileURL = targetDirectory.appendingPathComponent(fileName)
        try imageData.write(to: fileURL, options: .atomic)
        return "local-avatar/\(fileName)"
    }

    @objc private func handleTopLeadingTap() {
    }

    @objc private func handleTopTrailingTap() {
        if currentPage == .persona {
            show(.settings)
        }
    }
}

extension RootTabsController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let overlayView = activeProfileEditOverlayView else { return }
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else {
            return
        }

        overlayView.showBlockingProgress()
        provider.loadObject(ofClass: UIImage.self) { [weak self, weak overlayView] object, _ in
            guard let self,
                  let overlayView else { return }
            let loadedImage = object as? UIImage
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result { () -> (UIImage, String) in
                    guard let loadedImage else {
                        throw CocoaError(.fileReadUnknown)
                    }
                    let asset = try self.storeProfileAvatarImage(loadedImage)
                    return (loadedImage, asset)
                }
                DispatchQueue.main.async {
                    overlayView.hideBlockingProgress {
                        switch result {
                        case let .success((image, asset)):
                            overlayView.updateProfileEditorAvatar(image: image, asset: asset)
                        case .failure:
                            MorviToastView.show("Avatar upload failed.", in: self.view)
                        }
                    }
                }
            }
        }
    }
}

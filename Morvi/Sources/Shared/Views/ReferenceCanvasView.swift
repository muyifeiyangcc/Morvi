import UIKit
import WebKit
import CoreImage
import CoreImage.CIFilterBuiltins
import AVFoundation
import ImageIO

private final class PlayerLayerHostView: UIView {
    private let playerLayer: AVPlayerLayer

    init(playerLayer: AVPlayerLayer) {
        self.playerLayer = playerLayer
        super.init(frame: .zero)
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

final class ReferenceCanvasView: UIView {
    struct WorkUploadDraft {
        let titleText: String
        let detailText: String
        let themeTitles: [String]
        let mediaKind: Int
        let mediaAsset: String
        let coverAsset: String
        let mediaSize: CGSize
        let durationSeconds: TimeInterval?
    }

    struct ProfileEditDraft {
        let displayNameText: String
        let avatarAsset: String?
    }

    private static let assistantUnlockCost = 200
    private static let assistantThreadKind = 2
    private static let assistantLocalSpeakerKind = 0
    private static let assistantRemoteSpeakerKind = 1
    private static let assistantTextEntryKind = 0
    private static let assistantCompleteState = 0
    private static let assistantPendingState = 1
    private static let assistantThinkingText = "Thinking..."
    private static let floatingDockClearance: CGFloat = 114
    private static let userAgreementURLString = "https://sites.google.com/view/morvi-web/home/morvi-user-agreement"
    private static let privacyPolicyURLString = "https://sites.google.com/view/morvi-web/home/morvis-privacy-policy"
    private static let visualAssetCache = NSCache<NSString, UIImage>()
    private static var agreementConsentAccepted = true
    private static let agreementConsentDidChangeNotification = Notification.Name("Morvi.agreementConsentDidChange")
    private static let ciContext = CIContext(options: nil)
    private static let largeFieldPlaceholderTag = 7801

    static var hasAcceptedAgreementConsent: Bool {
        agreementConsentAccepted
    }

    private let page: ScenePage
    private let selectedMoodIndex: Int
    var didTapOutsideContent: (() -> Void)?
    var didRequestPage: ((ScenePage) -> Void)?
    var didRequestSubjectPage: ((ScenePage, String?) -> Void)?
    var didRequestOverlayPage: ((ScenePage) -> Void)?
    var didRequestSubjectOverlayPage: ((ScenePage, String?) -> Void)?
    var didRequestDialogueImageSelection: (() -> Void)?
    var didRequestPrimaryAction: (() -> Void)?
    var didRequestUploadMediaSelection: (() -> Void)?
    var didSubmitUploadWork: ((WorkUploadDraft) -> Void)?
    var didRequestProfileAvatarSelection: (() -> Void)?
    var didSubmitProfileEdit: ((ProfileEditDraft) -> Void)?
    var didChooseMood: ((Int) -> Void)?
    var didCompleteMoodEntry: (() -> Void)?
    var didCompleteSignOut: (() -> Void)?
    var didCompleteAccountRemoval: (() -> Void)?
    private weak var activeLayoutContainer: UIView?
    private weak var keyboardAwareScrollView: UIScrollView?
    private weak var keyboardAvoidanceInputView: UIView?
    private weak var keyboardSyncedDialogueFlowListView: DialogueFlowListView?
    private weak var dialogueFlowListView: DialogueFlowListView?
    private weak var dialogueCardListView: DialogueCardListView?
    private weak var overlayContentView: UIView?
    private weak var registrationAvatarImageView: UIImageView?
    private weak var uploadTitleField: UITextField?
    private weak var uploadDetailTextView: UITextView?
    private weak var uploadThemeFlowView: UploadThemeFlowView?
    private weak var uploadThemeEntryBar: UIView?
    private weak var uploadThemeEntryField: UITextField?
    private weak var uploadMediaPreviewImageView: UIImageView?
    private weak var uploadMediaIconView: UIImageView?
    private weak var uploadMediaPlayIconView: UIImageView?
    private weak var profileEditAvatarImageView: UIImageView?
    private weak var profileEditNameField: UITextField?
    private weak var feelingInputTextView: UITextView?
    private var uploadMediaAsset: String?
    private var uploadCoverAsset: String?
    private var uploadMediaSize: CGSize?
    private var uploadMediaKind = 0
    private var uploadDurationSeconds: TimeInterval?
    private var profileEditAvatarAsset: String?
    private var keyboardAvoidanceBottomConstraint: NSLayoutConstraint?
    private var keyboardAvoidanceBaseBottomConstant: CGFloat = 0
    private var uploadThemeEntryBottomConstraint: NSLayoutConstraint?
    private var uploadThemeHeightConstraint: NSLayoutConstraint?
    private var uploadFormHeightConstraint: NSLayoutConstraint?
    private var dialogueFlowBottomConstraint: NSLayoutConstraint?
    private var dialogueFlowBottomBaseConstant: CGFloat = 0
    private var keyboardBaseContentInset: UIEdgeInsets?
    private var keyboardBaseIndicatorInsets: UIEdgeInsets?
    private var keyboardBaseContentOffset: CGPoint?
    private var keyboardIsVisible = false
    private let creativeRepository = SQLiteCreativeWorkRepository()
    private let moodRepository = SQLiteMoodEntryRepository()
    private let replyListDataSource = ReplyListDataSource()
    private let dialogueRepository = SQLiteDialogueRepository()
    private weak var agreementConsentIconView: UIImageView?
    private weak var progressOverlayView: MorviProgressOverlayView?
    private weak var assistantInputField: UITextField?
    private weak var directDialogueInputField: UITextField?
    private var galleryPreviewPlayer: AVPlayer?
    private weak var voiceDurationLabel: UILabel?
    private weak var activeVoiceRippleView: VoiceRippleView?
    private weak var activeVoiceIconView: UIView?
    private var voiceElapsedSeconds = 0
    private var voiceTimer: Timer?
    private var voiceRecorder: AVAudioRecorder?
    private var activeVoiceAsset: String?
    private var personaMediaFrames: [CGRect] = []
    private var personaMediaTargets: [(frame: CGRect, workKey: String, accountKey: String)] = []
    private var personaBackdropBaseHeight: CGFloat = 0
    private var personaBackdropHeightConstraint: NSLayoutConstraint?
    private var settingsTapActions: [(frame: CGRect, action: () -> Void)] = []
    private var animatedAssistantEntryKeys: Set<String> = []
    private let restrictionSubjectKey: String?
    private let showsAgreementActionArea: Bool
    private var selectedSafetyReasonIndex = 0
    private weak var replyInputField: UITextField?

    init(
        page: ScenePage,
        selectedMoodIndex: Int = 0,
        restrictionSubjectKey: String? = nil,
        showsAgreementActionArea: Bool = false
    ) {
        self.page = page
        self.selectedMoodIndex = selectedMoodIndex
        self.restrictionSubjectKey = restrictionSubjectKey
        self.showsAgreementActionArea = showsAgreementActionArea
        super.init(frame: .zero)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAgreementConsentDidChange),
            name: Self.agreementConsentDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCreativeWorkActivityDidChange),
            name: SQLiteCreativeWorkRepository.activityDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDialogueRepositoryDidChange),
            name: SQLiteDialogueRepository.didChangeNotification,
            object: nil
        )
        clipsToBounds = true
        backgroundColor = usesDecorativeBackground ? .clear : .white
        render()
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private var usesDecorativeBackground: Bool {
        switch page {
        case .entry, .signIn, .signUp, .resetAccess, .agreement, .personalDetail, .home, .discover, .wallet, .assistantDialogue, .settings, .restrictedList, .outboundConnectionRoster, .inboundConnectionRoster:
            return true
        default:
            return false
        }
    }

    private var adaptiveLayoutWidth: CGFloat {
        if bounds.width > 0 {
            return bounds.width
        }
        let screenBounds = UIScreen.main.bounds
        let portraitWidth = min(screenBounds.width, screenBounds.height)
        return portraitWidth > 0 ? portraitWidth : 375
    }

    private var adaptiveLayoutHeight: CGFloat {
        if bounds.height > 0 {
            return bounds.height
        }
        let screenBounds = UIScreen.main.bounds
        let portraitHeight = max(screenBounds.width, screenBounds.height)
        return portraitHeight > 0 ? portraitHeight : 812
    }

    private func adaptivePairLayout(leftInset: CGFloat = 20, rightInset: CGFloat = 20, gap: CGFloat = 12) -> (width: CGFloat, secondLeft: CGFloat) {
        let availableWidth = max(0, adaptiveLayoutWidth - leftInset - rightInset - gap)
        let itemWidth = floor(availableWidth / 2)
        return (itemWidth, leftInset + itemWidth + gap)
    }

    private func currentStatusBarHeight() -> CGFloat {
        let rawHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? safeAreaInsets.top
        if rawHeight > 0 {
            return rawHeight > 24 ? 44 : 20
        }
        return 44
    }

    private func fillsReferenceTrailing(_ frame: CGRect, trailingInset: CGFloat = 20) -> Bool {
        frame.minX <= trailingInset && frame.width >= 300
    }

    private func render() {
        switch page {
        case .entry:
            renderEntry()
        case .signIn:
            renderSignIn()
        case .signUp:
            renderSignUp()
        case .resetAccess:
            renderResetAccess()
        case .home:
            renderHome()
        case .discover:
            renderDiscover()
        case .dialogueList:
            renderDialogueList()
        case .persona:
            renderPersona()
        case .settings:
            renderSettings()
        case .wallet:
            renderWallet()
        case .directDialogue:
            renderConversation(title: "Victoria", mode: .text)
        case .voiceDialogue:
            renderConversation(title: "Victoria", mode: .voice)
        case .assistantDialogue:
            renderAssistantDialogue()
        case .galleryDetail:
            renderGalleryDetail()
        case .galleryPreview:
            renderGalleryPreview()
        case .publicPersona:
            renderPersonaDetail()
        case .personalDetail:
            renderPersonalDetail()
        case .profileEditor:
            renderProfileEditor()
        case .uploadEmpty:
            renderUpload(filled: false)
        case .uploadFilled:
            renderUpload(filled: true)
        case .feelingEditor:
            renderFeelingEditor()
        case .weeklyFeeling:
            renderWeeklyFeeling()
        case .repliesPanel:
            renderRepliesPanel()
        case .reportPanel:
            renderReportPanel()
        case .restrictPanel:
            renderRestrictPanel()
        case .restrictedList:
            renderRestrictedList()
        case .outboundConnectionRoster:
            renderConnectionRoster(kind: .outbound)
        case .inboundConnectionRoster:
            renderConnectionRoster(kind: .inbound)
        case .agreement:
            renderAgreement()
        case .accessGate:
            renderConfirmCard(title: "Log in", text: "To ensure the normal operation\nof the function, please log in to\nyour account first.", confirm: "Log in", portrait: false, showsWordmark: true)
        case .spendConfirm:
            renderConfirmCard(title: nil, text: "Are you sure you want to spend\n200 diamonds to unlock the AI\nfunction?", confirm: "Sure", portrait: false)
        case .creditShortage:
            renderConfirmCard(title: nil, text: "Unfortunately, your account\nbalance is insufficient. Please go\nto recharge.", confirm: "Recharge", portrait: false)
        case .restrictConfirm:
            let profile = resolvedRestrictionProfile()
            renderConfirmCard(
                title: profile.displayName,
                text: "Are you sure you want to block\nthis user? After blocking, no\nrelated content will be received.",
                confirm: "Sure",
                portrait: true,
                portraitAvatarAsset: profile.avatarAsset
            )
        case .exitConfirm:
            renderConfirmCard(title: nil, text: "Are you sure you want to delete\nthis account? All data will be\ncleared after deletion and cannot\nbe recovered.", confirm: "Sure", portrait: false)
        case .signOutConfirm:
            renderConfirmCard(title: nil, text: "Are you sure you want to log\nout of this account?", confirm: "Sure", portrait: false)
        }
    }

    private func renderEntry() {
        let consentLine = addAgreementConsentLine(bottom: 51)
        let scrollView = CancelFriendlyScrollView()
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .clear
        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: consentLine.topAnchor)
        ])

        let scrollContent = UIView()
        scrollContent.backgroundColor = .clear
        scrollView.addSubview(scrollContent)
        scrollContent.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollContent.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContent.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContent.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            scrollContent.heightAnchor.constraint(equalToConstant: 700)
        ])

        activeLayoutContainer = scrollContent
        addLogo(top: 168)
        addText("Morvi", size: 38, weight: .black, top: 307, centered: true)
        addButton("Login by email", top: 417, filled: false, usesOneFont: true)
        addButton("I'm new", top: 486, filled: true, usesOneFont: true)
        addEntrySignUpPrompt(top: 568)
        addText("Guest login", size: 12, weight: .regular, top: 608, centered: true, color: .lightGray)
        addAppleLoginCircle(top: 640)
        activeLayoutContainer = nil
    }

    private func renderHome() {
        let headerContent = AccountSessionCenter.shared.activeHeaderContent()
        let displayName = headerContent?.displayName ?? "Please log in first"
        let avatarImage = resolveAccountAvatar(headerContent?.avatarAsset)
            ?? UIImage(named: "default_avatar")
        let greetingText = headerContent == nil
            ? "Hello!\nDid everything go\nsmoothly today?"
            : "Hello, \(displayName)!\nDid everything go\nsmoothly today?"
        let scrollView = CancelFriendlyScrollView()
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
        scrollView.contentInset.bottom = 104
        scrollView.verticalScrollIndicatorInsets.bottom = 104
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .clear
        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let scrollContent = UIView()
        scrollContent.backgroundColor = .clear
        scrollView.addSubview(scrollContent)
        scrollContent.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollContent.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContent.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContent.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            scrollContent.heightAnchor.constraint(equalToConstant: 720)
        ])

        activeLayoutContainer = scrollContent
        addProfileAvatar(
            image: avatarImage,
            top: 60,
            left: 20,
            size: 58,
            backgroundColor: UIColor(white: 0.8, alpha: 1),
            showsBorder: false,
            showsShadow: false
        )
        addText("Welcome back", size: 17, weight: .black, top: 68, left: 96)
        addText(displayName, size: 16, weight: .regular, top: 98, left: 96)
        if headerContent == nil {
            addHomeActionButton(frame: CGRect(x: 0, y: 48, width: 260, height: 84)) { [weak self] in
                self?.didRequestOverlayPage?(.accessGate)
            }
        }
        addText(greetingText, size: 30, weight: .regular, top: 146, left: 20)
        addText("Choose your mood today", size: 20, weight: .bold, top: 303, left: 20)
        addMoodRow(top: 340)
        addButton(
            "Save your feelings",
            top: 458,
            filled: true,
            cornerRadius: 12,
            shadowOpacity: 0,
            bottomPlateHeight: 3
        )
        let featureLayout = adaptivePairLayout(gap: 12)
        addFeatureCard(title: "Discover", top: 536, left: 20, width: featureLayout.width, tint: .forest, imageName: "home_discover")
        addFeatureCard(title: "Recot Bot", top: 536, left: featureLayout.secondLeft, width: featureLayout.width, tint: .night, imageName: "home_recot_bot")
        addHomeActionButton(frame: CGRect(x: 20, y: 458, width: 335, height: 52)) { [weak self] in
            self?.didRequestOverlayPage?(.feelingEditor)
        }
        addHomeActionButton(frame: CGRect(x: 20, y: 536, width: featureLayout.width, height: 145)) { [weak self] in
            self?.didRequestPage?(.discover)
        }
        addHomeActionButton(frame: CGRect(x: featureLayout.secondLeft, y: 536, width: featureLayout.width, height: 145)) { [weak self] in
            self?.requestAssistantEntry()
        }
        activeLayoutContainer = nil
    }

    private func requestAssistantEntry() {
        guard AccountSessionCenter.shared.isSignedIn else {
            didRequestOverlayPage?(.accessGate)
            return
        }
        didRequestOverlayPage?(.spendConfirm)
    }

    private func renderDiscover() {
        addTopTitle("Discover")
        let stripEntries = discoverStripEntries()
        let workEntries = discoverWorkEntries()
        let cardGap: CGFloat = 28
        let cardHeight: CGFloat = 444
        let firstCardTop: CGFloat = 126
        let contentHeight = max(
            1090,
            firstCardTop + CGFloat(max(workEntries.count, 1)) * cardHeight + CGFloat(max(workEntries.count - 1, 0)) * cardGap + 40
        )
        let scrollView = CancelFriendlyScrollView()
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .clear
        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 120),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let scrollContent = UIView()
        scrollContent.backgroundColor = .clear
        scrollView.addSubview(scrollContent)
        scrollContent.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollContent.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContent.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContent.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            scrollContent.heightAnchor.constraint(equalToConstant: contentHeight)
        ])

        activeLayoutContainer = scrollContent
        addStoryStrip(top: 22, entries: stripEntries)
        if workEntries.isEmpty {
            addFeedCard(
                item: DiscoveryWorkEntry(
                    stableKey: "fallback-work",
                    accountKey: "acct-local-victoria",
                    displayName: "Victoria",
                    avatarAsset: "builtin_avatar_victoria",
                    coverAssetForAccount: "builtin_avatar_victoria",
                    title: "Moments Matter",
                    bodyText: "Capturing today's happiness. Saving it for tomorrow's memories.",
                    mediaKind: 1,
                    mediaAsset: "builtin_victoria.mp4",
                    coverAsset: "discover_feed_cover",
                    mediaWidth: nil,
                    mediaHeight: nil,
                    themes: tagTexts,
                    reactionCount: 666,
                    replyCount: 777
                ),
                top: firstCardTop,
                tint: .coast
            )
        } else {
            for (index, item) in workEntries.enumerated() {
                let top = firstCardTop + CGFloat(index) * (cardHeight + cardGap)
                addFeedCard(item: item, top: top, tint: index.isMultiple(of: 2) ? .coast : .sky)
            }
        }
        activeLayoutContainer = nil
    }

    private func renderDialogueList() {
        addDecorativeBackground()
        addTopTitle("Chat")
        let statusBarHeight = currentStatusBarHeight()
        let listView = DialogueCardListView(entries: dialogueCardEntries())
        dialogueCardListView = listView
        listView.didSelectEntry = { [weak self] entry in
            RouteContextStore.setTargetDialogueThread(key: entry.stableKey, title: entry.name)
            RouteContextStore.setTargetAccountKey(entry.counterpartAccountKey)
            self?.didRequestPage?(.directDialogue)
        }
        addSubview(listView)
        listView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            listView.leadingAnchor.constraint(equalTo: leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: trailingAnchor),
            listView.topAnchor.constraint(equalTo: topAnchor, constant: statusBarHeight + 76),
            listView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @objc private func handleDialogueRepositoryDidChange() {
        guard page == .dialogueList else { return }
        DispatchQueue.main.async { [weak self] in
            self?.dialogueCardListView?.configure(entries: self?.dialogueCardEntries() ?? [])
        }
    }

    private func dialogueCardEntries() -> [DialogueCardEntry] {
        guard let accountKey = AccountSessionCenter.shared.activeAccountKey,
              let records = try? dialogueRepository.summaries(accountKey: accountKey) else {
            return []
        }
        return records.enumerated().map { index, record in
            DialogueCardEntry(
                stableKey: record.stableKey,
                counterpartAccountKey: record.counterpartAccountKey,
                name: record.title,
                preview: record.latestPreviewText,
                portraitImage: resolveAccountAvatar(record.avatarAsset),
                threadKind: record.threadKind,
                usesDarkStyle: index % 3 != 0
            )
        }
    }

    private func renderPersona() {
        let accountKey = AccountSessionCenter.shared.activeAccountKey
        let detail = accountKey.map {
            resolvedPersonaDetail(accountKey: $0, fallbackName: "Please log in first")
        } ?? PersonaDetailEntry(
            accountKey: "",
            displayName: "Please log in first",
            avatarAsset: "default_avatar",
            coverAsset: "image.png",
            worksText: "0",
            followersText: "0",
            followingText: "0"
        )
        let workEntries = accountKey.map { resolvedPersonaWorks(accountKey: $0) } ?? []
        addPersonaRootGradient()
        addPersonaBackdrop(imageName: personaBackdropAssetName(for: detail))
        let scrollView = CancelFriendlyScrollView()
        scrollView.delegate = self
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = scrollView.contentInset
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .clear
        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let scrollContent = UIView()
        scrollContent.backgroundColor = .clear
        scrollView.addSubview(scrollContent)
        scrollContent.translatesAutoresizingMaskIntoConstraints = false
        activeLayoutContainer = scrollContent

        let cellTop: CGFloat = 348
        let cellGap: CGFloat = 15
        let waterfallLayout = adaptivePairLayout(gap: cellGap)
        let cellWidth = waterfallLayout.width
        var columnBottoms = [cellTop, cellTop]
        let columnLefts: [CGFloat] = [20, waterfallLayout.secondLeft]
        let cellPlacements = workEntries.enumerated().map { index, item -> (top: CGFloat, left: CGFloat, width: CGFloat, height: CGFloat, item: DiscoveryWorkEntry, tint: MediaTint) in
            let columnIndex = waterfallColumnIndex(for: columnBottoms)
            let left = columnLefts[columnIndex]
            let width = cellWidth
            let height = proportionalCellHeight(for: item, width: width)
            let placement = (
                top: columnBottoms[columnIndex],
                left: left,
                width: width,
                height: height,
                item: item,
                tint: index.isMultiple(of: 2) ? MediaTint.coast : MediaTint.night
            )
            columnBottoms[columnIndex] += height + cellGap
            return placement
        }
        personaMediaFrames = cellPlacements.map {
            CGRect(x: $0.left, y: $0.top, width: $0.width, height: $0.height)
        }
        personaMediaTargets = cellPlacements.map {
            (CGRect(x: $0.left, y: $0.top, width: $0.width, height: $0.height), $0.item.stableKey, $0.item.accountKey)
        }
        let contentHeight = max(
            adaptiveLayoutHeight + Self.floatingDockClearance,
            (columnBottoms.max() ?? adaptiveLayoutHeight) - cellGap + Self.floatingDockClearance
        )
        NSLayoutConstraint.activate([
            scrollContent.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContent.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContent.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            scrollContent.heightAnchor.constraint(equalToConstant: contentHeight)
        ])

        let baseHeight = contentHeight - 228
        let base = addPanel(top: 228, left: 0, width: 375, height: baseHeight, alpha: 1, trailing: 0)
        addThemeGradientBackground(
            to: base,
            width: adaptiveLayoutWidth,
            height: baseHeight,
            cornerRadius: 20,
            maskedCorners: [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        )
        base.backgroundColor = .clear
        base.layer.borderWidth = 0
        base.layer.shadowOpacity = 0
        base.layer.cornerRadius = 20
        base.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        addProfileAvatar(image: resolveAccountAvatar(detail.avatarAsset), top: 198, left: 36, size: 74, showsBorder: false, showsShadow: false)
        addText(detail.displayName, size: 20, weight: .medium, top: 275, left: 36)
        addPersonaMetricLine(
            top: 311,
            left: 20,
            worksText: detail.worksText,
            followersText: detail.followersText,
            followingText: detail.followingText
        )
        addAssetIcon("persona_settings_icon", top: 247, left: 214, size: 30)
        addPersonaSettingsAction(top: 240, left: 204)
        addPersonaEditAction(top: 244, left: 256)
        cellPlacements.forEach { placement in
            addMediaBlock(
                top: placement.top,
                left: placement.left,
                width: placement.width,
                height: placement.height,
                title: "",
                tint: placement.tint,
                action: placement.item.mediaKind == 1 ? .play : .none,
                imageName: placement.item.coverAsset,
                playIconName: "persona_media_play_icon",
                playIconSize: 28,
                shadowOpacity: 0
            )
        }
        if workEntries.isEmpty {
            addPersonaEmptyState(top: cellTop, in: scrollContent)
        }
        addPersonaMediaContainerSelection(to: scrollContent)
        activeLayoutContainer = nil
    }

    private func resolvedPersonaDetail(accountKey: String, fallbackName: String) -> PersonaDetailEntry {
        if let detail = try? creativeRepository.personaDetail(accountKey: accountKey) {
            return detail
        }
        return PersonaDetailEntry(
            accountKey: accountKey,
            displayName: fallbackName,
            avatarAsset: "default_avatar",
            coverAsset: "discover_feed_cover",
            worksText: "0",
            followersText: "0",
            followingText: "0"
        )
    }

    private func resolvedPersonaWorks(accountKey: String) -> [DiscoveryWorkEntry] {
        (try? creativeRepository.works(ownerAccountKey: accountKey, limit: 30)) ?? []
    }

    private func addPersonaEmptyState(top: CGFloat, in container: UIView) {
        let emptyStateView = EmptyStateView(copy: "No works yet")
        container.addSubview(emptyStateView)
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            emptyStateView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            emptyStateView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            emptyStateView.topAnchor.constraint(equalTo: container.topAnchor, constant: top),
            emptyStateView.heightAnchor.constraint(equalToConstant: 250)
        ])
    }

    private func proportionalCellHeight(for item: DiscoveryWorkEntry, width: CGFloat) -> CGFloat {
        if let mediaWidth = item.mediaWidth, let mediaHeight = item.mediaHeight, mediaWidth > 0 {
            return ceil(width * CGFloat(mediaHeight / mediaWidth))
        }
        let imageSize = resolveVisualAsset(item.coverAsset)?.size ?? .zero
        return imageSize.width > 0 ? ceil(width * imageSize.height / imageSize.width) : width
    }

    private func waterfallColumnIndex(for bottomEdges: [CGFloat]) -> Int {
        guard bottomEdges.count >= 2 else { return 0 }
        if abs(bottomEdges[0] - bottomEdges[1]) <= 0.5 {
            return 0
        }
        return bottomEdges[0] < bottomEdges[1] ? 0 : 1
    }

    private func renderConversation(title: String, mode: ConversationMode) {
        addDecorativeBackground()
        addTopTitle(title)
        switch mode {
        case .text:
            let dockView = addDialogueInputDock { [weak self] in
                self?.submitDirectDialogueText()
            }
            addDialogueFlowList(
                top: 136,
                bottomAnchor: dockView.topAnchor,
                bottomSpacing: 8,
                entries: directDialogueEntries()
            )
            bringSubviewToFront(dockView)
        case .voice:
            addDialogueFlowList(top: 136, bottom: 696)
            addVoiceClip(top: 552)
            let panel = addPanel(top: 586, left: 0, width: 375, height: 226, alpha: 1, trailing: 0)
            panel.backgroundColor = UIColor(red: 1.0, green: 0.76, blue: 0.02, alpha: 1)
            panel.layer.borderWidth = 0
            addText("▦", size: 24, weight: .regular, top: 606, left: 20)
            addCircle(text: "♬", top: 650, left: 138, size: 100, color: UIColor(red: 0.82, green: 1, blue: 0.78, alpha: 1))
        }
    }

    private func addDecorativeBackground() {
        let backgroundView = DecorativeGradientView()
        insertSubview(backgroundView, at: 0)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func addDialogueInputDock(showsAccessoryButtons: Bool = true, onSubmit: (() -> Void)? = nil) -> UIView {
        let dockView = UIView()
        dockView.backgroundColor = .clear
        addSubview(dockView)
        dockView.translatesAutoresizingMaskIntoConstraints = false
        let bottomConstraint = dockView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -27)
        NSLayoutConstraint.activate([
            dockView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dockView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dockView.heightAnchor.constraint(equalToConstant: showsAccessoryButtons ? 81 : 45),
            bottomConstraint
        ])

        let voiceButton = UIButton(type: .custom)
        voiceButton.setImage(UIImage(named: "input_voice_icon"), for: .normal)
        voiceButton.imageView?.contentMode = .scaleAspectFit
        voiceButton.addTarget(self, action: #selector(requestVoiceInputPanel), for: .touchUpInside)
        dockView.addSubview(voiceButton)
        voiceButton.translatesAutoresizingMaskIntoConstraints = false

        let photoButton = UIButton(type: .custom)
        photoButton.setImage(UIImage(named: "input_photo_icon"), for: .normal)
        photoButton.imageView?.contentMode = .scaleAspectFit
        photoButton.addTarget(self, action: #selector(requestDialogueImageSelection), for: .touchUpInside)
        dockView.addSubview(photoButton)
        photoButton.translatesAutoresizingMaskIntoConstraints = false

        let inputBar = addInputBar(
            bottom: 0,
            text: "Say something",
            trailing: "➤",
            in: dockView,
            textFieldHandler: { [weak self] textField in
                if showsAccessoryButtons {
                    self?.directDialogueInputField = textField
                    textField.addTarget(
                        self,
                        action: #selector(ReferenceCanvasView.submitDirectDialogueText),
                        for: .editingDidEndOnExit
                    )
                } else {
                    self?.assistantInputField = textField
                    textField.addTarget(
                        self,
                        action: #selector(ReferenceCanvasView.submitAssistantText),
                        for: .editingDidEndOnExit
                    )
                }
            },
            actionHandler: onSubmit
        )
        if showsAccessoryButtons {
            NSLayoutConstraint.activate([
                voiceButton.leadingAnchor.constraint(equalTo: dockView.leadingAnchor, constant: 24),
                voiceButton.topAnchor.constraint(equalTo: dockView.topAnchor),
                voiceButton.widthAnchor.constraint(equalToConstant: 24),
                voiceButton.heightAnchor.constraint(equalToConstant: 24),

                photoButton.leadingAnchor.constraint(equalTo: voiceButton.trailingAnchor, constant: 12),
                photoButton.centerYAnchor.constraint(equalTo: voiceButton.centerYAnchor),
                photoButton.widthAnchor.constraint(equalToConstant: 24),
                photoButton.heightAnchor.constraint(equalToConstant: 24),

                inputBar.topAnchor.constraint(equalTo: dockView.topAnchor, constant: 36)
            ])
        } else {
            voiceButton.removeFromSuperview()
            photoButton.removeFromSuperview()
            NSLayoutConstraint.activate([
                inputBar.topAnchor.constraint(equalTo: dockView.topAnchor)
            ])
        }
        keyboardAvoidanceInputView = dockView
        keyboardAvoidanceBottomConstraint = bottomConstraint
        keyboardAvoidanceBaseBottomConstant = -27
        installKeyboardAvoidance()
        installBlankAreaKeyboardDismissal()
        return dockView
    }

    @objc private func requestDialogueImageSelection() {
        didRequestDialogueImageSelection?()
    }

    @objc private func requestVoiceInputPanel() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            showVoiceInputPanel()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] isAllowed in
                DispatchQueue.main.async {
                    if isAllowed {
                        self?.showVoiceInputPanel()
                    } else {
                        self?.openMicrophoneSettingsGuide()
                    }
                }
            }
        case .denied, .restricted:
            openMicrophoneSettingsGuide()
        @unknown default:
            openMicrophoneSettingsGuide()
        }
    }

    private func openMicrophoneSettingsGuide() {
        MorviToastView.show("Please allow microphone access in Settings.", in: self)
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }

    @objc private func showVoiceInputPanel() {
        endEditing(true)
        viewWithTag(9206)?.removeFromSuperview()
        resetVoicePanelAvoidance(animated: false)

        let overlayView = UIControl()
        overlayView.tag = 9206
        overlayView.backgroundColor = .clear
        overlayView.addTarget(self, action: #selector(hideVoiceInputPanel), for: .touchUpInside)
        addSubview(overlayView)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            overlayView.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let panel = UIView()
        panel.backgroundColor = .clear
        panel.layer.cornerRadius = 18
        panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        panel.layer.masksToBounds = true
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(red: 235 / 255, green: 254 / 255, blue: 175 / 255, alpha: 1).cgColor,
            UIColor(red: 224 / 255, green: 251 / 255, blue: 252 / 255, alpha: 1).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 226)
        gradient.cornerRadius = 18
        panel.layer.insertSublayer(gradient, at: 0)
        overlayView.addSubview(panel)
        panel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: overlayView.bottomAnchor),
            panel.heightAnchor.constraint(equalToConstant: 226)
        ])

        let gridIcon = UIButton(type: .custom)
        gridIcon.setImage(UIImage(named: "voice_panel_grid"), for: .normal)
        gridIcon.imageView?.contentMode = .scaleAspectFit
        gridIcon.addTarget(self, action: #selector(hideVoiceInputPanel), for: .touchUpInside)
        panel.addSubview(gridIcon)
        gridIcon.translatesAutoresizingMaskIntoConstraints = false

        let rippleView = VoiceRippleView(colors: [
            UIColor(red: 0.56, green: 0.78, blue: 0.22, alpha: 1),
            UIColor(red: 0.56, green: 0.78, blue: 0.22, alpha: 1)
        ])
        panel.addSubview(rippleView)
        rippleView.translatesAutoresizingMaskIntoConstraints = false

        let microphoneIcon = UIImageView(image: UIImage(named: "voice_panel_microphone"))
        microphoneIcon.contentMode = .scaleAspectFit
        panel.addSubview(microphoneIcon)
        microphoneIcon.translatesAutoresizingMaskIntoConstraints = false

        microphoneIcon.isUserInteractionEnabled = true
        let pressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleVoiceCapturePress(_:)))
        pressGesture.minimumPressDuration = 0.08
        microphoneIcon.addGestureRecognizer(pressGesture)

        let durationLabel = UILabel()
        durationLabel.text = nil
        durationLabel.textColor = UIColor(red: 0.17, green: 0.22, blue: 0.18, alpha: 1)
        durationLabel.font = AppFont.source(16, weight: .medium)
        durationLabel.textAlignment = .center
        durationLabel.isHidden = true
        panel.addSubview(durationLabel)
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        voiceDurationLabel = durationLabel
        NSLayoutConstraint.activate([
            gridIcon.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 20),
            gridIcon.topAnchor.constraint(equalTo: panel.topAnchor, constant: 20),
            gridIcon.widthAnchor.constraint(equalToConstant: 24),
            gridIcon.heightAnchor.constraint(equalToConstant: 24),

            durationLabel.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            durationLabel.centerYAnchor.constraint(equalTo: gridIcon.centerYAnchor),

            rippleView.centerXAnchor.constraint(equalTo: microphoneIcon.centerXAnchor),
            rippleView.centerYAnchor.constraint(equalTo: microphoneIcon.centerYAnchor),
            rippleView.widthAnchor.constraint(equalToConstant: 160),
            rippleView.heightAnchor.constraint(equalToConstant: 160),

            microphoneIcon.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            microphoneIcon.topAnchor.constraint(equalTo: panel.topAnchor, constant: 57),
            microphoneIcon.widthAnchor.constraint(equalToConstant: 104),
            microphoneIcon.heightAnchor.constraint(equalToConstant: 104)
        ])
        applyVoicePanelAvoidance(panelHeight: 226, gap: 10)
    }

    @objc private func handleVoiceCapturePress(_ recognizer: UILongPressGestureRecognizer) {
        guard let microphoneIcon = recognizer.view else { return }
        let rippleView = microphoneIcon.superview?.subviews.first { $0 is VoiceRippleView } as? VoiceRippleView
        switch recognizer.state {
        case .began:
            guard startVoiceCapture(rippleView: rippleView, iconView: microphoneIcon) else { return }
            UIView.animate(withDuration: 0.16, delay: 0, options: [.curveEaseOut], animations: {
                microphoneIcon.transform = CGAffineTransform(scaleX: 80 / 104, y: 80 / 104)
            }, completion: { _ in
                guard self.activeVoiceIconView === microphoneIcon else { return }
                UIView.animate(
                    withDuration: 0.7,
                    delay: 0,
                    options: [.autoreverse, .repeat, .allowUserInteraction, .curveEaseInOut],
                    animations: {
                        microphoneIcon.transform = CGAffineTransform(scaleX: 88 / 104, y: 88 / 104)
                    }
                )
            })
        case .ended, .cancelled, .failed:
            let elapsedSeconds = voiceElapsedSeconds
            if voiceTimer != nil && elapsedSeconds < 1 {
                stopVoiceCapture(keepsRecordedAudio: false)
                MorviToastView.show("Audio is too short", in: self)
            } else if voiceTimer != nil {
                let audioAsset = stopVoiceCapture(keepsRecordedAudio: true)
                appendDirectDialogueAudio(durationSeconds: elapsedSeconds, audioAsset: audioAsset)
            } else {
                stopVoiceCapture(keepsRecordedAudio: false)
            }
        default:
            break
        }
    }

    private func startVoiceCapture(rippleView: VoiceRippleView?, iconView: UIView) -> Bool {
        guard startVoiceRecorder() else {
            MorviToastView.show("Recording failed", in: self)
            return false
        }
        stopVoiceTimer()
        activeVoiceRippleView = rippleView
        activeVoiceIconView = iconView
        voiceElapsedSeconds = 0
        voiceDurationLabel?.text = nil
        voiceDurationLabel?.isHidden = true
        rippleView?.startAnimating()
        voiceTimer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(handleVoiceTimerTick),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(voiceTimer!, forMode: .common)
        return true
    }

    @objc private func handleVoiceTimerTick() {
        voiceElapsedSeconds += 1
        voiceDurationLabel?.text = "\(voiceElapsedSeconds)s"
        voiceDurationLabel?.isHidden = false
        if voiceElapsedSeconds >= 60 {
            let audioAsset = stopVoiceCapture(keepsRecordedAudio: true)
            appendDirectDialogueAudio(durationSeconds: voiceElapsedSeconds, audioAsset: audioAsset)
        }
    }

    @discardableResult
    private func stopVoiceCapture(keepsRecordedAudio: Bool = false) -> String? {
        let audioAsset = finishVoiceRecorder(keepsFile: keepsRecordedAudio)
        stopVoiceTimer()
        activeVoiceRippleView?.stopAnimating()
        if let iconView = activeVoiceIconView {
            iconView.layer.removeAllAnimations()
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
                iconView.transform = .identity
            }
        }
        voiceDurationLabel?.isHidden = true
        activeVoiceRippleView = nil
        activeVoiceIconView = nil
        return audioAsset
    }

    private func stopVoiceTimer() {
        voiceTimer?.invalidate()
        voiceTimer = nil
    }

    private func startVoiceRecorder() -> Bool {
        finishVoiceRecorder(keepsFile: false)
        do {
            let capture = try makeVoiceCaptureDestination()
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker]
            )
            try AVAudioSession.sharedInstance().setActive(true)
            let recorder = try AVAudioRecorder(
                url: capture.url,
                settings: [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44_100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
            )
            recorder.prepareToRecord()
            guard recorder.record() else {
                try? FileManager.default.removeItem(at: capture.url)
                return false
            }
            voiceRecorder = recorder
            activeVoiceAsset = capture.asset
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    private func finishVoiceRecorder(keepsFile: Bool) -> String? {
        let audioAsset = activeVoiceAsset
        let audioURL = voiceRecorder?.url
        voiceRecorder?.stop()
        voiceRecorder = nil
        activeVoiceAsset = nil
        guard keepsFile else {
            if let audioURL {
                try? FileManager.default.removeItem(at: audioURL)
            }
            return nil
        }
        return audioAsset
    }

    private func makeVoiceCaptureDestination() throws -> (asset: String, url: URL) {
        let directory = try voiceCaptureDirectory()
        let fileName = "voice-\(UUID().uuidString.lowercased()).m4a"
        return ("local-voice/\(fileName)", directory.appendingPathComponent(fileName))
    }

    private func voiceCaptureDirectory() throws -> URL {
        let baseDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = baseDirectory
            .appendingPathComponent("Morvi", isDirectory: true)
            .appendingPathComponent("DialogueAudio", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    @objc private func hideVoiceInputPanel() {
        stopVoiceCapture(keepsRecordedAudio: false)
        viewWithTag(9206)?.removeFromSuperview()
        resetVoicePanelAvoidance(animated: true)
    }

    private func applyVoicePanelAvoidance(panelHeight: CGFloat, gap: CGFloat) {
        guard
            let bottomConstraint = dialogueFlowBottomConstraint,
            let listView = dialogueFlowListView
        else { return }
        layoutIfNeeded()
        let currentBottom = listView.convert(listView.bounds, to: self).maxY
        let panelTop = bounds.maxY - panelHeight
        let requiredOffset = max(0, currentBottom + gap - panelTop)
        bottomConstraint.constant = dialogueFlowBottomBaseConstant - requiredOffset
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut]) {
            self.layoutIfNeeded()
        } completion: { [weak self] _ in
            self?.dialogueFlowListView?.scrollToEnd(animated: true)
        }
    }

    private func resetVoicePanelAvoidance(animated: Bool) {
        guard let bottomConstraint = dialogueFlowBottomConstraint else { return }
        bottomConstraint.constant = dialogueFlowBottomBaseConstant
        let updates = {
            self.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut], animations: updates)
        } else {
            updates()
        }
    }

    private func addDialogueFlowList(
        top: CGFloat,
        bottom: CGFloat? = nil,
        bottomAnchor: NSLayoutYAxisAnchor? = nil,
        bottomSpacing: CGFloat = 0,
        entries: [DialogueFlowEntry]? = nil
    ) {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US_POSIX")
        let referenceDate = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        components.hour = 9
        components.minute = 41
        let eventDate = calendar.date(from: components) ?? referenceDate.addingTimeInterval(-2 * 60 * 60)
        let adjustedDate = eventDate < referenceDate ? eventDate : referenceDate.addingTimeInterval(-2 * 60 * 60)

        let listView = DialogueFlowListView()
        let defaultEntries: [DialogueFlowEntry] = [
            .moment(DialogueMomentFormatter.title(for: adjustedDate, referenceDate: referenceDate, calendar: calendar)),
            .phrase(text: "Nice to meet you, nice\nto meet you!", side: .local, showsAvatar: true),
            .audioClip(durationText: "5s", side: .remote, showsAvatar: true, audioAsset: nil),
            .portraitAsset(name: "profile_avatar", side: .local, showsAvatar: true),
            .phrase(text: "Nice to meet you.", side: .remote, showsAvatar: true),
            .audioClip(durationText: "5s", side: .local, showsAvatar: true, audioAsset: nil),
            .portraitAsset(name: "profile_avatar", side: .remote, showsAvatar: true)
        ]
        listView.didRequestImagePreview = { [weak self] assetName in
            self?.presentDialogueImagePreview(named: assetName)
        }
        listView.configure(entries: entries ?? defaultEntries)
        addSubview(listView)
        listView.translatesAutoresizingMaskIntoConstraints = false
        var constraints = [
            listView.leadingAnchor.constraint(equalTo: leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: trailingAnchor),
            listView.topAnchor.constraint(equalTo: topAnchor, constant: top)
        ]
        if let bottomAnchor {
            let bottomConstraint = listView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bottomSpacing)
            constraints.append(bottomConstraint)
            dialogueFlowListView = listView
            dialogueFlowBottomConstraint = bottomConstraint
            dialogueFlowBottomBaseConstant = -bottomSpacing
        } else if let bottom {
            constraints.append(listView.bottomAnchor.constraint(equalTo: topAnchor, constant: bottom))
        }
        NSLayoutConstraint.activate(constraints)
        if bottomAnchor != nil {
            keyboardSyncedDialogueFlowListView = listView
        }
    }

    private func presentDialogueImagePreview(named assetName: String) {
        let overlayView = MediaPreviewOverlayView(image: resolveVisualAsset(assetName))
        let hostView = owningController()?.view ?? self
        hostView.addSubview(overlayView)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            overlayView.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: hostView.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: hostView.bottomAnchor)
        ])
    }

    private func assistantDialogueEntries() -> [DialogueFlowEntry] {
        let records = storedAssistantEntries()
        let hasRemoteRecord = records.contains { $0.speakerKind == Self.assistantRemoteSpeakerKind }
        var entries: [DialogueFlowEntry] = [
            .wideAsset(
                name: "assistant_intro_card_background",
                title: "Hello!\nHow can I help you?",
                revealsCharacters: hasRemoteRecord == false,
                revealIdentifier: "assistant-intro"
            )
        ]
        entries.append(contentsOf: records.compactMap { record in
            guard let text = record.bodyText, text.isEmpty == false else { return nil }
            let isRemote = record.speakerKind == Self.assistantRemoteSpeakerKind
            let shouldReveal = isRemote && animatedAssistantEntryKeys.remove(record.stableKey) != nil
            return .roundedPhrase(
                text: text,
                side: isRemote ? .remote : .local,
                showsAvatar: false,
                revealsCharacters: shouldReveal,
                revealIdentifier: record.stableKey
            )
        })
        return entries
    }

    private func storedAssistantEntries() -> [DialogueEntryRecord] {
        guard let threadKey = activeAssistantThreadKey else { return [] }
        return (try? dialogueRepository.entries(threadKey: threadKey)) ?? []
    }

    private var activeAssistantThreadKey: String? {
        guard let accountKey = AccountSessionCenter.shared.activeAccountKey else { return nil }
        return "assistant-\(accountKey)"
    }

    private func reloadAssistantDialogueList() {
        dialogueFlowListView?.configure(entries: assistantDialogueEntries())
    }

    private func directDialogueEntries() -> [DialogueFlowEntry] {
        guard let threadKey = activeDirectDialogueThreadKey else { return [] }
        let records = (try? dialogueRepository.entries(threadKey: threadKey)) ?? []
        guard records.isEmpty == false else { return [] }
        var entries: [DialogueFlowEntry] = []
        if let firstDate = LocalDateText.date(from: records.first?.createdAt ?? "") {
            var calendar = Calendar.current
            calendar.locale = Locale(identifier: "en_US_POSIX")
            entries.append(.moment(DialogueMomentFormatter.title(for: firstDate, referenceDate: Date(), calendar: calendar)))
        }
        for index in records.indices {
            let record = records[index]
            let side: DialogueFlowSide = record.speakerKind == Self.assistantLocalSpeakerKind ? .local : .remote
            let showsAvatar = index == records.startIndex || records[records.index(before: index)].speakerKind != record.speakerKind
            switch record.entryKind {
            case 1:
                entries.append(.portraitAsset(name: record.mediaAsset ?? "profile_avatar", side: side, showsAvatar: showsAvatar))
            case 2:
                let durationText = "\(Int(record.audioDuration ?? 1))s"
                entries.append(.audioClip(
                    durationText: durationText,
                    side: side,
                    showsAvatar: showsAvatar,
                    audioAsset: record.mediaAsset
                ))
            default:
                entries.append(.phrase(text: record.bodyText ?? "", side: side, showsAvatar: showsAvatar))
            }
        }
        return entries
    }

    private var activeDirectDialogueThreadKey: String? {
        if let key = RouteContextStore.currentTargetDialogueThreadKey() {
            return key
        }
        guard let activeKey = AccountSessionCenter.shared.activeAccountKey,
              let targetKey = RouteContextStore.currentTargetAccountKey() else {
            return nil
        }
        let pair = [activeKey, targetKey].sorted().joined(separator: "-")
        let threadKey = "direct-\(pair)"
        RouteContextStore.setTargetDialogueThread(key: threadKey, title: resolvedDirectDialogueProfile().displayName)
        return threadKey
    }

    private func resolvedDirectDialogueProfile() -> (displayName: String, avatarAsset: String?) {
        if let targetKey = RouteContextStore.currentTargetAccountKey(),
           let profile = AccountSessionCenter.shared.safetyProfile(accountKey: targetKey) {
            return (profile.displayName, profile.avatarAsset)
        }
        return (RouteContextStore.currentTargetDialogueTitle() ?? "Victoria", "profile_avatar")
    }

    @objc private func submitDirectDialogueText() {
        let text = directDialogueInputField?.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard text.isEmpty == false else { return }
        guard appendDirectDialogueEntry(entryKind: 0, bodyText: text) else {
            MorviToastView.show("Send failed", in: self)
            return
        }
        directDialogueInputField?.text = nil
        reloadDirectDialogueList()
    }

    func appendDirectDialogueImage(mediaAsset: String, imageSize: CGSize) {
        guard appendDirectDialogueEntry(
            entryKind: 1,
            mediaAsset: mediaAsset,
            mediaSize: imageSize
        ) else {
            MorviToastView.show("Image send failed", in: self)
            return
        }
        reloadDirectDialogueList()
    }

    private func appendDirectDialogueAudio(durationSeconds: Int, audioAsset: String?) {
        guard appendDirectDialogueEntry(
            entryKind: 2,
            mediaAsset: audioAsset,
            durationSeconds: TimeInterval(durationSeconds)
        ) else {
            MorviToastView.show("Audio send failed", in: self)
            return
        }
        reloadDirectDialogueList()
    }

    private func appendDirectDialogueEntry(
        entryKind: Int,
        bodyText: String? = nil,
        mediaAsset: String? = nil,
        mediaSize: CGSize? = nil,
        durationSeconds: TimeInterval? = nil
    ) -> Bool {
        guard let activeKey = AccountSessionCenter.shared.activeAccountKey,
              let threadKey = activeDirectDialogueThreadKey else {
            didRequestOverlayPage?(.accessGate)
            return false
        }
        do {
            let now = LocalDateText.now()
            let sequenceNumber = try dialogueRepository.nextSequenceNumber(threadKey: threadKey)
            let entryKey = "entry-direct-\(UUID().uuidString.lowercased())"
            let profile = resolvedDirectDialogueProfile()
            try dialogueRepository.saveEntry(
                DialogueEntryRecord(
                    stableKey: entryKey,
                    threadKey: threadKey,
                    authorAccountKey: activeKey,
                    speakerKind: Self.assistantLocalSpeakerKind,
                    entryKind: entryKind,
                    bodyText: bodyText,
                    mediaAsset: mediaAsset,
                    mediaWidth: mediaSize.map { Double($0.width) },
                    mediaHeight: mediaSize.map { Double($0.height) },
                    audioDuration: durationSeconds,
                    sequenceNumber: sequenceNumber,
                    deliveryState: Self.assistantCompleteState,
                    createdAt: now
                )
            )
            try dialogueRepository.saveThread(
                DialogueThreadRecord(
                    stableKey: threadKey,
                    threadKind: 0,
                    counterpartAccountKey: RouteContextStore.currentTargetAccountKey(),
                    title: profile.displayName,
                    avatarAsset: profile.avatarAsset,
                    latestEntryKey: entryKey,
                    latestEntryAt: now,
                    lastReadAt: nil,
                    isArchived: false,
                    createdAt: now,
                    updatedAt: now
                )
            )
            return true
        } catch {
            return false
        }
    }

    private func reloadDirectDialogueList() {
        dialogueFlowListView?.configure(entries: directDialogueEntries())
    }

    @objc private func submitAssistantText() {
        let text = assistantInputField?.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard text.isEmpty == false else { return }
        guard let accountKey = AccountSessionCenter.shared.activeAccountKey else {
            didRequestOverlayPage?(.accessGate)
            return
        }

        assistantInputField?.text = nil
        do {
            try storeAssistantExchange(text: text, accountKey: accountKey)
            reloadAssistantDialogueList()
        } catch {
            MorviToastView.show("Send failed", in: self)
        }
    }

    private func storeAssistantExchange(text: String, accountKey: String) throws {
        let now = LocalDateText.now()
        let threadKey = "assistant-\(accountKey)"
        try dialogueRepository.saveThread(
            DialogueThreadRecord(
                stableKey: threadKey,
                threadKind: Self.assistantThreadKind,
                counterpartAccountKey: nil,
                title: "Recot Bot",
                avatarAsset: nil,
                latestEntryKey: nil,
                latestEntryAt: now,
                lastReadAt: nil,
                isArchived: false,
                createdAt: now,
                updatedAt: now
            )
        )
        try dialogueRepository.removePendingAssistantEntries(threadKey: threadKey)

        var sequenceNumber = try dialogueRepository.nextSequenceNumber(threadKey: threadKey)
        let localKey = "assistant-local-\(UUID().uuidString.lowercased())"
        try dialogueRepository.saveEntry(
            DialogueEntryRecord(
                stableKey: localKey,
                threadKey: threadKey,
                authorAccountKey: accountKey,
                speakerKind: Self.assistantLocalSpeakerKind,
                entryKind: Self.assistantTextEntryKind,
                bodyText: text,
                mediaAsset: nil,
                mediaWidth: nil,
                mediaHeight: nil,
                audioDuration: nil,
                sequenceNumber: sequenceNumber,
                deliveryState: Self.assistantCompleteState,
                createdAt: now
            )
        )
        sequenceNumber += 1

        let pendingKey = "assistant-thinking-\(UUID().uuidString.lowercased())"
        try dialogueRepository.saveEntry(
            DialogueEntryRecord(
                stableKey: pendingKey,
                threadKey: threadKey,
                authorAccountKey: nil,
                speakerKind: Self.assistantRemoteSpeakerKind,
                entryKind: Self.assistantTextEntryKind,
                bodyText: Self.assistantThinkingText,
                mediaAsset: nil,
                mediaWidth: nil,
                mediaHeight: nil,
                audioDuration: nil,
                sequenceNumber: sequenceNumber,
                deliveryState: Self.assistantPendingState,
                createdAt: now
            )
        )
        try dialogueRepository.saveThread(
            DialogueThreadRecord(
                stableKey: threadKey,
                threadKind: Self.assistantThreadKind,
                counterpartAccountKey: nil,
                title: "Recot Bot",
                avatarAsset: nil,
                latestEntryKey: pendingKey,
                latestEntryAt: now,
                lastReadAt: nil,
                isArchived: false,
                createdAt: now,
                updatedAt: now
            )
        )
        animatedAssistantEntryKeys = [pendingKey]
    }

    private func addInputToolbarIcons(top: CGFloat) {
        let layoutContainer = activeLayoutContainer ?? self
        let voiceButton = UIButton(type: .custom)
        voiceButton.setImage(UIImage(named: "input_voice_icon"), for: .normal)
        voiceButton.imageView?.contentMode = .scaleAspectFit
        layoutContainer.addSubview(voiceButton)
        voiceButton.translatesAutoresizingMaskIntoConstraints = false

        let photoButton = UIButton(type: .custom)
        photoButton.setImage(UIImage(named: "input_photo_icon"), for: .normal)
        photoButton.imageView?.contentMode = .scaleAspectFit
        layoutContainer.addSubview(photoButton)
        photoButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            voiceButton.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: 24),
            voiceButton.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            voiceButton.widthAnchor.constraint(equalToConstant: 24),
            voiceButton.heightAnchor.constraint(equalToConstant: 24),

            photoButton.leadingAnchor.constraint(equalTo: voiceButton.trailingAnchor, constant: 12),
            photoButton.centerYAnchor.constraint(equalTo: voiceButton.centerYAnchor),
            photoButton.widthAnchor.constraint(equalToConstant: 24),
            photoButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    private func addPortraitMediaBlock(top: CGFloat, edge: CGFloat, outgoing: Bool, width: CGFloat) {
        let layoutContainer = activeLayoutContainer ?? self
        let image = UIImage(named: "profile_avatar")
        let ratio = (image?.size.height ?? width) / max(image?.size.width ?? width, 1)
        let height = width * ratio

        let shadowHost = UIView()
        shadowHost.backgroundColor = .clear
        shadowHost.layer.shadowColor = UIColor.black.cgColor
        shadowHost.layer.shadowOpacity = 0.18
        shadowHost.layer.shadowOffset = CGSize(width: 0, height: 5)
        shadowHost.layer.shadowRadius = 12
        layoutContainer.addSubview(shadowHost)
        shadowHost.translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 10
        shadowHost.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false

        var constraints = [
            shadowHost.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            shadowHost.widthAnchor.constraint(equalToConstant: width),
            shadowHost.heightAnchor.constraint(equalToConstant: height),

            imageView.leadingAnchor.constraint(equalTo: shadowHost.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: shadowHost.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: shadowHost.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: shadowHost.bottomAnchor)
        ]
        if outgoing {
            constraints.append(shadowHost.trailingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: edge))
        } else {
            constraints.append(shadowHost.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: edge))
        }
        NSLayoutConstraint.activate(constraints)
    }

    private func renderAssistantDialogue() {
        addTopTitle("Recot Bot")
        let dockView = addDialogueInputDock(showsAccessoryButtons: false) { [weak self] in
            self?.submitAssistantText()
        }
        addDialogueFlowList(
            top: 136,
            bottomAnchor: dockView.topAnchor,
            bottomSpacing: 8,
            entries: assistantDialogueEntries()
        )
        bringSubviewToFront(dockView)
    }

    private func renderGalleryDetail() {
        let item = resolvedGalleryWork()
        addFullscreenGalleryCover(item: item)
        let bodyWidth = adaptiveLayoutWidth - 40
        let bodyHeight = measuredCopyHeight(
            item.bodyText,
            size: 16,
            weight: .regular,
            width: bodyWidth
        )
        let tagsHeight = measuredTagsHeight(left: 20, right: 20, items: item.themes)
        let bodyOffset: CGFloat = 78
        let tagsOffset = bodyOffset + bodyHeight + 24
        let panelHeight = tagsOffset + tagsHeight + 68
        let panelTop = max(0, adaptiveLayoutHeight - panelHeight)
        let avatarTop = panelTop + 23
        let nameTop = panelTop + 31
        let bodyTop = panelTop + bodyOffset
        let tagsTop = panelTop + tagsOffset
        let reactionsTop = tagsTop + tagsHeight + 22
        let panel = addGlassPanel(
            top: panelTop,
            left: 0,
            width: 375,
            height: panelHeight,
            radius: 14,
            fillAlpha: 0.4,
            blurRadius: 16,
            backdropAssetName: item.coverAsset,
            trailing: 0
        )
        panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        addAssetAvatar(item.avatarAsset, top: avatarTop, left: 20, size: 36)
        addText(item.displayName, size: 17, weight: .bold, top: nameTop, left: 68)
        addText(item.bodyText, size: 16, weight: .regular, top: bodyTop, left: 20)
        addTags(top: tagsTop, left: 20, right: 20, items: item.themes)
        addFeedStat(
            iconName: "feed_like_icon",
            text: "\(item.reactionCount) Likes",
            top: reactionsTop,
            left: 22,
            parent: self,
            iconTint: isWorkReacted(item.stableKey) ? UIColor(red: 0.39, green: 0.68, blue: 0.02, alpha: 1) : nil
        )
        addFeedStat(iconName: "feed_reply_icon", text: "\(item.replyCount) Comments", top: reactionsTop, left: 130, parent: self)
        addDiscoverActionButton(frame: CGRect(x: 20, y: reactionsTop - 12, width: 106, height: 44)) { [weak self] in
            self?.toggleWorkReaction(workKey: item.stableKey)
        }
        addDiscoverActionButton(frame: CGRect(x: 126, y: reactionsTop - 12, width: 152, height: 44)) { [weak self] in
            RouteContextStore.setTargetWorkKey(item.stableKey)
            RouteContextStore.setTargetAccountKey(item.accountKey)
            self?.didRequestOverlayPage?(.repliesPanel)
        }
        addDiscoverActionButton(frame: CGRect(x: 20, y: avatarTop - 8, width: 220, height: 58)) { [weak self] in
            self?.requestPublicPersona(subjectKey: item.accountKey)
        }
    }

    private func renderGalleryPreview() {
        backgroundColor = .black
        let item = resolvedGalleryWork()
        let imageView = UIImageView(image: resolveVisualAsset(item.coverAsset))
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .black
        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        guard item.mediaKind == 1,
              let mediaURL = resolvedMediaURL(for: item.mediaAsset) else {
            addGalleryPreviewBackButton()
            return
        }

        let player = AVPlayer(url: mediaURL)
        galleryPreviewPlayer = player
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        let hostView = PlayerLayerHostView(playerLayer: playerLayer)
        hostView.backgroundColor = .clear
        addSubview(hostView)
        hostView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostView.topAnchor.constraint(equalTo: topAnchor),
            hostView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        player.play()
        addGalleryPreviewBackButton()
    }

    private func addGalleryPreviewBackButton() {
        let buttonSize: CGFloat = 58
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "navigation_back_circle"), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: #selector(closeGalleryPreview), for: .touchUpInside)
        addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            button.topAnchor.constraint(equalTo: topAnchor, constant: currentStatusBarHeight() + 20),
            button.widthAnchor.constraint(equalToConstant: buttonSize),
            button.heightAnchor.constraint(equalToConstant: buttonSize)
        ])
    }

    @objc private func closeGalleryPreview() {
        galleryPreviewPlayer?.pause()
        galleryPreviewPlayer = nil
        removeFromSuperview()
    }

    private func resolvedMediaURL(for asset: String?) -> URL? {
        guard let asset, asset.isEmpty == false else { return nil }
        let localPrefixes = ["local-work-video/", "local-work/"]
        for prefix in localPrefixes where asset.hasPrefix(prefix) {
            guard let localURL = localWorkMediaURL(
                fileName: String(asset.dropFirst(prefix.count))
            ) else { return nil }
            return localURL
        }
        if asset.hasPrefix("file://"),
           let fileURL = URL(string: asset),
           FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        let url = URL(fileURLWithPath: asset)
        if url.isFileURL,
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        let resourceName = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
        return Bundle.main.url(forResource: resourceName, withExtension: fileExtension)
    }

    private func localWorkMediaURL(fileName: String) -> URL? {
        guard fileName.isEmpty == false,
              let baseDirectory = try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
              ) else {
            return nil
        }
        let fileURL = baseDirectory
            .appendingPathComponent("Morvi", isDirectory: true)
            .appendingPathComponent("WorkMedia", isDirectory: true)
            .appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return fileURL
    }

    private func addFullscreenGalleryCover(item: DiscoveryWorkEntry) {
        let coverImage = resolveVisualAsset(item.coverAsset)
        let coverContainer = UIView()
        coverContainer.clipsToBounds = true
        addSubview(coverContainer)
        coverContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            coverContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            coverContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            coverContainer.topAnchor.constraint(equalTo: topAnchor),
            coverContainer.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let coverView = UIImageView(image: coverImage)
        coverView.contentMode = .scaleAspectFill
        coverView.clipsToBounds = true
        coverContainer.addSubview(coverView)
        coverView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            coverView.leadingAnchor.constraint(equalTo: coverContainer.leadingAnchor),
            coverView.trailingAnchor.constraint(equalTo: coverContainer.trailingAnchor),
            coverView.topAnchor.constraint(equalTo: coverContainer.topAnchor),
            coverView.bottomAnchor.constraint(equalTo: coverContainer.bottomAnchor)
        ])

        if item.mediaKind == 1 {
            let iconView = UIImageView(image: UIImage(named: "video_play_icon"))
            iconView.contentMode = .scaleAspectFit
            coverContainer.addSubview(iconView)
            iconView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                iconView.centerXAnchor.constraint(equalTo: coverContainer.centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: coverContainer.centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 40),
                iconView.heightAnchor.constraint(equalToConstant: 40)
            ])
        }

        let button = ClearTapButton(frame: .zero) { [weak self] in
            RouteContextStore.setTargetWorkKey(item.stableKey)
            RouteContextStore.setTargetAccountKey(item.accountKey)
            self?.didRequestOverlayPage?(.galleryPreview)
        }
        coverContainer.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: coverContainer.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: coverContainer.trailingAnchor),
            button.topAnchor.constraint(equalTo: coverContainer.topAnchor),
            button.bottomAnchor.constraint(equalTo: coverContainer.bottomAnchor)
        ])
    }

    private func renderPersonaDetail() {
        let accountKey = RouteContextStore.currentTargetAccountKey()
            ?? restrictionSubjectKey
            ?? resolvedGalleryWork().accountKey
        let detail = resolvedPersonaDetail(accountKey: accountKey, fallbackName: "Victoria")
        let workEntries = resolvedPersonaWorks(accountKey: accountKey)
        addPersonaRootGradient()
        addPersonaBackdrop(imageName: personaBackdropAssetName(for: detail))
        let scrollView = CancelFriendlyScrollView()
        scrollView.delegate = self
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .clear
        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let scrollContent = UIView()
        scrollContent.backgroundColor = .clear
        scrollView.addSubview(scrollContent)
        scrollContent.translatesAutoresizingMaskIntoConstraints = false
        activeLayoutContainer = scrollContent
        let nameTop: CGFloat = 394
        let nameHeight = ceil(AppFont.source(26, weight: .bold).lineHeight)
        let statsTop = nameTop + nameHeight + 15
        let buttonTop = statsTop + 80 + 22
        let cellTop = buttonTop + 40 + 24
        let cellGap: CGFloat = 15
        let waterfallLayout = adaptivePairLayout(gap: cellGap)
        let cellWidth = waterfallLayout.width
        let columnLefts: [CGFloat] = [20, waterfallLayout.secondLeft]
        var columnBottoms = [cellTop, cellTop]
        let cellPlacements = workEntries.enumerated().map { index, item -> (top: CGFloat, left: CGFloat, width: CGFloat, height: CGFloat, item: DiscoveryWorkEntry, tint: MediaTint) in
            let columnIndex = waterfallColumnIndex(for: columnBottoms)
            let height = proportionalCellHeight(for: item, width: cellWidth)
            let placement = (
                top: columnBottoms[columnIndex],
                left: columnLefts[columnIndex],
                width: cellWidth,
                height: height,
                item: item,
                tint: index.isMultiple(of: 2) ? MediaTint.coast : MediaTint.sky
            )
            columnBottoms[columnIndex] += height + cellGap
            return placement
        }
        personaMediaFrames = cellPlacements.map {
            CGRect(x: $0.left, y: $0.top, width: $0.width, height: $0.height)
        }
        personaMediaTargets = cellPlacements.map {
            (CGRect(x: $0.left, y: $0.top, width: $0.width, height: $0.height), $0.item.stableKey, $0.item.accountKey)
        }
        let contentHeight = max(adaptiveLayoutHeight, (columnBottoms.max() ?? adaptiveLayoutHeight) - cellGap + 32)

        NSLayoutConstraint.activate([
            scrollContent.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContent.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContent.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            scrollContent.heightAnchor.constraint(equalToConstant: contentHeight)
        ])

        let baseHeight = contentHeight - 328
        let base = addPanel(top: 328, left: 0, width: 375, height: baseHeight, alpha: 1, trailing: 0)
        addThemeGradientBackground(
            to: base,
            width: adaptiveLayoutWidth,
            height: baseHeight,
            cornerRadius: 20,
            maskedCorners: [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        )
        base.backgroundColor = .clear
        base.layer.borderWidth = 0
        base.layer.shadowOpacity = 0
        base.layer.cornerRadius = 20
        base.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        addProfileAvatar(image: resolveAccountAvatar(detail.avatarAsset), top: 268, left: 128, size: 120, showsBorder: false, showsShadow: false)
        addText(detail.displayName, size: 26, weight: .bold, top: nameTop, centered: true)
        addStatsPanel(top: statsTop, detail: detail)
        let actionLayout = adaptivePairLayout(gap: 15)
        let dialogueButton = addPillButton("Chat", top: buttonTop, left: 20, width: actionLayout.width, height: 40, dark: true, fontSize: 16, fontWeight: .medium)
        dialogueButton.addTarget(self, action: #selector(handlePersonaDialogueTap), for: .touchUpInside)
        let isConnected = AccountSessionCenter.shared.isConnectedToAccount(accountKey: accountKey)
        let connectButton = addPillButton(
            isConnected ? "Unfollow" : "Follow",
            top: buttonTop,
            left: actionLayout.secondLeft,
            width: actionLayout.width,
            height: 40,
            dark: isConnected == false,
            fontSize: 16,
            fontWeight: .medium
        )
        connectButton.addTarget(self, action: #selector(handlePersonaConnectTap), for: .touchUpInside)
        cellPlacements.forEach { placement in
            addMediaBlock(
                top: placement.top,
                left: placement.left,
                width: placement.width,
                height: placement.height,
                title: "",
                tint: placement.tint,
                action: placement.item.mediaKind == 1 ? .play : .none,
                imageName: placement.item.coverAsset,
                playIconName: "persona_media_play_icon",
                playIconSize: 28,
                shadowOpacity: 0
            )
        }
        if workEntries.isEmpty {
            addPersonaEmptyState(top: cellTop, in: scrollContent)
        }
        addPersonaMediaContainerSelection(to: scrollContent)
        activeLayoutContainer = nil
    }

    @objc private func handlePersonaDialogueTap() {
        let accountKey = RouteContextStore.currentTargetAccountKey()
            ?? restrictionSubjectKey
            ?? resolvedGalleryWork().accountKey
        guard AccountSessionCenter.shared.isSignedIn else {
            didRequestOverlayPage?(.accessGate)
            return
        }
        guard AccountSessionCenter.shared.isActiveAccount(accountKey) == false else {
            didRequestPage?(.persona)
            return
        }
        guard AccountSessionCenter.shared.hasMutualConnection(with: accountKey) else {
            MorviToastView.show("You need to follow each other first.", in: self)
            return
        }
        let profile = AccountSessionCenter.shared.safetyProfile(accountKey: accountKey)
        RouteContextStore.setTargetAccountKey(accountKey)
        RouteContextStore.setTargetDialogueThread(key: nil, title: profile?.displayName)
        didRequestPage?(.directDialogue)
    }

    @objc private func handlePersonaConnectTap() {
        let accountKey = RouteContextStore.currentTargetAccountKey()
            ?? restrictionSubjectKey
            ?? resolvedGalleryWork().accountKey
        guard AccountSessionCenter.shared.isSignedIn else {
            didRequestOverlayPage?(.accessGate)
            return
        }
        guard AccountSessionCenter.shared.isActiveAccount(accountKey) == false else {
            MorviToastView.show("You cannot follow yourself.", in: self)
            return
        }
        do {
            guard let isConnected = try AccountSessionCenter.shared.toggleConnectionToAccount(accountKey: accountKey) else {
                MorviToastView.show("You cannot follow yourself.", in: self)
                return
            }
            MorviToastView.show(isConnected ? "Followed" : "Unfollowed", in: self)
            reloadRenderedContent()
        } catch {
            MorviToastView.show("Operation failed", in: self)
        }
    }

    private func addPersonaMediaContainerSelection(to container: UIView) {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handlePersonaMediaContainerTap(_:)))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        container.addGestureRecognizer(tapGesture)
    }

    @objc private func handlePersonaMediaContainerTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, let container = gesture.view else { return }
        let location = gesture.location(in: container)
        guard let target = personaMediaTargets.first(where: { $0.frame.contains(location) }) else { return }
        RouteContextStore.setTargetWorkKey(target.workKey)
        RouteContextStore.setTargetAccountKey(target.accountKey)
        didRequestPage?(.galleryDetail)
    }

    private func addPersonaRootGradient() {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(red: 235 / 255, green: 254 / 255, blue: 175 / 255, alpha: 1).cgColor,
            UIColor(red: 224 / 255, green: 251 / 255, blue: 252 / 255, alpha: 1).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        let screenHeight = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        gradient.frame = CGRect(x: 0, y: 0, width: adaptiveLayoutWidth, height: max(adaptiveLayoutHeight, screenHeight))
        layer.insertSublayer(gradient, at: 0)
    }

    private func addPersonaBackdrop(imageName: String = "discover_feed_cover") {
        let coverImage = resolveVisualAsset(imageName)
        let coverView = UIImageView(image: coverImage)
        coverView.contentMode = .scaleAspectFill
        coverView.clipsToBounds = true
        addSubview(coverView)
        coverView.translatesAutoresizingMaskIntoConstraints = false

        let screenWidth = UIScreen.main.bounds.width
        if let coverImage, coverImage.size.width > 0 {
            personaBackdropBaseHeight = ceil(screenWidth * coverImage.size.height / coverImage.size.width)
        } else {
            personaBackdropBaseHeight = 403
        }
        let heightConstraint = coverView.heightAnchor.constraint(equalToConstant: personaBackdropBaseHeight)
        personaBackdropHeightConstraint = heightConstraint
        NSLayoutConstraint.activate([
            coverView.leadingAnchor.constraint(equalTo: leadingAnchor),
            coverView.trailingAnchor.constraint(equalTo: trailingAnchor),
            coverView.topAnchor.constraint(equalTo: topAnchor),
            heightConstraint
        ])
    }

    private func personaBackdropAssetName(for detail: PersonaDetailEntry) -> String {
        detail.avatarAsset == "default_avatar" ? "image.png" : detail.avatarAsset
    }

    private func updatePersonaBackdrop(for scrollView: UIScrollView) {
        guard page == .persona || page == .publicPersona else { return }
        let pullDistance = max(0, -scrollView.contentOffset.y)
        personaBackdropHeightConstraint?.constant = personaBackdropBaseHeight + pullDistance
    }

    private func addPersonaEditAction(top: CGFloat, left: CGFloat) {
        let layoutContainer = activeLayoutContainer ?? self
        let title = "Edit Profile"
        let font = AppFont.source(16, weight: .medium)
        let titleSize = (title as NSString).size(withAttributes: [.font: font])
        let height = ceil(font.lineHeight) + 12
        let width = ceil(titleSize.width) + 24

        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(UIColor(red: 0.78, green: 1, blue: 0.20, alpha: 1), for: .normal)
        button.titleLabel?.font = font
        button.backgroundColor = UIColor(red: 0.04, green: 0.05, blue: 0.04, alpha: 1)
        button.layer.cornerRadius = height / 2
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(handlePersonaEditTap), for: .touchUpInside)
        layoutContainer.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            button.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            button.widthAnchor.constraint(equalToConstant: width),
            button.heightAnchor.constraint(equalToConstant: height)
        ])
    }

    @objc private func handlePersonaEditTap() {
        didRequestOverlayPage?(.profileEditor)
    }

    private func addPersonaSettingsAction(top: CGFloat, left: CGFloat) {
        let layoutContainer = activeLayoutContainer ?? self
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(handlePersonaSettingsTap), for: .touchUpInside)
        layoutContainer.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            button.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            button.widthAnchor.constraint(equalToConstant: 50),
            button.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    @objc private func handlePersonaSettingsTap() {
        didRequestPage?(.settings)
    }

    private func addPersonaMetricLine(
        top: CGFloat,
        left: CGFloat,
        worksText: String = "0",
        followersText: String = "77",
        followingText: String = "99"
    ) {
        let layoutContainer = activeLayoutContainer ?? self
        let font = AppFont.source(14, weight: .regular)
        let worksValue = UILabel()
        worksValue.text = worksText
        worksValue.textColor = UIColor(red: 0.36, green: 0.83, blue: 0.12, alpha: 1)
        worksValue.font = font

        let worksTitle = UILabel()
        worksTitle.text = "Works"
        worksTitle.textColor = .darkGray
        worksTitle.font = font

        let firstValue = UILabel()
        firstValue.text = followersText
        firstValue.textColor = UIColor(red: 1.0, green: 0.60, blue: 0.00, alpha: 1)
        firstValue.font = font

        let firstText = UILabel()
        firstText.text = "Followers"
        firstText.textColor = .darkGray
        firstText.font = font

        let secondValue = UILabel()
        secondValue.text = followingText
        secondValue.textColor = UIColor(red: 0.08, green: 0.57, blue: 1.0, alpha: 1)
        secondValue.font = font

        let secondText = UILabel()
        secondText.text = "Following"
        secondText.textColor = .darkGray
        secondText.font = font

        [worksValue, worksTitle, firstValue, firstText, secondValue, secondText].forEach {
            layoutContainer.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            worksValue.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            worksValue.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),

            worksTitle.leadingAnchor.constraint(equalTo: worksValue.trailingAnchor, constant: 4),
            worksTitle.centerYAnchor.constraint(equalTo: worksValue.centerYAnchor),

            firstValue.leadingAnchor.constraint(equalTo: worksTitle.trailingAnchor, constant: 12),
            firstValue.centerYAnchor.constraint(equalTo: worksValue.centerYAnchor),

            firstText.leadingAnchor.constraint(equalTo: firstValue.trailingAnchor, constant: 4),
            firstText.centerYAnchor.constraint(equalTo: worksValue.centerYAnchor),

            secondValue.leadingAnchor.constraint(equalTo: firstText.trailingAnchor, constant: 12),
            secondValue.centerYAnchor.constraint(equalTo: worksValue.centerYAnchor),

            secondText.leadingAnchor.constraint(equalTo: secondValue.trailingAnchor, constant: 4),
            secondText.centerYAnchor.constraint(equalTo: worksValue.centerYAnchor),
            secondText.trailingAnchor.constraint(lessThanOrEqualTo: layoutContainer.trailingAnchor, constant: -20)
        ])

        let inboundButton = ClearTapButton(frame: .zero) { [weak self] in
            self?.didRequestPage?(.inboundConnectionRoster)
        }
        let outboundButton = ClearTapButton(frame: .zero) { [weak self] in
            self?.didRequestPage?(.outboundConnectionRoster)
        }
        [inboundButton, outboundButton].forEach {
            layoutContainer.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            inboundButton.leadingAnchor.constraint(equalTo: firstValue.leadingAnchor, constant: -8),
            inboundButton.trailingAnchor.constraint(equalTo: firstText.trailingAnchor, constant: 8),
            inboundButton.centerYAnchor.constraint(equalTo: firstValue.centerYAnchor),
            inboundButton.heightAnchor.constraint(equalToConstant: 44),

            outboundButton.leadingAnchor.constraint(equalTo: secondValue.leadingAnchor, constant: -8),
            outboundButton.trailingAnchor.constraint(equalTo: secondText.trailingAnchor, constant: 8),
            outboundButton.centerYAnchor.constraint(equalTo: secondValue.centerYAnchor),
            outboundButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func addThemeGradientBackground(
        to view: UIView,
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat,
        maskedCorners: CACornerMask = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner,
            .layerMinXMaxYCorner,
            .layerMaxXMaxYCorner
        ]
    ) {
        let backgroundView = UIView()
        backgroundView.layer.cornerRadius = cornerRadius
        backgroundView.layer.maskedCorners = maskedCorners
        backgroundView.layer.masksToBounds = true
        view.insertSubview(backgroundView, at: 0)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(red: 235 / 255, green: 254 / 255, blue: 175 / 255, alpha: 1).cgColor,
            UIColor(red: 224 / 255, green: 251 / 255, blue: 252 / 255, alpha: 1).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.frame = CGRect(x: 0, y: 0, width: width, height: height)
        backgroundView.layer.insertSublayer(gradient, at: 0)
    }

    private func renderSignIn() {
        let navigationBottom = currentStatusBarHeight() + 76
        let scrollView = CancelFriendlyScrollView()
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .clear
        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: navigationBottom)
        ])

        let scrollContent = UIView()
        scrollContent.backgroundColor = .clear
        scrollView.addSubview(scrollContent)
        scrollContent.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollContent.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContent.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContent.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            scrollContent.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        keyboardAwareScrollView = scrollView
        installKeyboardAvoidance()

        activeLayoutContainer = scrollContent
        addTopTitle("Sign in")
        addLogo(top: 168 - navigationBottom)
        addText("Morvi", size: 42, weight: .black, top: 308 - navigationBottom, centered: true)
        addText("Email", size: 16, weight: .black, top: 388 - navigationBottom, left: 20)
        addInputField("Please enter", top: 413 - navigationBottom, keyboardType: .emailAddress)
        addText("Password", size: 16, weight: .black, top: 496 - navigationBottom, left: 20)
        addInputField("Please enter", top: 523 - navigationBottom, isSecureTextEntry: true)
        addUnderlinedText("Forgot ?", size: 12, top: 588 - navigationBottom, left: 303, color: .gray)
        activeLayoutContainer = nil
        let actionButton = addButton("Log in", bottom: 29, filled: true, usesOneFont: true)
        actionButton.addTarget(self, action: #selector(handlePrimaryAction), for: .touchUpInside)
        scrollView.bottomAnchor.constraint(equalTo: actionButton.topAnchor, constant: -16).isActive = true
    }

    private func renderSignUp() {
        let navigationBottom = currentStatusBarHeight() + 76
        let scrollView = CancelFriendlyScrollView()
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .clear
        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: navigationBottom)
        ])

        let scrollContent = UIView()
        scrollContent.backgroundColor = .clear
        scrollView.addSubview(scrollContent)
        scrollContent.translatesAutoresizingMaskIntoConstraints = false
        let viewportHeight = scrollContent.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        viewportHeight.priority = .defaultHigh
        NSLayoutConstraint.activate([
            scrollContent.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContent.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContent.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            scrollContent.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor),
            scrollContent.heightAnchor.constraint(greaterThanOrEqualToConstant: 702 - navigationBottom),
            viewportHeight
        ])

        keyboardAwareScrollView = scrollView
        installKeyboardAvoidance()

        activeLayoutContainer = scrollContent
        addTopTitle("Sign up")
        addLogo(top: 168 - navigationBottom)
        addText("Morvi", size: 42, weight: .black, top: 308 - navigationBottom, centered: true)
        let fields = ["Email", "Password", "Enter the password again"]
        fields.enumerated().forEach { index, field in
            let top = CGFloat(388 + index * 108) - navigationBottom
            addText(field, size: 16, weight: .bold, top: top, left: 20)
            addInputField(
                "Please enter",
                top: top + 26,
                keyboardType: index == 0 ? .emailAddress : .default,
                isSecureTextEntry: index != 0
            )
        }
        activeLayoutContainer = nil
        let actionButton = addButton("Sign up", bottom: 29, filled: true, usesOneFont: true)
        actionButton.addTarget(self, action: #selector(handlePrimaryAction), for: .touchUpInside)
        scrollView.bottomAnchor.constraint(equalTo: actionButton.topAnchor, constant: -16).isActive = true
    }

    private func renderResetAccess() {
        let navigationBottom = currentStatusBarHeight() + 76
        let scrollView = CancelFriendlyScrollView()
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .clear
        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: navigationBottom)
        ])

        let scrollContent = UIView()
        scrollContent.backgroundColor = .clear
        scrollView.addSubview(scrollContent)
        scrollContent.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollContent.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContent.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContent.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            scrollContent.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        keyboardAwareScrollView = scrollView
        installKeyboardAvoidance()

        activeLayoutContainer = scrollContent
        addTopTitle("Forgot password")
        let fields = ["Email", "Password", "Enter the password again"]
        fields.enumerated().forEach { index, field in
            let top = CGFloat(158 + index * 108) - navigationBottom
            addText(field, size: 16, weight: .bold, top: top, left: 20)
            let placeholder = index == 0 ? "Enter email address" : "Enter password"
            addInputField(
                placeholder,
                top: top + 26,
                keyboardType: index == 0 ? .emailAddress : .default,
                isSecureTextEntry: index != 0
            )
        }
        activeLayoutContainer = nil
        let actionButton = addButton("Next", bottom: 29, filled: true, usesOneFont: true)
        actionButton.addTarget(self, action: #selector(handlePrimaryAction), for: .touchUpInside)
        scrollView.bottomAnchor.constraint(equalTo: actionButton.topAnchor, constant: -16).isActive = true
    }

    private func renderForm(title: String, fields: [String], action: String, footer: String?) {
        addTopTitle(title)
        if title == "Sign in" || title == "Sign up" {
            addLogo(top: 168)
            addText("Morvi", size: 42, weight: .black, top: 308, centered: true)
        }
        var top: CGFloat = title == "Forgot password" ? 158 : 388
        fields.enumerated().forEach { index, field in
            addText(field, size: 16, weight: .bold, top: top, left: 20)
            let placeholder: String
            if title == "Forgot password" {
                placeholder = index == 0 ? "Enter email address" : "Enter password"
            } else {
                placeholder = "Please enter"
            }
            addField(placeholder, top: top + 26)
            top += 108
        }
        if let footer {
            addText(footer, size: 12, weight: .regular, top: max(570, top - 20), left: 302, color: .gray)
        }
        if !action.isEmpty {
            addButton(action, top: 716, filled: true, usesOneFont: true)
        }
    }

    private func renderWallet() {
        addTopTitle("Wallet")
        let balanceText = "\(AccountSessionCenter.shared.activeWalletBalanceValue())"
        let amounts = [400, 800, 1780, 2450, 5150, 10800, 14900, 29400, 34500, 63700]
        let prices = ["$0.99", "$1.99", "$3.99", "$4.99", "$9.99", "$19.99", "$29.99", "$49.99", "$69.99", "$99.99"]
        let bundlePrefix = Bundle.main.bundleIdentifier ?? "com.morvi.app"
        let priceIdentifierOverrides = [
            "$0.99": "mqlravtspzbnheyc",
            "$1.99": "qmwkqadsjekmrvjl",
            "$3.99": "jfukgudeggyrveyo",
            "$4.99": "lwauthykogfgikvz",
            "$9.99": "ekilrobkqllkbcfw",
            "$19.99": "txictgmtylhydqow",
            "$29.99": "kxafnnejjhdudgmq",
            "$49.99": "czeaavhyyldqftuc",
            "$69.99": "vdjzqpsrzdfnrbwb",
            "$99.99": "eujrdvblverymclw"
        ]
        let listTop: CGFloat = 188
        let rowStep: CGFloat = 80
        let rowHeight: CGFloat = 68
        let contentHeight = listTop + CGFloat(amounts.count - 1) * rowStep + rowHeight + 40
        let scrollView = CancelFriendlyScrollView()
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .clear
        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 120),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let scrollContent = UIView()
        scrollContent.backgroundColor = .clear
        scrollView.addSubview(scrollContent)
        scrollContent.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollContent.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContent.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContent.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            scrollContent.heightAnchor.constraint(equalToConstant: contentHeight)
        ])

        activeLayoutContainer = scrollContent
        addNotchedPanel(top: 56, left: 20, width: 335, height: 122, trailing: 20)
        addWalletBalanceTextGroup(parent: scrollContent, cardTop: 56, amountText: balanceText)
        for index in amounts.indices {
            let top = listTop + CGFloat(index) * rowStep
            let amount = amounts[index]
            let price = prices[index]
            let pack = CreditPack(
                value: amount,
                storeIdentifier: priceIdentifierOverrides[price] ?? "\(bundlePrefix).credit.\(amount)"
            )
            addWalletListRow(parent: scrollContent, top: top, amount: "\(amount)", price: price) { [weak self] in
                self?.startCreditAcquisition(pack)
            }
        }
        addGem(assetName: "balance_gem_mark", top: -4, left: 144, width: 180, height: 182)
        activeLayoutContainer = nil
    }

    private func startCreditAcquisition(_ pack: CreditPack) {
        guard AccountSessionCenter.shared.isSignedIn else {
            didRequestOverlayPage?(.accessGate)
            return
        }
        guard AccountSessionCenter.shared.usesGuestAccess == false else {
            MorviToastView.show(
                "Please choose another login method to make a purchase.",
                in: self
            )
            return
        }

        showProgressOverlay()
        Task { [weak self] in
            let outcome = await StorefrontCreditBroker.shared.acquire(pack)
            await MainActor.run {
                self?.hideProgressOverlay {
                    self?.resolveCreditAcquisition(outcome)
                }
            }
        }
    }

    private func resolveCreditAcquisition(_ outcome: CreditAcquisitionOutcome) {
        switch outcome {
        case .completed(let value):
            do {
                guard try AccountSessionCenter.shared.addActiveWalletBalanceValue(amount: value) else {
                    MorviToastView.show("Please log in first", in: self)
                    return
                }
                reloadRenderedContent()
                MorviToastView.show("Purchase successful", in: self)
            } catch {
                MorviToastView.show("Purchase failed", in: self)
            }
        case .cancelled:
            MorviToastView.show("Purchase canceled", in: self)
        case .pending:
            MorviToastView.show("Purchase pending", in: self)
        case .unavailable:
            MorviToastView.show("Purchase unavailable", in: self)
        case .failed:
            MorviToastView.show("Purchase failed", in: self)
        }
    }

    private func addNotchedPanel(top: CGFloat, left: CGFloat, width: CGFloat, height: CGFloat, trailing: CGFloat? = nil) {
        let layoutContainer = activeLayoutContainer ?? self
        let panel = NotchedPanelView()
        layoutContainer.addSubview(panel)
        panel.translatesAutoresizingMaskIntoConstraints = false
        var panelConstraints = [
            panel.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            panel.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            panel.heightAnchor.constraint(equalToConstant: height)
        ]
        if let trailing {
            panelConstraints.append(panel.trailingAnchor.constraint(equalTo: layoutContainer.trailingAnchor, constant: -trailing))
        } else {
            panelConstraints.append(panel.widthAnchor.constraint(equalToConstant: width))
        }
        NSLayoutConstraint.activate(panelConstraints)
    }

    private func addWalletBalanceTextGroup(parent: UIView, cardTop: CGFloat, amountText: String) {
        let group = UIView()
        group.backgroundColor = .clear
        parent.addSubview(group)
        group.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "My balance"
        titleLabel.textColor = .white
        titleLabel.font = AppFont.source(20, weight: .medium)

        let amountLabel = UILabel()
        amountLabel.text = amountText
        amountLabel.textColor = UIColor(red: 0.79, green: 1, blue: 0.18, alpha: 1)
        amountLabel.font = AppFont.fredoka(36)

        group.addSubview(titleLabel)
        group.addSubview(amountLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        amountLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            group.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: 36),
            group.centerYAnchor.constraint(equalTo: parent.topAnchor, constant: cardTop + 61),
            group.heightAnchor.constraint(equalToConstant: 78),

            titleLabel.leadingAnchor.constraint(equalTo: group.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: group.topAnchor),

            amountLabel.leadingAnchor.constraint(equalTo: group.leadingAnchor),
            amountLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            amountLabel.bottomAnchor.constraint(equalTo: group.bottomAnchor)
        ])
    }

    private func addWalletListRow(parent: UIView, top: CGFloat, amount: String, price: String, action: (() -> Void)? = nil) {
        let cell = UIView()
        cell.backgroundColor = .white
        cell.layer.cornerRadius = 12
        cell.layer.masksToBounds = false
        cell.layer.shadowColor = UIColor.black.cgColor
        cell.layer.shadowOpacity = 0.10
        cell.layer.shadowOffset = CGSize(width: 0, height: 4)
        cell.layer.shadowRadius = 14
        parent.addSubview(cell)
        cell.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(named: "wallet_item_gem_mark"))
        iconView.contentMode = .scaleAspectFit
        iconView.layer.shadowColor = UIColor.green.cgColor
        iconView.layer.shadowOpacity = 0.28
        iconView.layer.shadowRadius = 8
        iconView.layer.shadowOffset = CGSize(width: 0, height: 4)

        let amountLabel = UILabel()
        amountLabel.text = amount
        amountLabel.textColor = .black
        amountLabel.font = AppFont.source(24, weight: .medium)

        let priceLabel = UILabel()
        priceLabel.text = price
        priceLabel.textColor = UIColor.black.withAlphaComponent(0.8)
        priceLabel.font = AppFont.source(20, weight: .regular)

        let underline = FadeUnderlineView()

        cell.addSubview(iconView)
        cell.addSubview(amountLabel)
        cell.addSubview(underline)
        cell.addSubview(priceLabel)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        underline.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            cell.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: 15),
            cell.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -15),
            cell.topAnchor.constraint(equalTo: parent.topAnchor, constant: top),
            cell.heightAnchor.constraint(equalToConstant: 68),

            iconView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 15),
            iconView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 36),

            amountLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 65),
            amountLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

            priceLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -16),
            priceLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

            underline.leadingAnchor.constraint(equalTo: priceLabel.leadingAnchor),
            underline.trailingAnchor.constraint(equalTo: priceLabel.trailingAnchor),
            underline.bottomAnchor.constraint(equalTo: priceLabel.bottomAnchor),
            underline.heightAnchor.constraint(equalToConstant: 4)
        ])

        if let action {
            let button = ClearTapButton(frame: .zero, action: action)
            cell.addSubview(button)
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
                button.topAnchor.constraint(equalTo: cell.topAnchor),
                button.bottomAnchor.constraint(equalTo: cell.bottomAnchor)
            ])
        }
    }

    private func renderUpload(filled: Bool) {
        backgroundColor = UIColor.black.withAlphaComponent(filled ? 0.62 : 0.58)
        let sheet = UIView()
        sheet.backgroundColor = .white
        sheet.layer.cornerRadius = 20
        sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        addSubview(sheet)
        sheet.translatesAutoresizingMaskIntoConstraints = false
        let preferredHeight = sheet.heightAnchor.constraint(equalToConstant: 635)
        preferredHeight.priority = .defaultHigh
        NSLayoutConstraint.activate([
            sheet.leadingAnchor.constraint(equalTo: leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: trailingAnchor),
            sheet.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 20),
            sheet.bottomAnchor.constraint(equalTo: bottomAnchor),
            sheet.heightAnchor.constraint(lessThanOrEqualToConstant: 635),
            preferredHeight
        ])
        overlayContentView = sheet

        let grabber = UIView()
        grabber.backgroundColor = .white
        grabber.layer.cornerRadius = 2
        addSubview(grabber)
        grabber.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            grabber.centerXAnchor.constraint(equalTo: centerXAnchor),
            grabber.bottomAnchor.constraint(equalTo: sheet.topAnchor, constant: -6),
            grabber.widthAnchor.constraint(equalToConstant: 112),
            grabber.heightAnchor.constraint(equalToConstant: 4)
        ])

        let titleLabel = UILabel()
        titleLabel.text = "Upload work"
        titleLabel.font = AppFont.fredoka(31)
        titleLabel.textColor = .black
        sheet.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 20),
            titleLabel.topAnchor.constraint(equalTo: sheet.topAnchor, constant: 34)
        ])

        activeLayoutContainer = sheet
        let uploadButton = addButton(
            "Upload",
            bottom: 29,
            trailing: 20,
            filled: true,
            usesOneFont: true,
            cornerRadius: 12,
            shadowOpacity: 0,
            bottomPlateHeight: 3
        )
        uploadButton.addTarget(self, action: #selector(handleUploadWorkAction), for: .touchUpInside)
        activeLayoutContainer = nil

        let scrollView = CancelFriendlyScrollView()
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        sheet.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: sheet.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: sheet.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 13),
            scrollView.bottomAnchor.constraint(equalTo: uploadButton.topAnchor, constant: -10)
        ])

        let formView = UIView()
        formView.backgroundColor = .clear
        scrollView.addSubview(formView)
        formView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            formView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            formView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            formView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            formView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            formView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
        let formHeightConstraint = formView.heightAnchor.constraint(equalToConstant: 518)
        formHeightConstraint.isActive = true
        uploadFormHeightConstraint = formHeightConstraint

        activeLayoutContainer = formView
        addText("Title of work:", size: 17, weight: .regular, top: 0, left: 20)
        uploadTitleField = addInputField(
            "Enter the title",
            top: 32,
            fieldBackgroundColor: UIColor(
                red: 212 / 255,
                green: 1,
                blue: 59 / 255,
                alpha: 0.3
            ),
            usesGradient: false
        )
        addText("Theme:", size: 17, weight: .regular, top: 99, left: 20)
        let themeChoices = addUploadThemeChoices(top: 131)
        let descriptionLabel = addText(
            "Description:",
            size: 17,
            weight: .regular,
            top: 0,
            topAnchor: themeChoices.bottomAnchor,
            topOffset: 17,
            left: 20
        )
        let detailField = addLargeField("Say something", topAnchor: descriptionLabel.bottomAnchor, topOffset: 12) { [weak self] textView in
            self?.uploadDetailTextView = textView
        }
        addUploadBox(top: 0, topAnchor: detailField.bottomAnchor, topOffset: 17) { [weak self] in
            self?.didRequestUploadMediaSelection?()
        }
        activeLayoutContainer = nil

        keyboardAwareScrollView = scrollView
        installKeyboardAvoidance()
        installBlankAreaKeyboardDismissal()
    }

    private func renderList(title: String, sections: [[String]]) {
        addTopTitle(title)
        var top: CGFloat = 142
        for section in sections {
            let height = CGFloat(section.count * 64 + 18)
            _ = addPanel(top: top, left: 20, width: 335, height: height, alpha: 1, trailing: 20)
            var rowTop = top + 18
            section.forEach { row in
                addRow(row, top: rowTop)
                rowTop += 64
            }
            top += height + 28
        }
    }

    private func renderSettings() {
        settingsTapActions = []
        let scrollView = CancelFriendlyScrollView()
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .clear
        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 120),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let scrollContent = UIView()
        scrollContent.backgroundColor = .clear
        scrollView.addSubview(scrollContent)
        scrollContent.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollContent.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContent.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContent.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            scrollContent.heightAnchor.constraint(equalToConstant: 574)
        ])

        activeLayoutContainer = scrollContent
        addSettingsCard(top: 0, height: 276, rows: ["Wallet", "Blacklist", "Privacy Policy", "User Agreement"])
        addSettingsCard(top: 304, height: 150, rows: ["Delete account", "Log out"])
        activeLayoutContainer = nil

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSettingsTap))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        scrollContent.addGestureRecognizer(tapGesture)
    }

    private func addSettingsCard(top: CGFloat, height: CGFloat, rows: [String]) {
        let card = addPanel(top: top, left: 20, width: 335, height: height, alpha: 1, trailing: 20)
        card.layer.cornerRadius = 20
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor(white: 0.93, alpha: 1).cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        card.layer.shadowRadius = 12

        rows.enumerated().forEach { index, text in
            addSettingsItem(text, top: top + 17 + CGFloat(index) * 64)
        }
    }

    private func addSettingsItem(_ text: String, top: CGFloat) {
        let layoutContainer = activeLayoutContainer ?? self
        let itemView = AdaptiveInputView(
            backgroundColor: UIColor(red: 212 / 255, green: 1, blue: 59 / 255, alpha: 0.3),
            cornerRadius: 10
        )
        layoutContainer.addSubview(itemView)
        itemView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            itemView.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: 36),
            itemView.trailingAnchor.constraint(equalTo: layoutContainer.trailingAnchor, constant: -36),
            itemView.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            itemView.heightAnchor.constraint(equalToConstant: 52)
        ])

        let titleLabel = UILabel()
        titleLabel.text = text
        titleLabel.font = AppFont.source(16)
        titleLabel.textColor = UIColor.black.withAlphaComponent(0.85)
        itemView.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let nextIconView = UIImageView(image: UIImage(named: "next_step_icon"))
        nextIconView.contentMode = .scaleAspectFit
        itemView.addSubview(nextIconView)
        nextIconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: itemView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: itemView.centerYAnchor),

            nextIconView.trailingAnchor.constraint(equalTo: itemView.trailingAnchor, constant: -15),
            nextIconView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            nextIconView.widthAnchor.constraint(equalToConstant: 20),
            nextIconView.heightAnchor.constraint(equalToConstant: 20)
        ])

        if let action = settingsTapAction(for: text) {
            settingsTapActions.append((
                frame: CGRect(x: 36, y: top, width: 303, height: 52),
                action: action
            ))
        }
    }

    @objc private func handleSettingsTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: gesture.view)
        settingsTapActions.first { $0.frame.contains(point) }?.action()
    }

    private func settingsTapAction(for text: String) -> (() -> Void)? {
        switch text {
        case "Wallet":
            return { [weak self] in
                self?.performSettingsSignedInAction {
                    self?.didRequestPage?(.wallet)
                }
            }
        case "Blacklist":
            return { [weak self] in
                self?.performSettingsSignedInAction {
                    self?.didRequestPage?(.restrictedList)
                }
            }
        case "Privacy Policy", "User Agreement":
            return { [weak self] in
                RouteContextStore.setAgreementTitle(text)
                self?.didRequestPage?(.agreement)
            }
        case "Delete account":
            return { [weak self] in
                self?.performSettingsSignedInAction {
                    self?.didRequestOverlayPage?(.exitConfirm)
                }
            }
        case "Log out":
            return { [weak self] in
                self?.performSettingsSignedInAction {
                    self?.didRequestOverlayPage?(.signOutConfirm)
                }
            }
        default:
            return nil
        }
    }

    private func performSettingsSignedInAction(_ action: () -> Void) {
        guard AccountSessionCenter.shared.isSignedIn else {
            didRequestOverlayPage?(.accessGate)
            return
        }
        action()
    }

    private func renderPersonalDetail() {
        let navigationBottom = currentStatusBarHeight() + 76
        let scrollView = CancelFriendlyScrollView()
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.backgroundColor = .clear
        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: navigationBottom)
        ])

        let scrollContent = UIView()
        scrollContent.backgroundColor = .clear
        scrollView.addSubview(scrollContent)
        scrollContent.translatesAutoresizingMaskIntoConstraints = false
        let viewportHeight = scrollContent.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        viewportHeight.priority = .defaultHigh
        NSLayoutConstraint.activate([
            scrollContent.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContent.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContent.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            scrollContent.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor),
            scrollContent.heightAnchor.constraint(greaterThanOrEqualToConstant: 700 - navigationBottom),
            viewportHeight
        ])

        keyboardAwareScrollView = scrollView
        installKeyboardAvoidance()

        activeLayoutContainer = scrollContent
        registrationAvatarImageView = addAssetAvatar("default_avatar", top: 147 - navigationBottom, left: 145, size: 84)
        addAvatarEditBadge(top: 210 - navigationBottom, left: 207)
        let items = [
            ("Nickname", "Please enter", CGFloat.zero),
            ("Gender", "Female", CGFloat(84)),
            ("Birthday", "Please enter", CGFloat(103)),
            ("Location", "Please enter", CGFloat(104))
        ]
        for index in items.indices {
            let top = CGFloat(274 + index * 109) - navigationBottom
            addText(items[index].0, size: 17, weight: .black, top: top, left: 20)
            if items[index].2 > 0 {
                addText(
                    "(optional)",
                    size: 12,
                    weight: .regular,
                    top: top + 4,
                    left: items[index].2,
                    color: UIColor.gray.withAlphaComponent(0.55)
                )
            }
            addInputField(items[index].1, top: top + 27)
        }
        activeLayoutContainer = nil
        let actionButton = addButton("Sign up", bottom: 29, filled: true, usesOneFont: true)
        actionButton.addTarget(self, action: #selector(handlePrimaryAction), for: .touchUpInside)
        scrollView.bottomAnchor.constraint(equalTo: actionButton.topAnchor, constant: -16).isActive = true
    }

    @objc private func handlePrimaryAction() {
        didRequestPrimaryAction?()
    }

    @objc private func handleUploadWorkAction() {
        endEditing(true)
        let titleText = (uploadTitleField?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard titleText.isEmpty == false else {
            MorviToastView.show("Please enter the title", in: self)
            return
        }

        let themeTitles = uploadThemeFlowView?.selectedTitles ?? []
        guard themeTitles.isEmpty == false else {
            MorviToastView.show("Please select theme", in: self)
            return
        }

        let detailText = (uploadDetailTextView?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard detailText.isEmpty == false else {
            MorviToastView.show("Please enter description", in: self)
            return
        }

        guard let uploadMediaAsset,
              let uploadCoverAsset,
              let uploadMediaSize,
              uploadMediaSize.width > 0,
              uploadMediaSize.height > 0 else {
            MorviToastView.show("Please upload image", in: self)
            return
        }

        didSubmitUploadWork?(
            WorkUploadDraft(
                titleText: titleText,
                detailText: detailText,
                themeTitles: themeTitles,
                mediaKind: uploadMediaKind,
                mediaAsset: uploadMediaAsset,
                coverAsset: uploadCoverAsset,
                mediaSize: uploadMediaSize,
                durationSeconds: uploadDurationSeconds
            )
        )
    }

    private enum ConnectionRosterKind {
        case outbound
        case inbound
    }

    private func renderRestrictedList() {
        renderRosterList(
            title: "Blacklist",
            entries: AccountSessionCenter.shared.restrictedRoster(),
            accessoryImageName: "restricted_restore_icon",
            allowsRestrictionRemoval: true
        )
    }

    private func renderConnectionRoster(kind: ConnectionRosterKind) {
        switch kind {
        case .outbound:
            renderRosterList(
                title: "Following",
                entries: AccountSessionCenter.shared.outboundConnectionRoster(),
                accessoryImageName: "restricted_restore_icon",
                allowsOutboundConnectionRemoval: true
            )
        case .inbound:
            renderRosterList(
                title: "Followers",
                entries: AccountSessionCenter.shared.inboundConnectionRoster(),
                accessoryImageName: "dialogue_card_action_dark",
                allowsDialogueAction: true
            )
        }
    }

    private func renderRosterList(
        title: String,
        entries: [RelationRosterRecord],
        accessoryImageName: String? = nil,
        allowsDialogueAction: Bool = false,
        allowsOutboundConnectionRemoval: Bool = false,
        allowsRestrictionRemoval: Bool = false
    ) {
        addTopTitle(title)
        let listEntries = entries.map {
            RestrictedRosterListView.Entry(
                accountKey: $0.stableKey,
                name: $0.displayName,
                avatarAsset: $0.avatarAsset
            )
        }
        let listView = RestrictedRosterListView(
            entries: listEntries,
            accessoryImageName: accessoryImageName,
            emptyCopy: rosterEmptyCopy(for: title)
        )
        listView.didSelectEntry = { [weak self] entry in
            self?.requestPublicPersona(subjectKey: entry.accountKey)
        }
        if allowsDialogueAction {
            listView.didTapAction = { [weak self] entry in
                self?.requestRosterDialogue(accountKey: entry.accountKey)
            }
        }
        if allowsOutboundConnectionRemoval {
            listView.didTapAction = { [weak self] entry in
                self?.removeOutboundConnectionRosterEntry(accountKey: entry.accountKey)
            }
        }
        if allowsRestrictionRemoval {
            listView.didTapAction = { [weak self] entry in
                self?.removeRestrictionRosterEntry(accountKey: entry.accountKey)
            }
        }
        addSubview(listView)
        listView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            listView.leadingAnchor.constraint(equalTo: leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: trailingAnchor),
            listView.topAnchor.constraint(equalTo: topAnchor, constant: 120),
            listView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func rosterEmptyCopy(for title: String) -> String {
        switch title {
        case "Blacklist":
            return "No blocked users"
        case "Following":
            return "No following yet"
        case "Followers":
            return "No followers yet"
        default:
            return "No data yet"
        }
    }

    private func requestRosterDialogue(accountKey: String) {
        showProgressOverlay()
        guard AccountSessionCenter.shared.isSignedIn else {
            hideProgressOverlay { [weak self] in
                self?.didRequestOverlayPage?(.accessGate)
            }
            return
        }
        guard AccountSessionCenter.shared.isActiveAccount(accountKey) == false else {
            hideProgressOverlay { [weak self] in
                guard let self else { return }
                MorviToastView.show("You cannot chat with yourself.", in: self)
            }
            return
        }
        guard AccountSessionCenter.shared.hasMutualConnection(with: accountKey) else {
            hideProgressOverlay { [weak self] in
                guard let self else { return }
                MorviToastView.show("You need to follow each other first.", in: self)
            }
            return
        }
        let profile = AccountSessionCenter.shared.safetyProfile(accountKey: accountKey)
        RouteContextStore.setTargetAccountKey(accountKey)
        RouteContextStore.setTargetDialogueThread(key: nil, title: profile?.displayName)
        hideProgressOverlay { [weak self] in
            guard let self else { return }
            if let didRequestSubjectPage {
                didRequestSubjectPage(.directDialogue, accountKey)
            } else {
                didRequestPage?(.directDialogue)
            }
        }
    }

    private func removeOutboundConnectionRosterEntry(accountKey: String) {
        showProgressOverlay()
        do {
            let didRemove = try AccountSessionCenter.shared.removeOutboundConnectionFromRoster(accountKey: accountKey)
            guard didRemove else {
                hideProgressOverlay { [weak self] in
                    guard let self else { return }
                    MorviToastView.show("Unable to update following.", in: self)
                }
                return
            }
            hideProgressOverlay { [weak self] in
                guard let self else { return }
                MorviToastView.show("Removed from following.", in: self)
                reloadRenderedContent()
            }
        } catch {
            hideProgressOverlay { [weak self] in
                guard let self else { return }
                MorviToastView.show("Unable to update following.", in: self)
            }
        }
    }

    private func removeRestrictionRosterEntry(accountKey: String) {
        showProgressOverlay()
        do {
            let didRemove = try AccountSessionCenter.shared.removeRestrictionFromRoster(accountKey: accountKey)
            guard didRemove else {
                hideProgressOverlay { [weak self] in
                    guard let self else { return }
                    MorviToastView.show("Unable to update blacklist.", in: self)
                }
                return
            }
            hideProgressOverlay { [weak self] in
                guard let self else { return }
                MorviToastView.show("Removed from blacklist.", in: self)
                reloadRenderedContent()
            }
        } catch {
            hideProgressOverlay { [weak self] in
                guard let self else { return }
                MorviToastView.show("Unable to update blacklist.", in: self)
            }
        }
    }

    private func renderAgreement() {
        addTopTitle(RouteContextStore.currentAgreementTitle() ?? "EULA")
        let bottomBar: UIView?
        if showsAgreementActionArea {
            let actionBar = UIView()
            actionBar.backgroundColor = .clear
            addSubview(actionBar)
            actionBar.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                actionBar.leadingAnchor.constraint(equalTo: leadingAnchor),
                actionBar.trailingAnchor.constraint(equalTo: trailingAnchor),
                actionBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -32),
                actionBar.heightAnchor.constraint(equalToConstant: 96)
            ])
            bottomBar = actionBar
        } else {
            bottomBar = nil
        }

        let webView = WKWebView(frame: .zero)
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.contentInset.bottom = showsAgreementActionArea ? 16 : 0
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.navigationDelegate = self
        addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        var webConstraints = [
            webView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            webView.topAnchor.constraint(equalTo: topAnchor, constant: 120)
        ]
        if let bottomBar {
            webConstraints.append(webView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -16))
        } else {
            webConstraints.append(webView.bottomAnchor.constraint(equalTo: bottomAnchor))
        }
        NSLayoutConstraint.activate(webConstraints)

        if let bottomBar {
            addPillButton("Cancel", top: 0, left: 48, width: 124, dark: false, fontWeight: .medium, parent: bottomBar)
            addPillButton("I agree", top: 0, left: 204, width: 124, dark: true, fontWeight: .medium, parent: bottomBar)
            addAgreementConsentLine(top: 76, parent: bottomBar)
            bringSubviewToFront(bottomBar)
        }
        showProgressOverlay()
        if let agreementURL = agreementURL() {
            webView.load(URLRequest(url: agreementURL))
        } else {
            webView.loadHTMLString(agreementHTML(), baseURL: nil)
        }
    }

    private func agreementURL() -> URL? {
        let title = RouteContextStore.currentAgreementTitle()
        let urlString: String
        switch title {
        case "Privacy Policy":
            urlString = Self.privacyPolicyURLString
        case "User Agreement":
            urlString = Self.userAgreementURLString
        default:
            return nil
        }
        return URL(string: urlString)
    }

    private func agreementHTML() -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
        <style>
        html, body {
            margin: 0;
            padding: 0;
            background: transparent;
            color: #5E5E5E;
            font-family: "SourceHanSansSC-Regular", -apple-system, BlinkMacSystemFont, sans-serif;
            font-size: 16px;
            line-height: 1.42;
            -webkit-text-size-adjust: 100%;
        }
        p {
            margin: 0;
        }
        .section {
            margin-top: 0;
        }
        ul {
            margin: 0;
            padding-left: 16px;
        }
        li {
            margin: 0;
        }
        a {
            color: #3F3F3F;
            text-decoration: underline;
        }
        </style>
        </head>
        <body>
        <p>This End User License Agreement (EULA) governs your use of the Morvi Application (the "App"). By downloading, accessing or using the App, you agree to be bound by this Agreement. If you do not agree, you may not use the App.</p>
        <p class="section">1. Qualifications</p>
        <p>By using the App, you confirm that you are at least 18 years of age. You agree to provide true and accurate age information. If you are under 18, you are prohibited from using the App.</p>
        <p class="section">2. User Generated Content</p>
        <p>This App allows users to post, share and view street dance-related video content (including supporting text and pictures).</p>
        <p>By posting content ("User Content") on the App, you agree to the following:</p>
        <p class="section">2.1 Prohibited Content</p>
        <p>You may not post offensive, harmful, inappropriate or illegal content, including but not limited to:</p>
        <ul>
        <li>Hate speech, abuse, harassment, threats or personal attacks;</li>
        <li>Pornographic, explicit or vulgar content;</li>
        <li>Content promoting violence, discrimination, illegal activities or infringing others’ rights;</li>
        <li>Content irrelevant to street dance, violating public order and good customs, or used for unauthorized advertising;</li>
        <li>False or misleading information.</li>
        </ul>
        <p class="section">2.2 Content Licensing</p>
        <p>You retain ownership of your User Content, but by posting it, you grant Funksy a non-exclusive, royalty-free license to use, distribute, display and promote such content within the App and its related services.</p>
        <p class="section">3. Reporting and Response Mechanism</p>
        <p>3.1 Your Responsibilities</p>
        <p>If you find content violating this EULA, report it immediately via the App’s reporting mechanism.</p>
        <p>3.2 Our Response</p>
        <p>We will review reported content within 24 hours and take appropriate measures (e.g., removing content, warning or banning users). Repeated violations may result in permanent account suspension.</p>
        <p class="section">4. Privacy Policy</p>
        <p>By using the App, you acknowledge having read and agreed to our <a href="\(Self.privacyPolicyURLString)">Privacy Policy</a>, which details how we collect, use and protect your personal information.</p>
        <p class="section">5. Termination</p>
        <p>We may terminate or suspend your access to the App at any time, with or without notice. You may stop using the App and delete your account at any time.</p>
        <p class="section">6. Modification of the Agreement</p>
        <p>We may amend this Agreement at any time. Changes will be announced in the App; your continued use constitutes acceptance of revised terms.</p>
        <p class="section">7. Disclaimer</p>
        <p>The App is provided "AS IS" without any warranties. We do not guarantee it will be uninterrupted, error-free or secure, nor the accuracy of its content.</p>
        <p class="section">8. Limitation of Liability</p>
        <p>To the fullest extent permitted by law, we are not liable for any damages arising from your use of the App or its content.</p>
        </body>
        </html>
        """
    }

    private func showProgressOverlay() {
        let overlay = MorviProgressOverlayView()
        progressOverlayView = overlay
        overlay.show(in: self)
    }

    private func hideProgressOverlay(completion: (() -> Void)? = nil) {
        guard let overlay = progressOverlayView else {
            completion?()
            return
        }
        overlay.dismiss {
            completion?()
        }
        progressOverlayView = nil
    }

    func showBlockingProgress() {
        showProgressOverlay()
    }

    func hideBlockingProgress(completion: (() -> Void)? = nil) {
        hideProgressOverlay(completion: completion)
    }

    private func renderFeelingEditor() {
        backgroundColor = UIColor.black.withAlphaComponent(0.58)
        let sheet = UIView()
        sheet.backgroundColor = .white
        sheet.layer.cornerRadius = 20
        sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        addSubview(sheet)
        sheet.translatesAutoresizingMaskIntoConstraints = false
        let sheetBottomConstraint = sheet.bottomAnchor.constraint(equalTo: bottomAnchor)
        NSLayoutConstraint.activate([
            sheet.leadingAnchor.constraint(equalTo: leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: trailingAnchor),
            sheetBottomConstraint
        ])
        keyboardAvoidanceBottomConstraint = sheetBottomConstraint
        keyboardAvoidanceBaseBottomConstant = 0
        overlayContentView = sheet

        let grabber = UIView()
        grabber.backgroundColor = .white
        grabber.layer.cornerRadius = 2
        addSubview(grabber)
        grabber.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            grabber.centerXAnchor.constraint(equalTo: centerXAnchor),
            grabber.bottomAnchor.constraint(equalTo: sheet.topAnchor, constant: -6),
            grabber.widthAnchor.constraint(equalToConstant: 112),
            grabber.heightAnchor.constraint(equalToConstant: 4)
        ])

        let titleLabel = UILabel()
        titleLabel.text = "Today's feelings"
        titleLabel.font = AppFont.fredoka(31)
        titleLabel.textColor = .black
        sheet.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 20),
            titleLabel.topAnchor.constraint(equalTo: sheet.topAnchor, constant: 34)
        ])

        activeLayoutContainer = sheet
        let uploadButton = addButton(
            "Upload",
            bottom: 29,
            trailing: 20,
            filled: true,
            usesOneFont: true,
            cornerRadius: 12,
            shadowOpacity: 0,
            bottomPlateHeight: 3
        )
        uploadButton.addTarget(self, action: #selector(handleFeelingUploadTap), for: .touchUpInside)
        activeLayoutContainer = nil

        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 18
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor(white: 0.9, alpha: 1).cgColor
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.12
        card.layer.shadowOffset = CGSize(width: 0, height: 4)
        card.layer.shadowRadius = 14
        sheet.addSubview(card)
        card.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -20),
            card.topAnchor.constraint(equalTo: titleLabel.topAnchor, constant: 94),
            card.bottomAnchor.constraint(equalTo: uploadButton.topAnchor, constant: -20)
        ])

        addMoodPreview(
            topAnchor: card.topAnchor,
            topOffset: -41,
            trailing: 40,
            size: 100,
            parent: sheet
        )
        let feelingInput = addLargeField(
            "Input here...",
            height: 118,
            horizontalMargin: 16,
            parent: card,
            bottomAnchor: card.bottomAnchor,
            bottomInset: 16,
            textViewHandler: { [weak self] textView in
                self?.feelingInputTextView = textView
            }
        )
        feelingInput.topAnchor.constraint(equalTo: card.topAnchor, constant: 75).isActive = true
        keyboardAvoidanceInputView = feelingInput
        installKeyboardAvoidance()
        installBlankAreaKeyboardDismissal()
        sheet.layoutIfNeeded()
        (uploadButton.layer.sublayers?.first as? CAGradientLayer)?.frame = uploadButton.bounds
    }

    @objc private func handleFeelingUploadTap() {
        let text = (feelingInputTextView?.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else {
            MorviToastView.show("Please enter your feelings.", in: self)
            return
        }
        guard let accountKey = AccountSessionCenter.shared.activeAccountKey else {
            didRequestOverlayPage?(.accessGate)
            return
        }

        endEditing(true)
        showProgressOverlay()
        let descriptor = MoodDescriptor.descriptor(at: selectedMoodIndex)
        let timestamp = LocalDateText.now()
        let record = MoodEntryRecord(
            stableKey: "mood-\(UUID().uuidString.lowercased())",
            accountKey: accountKey,
            moodCode: min(max(selectedMoodIndex, 0), MoodDescriptor.all.count - 1),
            moodAsset: descriptor.assetName,
            moodTitle: descriptor.title,
            bodyText: text,
            toneCode: descriptor.toneCode,
            recordedAt: timestamp,
            updatedAt: timestamp
        )
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try self?.moodRepository.save(record)
                DispatchQueue.main.async {
                    self?.hideProgressOverlay {
                        guard let self else { return }
                        MorviToastView.show("Published successfully", in: self)
                        self.didCompleteMoodEntry?()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.hideProgressOverlay {
                        guard let self else { return }
                        MorviToastView.show("Upload failed", in: self)
                    }
                }
            }
        }
    }

    private func renderWeeklyFeeling() {
        let records: [MoodEntryRecord]
        if let accountKey = AccountSessionCenter.shared.activeAccountKey {
            let interval = currentWeekInterval()
            records = (try? moodRepository.entries(
                accountKey: accountKey,
                from: LocalDateText.string(from: interval.start),
                through: LocalDateText.string(from: interval.end)
            )) ?? []
        } else {
            records = []
        }
        let listView = WeeklyFeelingListView(records: records)
        addSubview(listView)
        listView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            listView.leadingAnchor.constraint(equalTo: leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: trailingAnchor),
            listView.topAnchor.constraint(equalTo: topAnchor),
            listView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func currentWeekInterval() -> DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        return calendar.dateInterval(of: .weekOfYear, for: Date())
            ?? DateInterval(start: calendar.startOfDay(for: Date()), duration: 7 * 24 * 60 * 60)
    }

    private func renderProfileEditor() {
        backgroundColor = UIColor.black.withAlphaComponent(0.58)
        let currentHeader = AccountSessionCenter.shared.activeHeaderContent()
        profileEditAvatarAsset = currentHeader?.avatarAsset

        let sheet = UIView()
        sheet.backgroundColor = .white
        sheet.layer.cornerRadius = 20
        sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        addSubview(sheet)
        sheet.translatesAutoresizingMaskIntoConstraints = false
        let sheetBottomConstraint = sheet.bottomAnchor.constraint(equalTo: bottomAnchor)
        NSLayoutConstraint.activate([
            sheet.leadingAnchor.constraint(equalTo: leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: trailingAnchor),
            sheet.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 180),
            sheetBottomConstraint
        ])
        overlayContentView = sheet

        let grabber = UIView()
        grabber.backgroundColor = .white
        grabber.layer.cornerRadius = 2
        addSubview(grabber)
        grabber.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            grabber.centerXAnchor.constraint(equalTo: centerXAnchor),
            grabber.bottomAnchor.constraint(equalTo: sheet.topAnchor, constant: -6),
            grabber.widthAnchor.constraint(equalToConstant: 112),
            grabber.heightAnchor.constraint(equalToConstant: 4)
        ])

        let titleLabel = UILabel()
        titleLabel.text = "Edit Profile"
        titleLabel.font = AppFont.fredoka(31)
        titleLabel.textColor = .black
        sheet.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 20),
            titleLabel.topAnchor.constraint(equalTo: sheet.topAnchor, constant: 34)
        ])

        let avatarView = UIImageView(
            image: resolveAccountAvatar(currentHeader?.avatarAsset) ?? UIImage(named: "default_avatar")
        )
        avatarView.backgroundColor = UIColor(white: 0.95, alpha: 1)
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 37
        sheet.addSubview(avatarView)
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            avatarView.centerXAnchor.constraint(equalTo: sheet.centerXAnchor),
            avatarView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 47),
            avatarView.widthAnchor.constraint(equalToConstant: 74),
            avatarView.heightAnchor.constraint(equalToConstant: 74)
        ])

        let editMark = UIImageView(image: UIImage(named: "profile_avatar_edit_mark"))
        editMark.backgroundColor = UIColor(red: 0.76, green: 1, blue: 0.20, alpha: 1)
        editMark.contentMode = .scaleAspectFit
        editMark.layer.cornerRadius = 12
        editMark.clipsToBounds = true
        sheet.addSubview(editMark)
        editMark.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            editMark.trailingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 4),
            editMark.bottomAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 2),
            editMark.widthAnchor.constraint(equalToConstant: 24),
            editMark.heightAnchor.constraint(equalToConstant: 24)
        ])

        let avatarTapArea = UIButton(type: .custom)
        avatarTapArea.backgroundColor = .clear
        sheet.addSubview(avatarTapArea)
        avatarTapArea.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            avatarTapArea.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarTapArea.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            avatarTapArea.widthAnchor.constraint(equalToConstant: 112),
            avatarTapArea.heightAnchor.constraint(equalToConstant: 112)
        ])
        avatarTapArea.addTarget(self, action: #selector(handleProfileAvatarTap), for: .touchUpInside)

        let nameLabel = UILabel()
        nameLabel.text = "Username:"
        nameLabel.font = AppFont.source(16, weight: .medium)
        nameLabel.textColor = .black
        sheet.addSubview(nameLabel)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 20),
            nameLabel.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 49)
        ])

        activeLayoutContainer = sheet
        let nameInput = addInputField(
            "Enter username",
            top: 0,
            topAnchor: nameLabel.bottomAnchor,
            topOffset: 8,
            fieldBackgroundColor: UIColor(red: 212 / 255, green: 1, blue: 59 / 255, alpha: 0.3),
            usesGradient: false
        )
        nameInput.text = currentHeader?.displayName
        let uploadButton = addButton(
            "Upload",
            top: nil,
            bottom: 29,
            trailing: 20,
            filled: true,
            usesOneFont: true,
            cornerRadius: 12,
            shadowOpacity: 0,
            bottomPlateHeight: 3
        )
        activeLayoutContainer = nil

        uploadButton.addTarget(self, action: #selector(handleProfileEditUploadTap), for: .touchUpInside)
        profileEditAvatarImageView = avatarView
        profileEditNameField = nameInput
        uploadButton.topAnchor.constraint(equalTo: nameInput.bottomAnchor, constant: 32).isActive = true
        keyboardAvoidanceBottomConstraint = sheetBottomConstraint
        keyboardAvoidanceBaseBottomConstant = 0
        keyboardAvoidanceInputView = nameInput
        installKeyboardAvoidance()
        installBlankAreaKeyboardDismissal()
    }

    func updateProfileEditorAvatar(image: UIImage, asset: String) {
        profileEditAvatarAsset = asset
        profileEditAvatarImageView?.image = image
    }

    @objc private func handleProfileAvatarTap() {
        didRequestProfileAvatarSelection?()
    }

    @objc private func handleProfileEditUploadTap() {
        didSubmitProfileEdit?(
            ProfileEditDraft(
                displayNameText: profileEditNameField?.text ?? "",
                avatarAsset: profileEditAvatarAsset
            )
        )
    }

    private func renderRepliesPanel() {
        let item = resolvedGalleryWork()
        backgroundColor = UIColor.black.withAlphaComponent(0.58)
        let sheet = UIView()
        sheet.backgroundColor = .white
        sheet.layer.cornerRadius = 20
        sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        addSubview(sheet)
        sheet.translatesAutoresizingMaskIntoConstraints = false
        let sheetBottomConstraint = sheet.bottomAnchor.constraint(equalTo: bottomAnchor)
        NSLayoutConstraint.activate([
            sheet.leadingAnchor.constraint(equalTo: leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: trailingAnchor),
            sheet.heightAnchor.constraint(equalToConstant: 391),
            sheetBottomConstraint
        ])
        overlayContentView = sheet

        let grabber = UIView()
        grabber.backgroundColor = .white
        grabber.layer.cornerRadius = 2
        addSubview(grabber)
        grabber.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            grabber.centerXAnchor.constraint(equalTo: centerXAnchor),
            grabber.bottomAnchor.constraint(equalTo: sheet.topAnchor, constant: -6),
            grabber.widthAnchor.constraint(equalToConstant: 112),
            grabber.heightAnchor.constraint(equalToConstant: 4)
        ])

        let inputBar = addInputBar(
            bottom: 29,
            text: "Say something",
            trailing: "",
            usesDashedBorder: true,
            in: self,
            textFieldHandler: { [weak self] field in
                self?.replyInputField = field
            },
            actionHandler: { [weak self] in
                self?.submitReply(for: item.stableKey)
            },
            bottomConstraintHandler: { [weak self] bottomConstraint in
                self?.keyboardAvoidanceBottomConstraint = bottomConstraint
                self?.keyboardAvoidanceBaseBottomConstant = -29
            }
        )
        let tableView = CancelFriendlyTableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 116
        tableView.register(ReplyListCell.self, forCellReuseIdentifier: ReplyListCell.reuseIdentifier)
        tableView.dataSource = replyListDataSource
        tableView.delegate = replyListDataSource
        sheet.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: sheet.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: sheet.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: sheet.topAnchor, constant: 15),
            tableView.bottomAnchor.constraint(equalTo: inputBar.topAnchor, constant: -20)
        ])
        reloadReplies(for: item.stableKey, in: tableView)
        replyListDataSource.didTapMore = { [weak self] accountKey in
            self?.didRequestSubjectOverlayPage?(.restrictPanel, accountKey)
        }
        keyboardAvoidanceInputView = inputBar
        installKeyboardAvoidance()
        installBlankAreaKeyboardDismissal()
    }

    private func reloadReplies(for workKey: String, in tableView: UITableView) {
        let entries = (try? creativeRepository.replies(workKey: workKey)) ?? []
        let items = entries.map {
            ReplyListItem(
                accountKey: $0.accountKey,
                avatarAsset: $0.avatarAsset,
                name: $0.displayName,
                text: $0.bodyText
            )
        }
        replyListDataSource.apply(items, to: tableView)
    }

    private func submitReply(for workKey: String) {
        guard let textField = replyInputField else { return }
        let text = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else {
            MorviToastView.show("Please enter content", in: self)
            return
        }
        guard let accountKey = AccountSessionCenter.shared.activeAccountKey else {
            didRequestOverlayPage?(.accessGate)
            return
        }
        endEditing(true)
        showProgressOverlay()
        DispatchQueue.global(qos: .userInitiated).async { [weak self, weak textField] in
            do {
                try self?.creativeRepository.addReply(
                    workKey: workKey,
                    accountKey: accountKey,
                    bodyText: text
                )
                DispatchQueue.main.async {
                    self?.hideProgressOverlay {
                        textField?.text = nil
                        guard let tableView = self?.overlayContentView?.subviews.compactMap({ $0 as? UITableView }).first else {
                            self?.reloadRenderedContent()
                            return
                        }
                        self?.reloadReplies(for: workKey, in: tableView)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.hideProgressOverlay {
                        guard let self else { return }
                        MorviToastView.show("Upload failed", in: self)
                    }
                }
            }
        }
    }

    private func isWorkReacted(_ workKey: String) -> Bool {
        guard let accountKey = AccountSessionCenter.shared.activeAccountKey else {
            return false
        }
        return (try? creativeRepository.hasReaction(workKey: workKey, accountKey: accountKey)) ?? false
    }

    private func toggleWorkReaction(workKey: String) {
        guard let accountKey = AccountSessionCenter.shared.activeAccountKey else {
            didRequestOverlayPage?(.accessGate)
            return
        }
        do {
            _ = try creativeRepository.toggleReaction(workKey: workKey, accountKey: accountKey)
            reloadRenderedContent()
        } catch {
            MorviToastView.show("Operation failed", in: self)
        }
    }

    private func renderReportPanel() {
        backgroundColor = UIColor.black.withAlphaComponent(0.58)
        let sheet = UIView()
        sheet.backgroundColor = .white
        sheet.layer.cornerRadius = 20
        sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        addSubview(sheet)
        sheet.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sheet.leadingAnchor.constraint(equalTo: leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: trailingAnchor),
            sheet.bottomAnchor.constraint(equalTo: bottomAnchor),
            sheet.heightAnchor.constraint(equalToConstant: 567)
        ])
        overlayContentView = sheet

        let grabber = UIView()
        grabber.backgroundColor = .white
        grabber.layer.cornerRadius = 2
        addSubview(grabber)
        grabber.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            grabber.centerXAnchor.constraint(equalTo: centerXAnchor),
            grabber.bottomAnchor.constraint(equalTo: sheet.topAnchor, constant: -7),
            grabber.widthAnchor.constraint(equalToConstant: 112),
            grabber.heightAnchor.constraint(equalToConstant: 4)
        ])

        activeLayoutContainer = sheet
        addText("Report", size: 31, weight: .black, top: 35, left: 20, usesOneFont: true)
        let rows = [
            "Politically sensitive",
            "Bloody violence",
            "Frequent harassment",
            "Infringement of rights",
            "Pornographic and vulgar",
            "Discrimination"
        ]
        for index in rows.indices {
            let top = CGFloat(87 + index * 64)
            addReportChoiceRow(rows[index], top: top, index: index, checked: index == selectedSafetyReasonIndex)
        }
        let uploadButton = addButton(
            "Upload",
            bottom: 29,
            trailing: 20,
            filled: true,
            usesOneFont: true,
            cornerRadius: 12,
            shadowOpacity: 0,
            bottomPlateHeight: 3
        )
        uploadButton.addTarget(self, action: #selector(submitSafetyNotice), for: .touchUpInside)
        activeLayoutContainer = nil
        installBlankAreaKeyboardDismissal()
    }

    private func renderRestrictPanel() {
        backgroundColor = UIColor.black.withAlphaComponent(0.58)
        let sheet = UIView()
        sheet.backgroundColor = .white
        sheet.layer.cornerRadius = 20
        sheet.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        addSubview(sheet)
        sheet.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sheet.leadingAnchor.constraint(equalTo: leadingAnchor),
            sheet.trailingAnchor.constraint(equalTo: trailingAnchor),
            sheet.bottomAnchor.constraint(equalTo: bottomAnchor),
            sheet.heightAnchor.constraint(equalToConstant: 252)
        ])
        overlayContentView = sheet

        let grabber = UIView()
        grabber.backgroundColor = .white
        grabber.layer.cornerRadius = 2
        addSubview(grabber)
        grabber.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            grabber.centerXAnchor.constraint(equalTo: centerXAnchor),
            grabber.bottomAnchor.constraint(equalTo: sheet.topAnchor, constant: -5),
            grabber.widthAnchor.constraint(equalToConstant: 112),
            grabber.heightAnchor.constraint(equalToConstant: 4)
        ])

        activeLayoutContainer = sheet
        addText("Report or block", size: 31, weight: .black, top: 28, left: 20, usesOneFont: true)
        let reportTile = addOptionTile(iconName: "restrict_report_icon", top: 81) { [weak self] in
            self?.requestModerationOverlay(.reportPanel)
        }
        let restrictTile = addOptionTile(iconName: "restrict_block_icon", top: 81) { [weak self] in
            self?.requestModerationOverlay(.restrictConfirm)
        }
        NSLayoutConstraint.activate([
            reportTile.leadingAnchor.constraint(equalTo: sheet.leadingAnchor, constant: 20),
            restrictTile.leadingAnchor.constraint(equalTo: reportTile.trailingAnchor, constant: 19),
            restrictTile.trailingAnchor.constraint(equalTo: sheet.trailingAnchor, constant: -20),
            reportTile.widthAnchor.constraint(equalTo: restrictTile.widthAnchor)
        ])
        activeLayoutContainer = nil
        installBlankAreaKeyboardDismissal()
    }

    private func requestModerationOverlay(_ page: ScenePage) {
        if let restrictionSubjectKey,
           let activeKey = AccountSessionCenter.shared.activeAccountKey,
           restrictionSubjectKey == activeKey {
            let text = page == .reportPanel ? "You can't report yourself." : "You can't block yourself."
            MorviToastView.show(text, in: self)
            return
        }
        if let didRequestSubjectOverlayPage {
            didRequestSubjectOverlayPage(page, restrictionSubjectKey)
        } else {
            didRequestOverlayPage?(page)
        }
    }

    private func requestPublicPersona(subjectKey: String?) {
        RouteContextStore.setTargetAccountKey(subjectKey)
        if let didRequestSubjectPage {
            didRequestSubjectPage(.publicPersona, subjectKey)
        } else {
            didRequestPage?(.publicPersona)
        }
    }

    private func resolvedRestrictionProfile() -> (displayName: String, avatarAsset: String?) {
        guard let restrictionSubjectKey,
              let profile = AccountSessionCenter.shared.safetyProfile(accountKey: restrictionSubjectKey) else {
            return ("Victoria", "profile_avatar")
        }
        return (profile.displayName, profile.avatarAsset ?? "profile_avatar")
    }

    @objc private func handleSafetyChoiceTap(_ sender: UIButton) {
        selectedSafetyReasonIndex = sender.tag
        updateSafetyChoiceIcons()
    }

    private func updateSafetyChoiceIcons() {
        let layoutContainer = activeLayoutContainer ?? overlayContentView ?? self
        for index in 0..<6 {
            let icon = layoutContainer.viewWithTag(9400 + index) as? UIImageView
            icon?.image = UIImage(
                named: index == selectedSafetyReasonIndex
                    ? "report_check_selected"
                    : "report_check_unselected"
            )
        }
    }

    @objc private func submitSafetyNotice() {
        guard let subjectKey = restrictionSubjectKey else {
            MorviToastView.show("Report failed", in: self)
            return
        }
        let hostView = owningController()?.view ?? superview ?? self
        let overlay = MorviProgressOverlayView()
        let reasonCode = selectedSafetyReasonIndex
        overlay.show(in: hostView)
        removeFromSuperview()
        DispatchQueue.global(qos: .userInitiated).async {
            let didSubmit: Bool
            do {
                didSubmit = try AccountSessionCenter.shared.submitSafetyNotice(
                    subjectKey: subjectKey,
                    reasonCode: reasonCode,
                    detailText: nil
                )
            } catch {
                didSubmit = false
            }
            DispatchQueue.main.async {
                overlay.dismiss {
                    MorviToastView.show(didSubmit ? "Report submitted" : "Report failed", in: hostView)
                }
            }
        }
    }

    private func renderConfirmCard(
        title: String?,
        text: String,
        confirm: String,
        portrait: Bool,
        showsWordmark: Bool = false,
        portraitAvatarAsset: String? = nil
    ) {
        backgroundColor = UIColor(white: 0, alpha: 0.58)
        let titleTop: CGFloat = 39
        let portraitAvatarTop: CGFloat = 41
        let portraitAvatarLeft: CGFloat = 120
        let portraitAvatarSize: CGFloat = 76
        let titleHeight = title == nil ? 0 : AppFont.fredoka(31).lineHeight
        let textTop: CGFloat = portrait
            ? portraitAvatarTop + portraitAvatarSize + restrictPopupNamePillHeight() / 2 + 20
            : (title == nil ? 39 : titleTop + titleHeight + 24)
        let textHeight = CGFloat(text.components(separatedBy: "\n").count) * sourceFont(for: text, size: 17, weight: .regular).lineHeight
        let buttonTop: CGFloat = textTop + textHeight + 24
        let panelHeight: CGFloat = portrait ? 340 : buttonTop + 50 + 36
        let panel = addCenteredPanel(width: 322, height: panelHeight, alpha: 1)
        panel.backgroundColor = .clear
        panel.layer.borderWidth = 0
        overlayContentView = panel
        let backgroundImageView = UIImageView(image: popupBackgroundImage())
        backgroundImageView.contentMode = .scaleToFill
        backgroundImageView.clipsToBounds = true
        panel.addSubview(backgroundImageView)
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backgroundImageView.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            backgroundImageView.topAnchor.constraint(equalTo: panel.topAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: panel.bottomAnchor)
        ])
        if showsWordmark {
            addPopupWordmark(to: panel)
        }
        activeLayoutContainer = panel
        if portrait {
            addRestrictPopupAvatar(
                top: portraitAvatarTop,
                left: portraitAvatarLeft,
                size: portraitAvatarSize,
                assetName: portraitAvatarAsset
            )
        }
        if let title {
            if portrait {
                addRestrictPopupNamePill(title, avatarTop: portraitAvatarTop, avatarLeft: portraitAvatarLeft, avatarSize: portraitAvatarSize)
            } else {
                addText(title, size: 31, weight: .black, top: titleTop, centered: true, usesOneFont: true)
            }
        }
        addText(text, size: 17, weight: .regular, top: textTop, left: 36)
        let cancelButton = addPillButton("Cancel", top: buttonTop, left: 36, width: 112, dark: false, fontWeight: .medium)
        cancelButton.addTarget(self, action: #selector(closePopupOverlay), for: .touchUpInside)
        let confirmButton = addPillButton(confirm, top: buttonTop, left: 174, width: 112, dark: true, fontWeight: .medium)
        if page == .accessGate {
            confirmButton.addTarget(self, action: #selector(openSignInFromPopup), for: .touchUpInside)
        } else if page == .spendConfirm {
            confirmButton.addTarget(self, action: #selector(confirmAssistantUnlock), for: .touchUpInside)
        } else if page == .creditShortage {
            confirmButton.addTarget(self, action: #selector(openWalletFromPopup), for: .touchUpInside)
        } else if page == .signOutConfirm {
            confirmButton.addTarget(self, action: #selector(confirmSignOut), for: .touchUpInside)
        } else if page == .exitConfirm {
            confirmButton.addTarget(self, action: #selector(confirmAccountRemoval), for: .touchUpInside)
        } else if page == .restrictConfirm {
            confirmButton.addTarget(self, action: #selector(confirmRestrictionAction), for: .touchUpInside)
        }
        activeLayoutContainer = nil
    }

    @objc private func closePopupOverlay() {
        removeFromSuperview()
    }

    @objc private func openSignInFromPopup() {
        let controller = owningController()
        removeFromSuperview()
        let authFlow = FlowShellController(rootViewController: EntrySceneController())
        authFlow.modalPresentationStyle = .fullScreen
        authFlow.modalTransitionStyle = .coverVertical
        controller?.present(authFlow, animated: true)
    }

    @objc private func showCreditShortagePopup() {
        didRequestOverlayPage?(.creditShortage)
    }

    @objc private func confirmAssistantUnlock() {
        let controller = owningController()
        let requestOverlay = didRequestOverlayPage
        let overlay = MorviProgressOverlayView()
        overlay.show(in: controller?.view ?? superview ?? self)
        removeFromSuperview()
        DispatchQueue.main.async {
            let didConsume: Bool
            do {
                didConsume = try AccountSessionCenter.shared.consumeActiveWalletBalanceValue(
                    amount: Self.assistantUnlockCost
                )
            } catch {
                didConsume = false
            }
            overlay.dismiss {
                guard didConsume else {
                    requestOverlay?(.creditShortage)
                    return
                }
                controller?.navigationController?.pushViewController(RouteFactory.controller(for: .assistantDialogue), animated: true)
            }
        }
    }

    @objc private func openWalletFromPopup() {
        let controller = owningController()
        removeFromSuperview()
        controller?.navigationController?.pushViewController(RouteFactory.controller(for: .wallet), animated: true)
    }

    @objc private func confirmSignOut() {
        AccountSessionCenter.shared.clearActiveSession()
        didCompleteSignOut?()
        removeFromSuperview()
    }

    @objc private func confirmAccountRemoval() {
        showProgressOverlay()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let didRemove = try AccountSessionCenter.shared.removeActiveAccount()
                DispatchQueue.main.async {
                    self?.hideProgressOverlay {
                        guard let self else { return }
                        guard didRemove else {
                            MorviToastView.show("Account deletion failed", in: self)
                            return
                        }
                        self.removeFromSuperview()
                        self.didCompleteAccountRemoval?()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.hideProgressOverlay {
                        guard let self else { return }
                        MorviToastView.show("Account deletion failed", in: self)
                    }
                }
            }
        }
    }

    @objc private func confirmRestrictionAction() {
        guard let subjectKey = restrictionSubjectKey else {
            MorviToastView.show("Action unavailable", in: self)
            return
        }
        let hostView = owningController()?.view ?? superview ?? self
        let overlay = MorviProgressOverlayView()
        overlay.show(in: hostView)
        removeFromSuperview()
        DispatchQueue.global(qos: .userInitiated).async {
            let didSubmit: Bool
            do {
                didSubmit = try AccountSessionCenter.shared.confirmRestriction(subjectKey: subjectKey)
            } catch {
                didSubmit = false
            }
            DispatchQueue.main.async {
                overlay.dismiss {
                    MorviToastView.show(didSubmit ? "Blocked" : "Action unavailable", in: hostView)
                }
            }
        }
    }

    private func owningController() -> UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController {
                return controller
            }
            responder = current.next
        }
        return nil
    }

    private func addPopupWordmark(to panel: UIView) {
        let imageView = UIImageView(image: UIImage(named: "popup_wordmark"))
        imageView.contentMode = .scaleAspectFit
        panel.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: panel.topAnchor, constant: 15),
            imageView.widthAnchor.constraint(equalToConstant: 237),
            imageView.heightAnchor.constraint(equalToConstant: 88)
        ])
    }

    private func addRestrictPopupAvatar(top: CGFloat, left: CGFloat, size: CGFloat, assetName: String? = nil) {
        let layoutContainer = activeLayoutContainer ?? self
        let ringInset: CGFloat = 6
        let ringView = UIImageView(image: UIImage(named: "restrict_avatar_ring"))
        ringView.contentMode = .scaleAspectFit
        layoutContainer.addSubview(ringView)
        ringView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            ringView.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left - ringInset),
            ringView.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top - ringInset),
            ringView.widthAnchor.constraint(equalToConstant: size + ringInset * 2),
            ringView.heightAnchor.constraint(equalToConstant: size + ringInset * 2)
        ])

        let imageView = UIImageView(image: UIImage(named: assetName ?? "profile_avatar"))
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = size / 2
        imageView.layer.masksToBounds = true
        layoutContainer.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            imageView.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            imageView.widthAnchor.constraint(equalToConstant: size),
            imageView.heightAnchor.constraint(equalToConstant: size)
        ])
    }

    private func addRestrictPopupNamePill(_ text: String, avatarTop: CGFloat, avatarLeft: CGFloat, avatarSize: CGFloat) {
        let layoutContainer = activeLayoutContainer ?? self
        let font = AppFont.source(16, weight: .medium)
        let horizontalPadding: CGFloat = 30
        let topPadding: CGFloat = 0
        let bottomPadding: CGFloat = 3
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        let width = ceil(textSize.width) + horizontalPadding * 2
        let height = restrictPopupNamePillHeight()
        let shadowDrop: CGFloat = 3
        let left = avatarLeft + avatarSize / 2 - width / 2
        let top = avatarTop + avatarSize - height / 2

        let shadowView = UIView()
        shadowView.backgroundColor = UIColor(red: 0.37, green: 0.68, blue: 0.03, alpha: 1)
        shadowView.layer.cornerRadius = height / 2
        shadowView.layer.cornerCurve = .continuous
        layoutContainer.addSubview(shadowView)
        shadowView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            shadowView.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            shadowView.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top + shadowDrop),
            shadowView.widthAnchor.constraint(equalToConstant: width),
            shadowView.heightAnchor.constraint(equalToConstant: height)
        ])

        let pillView = UIView()
        pillView.layer.cornerRadius = height / 2
        pillView.layer.cornerCurve = .continuous
        pillView.layer.masksToBounds = true
        layoutContainer.addSubview(pillView)
        pillView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pillView.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            pillView.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            pillView.widthAnchor.constraint(equalToConstant: width),
            pillView.heightAnchor.constraint(equalToConstant: height)
        ])

        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.82, green: 1, blue: 0.20, alpha: 1).cgColor,
            UIColor(red: 0.84, green: 0.97, blue: 0.93, alpha: 1).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.frame = CGRect(x: 0, y: 0, width: width, height: height)
        pillView.layer.insertSublayer(gradientLayer, at: 0)

        let label = UILabel()
        label.text = text
        label.textColor = .black
        label.font = font
        label.textAlignment = .center
        pillView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: pillView.leadingAnchor, constant: horizontalPadding),
            label.trailingAnchor.constraint(equalTo: pillView.trailingAnchor, constant: -horizontalPadding),
            label.topAnchor.constraint(equalTo: pillView.topAnchor, constant: topPadding),
            label.bottomAnchor.constraint(equalTo: pillView.bottomAnchor, constant: -bottomPadding)
        ])
    }

    private func restrictPopupNamePillHeight() -> CGFloat {
        ceil(AppFont.source(16, weight: .medium).lineHeight) + 3
    }

    private func popupBackgroundImage() -> UIImage? {
        guard let image = UIImage(named: "login_popup_background") else { return nil }
        let centerLength = 20 / max(image.scale, 1)
        let horizontalInset = max((image.size.width - centerLength) / 2, 0)
        let verticalInset = max((image.size.height - centerLength) / 2, 0)
        return image.resizableImage(
            withCapInsets: UIEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            ),
            resizingMode: .stretch
        )
    }

    @discardableResult
    private func addText(
        _ text: String,
        size: CGFloat,
        weight: UIFont.Weight,
        top: CGFloat,
        topAnchor: NSLayoutYAxisAnchor? = nil,
        topOffset: CGFloat = 0,
        left: CGFloat? = nil,
        centered: Bool = false,
        color: UIColor = .black,
        parent: UIView? = nil,
        usesOneFont: Bool = false
    ) -> UILabel {
        let layoutContainer = parent ?? activeLayoutContainer ?? self
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.textColor = color
        label.font = usesOneFont || usesFredokaText(text)
            ? AppFont.fredoka(size)
            : sourceFont(for: text, size: size, weight: weight)
        layoutContainer.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        if centered {
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: layoutContainer.centerXAnchor),
                label.topAnchor.constraint(
                    equalTo: topAnchor ?? layoutContainer.topAnchor,
                    constant: topAnchor == nil ? top : topOffset
                )
            ])
        } else {
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left ?? 20),
                label.topAnchor.constraint(
                    equalTo: topAnchor ?? layoutContainer.topAnchor,
                    constant: topAnchor == nil ? top : topOffset
                ),
                label.trailingAnchor.constraint(lessThanOrEqualTo: layoutContainer.trailingAnchor, constant: -20)
            ])
        }
        return label
    }

    private func addEntrySignUpPrompt(top: CGFloat) {
        let layoutContainer = activeLayoutContainer ?? self
        let text = "Don't have an account? Sign up"
        let attributedText = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: AppFont.source(12),
                .foregroundColor: UIColor.black
            ]
        )
        attributedText.addAttribute(
            .underlineStyle,
            value: NSUnderlineStyle.single.rawValue,
            range: (text as NSString).range(of: "Sign up")
        )

        let label = UILabel()
        label.attributedText = attributedText
        layoutContainer.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: layoutContainer.centerXAnchor),
            label.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top)
        ])
    }

    @discardableResult
    private func addButton(
        _ text: String,
        top: CGFloat? = nil,
        bottom: CGFloat? = nil,
        left: CGFloat = 20,
        width: CGFloat = 335,
        trailing: CGFloat? = 20,
        filled: Bool,
        dark: Bool = false,
        usesOneFont: Bool = false,
        cornerRadius: CGFloat = 24,
        shadowOffset: CGSize = CGSize(width: 0, height: 4),
        shadowRadius: CGFloat = 9,
        shadowOpacity: Float? = nil,
        bottomPlateHeight: CGFloat = 0
    ) -> UIButton {
        let layoutContainer = activeLayoutContainer ?? self
        if bottomPlateHeight > 0 {
            let plate = UIView()
            plate.backgroundColor = UIColor(red: 0.39, green: 0.68, blue: 0.02, alpha: 1)
            plate.layer.cornerRadius = cornerRadius
            plate.layer.masksToBounds = true
            layoutContainer.addSubview(plate)
            plate.translatesAutoresizingMaskIntoConstraints = false
            var plateConstraints = [
                plate.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
                plate.heightAnchor.constraint(equalToConstant: 52 + bottomPlateHeight)
            ]
            if let bottom {
                plateConstraints.append(
                    plate.bottomAnchor.constraint(equalTo: layoutContainer.bottomAnchor, constant: -bottom)
                )
            } else if let top {
                plateConstraints.append(plate.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top))
            }
            if let trailing {
                plateConstraints.append(
                    plate.trailingAnchor.constraint(equalTo: layoutContainer.trailingAnchor, constant: -trailing)
                )
            } else {
                plateConstraints.append(plate.widthAnchor.constraint(equalToConstant: width))
            }
            NSLayoutConstraint.activate(plateConstraints)
        }
        let button: UIButton = filled ? GradientActionButton() : UIButton(type: .custom)
        button.setTitle(text, for: .normal)
        button.titleLabel?.font = usesOneFont || usesFredokaText(text) ? AppFont.fredoka(16) : AppFont.source(16, weight: .black)
        button.setTitleColor(dark ? UIColor(red: 0.78, green: 1, blue: 0.20, alpha: 1) : .black, for: .normal)
        button.backgroundColor = dark ? UIColor(red: 0.04, green: 0.05, blue: 0.04, alpha: 1) : (filled ? .clear : .white)
        button.layer.cornerRadius = cornerRadius
        button.layer.borderWidth = filled || dark ? 0 : 1
        button.layer.borderColor = UIColor(white: 0.9, alpha: 1).cgColor
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = shadowOpacity ?? (filled ? 0.14 : 0.06)
        button.layer.shadowOffset = shadowOffset
        button.layer.shadowRadius = shadowRadius
        layoutContainer.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        var buttonConstraints = [
            button.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            button.heightAnchor.constraint(equalToConstant: 52)
        ]
        if let bottom {
            buttonConstraints.append(
                button.bottomAnchor.constraint(
                    equalTo: layoutContainer.bottomAnchor,
                    constant: -(bottom + bottomPlateHeight)
                )
            )
        } else if let top {
            buttonConstraints.append(button.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top))
        }
        if let trailing {
            buttonConstraints.append(
                button.trailingAnchor.constraint(equalTo: layoutContainer.trailingAnchor, constant: -trailing)
            )
        } else {
            buttonConstraints.append(button.widthAnchor.constraint(equalToConstant: width))
        }
        NSLayoutConstraint.activate(buttonConstraints)
        return button
    }

    private func usesFredokaText(_ text: String) -> Bool {
        text.caseInsensitiveCompare("Morvi") == .orderedSame
            || text == "Login by email"
            || text == "I'm new"
            || text == "Sign in"
            || text == "Log in"
            || text == "Welcome back"
            || text == "Save your feelings"
            || text == "Discover"
            || text == "Recot Bot"
            || text == "Upload"
    }

    private func sourceFont(for text: String, size: CGFloat, weight: UIFont.Weight) -> UIFont {
        if text == "Hello, Anna!\nDid everything go\nsmoothly today?" {
            return UIFont(name: "SourceHanSansSC-Normal", size: size) ?? AppFont.source(size, weight: weight)
        }
        return AppFont.source(size, weight: weight)
    }

    private func addUnderlinedText(_ text: String, size: CGFloat, top: CGFloat, left: CGFloat, color: UIColor) {
        let layoutContainer = activeLayoutContainer ?? self
        let label = UILabel()
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: AppFont.source(size),
                .foregroundColor: color,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )
        layoutContainer.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            label.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top)
        ])
    }

    private func addField(_ placeholder: String, top: CGFloat) {
        let field = addFieldContainer(top: top)
        let label = UILabel()
        label.text = placeholder
        label.textColor = .gray
        label.font = AppFont.source(15)
        field.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: field.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: field.centerYAnchor)
        ])
    }

    @discardableResult
    private func addInputField(
        _ placeholder: String,
        top: CGFloat,
        topAnchor: NSLayoutYAxisAnchor? = nil,
        topOffset: CGFloat = 0,
        keyboardType: UIKeyboardType = .default,
        isSecureTextEntry: Bool = false,
        fieldBackgroundColor: UIColor = .clear,
        usesGradient: Bool = true
    ) -> UITextField {
        let field = addFieldContainer(
            top: top,
            topAnchor: topAnchor,
            topOffset: topOffset,
            backgroundColor: fieldBackgroundColor,
            usesGradient: usesGradient
        )
        let textField = UITextField()
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.textColor = .black
        textField.tintColor = .black
        textField.font = AppFont.source(15)
        textField.keyboardType = keyboardType
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.isSecureTextEntry = isSecureTextEntry
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .font: AppFont.source(15),
                .foregroundColor: UIColor.gray
            ]
        )
        field.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: field.leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: field.trailingAnchor, constant: -16),
            textField.topAnchor.constraint(equalTo: field.topAnchor),
            textField.bottomAnchor.constraint(equalTo: field.bottomAnchor)
        ])
        return textField
    }

    private func addFieldContainer(
        top: CGFloat,
        topAnchor: NSLayoutYAxisAnchor? = nil,
        topOffset: CGFloat = 0,
        backgroundColor: UIColor = .clear,
        usesGradient: Bool = true
    ) -> UIView {
        let layoutContainer = activeLayoutContainer ?? self
        let field = AdaptiveInputView(
            backgroundColor: backgroundColor,
            gradientColors: usesGradient ? [
                UIColor(red: 0.94, green: 1, blue: 0.72, alpha: 1),
                UIColor(red: 0.88, green: 1, blue: 0.95, alpha: 1)
            ] : nil
        )
        layoutContainer.addSubview(field)
        field.translatesAutoresizingMaskIntoConstraints = false
        var constraints = [
            field.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: 20),
            field.trailingAnchor.constraint(equalTo: layoutContainer.trailingAnchor, constant: -20),
            field.heightAnchor.constraint(equalToConstant: 54)
        ]
        if let topAnchor {
            constraints.append(field.topAnchor.constraint(equalTo: topAnchor, constant: topOffset))
        } else {
            constraints.append(field.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top))
        }
        NSLayoutConstraint.activate(constraints)
        return field
    }

    private func installKeyboardAvoidance() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardFrameChange),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardFrameChange),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    private func installBlankAreaKeyboardDismissal() {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleBlankAreaTap))
        gesture.cancelsTouchesInView = false
        gesture.delegate = self
        addGestureRecognizer(gesture)
    }

    @objc private func handleBlankAreaTap(_ gesture: UITapGestureRecognizer) {
        guard let contentView = overlayContentView else {
            endEditing(true)
            return
        }

        if contentView.frame.contains(gesture.location(in: self)) {
            endEditing(true)
        } else if keyboardIsVisible {
            endEditing(true)
        } else {
            didTapOutsideContent?()
        }
    }

    @objc private func handleKeyboardFrameChange(_ notification: Notification) {
        let keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .zero
        let keyboardFrameInView = convert(keyboardFrame, from: nil)
        let isHiding = notification.name == UIResponder.keyboardWillHideNotification
        keyboardIsVisible = !isHiding && keyboardFrameInView.minY < bounds.maxY
        if isHiding {
            removeUploadThemeEntryBar()
        }
        if let scrollView = keyboardAwareScrollView {
            updateKeyboardAwareScrollView(
                scrollView,
                keyboardFrame: keyboardFrameInView,
                isHiding: isHiding
            )
        }

        guard
            let bottomConstraint = keyboardAvoidanceBottomConstraint,
            let inputView = keyboardAvoidanceInputView
        else { return }

        let baseConstant = keyboardAvoidanceBaseBottomConstant
        let keyboardGap: CGFloat = 10
        let inputFrame = inputView.convert(inputView.bounds, to: self)
        let unshiftedInputMaxY = inputFrame.maxY - (bottomConstraint.constant - baseConstant)
        let requiredOffset = isHiding
            ? 0
            : max(0, unshiftedInputMaxY + keyboardGap - keyboardFrameInView.minY)
        bottomConstraint.constant = baseConstant - requiredOffset

        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25
        let curveValue = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        let options = UIView.AnimationOptions(rawValue: curveValue << 16)
        UIView.animate(withDuration: duration, delay: 0, options: options) {
            self.layoutIfNeeded()
        } completion: { [weak self] _ in
            guard let self = self, self.keyboardIsVisible else { return }
            self.keyboardSyncedDialogueFlowListView?.scrollToEnd(animated: true)
        }
    }

    private func updateKeyboardAwareScrollView(
        _ scrollView: UIScrollView,
        keyboardFrame: CGRect,
        isHiding: Bool
    ) {
        let scrollFrame = scrollView.convert(scrollView.bounds, to: self)
        let scrollOverlap = max(0, scrollFrame.maxY - keyboardFrame.minY)

        if isHiding || scrollOverlap == 0 {
            if let baseInset = keyboardBaseContentInset {
                scrollView.contentInset = baseInset
            }
            if let baseIndicatorInsets = keyboardBaseIndicatorInsets {
                scrollView.verticalScrollIndicatorInsets = baseIndicatorInsets
            }
            if let baseOffset = keyboardBaseContentOffset {
                scrollView.setContentOffset(baseOffset, animated: true)
            }
            keyboardBaseContentInset = nil
            keyboardBaseIndicatorInsets = nil
            keyboardBaseContentOffset = nil
            return
        }

        if keyboardBaseContentInset == nil {
            keyboardBaseContentInset = scrollView.contentInset
            keyboardBaseIndicatorInsets = scrollView.verticalScrollIndicatorInsets
            keyboardBaseContentOffset = scrollView.contentOffset
        }

        let baseInset = keyboardBaseContentInset ?? .zero
        let baseIndicatorInsets = keyboardBaseIndicatorInsets ?? .zero
        scrollView.contentInset.bottom = baseInset.bottom + scrollOverlap + 10
        scrollView.verticalScrollIndicatorInsets.bottom = baseIndicatorInsets.bottom + scrollOverlap + 10

        guard let activeInput = firstResponder(in: scrollView) else { return }
        let targetRect = activeInput.convert(activeInput.bounds.insetBy(dx: 0, dy: -18), to: scrollView)
        let visibleHeight = max(1, keyboardFrame.minY - scrollFrame.minY - 10)
        let baseOffsetY = keyboardBaseContentOffset?.y ?? scrollView.contentOffset.y
        let requiredOffsetY = max(baseOffsetY, targetRect.maxY - visibleHeight)
        let minimumOffsetY = -scrollView.contentInset.top
        let maximumOffsetY = max(
            minimumOffsetY,
            scrollView.contentSize.height + scrollView.contentInset.bottom - scrollView.bounds.height
        )
        let clampedOffsetY = min(max(requiredOffsetY, minimumOffsetY), maximumOffsetY)
        scrollView.setContentOffset(
            CGPoint(x: scrollView.contentOffset.x, y: clampedOffsetY),
            animated: true
        )
    }

    private func firstResponder(in view: UIView) -> UIView? {
        if view.isFirstResponder {
            return view
        }
        for subview in view.subviews {
            if let responder = firstResponder(in: subview) {
                return responder
            }
        }
        return nil
    }

    private func addLogo(top: CGFloat) {
        let layoutContainer = activeLayoutContainer ?? self
        let imageView = UIImageView(image: UIImage(named: "LOGO"))
        imageView.contentMode = .scaleAspectFit
        layoutContainer.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: layoutContainer.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            imageView.widthAnchor.constraint(equalToConstant: 120),
            imageView.heightAnchor.constraint(equalToConstant: 120)
        ])
    }

    private func addAvatar(top: CGFloat, left: CGFloat) {
        addPortrait(top: top, left: left, size: 58, tint: .warm)
    }

    private func addProfileAvatar(
        image: UIImage? = nil,
        top: CGFloat,
        left: CGFloat,
        size: CGFloat,
        backgroundColor: UIColor = UIColor(white: 0.94, alpha: 1),
        showsBorder: Bool = true,
        showsShadow: Bool = true
    ) {
        let layoutContainer = activeLayoutContainer ?? self
        let imageView = UIImageView(image: image ?? UIImage(named: "profile_avatar"))
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = backgroundColor
        imageView.layer.cornerRadius = size / 2
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = showsBorder ? 2 : 0
        imageView.layer.borderColor = showsBorder ? UIColor.white.cgColor : UIColor.clear.cgColor

        let shadowHost = UIView()
        shadowHost.layer.shadowColor = UIColor.black.cgColor
        shadowHost.layer.shadowOpacity = showsShadow ? 0.18 : 0
        shadowHost.layer.shadowOffset = CGSize(width: 0, height: 2)
        shadowHost.layer.shadowRadius = 5
        layoutContainer.addSubview(shadowHost)
        shadowHost.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            shadowHost.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            shadowHost.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            shadowHost.widthAnchor.constraint(equalToConstant: size),
            shadowHost.heightAnchor.constraint(equalToConstant: size)
        ])

        shadowHost.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: shadowHost.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: shadowHost.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: shadowHost.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: shadowHost.bottomAnchor)
        ])
    }

    private func resolveAccountAvatar(_ asset: String?) -> UIImage? {
        resolveVisualAsset(asset)
    }

    private func resolveVisualAsset(_ asset: String?) -> UIImage? {
        guard let asset, asset.isEmpty == false else {
            return nil
        }
        guard asset.hasPrefix("local-avatar/") || asset.hasPrefix("local-work/") else {
            return UIImage(named: asset)
        }
        return resolveStoredImage(asset)
    }

    private func resolveStoredImage(_ asset: String) -> UIImage? {
        let prefix: String
        let folderName: String
        if asset.hasPrefix("local-avatar/") {
            prefix = "local-avatar/"
            folderName = "Avatars"
        } else if asset.hasPrefix("local-work/") {
            prefix = "local-work/"
            folderName = "WorkMedia"
        } else {
            return nil
        }
        let fileName = String(asset.dropFirst(prefix.count))
        guard fileName.isEmpty == false,
              let baseDirectory = try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
              ) else {
            return nil
        }
        let fileURL = baseDirectory
            .appendingPathComponent("Morvi", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent(fileName)
        let cacheKey = asset as NSString
        if let cachedImage = Self.visualAssetCache.object(forKey: cacheKey) {
            return cachedImage
        }
        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1400
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else { return nil }
        let image = UIImage(cgImage: cgImage)
        Self.visualAssetCache.setObject(image, forKey: cacheKey)
        return image
    }

    private func addAvatarEditBadge(top: CGFloat, left: CGFloat) {
        let layoutContainer = activeLayoutContainer ?? self
        let iconView = UIImageView(image: UIImage(named: "avatar_edit_badge"))
        iconView.contentMode = .scaleAspectFit
        layoutContainer.addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            iconView.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    private func addCircle(text: String, top: CGFloat, left: CGFloat, size: CGFloat, color: UIColor = UIColor(white: 0.94, alpha: 1), textColor: UIColor = .black) {
        let layoutContainer = activeLayoutContainer ?? self
        let view = UILabel()
        view.text = text
        view.textAlignment = .center
        view.font = AppFont.source(size * 0.44, weight: .bold)
        view.textColor = textColor
        view.backgroundColor = color
        view.layer.cornerRadius = size / 2
        view.layer.masksToBounds = true
        layoutContainer.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            view.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            view.widthAnchor.constraint(equalToConstant: size),
            view.heightAnchor.constraint(equalToConstant: size)
        ])
    }

    private func addAppleLoginCircle(top: CGFloat) {
        let layoutContainer = activeLayoutContainer ?? self
        let background = UIView()
        background.backgroundColor = UIColor(white: 0.94, alpha: 1)
        background.layer.cornerRadius = 20
        background.layer.masksToBounds = true
        layoutContainer.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        let icon = UILabel()
        icon.text = ""
        icon.textAlignment = .center
        icon.font = AppFont.source(20, weight: .bold)
        background.addSubview(icon)
        icon.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            background.centerXAnchor.constraint(equalTo: layoutContainer.centerXAnchor),
            background.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            background.widthAnchor.constraint(equalToConstant: 40),
            background.heightAnchor.constraint(equalToConstant: 40),

            icon.centerXAnchor.constraint(equalTo: background.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: background.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    private func addPanel(top: CGFloat, left: CGFloat, width: CGFloat, height: CGFloat, alpha: CGFloat, trailing: CGFloat? = nil) -> UIView {
        let layoutContainer = activeLayoutContainer ?? self
        let panel = makePanel(alpha: alpha)
        layoutContainer.addSubview(panel)
        panel.translatesAutoresizingMaskIntoConstraints = false
        var panelConstraints = [
            panel.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            panel.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            panel.heightAnchor.constraint(equalToConstant: height)
        ]
        if let trailing {
            panelConstraints.append(panel.trailingAnchor.constraint(equalTo: layoutContainer.trailingAnchor, constant: -trailing))
        } else {
            panelConstraints.append(panel.widthAnchor.constraint(equalToConstant: width))
        }
        NSLayoutConstraint.activate(panelConstraints)
        return panel
    }

    private func addCenteredPanel(width: CGFloat, height: CGFloat, alpha: CGFloat) -> UIView {
        let layoutContainer = activeLayoutContainer ?? self
        let panel = makePanel(alpha: alpha)
        layoutContainer.addSubview(panel)
        panel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: layoutContainer.centerXAnchor),
            panel.centerYAnchor.constraint(equalTo: layoutContainer.centerYAnchor),
            panel.widthAnchor.constraint(equalToConstant: min(width, max(0, adaptiveLayoutWidth - 60))),
            panel.heightAnchor.constraint(equalToConstant: height)
        ])
        return panel
    }

    private func makePanel(alpha: CGFloat) -> UIView {
        let panel: UIView
        if alpha < 1 {
            let holder = UIView()
            holder.backgroundColor = .clear
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialLight))
            blur.backgroundColor = UIColor(white: 1, alpha: alpha)
            blur.layer.cornerRadius = 18
            blur.layer.masksToBounds = true
            holder.addSubview(blur)
            blur.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                blur.leadingAnchor.constraint(equalTo: holder.leadingAnchor),
                blur.trailingAnchor.constraint(equalTo: holder.trailingAnchor),
                blur.topAnchor.constraint(equalTo: holder.topAnchor),
                blur.bottomAnchor.constraint(equalTo: holder.bottomAnchor)
            ])
            panel = holder
        } else {
            panel = UIView()
            panel.backgroundColor = .white
            panel.layer.borderWidth = 1
            panel.layer.borderColor = UIColor(white: 0.93, alpha: 1).cgColor
        }
        panel.layer.cornerRadius = 18
        panel.layer.masksToBounds = false
        panel.layer.shadowColor = UIColor.black.cgColor
        panel.layer.shadowOpacity = 0.12
        panel.layer.shadowOffset = CGSize(width: 0, height: 4)
        panel.layer.shadowRadius = 14
        return panel
    }

    private func addGlassPanel(
        top: CGFloat,
        left: CGFloat,
        width: CGFloat,
        height: CGFloat,
        radius: CGFloat,
        fillAlpha: CGFloat = 0.4,
        blurRadius: CGFloat = 16,
        backdropAssetName: String? = nil,
        trailing: CGFloat? = nil
    ) -> UIView {
        let panel = UIView()
        panel.backgroundColor = .clear
        panel.layer.cornerRadius = radius
        panel.layer.masksToBounds = true
        addSubview(panel)
        panel.translatesAutoresizingMaskIntoConstraints = false
        var panelConstraints = [
            panel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: left),
            panel.topAnchor.constraint(equalTo: topAnchor, constant: top),
            panel.heightAnchor.constraint(equalToConstant: height)
        ]
        if let trailing {
            panelConstraints.append(panel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -trailing))
        } else {
            panelConstraints.append(panel.widthAnchor.constraint(equalToConstant: width))
        }
        NSLayoutConstraint.activate(panelConstraints)

        if let backdropAssetName, let backdropImage = blurredImage(named: backdropAssetName, radius: blurRadius) {
            let imageView = UIImageView(image: backdropImage)
            imageView.contentMode = .scaleAspectFill
            panel.addSubview(imageView)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            pinFullHeightImageView(imageView, image: backdropImage)
        } else {
            let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialLight))
            panel.addSubview(effectView)
            effectView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                effectView.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
                effectView.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
                effectView.topAnchor.constraint(equalTo: panel.topAnchor),
                effectView.bottomAnchor.constraint(equalTo: panel.bottomAnchor)
            ])
        }

        let fillView = UIView()
        fillView.backgroundColor = UIColor.white.withAlphaComponent(fillAlpha)
        panel.addSubview(fillView)
        fillView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            fillView.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            fillView.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            fillView.topAnchor.constraint(equalTo: panel.topAnchor),
            fillView.bottomAnchor.constraint(equalTo: panel.bottomAnchor)
        ])
        return panel
    }

    private func pinFullHeightImageView(_ imageView: UIImageView, image: UIImage?, in container: UIView? = nil) {
        let container = container ?? self
        var constraints = [
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor)
        ]
        if let image, image.size.height > 0 {
            constraints.append(imageView.widthAnchor.constraint(
                equalTo: imageView.heightAnchor,
                multiplier: image.size.width / image.size.height
            ))
        } else {
            constraints.append(contentsOf: [
                imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            ])
        }
        NSLayoutConstraint.activate(constraints)
    }

    private func blurredImage(named name: String, radius: CGFloat) -> UIImage? {
        guard
            let sourceImage = UIImage(named: name),
            let inputImage = CIImage(image: sourceImage)
        else {
            return nil
        }
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = inputImage.clampedToExtent()
        filter.radius = Float(radius)
        guard
            let outputImage = filter.outputImage?.cropped(to: inputImage.extent),
            let cgImage = Self.ciContext.createCGImage(outputImage, from: inputImage.extent)
        else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: sourceImage.scale, orientation: sourceImage.imageOrientation)
    }

    private func addRow(_ text: String, top: CGFloat) {
        addField(text, top: top)
        addText("›", size: 30, weight: .regular, top: top + 10, left: 306, color: .gray)
    }

    private func addFloatingCircle(_ text: String, top: CGFloat, left: CGFloat) {
        let label = UILabel()
        label.text = text
        label.textAlignment = .center
        label.font = AppFont.source(text == "•••" ? 22 : 44)
        label.backgroundColor = .white
        label.layer.cornerRadius = 30
        label.layer.masksToBounds = true
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.08
        label.layer.shadowOffset = CGSize(width: 0, height: 4)
        label.layer.shadowRadius = 10
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: left),
            label.topAnchor.constraint(equalTo: topAnchor, constant: top),
            label.widthAnchor.constraint(equalToConstant: 60),
            label.heightAnchor.constraint(equalToConstant: 60)
        ])
    }

    private func addSmallField(
        _ text: String?,
        imageName: String? = nil,
        top: CGFloat,
        left: CGFloat,
        width: CGFloat,
        action: (() -> Void)? = nil
    ) {
        let layoutContainer = activeLayoutContainer ?? self
        let field = AdaptiveInputView(
            backgroundColor: UIColor(red: 0.94, green: 1, blue: 0.72, alpha: 1)
        )
        let label = UILabel()
        label.text = text
        label.textAlignment = .center
        label.textColor = .darkGray
        label.font = AppFont.source(14)
        layoutContainer.addSubview(field)
        field.addSubview(label)
        field.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            field.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            field.widthAnchor.constraint(equalToConstant: width),
            field.heightAnchor.constraint(equalToConstant: 45),
            label.leadingAnchor.constraint(equalTo: field.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: field.trailingAnchor),
            label.topAnchor.constraint(equalTo: field.topAnchor),
            label.bottomAnchor.constraint(equalTo: field.bottomAnchor)
        ])
        if let imageName {
            let iconView = UIImageView(image: UIImage(named: imageName))
            iconView.contentMode = .scaleAspectFit
            field.addSubview(iconView)
            iconView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                iconView.centerXAnchor.constraint(equalTo: field.centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: field.centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 30),
                iconView.heightAnchor.constraint(equalToConstant: 30)
            ])
        }
        if let action {
            let actionButton = UIButton(type: .custom)
            actionButton.addAction(UIAction { _ in action() }, for: .touchUpInside)
            field.addSubview(actionButton)
            actionButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                actionButton.leadingAnchor.constraint(equalTo: field.leadingAnchor),
                actionButton.trailingAnchor.constraint(equalTo: field.trailingAnchor),
                actionButton.topAnchor.constraint(equalTo: field.topAnchor),
                actionButton.bottomAnchor.constraint(equalTo: field.bottomAnchor)
            ])
        }
    }

    private func addUploadThemeChoices(top: CGFloat) -> UploadThemeFlowView {
        let layoutContainer = activeLayoutContainer ?? self
        let flowView = UploadThemeFlowView()
        flowView.didRequestEntry = { [weak self] in
            self?.showUploadThemeEntry()
        }
        flowView.didUpdateContentHeight = { [weak self] height in
            self?.updateUploadThemeHeight(height)
        }
        uploadThemeFlowView = flowView
        layoutContainer.addSubview(flowView)
        flowView.translatesAutoresizingMaskIntoConstraints = false

        let heightConstraint = flowView.heightAnchor.constraint(equalToConstant: 98)
        NSLayoutConstraint.activate([
            flowView.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: 20),
            flowView.trailingAnchor.constraint(equalTo: layoutContainer.trailingAnchor, constant: -20),
            flowView.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            heightConstraint
        ])
        uploadThemeHeightConstraint = heightConstraint
        return flowView
    }

    private func updateUploadThemeHeight(_ height: CGFloat) {
        let adjustedHeight = max(45, ceil(height))
        let heightDelta = adjustedHeight - 98
        uploadThemeHeightConstraint?.constant = adjustedHeight
        uploadFormHeightConstraint?.constant = 518 + max(0, heightDelta)
        layoutIfNeeded()
    }

    private func showUploadThemeEntry() {
        if let field = uploadThemeEntryField {
            field.becomeFirstResponder()
            return
        }

        let bar = UIView()
        bar.backgroundColor = .white
        addSubview(bar)
        bar.translatesAutoresizingMaskIntoConstraints = false

        let field = AdaptiveInputView(
            backgroundColor: UIColor(red: 212 / 255, green: 1, blue: 59 / 255, alpha: 0.3),
            gradientColors: nil
        )
        bar.addSubview(field)
        field.translatesAutoresizingMaskIntoConstraints = false

        let textField = UITextField()
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.textColor = .black
        textField.tintColor = .black
        textField.font = AppFont.source(15)
        textField.autocapitalizationType = .words
        textField.autocorrectionType = .no
        textField.returnKeyType = .done
        textField.attributedPlaceholder = NSAttributedString(
            string: "Theme",
            attributes: [
                .font: AppFont.source(15),
                .foregroundColor: UIColor.gray
            ]
        )
        textField.addTarget(self, action: #selector(commitUploadThemeEntry), for: .primaryActionTriggered)
        field.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false

        let bottomConstraint = bar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24)
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomConstraint,
            bar.heightAnchor.constraint(equalToConstant: 62),

            field.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 20),
            field.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -20),
            field.topAnchor.constraint(equalTo: bar.topAnchor, constant: 4),
            field.heightAnchor.constraint(equalToConstant: 54),

            textField.leadingAnchor.constraint(equalTo: field.leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: field.trailingAnchor, constant: -16),
            textField.topAnchor.constraint(equalTo: field.topAnchor),
            textField.bottomAnchor.constraint(equalTo: field.bottomAnchor)
        ])

        uploadThemeEntryBar = bar
        uploadThemeEntryField = textField
        uploadThemeEntryBottomConstraint = bottomConstraint
        keyboardAvoidanceInputView = bar
        keyboardAvoidanceBottomConstraint = bottomConstraint
        keyboardAvoidanceBaseBottomConstant = -24
        bringSubviewToFront(bar)
        textField.becomeFirstResponder()
    }

    @objc private func commitUploadThemeEntry() {
        let value = uploadThemeEntryField?.text ?? ""
        uploadThemeFlowView?.appendTheme(value)
        endEditing(true)
        removeUploadThemeEntryBar()
    }

    private func removeUploadThemeEntryBar() {
        uploadThemeEntryBar?.removeFromSuperview()
        uploadThemeEntryBar = nil
        uploadThemeEntryField = nil
        uploadThemeEntryBottomConstraint = nil
        if keyboardAvoidanceInputView == nil || keyboardAvoidanceInputView?.superview == nil {
            keyboardAvoidanceBottomConstraint = nil
            keyboardAvoidanceBaseBottomConstant = 0
        }
    }

    @discardableResult
    private func addLargeField(
        _ text: String,
        top: CGFloat? = nil,
        topAnchor: NSLayoutYAxisAnchor? = nil,
        topOffset: CGFloat = 0,
        height: CGFloat = 98,
        horizontalMargin: CGFloat = 20,
        parent: UIView? = nil,
        bottomAnchor: NSLayoutYAxisAnchor? = nil,
        bottomInset: CGFloat = 0,
        textViewHandler: ((UITextView) -> Void)? = nil
    ) -> UIView {
        let layoutContainer = parent ?? activeLayoutContainer ?? self
        let field = AdaptiveInputView(
            backgroundColor: UIColor(
                red: 212 / 255,
                green: 1,
                blue: 59 / 255,
                alpha: 0.3
            )
        )
        layoutContainer.addSubview(field)
        field.translatesAutoresizingMaskIntoConstraints = false
        var fieldConstraints = [
            field.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: horizontalMargin),
            field.trailingAnchor.constraint(equalTo: layoutContainer.trailingAnchor, constant: -horizontalMargin),
            field.heightAnchor.constraint(equalToConstant: height)
        ]
        if let bottomAnchor {
            fieldConstraints.append(field.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bottomInset))
        } else if let topAnchor {
            fieldConstraints.append(field.topAnchor.constraint(equalTo: topAnchor, constant: topOffset))
        } else if let top {
            fieldConstraints.append(field.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top))
        }
        NSLayoutConstraint.activate(fieldConstraints)
        let inputView = UITextView()
        inputView.text = ""
        inputView.textColor = .black
        inputView.font = AppFont.source(14)
        inputView.backgroundColor = .clear
        inputView.textContainerInset = .zero
        inputView.textContainer.lineFragmentPadding = 0
        inputView.delegate = self
        textViewHandler?(inputView)
        field.addSubview(inputView)
        inputView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            inputView.leadingAnchor.constraint(equalTo: field.leadingAnchor, constant: 16),
            inputView.trailingAnchor.constraint(equalTo: field.trailingAnchor, constant: -16),
            inputView.topAnchor.constraint(equalTo: field.topAnchor, constant: 16),
            inputView.bottomAnchor.constraint(equalTo: field.bottomAnchor, constant: -16)
        ])

        let placeholderLabel = UILabel()
        placeholderLabel.tag = Self.largeFieldPlaceholderTag
        placeholderLabel.text = text
        placeholderLabel.textColor = .darkGray
        placeholderLabel.font = AppFont.source(14)
        placeholderLabel.isUserInteractionEnabled = false
        field.addSubview(placeholderLabel)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: field.leadingAnchor, constant: 16),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: field.trailingAnchor, constant: -16),
            placeholderLabel.topAnchor.constraint(equalTo: field.topAnchor, constant: 16)
        ])
        return field
    }

    @discardableResult
    private func addInputBar(
        top: CGFloat,
        text: String,
        trailing: String,
        usesDashedBorder: Bool = false,
        textFieldHandler: ((UITextField) -> Void)? = nil,
        actionHandler: (() -> Void)? = nil
    ) -> UIView {
        let layoutContainer = activeLayoutContainer ?? self
        return addInputBar(
            top: top,
            bottom: nil,
            text: text,
            trailing: trailing,
            usesDashedBorder: usesDashedBorder,
            in: layoutContainer,
            textFieldHandler: textFieldHandler,
            actionHandler: actionHandler
        )
    }

    private func addInputBar(
        bottom: CGFloat,
        text: String,
        trailing: String,
        usesDashedBorder: Bool = false,
        in layoutContainer: UIView,
        textFieldHandler: ((UITextField) -> Void)? = nil,
        actionHandler: (() -> Void)? = nil,
        bottomConstraintHandler: ((NSLayoutConstraint) -> Void)? = nil
    ) -> UIView {
        addInputBar(
            top: nil,
            bottom: bottom,
            text: text,
            trailing: trailing,
            usesDashedBorder: usesDashedBorder,
            in: layoutContainer,
            textFieldHandler: textFieldHandler,
            actionHandler: actionHandler,
            bottomConstraintHandler: bottomConstraintHandler
        )
    }

    private func addInputBar(
        top: CGFloat?,
        bottom: CGFloat?,
        text: String,
        trailing: String,
        usesDashedBorder: Bool,
        in layoutContainer: UIView,
        textFieldHandler: ((UITextField) -> Void)? = nil,
        actionHandler: (() -> Void)? = nil,
        bottomConstraintHandler: ((NSLayoutConstraint) -> Void)? = nil
    ) -> UIView {
        let bar: UIView
        let inputSurface: UIView
        if usesDashedBorder {
            let container = UIView()
            container.backgroundColor = .clear
            bar = container

            let fallbackView = UIView()
            fallbackView.backgroundColor = .white
            fallbackView.layer.cornerRadius = 10
            fallbackView.layer.masksToBounds = true
            container.addSubview(fallbackView)
            fallbackView.translatesAutoresizingMaskIntoConstraints = false

            let surface = AdaptiveInputView(
                backgroundColor: UIColor(red: 0.83, green: 1, blue: 0.23, alpha: 0.3),
                cornerRadius: 10
            )
            container.addSubview(surface)
            surface.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                fallbackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                fallbackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                fallbackView.topAnchor.constraint(equalTo: container.topAnchor),
                fallbackView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                surface.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                surface.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                surface.topAnchor.constraint(equalTo: container.topAnchor),
                surface.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
            inputSurface = surface
        } else {
            let plainBar = UIView()
            plainBar.backgroundColor = UIColor(red: 0.94, green: 1, blue: 0.72, alpha: 1)
            plainBar.layer.cornerRadius = 10
            plainBar.layer.borderWidth = 1
            plainBar.layer.borderColor = UIColor(red: 0.53, green: 0.86, blue: 0.10, alpha: 1).cgColor
            bar = plainBar
            inputSurface = plainBar
        }
        layoutContainer.addSubview(bar)
        bar.translatesAutoresizingMaskIntoConstraints = false
        var constraints = [
            bar.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: 20),
            bar.trailingAnchor.constraint(equalTo: layoutContainer.trailingAnchor, constant: -20),
            bar.heightAnchor.constraint(equalToConstant: 45)
        ]
        if let top {
            constraints.append(bar.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top))
        }
        if let bottom {
            let bottomConstraint = bar.bottomAnchor.constraint(equalTo: layoutContainer.bottomAnchor, constant: -bottom)
            constraints.append(bottomConstraint)
            bottomConstraintHandler?(bottomConstraint)
        }
        NSLayoutConstraint.activate(constraints)
        let prompt = UITextField()
        prompt.placeholder = text
        prompt.font = AppFont.source(13)
        prompt.textColor = .black
        prompt.tintColor = .black
        prompt.backgroundColor = .clear
        prompt.borderStyle = .none
        prompt.returnKeyType = .send
        textFieldHandler?(prompt)
        inputSurface.addSubview(prompt)
        prompt.translatesAutoresizingMaskIntoConstraints = false
        let usesSendIcon = trailing.isEmpty || trailing == "➤"
        let action: UIView
        if usesSendIcon {
            let iconView = UIImageView(image: UIImage(named: "reply_send_icon"))
            iconView.contentMode = .scaleAspectFit
            action = iconView
        } else {
            let label = UILabel()
            label.text = trailing
            label.font = AppFont.source(26, weight: .black)
            label.textColor = .gray
            action = label
        }
        inputSurface.addSubview(action)
        action.translatesAutoresizingMaskIntoConstraints = false
        if let actionHandler {
            let button = ClearTapButton(frame: .zero, action: actionHandler)
            inputSurface.addSubview(button)
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: action.leadingAnchor, constant: -12),
                button.trailingAnchor.constraint(equalTo: inputSurface.trailingAnchor),
                button.topAnchor.constraint(equalTo: inputSurface.topAnchor),
                button.bottomAnchor.constraint(equalTo: inputSurface.bottomAnchor)
            ])
        }
        NSLayoutConstraint.activate([
            prompt.leadingAnchor.constraint(equalTo: inputSurface.leadingAnchor, constant: 16),
            prompt.trailingAnchor.constraint(equalTo: action.leadingAnchor, constant: -12),
            prompt.centerYAnchor.constraint(equalTo: inputSurface.centerYAnchor),
            action.trailingAnchor.constraint(equalTo: inputSurface.trailingAnchor, constant: -16),
            action.centerYAnchor.constraint(equalTo: inputSurface.centerYAnchor),
            action.widthAnchor.constraint(equalToConstant: usesSendIcon ? 28 : 24),
            action.heightAnchor.constraint(equalToConstant: 28)
        ])
        return bar
    }

    private func addUploadBox(
        top: CGFloat,
        topAnchor: NSLayoutYAxisAnchor? = nil,
        topOffset: CGFloat = 0,
        action: (() -> Void)? = nil
    ) {
        let layoutContainer = activeLayoutContainer ?? self
        let box = AdaptiveInputView(
            backgroundColor: UIColor(red: 0.94, green: 1, blue: 0.72, alpha: 1)
        )
        layoutContainer.addSubview(box)
        box.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            box.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: 20),
            box.topAnchor.constraint(
                equalTo: topAnchor ?? layoutContainer.topAnchor,
                constant: topAnchor == nil ? top : topOffset
            ),
            box.widthAnchor.constraint(equalToConstant: 92),
            box.heightAnchor.constraint(equalToConstant: 115)
        ])
        let previewView = UIImageView()
        previewView.contentMode = .scaleAspectFill
        previewView.clipsToBounds = true
        previewView.layer.cornerRadius = 10
        previewView.layer.masksToBounds = true
        previewView.isHidden = true
        box.addSubview(previewView)
        previewView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            previewView.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            previewView.topAnchor.constraint(equalTo: box.topAnchor),
            previewView.bottomAnchor.constraint(equalTo: box.bottomAnchor)
        ])
        uploadMediaPreviewImageView = previewView

        let playIcon = UIImageView(image: UIImage(named: "persona_media_play_icon"))
        playIcon.contentMode = .scaleAspectFit
        playIcon.isHidden = true
        box.addSubview(playIcon)
        playIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            playIcon.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            playIcon.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            playIcon.widthAnchor.constraint(equalToConstant: 28),
            playIcon.heightAnchor.constraint(equalToConstant: 28)
        ])
        uploadMediaPlayIconView = playIcon

        let icon = UIImageView(image: UIImage(named: "upload_media_icon"))
        icon.contentMode = .scaleAspectFit
        box.addSubview(icon)
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28)
        ])
        uploadMediaIconView = icon

        let actionButton = UIButton(type: .custom)
        actionButton.addAction(UIAction { _ in action?() }, for: .touchUpInside)
        box.addSubview(actionButton)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            actionButton.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            actionButton.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            actionButton.topAnchor.constraint(equalTo: box.topAnchor),
            actionButton.bottomAnchor.constraint(equalTo: box.bottomAnchor)
        ])
    }

    private func addGrabber(top: CGFloat) {
        let grabber = UIView()
        grabber.backgroundColor = .white
        grabber.layer.cornerRadius = 2
        addSubview(grabber)
        grabber.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            grabber.centerXAnchor.constraint(equalTo: centerXAnchor),
            grabber.topAnchor.constraint(equalTo: topAnchor, constant: top),
            grabber.widthAnchor.constraint(equalToConstant: 112),
            grabber.heightAnchor.constraint(equalToConstant: 4)
        ])
    }

    private func addLine(top: CGFloat, left: CGFloat, width: CGFloat, color: UIColor, parent: UIView? = nil) {
        let layoutContainer = parent ?? self
        let line = UIView()
        line.backgroundColor = color
        layoutContainer.addSubview(line)
        line.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            line.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            line.widthAnchor.constraint(equalToConstant: width),
            line.heightAnchor.constraint(equalToConstant: 2)
        ])
    }

    private func addGem(assetName: String, top: CGFloat, left: CGFloat, width: CGFloat, height: CGFloat) {
        let layoutContainer = activeLayoutContainer ?? self
        let gem = UIImageView(image: UIImage(named: assetName))
        gem.contentMode = .scaleAspectFit
        gem.layer.shadowColor = UIColor.green.cgColor
        gem.layer.shadowOpacity = 0.28
        gem.layer.shadowRadius = 8
        gem.layer.shadowOffset = CGSize(width: 0, height: 4)
        layoutContainer.addSubview(gem)
        gem.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            gem.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            gem.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            gem.widthAnchor.constraint(equalToConstant: width),
            gem.heightAnchor.constraint(equalToConstant: height)
        ])
    }

    private func addVoiceClip(top: CGFloat) {
        let clip = UIView()
        clip.backgroundColor = UIColor(red: 0.92, green: 1, blue: 0.78, alpha: 1)
        clip.layer.cornerRadius = 8
        clip.layer.borderWidth = 1
        clip.layer.borderColor = UIColor(red: 0.53, green: 0.86, blue: 0.10, alpha: 1).cgColor
        addSubview(clip)
        clip.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            clip.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 224),
            clip.topAnchor.constraint(equalTo: topAnchor, constant: top),
            clip.widthAnchor.constraint(equalToConstant: 64),
            clip.heightAnchor.constraint(equalToConstant: 36)
        ])
        addText("▥ 5s", size: 15, weight: .regular, top: top + 8, left: 238, color: .darkGray)
        addPortrait(top: top - 2, left: 306, size: 44, tint: .warm)
    }

    private func addReportChoiceRow(_ text: String, top: CGFloat, index: Int, checked: Bool) {
        let layoutContainer = activeLayoutContainer ?? self
        let field = AdaptiveInputView(
            backgroundColor: UIColor(red: 0.94, green: 1, blue: 0.72, alpha: 1)
        )
        let tapButton = UIButton(type: .custom)
        tapButton.tag = index
        tapButton.addTarget(self, action: #selector(handleSafetyChoiceTap(_:)), for: .touchUpInside)
        let label = UILabel()
        label.text = text
        label.textAlignment = .center
        label.textColor = .darkGray
        label.font = AppFont.source(14)
        let checkIcon = UIImageView(image: UIImage(named: checked ? "report_check_selected" : "report_check_unselected"))
        checkIcon.tag = 9400 + index
        checkIcon.contentMode = .scaleAspectFit

        layoutContainer.addSubview(field)
        field.addSubview(label)
        field.addSubview(checkIcon)
        field.addSubview(tapButton)
        field.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        checkIcon.translatesAutoresizingMaskIntoConstraints = false
        tapButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: 20),
            field.trailingAnchor.constraint(equalTo: layoutContainer.trailingAnchor, constant: -20),
            field.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            field.heightAnchor.constraint(equalToConstant: 52),
            label.leadingAnchor.constraint(equalTo: field.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: field.trailingAnchor),
            label.topAnchor.constraint(equalTo: field.topAnchor),
            label.bottomAnchor.constraint(equalTo: field.bottomAnchor),
            checkIcon.trailingAnchor.constraint(equalTo: field.trailingAnchor, constant: -17),
            checkIcon.centerYAnchor.constraint(equalTo: field.centerYAnchor),
            checkIcon.widthAnchor.constraint(equalToConstant: 24),
            checkIcon.heightAnchor.constraint(equalToConstant: 24),
            tapButton.leadingAnchor.constraint(equalTo: field.leadingAnchor),
            tapButton.trailingAnchor.constraint(equalTo: field.trailingAnchor),
            tapButton.topAnchor.constraint(equalTo: field.topAnchor),
            tapButton.bottomAnchor.constraint(equalTo: field.bottomAnchor)
        ])
    }

    @discardableResult
    private func addOptionTile(
        iconName: String,
        top: CGFloat,
        action: (() -> Void)? = nil
    ) -> UIView {
        let layoutContainer = activeLayoutContainer ?? self
        let tile = UIView()
        tile.backgroundColor = UIColor(red: 0.94, green: 1, blue: 0.72, alpha: 1)
        tile.layer.cornerRadius = 10
        tile.layer.borderWidth = 1
        tile.layer.borderColor = UIColor(red: 0.53, green: 0.86, blue: 0.10, alpha: 1).cgColor
        layoutContainer.addSubview(tile)
        tile.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tile.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            tile.heightAnchor.constraint(equalToConstant: 120)
        ])
        let iconView = UIImageView(image: UIImage(named: iconName))
        iconView.contentMode = .scaleAspectFit
        tile.addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 60),
            iconView.heightAnchor.constraint(equalToConstant: 60)
        ])
        if let action {
            let button = ClearTapButton(frame: .zero, action: action)
            tile.addSubview(button)
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: tile.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: tile.trailingAnchor),
                button.topAnchor.constraint(equalTo: tile.topAnchor),
                button.bottomAnchor.constraint(equalTo: tile.bottomAnchor)
            ])
        }
        return tile
    }

    @discardableResult
    private func addPillButton(
        _ text: String,
        top: CGFloat,
        left: CGFloat,
        width: CGFloat,
        height: CGFloat = 50,
        dark: Bool,
        usesOneFont: Bool = false,
        fontSize: CGFloat = 18,
        fontWeight: UIFont.Weight = .regular,
        parent: UIView? = nil
    ) -> UIButton {
        let layoutContainer = parent ?? activeLayoutContainer ?? self
        let button = UIButton(type: .custom)
        button.setTitle(text, for: .normal)
        button.titleLabel?.font = usesOneFont ? AppFont.fredoka(fontSize) : AppFont.source(fontSize, weight: fontWeight)
        button.setTitleColor(dark ? UIColor(red: 0.78, green: 1, blue: 0.20, alpha: 1) : .black, for: .normal)
        button.backgroundColor = dark ? UIColor(red: 0.04, green: 0.05, blue: 0.04, alpha: 1) : .white
        button.layer.cornerRadius = height / 2
        button.layer.borderWidth = dark ? 0 : 1
        button.layer.borderColor = UIColor(white: 0.90, alpha: 1).cgColor
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = dark ? 0 : 0.08
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 10
        layoutContainer.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            button.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            button.widthAnchor.constraint(equalToConstant: width),
            button.heightAnchor.constraint(equalToConstant: height)
        ])
        return button
    }

    private func addGradientBand(height: CGFloat) {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor(red: 0.70, green: 0.94, blue: 1, alpha: 1).cgColor,
            UIColor(red: 0.90, green: 1, blue: 0.68, alpha: 1).cgColor
        ]
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        layer.frame = CGRect(x: 0, y: 0, width: adaptiveLayoutWidth, height: height)
        self.layer.insertSublayer(layer, at: 0)
    }

    private func addMoodRow(top: CGFloat) {
        let layoutContainer = activeLayoutContainer ?? self
        let moodColor = UIColor(red: 1, green: 240 / 255, blue: 110 / 255, alpha: 1)
        let scrollView = CancelFriendlyScrollView()
        scrollView.backgroundColor = .clear
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        layoutContainer.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: layoutContainer.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            scrollView.heightAnchor.constraint(equalToConstant: 100)
        ])

        var selectedTile: UIControl?
        moodImageNames.enumerated().forEach { index, imageName in
            let tile = UIControl()
            let isSelected = index == selectedMoodIndex
            if isSelected {
                selectedTile = tile
            }
            tile.backgroundColor = isSelected ? moodColor : .clear
            tile.layer.cornerRadius = 28
            tile.layer.shadowColor = UIColor.black.cgColor
            tile.layer.shadowOpacity = 0.07
            tile.layer.shadowOffset = CGSize(width: 0, height: 5)
            tile.layer.shadowRadius = 12
            if !isSelected {
                let gradient = CAGradientLayer()
                gradient.colors = [
                    moodColor.cgColor,
                    moodColor.withAlphaComponent(0).cgColor
                ]
                gradient.startPoint = CGPoint(x: 0.5, y: 0)
                gradient.endPoint = CGPoint(x: 0.5, y: 1)
                gradient.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
                gradient.cornerRadius = 28
                tile.layer.insertSublayer(gradient, at: 0)
            }
            tile.addAction(UIAction { [weak self] _ in
                self?.didChooseMood?(index)
            }, for: .touchUpInside)
            scrollView.addSubview(tile)
            tile.translatesAutoresizingMaskIntoConstraints = false
            var constraints = [
                tile.leadingAnchor.constraint(
                    equalTo: scrollView.contentLayoutGuide.leadingAnchor,
                    constant: 20 + CGFloat(index) * 112
                ),
                tile.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                tile.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
                tile.widthAnchor.constraint(equalToConstant: 100),
                tile.heightAnchor.constraint(equalToConstant: 100)
            ]
            if index == moodImageNames.count - 1 {
                constraints.append(
                    tile.trailingAnchor.constraint(
                        equalTo: scrollView.contentLayoutGuide.trailingAnchor,
                        constant: -20
                    )
                )
            }
            NSLayoutConstraint.activate(constraints)
            let faceView = UIImageView(image: UIImage(named: imageName))
            faceView.contentMode = .scaleAspectFit
            faceView.isUserInteractionEnabled = false
            tile.addSubview(faceView)
            faceView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                faceView.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
                faceView.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
                faceView.widthAnchor.constraint(equalToConstant: 72),
                faceView.heightAnchor.constraint(equalToConstant: 72)
            ])
        }
        DispatchQueue.main.async { [weak scrollView, weak selectedTile] in
            guard let scrollView, let selectedTile else { return }
            scrollView.layoutIfNeeded()
            let selectedCenterX = selectedTile.convert(
                CGPoint(x: selectedTile.bounds.midX, y: selectedTile.bounds.midY),
                to: scrollView
            ).x + scrollView.contentOffset.x
            let viewportWidth = scrollView.bounds.width
            let maxOffset = max(0, scrollView.contentSize.width - viewportWidth)
            let selectedOffset = min(
                max(0, selectedCenterX - viewportWidth / 2),
                maxOffset
            )
            scrollView.setContentOffset(CGPoint(x: selectedOffset, y: 0), animated: false)
        }
    }

    private var moodImageNames: [String] {
        MoodDescriptor.all.map(\.assetName)
    }

    private var selectedMoodImageName: String {
        moodImageNames[min(max(selectedMoodIndex, 0), moodImageNames.count - 1)]
    }

    private func addMoodPreview(
        topAnchor: NSLayoutYAxisAnchor,
        topOffset: CGFloat,
        trailing: CGFloat,
        size: CGFloat,
        parent: UIView
    ) {
        let moodColor = UIColor(red: 1, green: 240 / 255, blue: 110 / 255, alpha: 1)
        let tile = UIView()
        tile.backgroundColor = moodColor
        tile.layer.cornerRadius = size * 0.28
        tile.layer.shadowColor = UIColor.black.cgColor
        tile.layer.shadowOpacity = 0.07
        tile.layer.shadowOffset = CGSize(width: 0, height: 5)
        tile.layer.shadowRadius = 12
        parent.addSubview(tile)
        tile.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tile.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -trailing),
            tile.topAnchor.constraint(equalTo: topAnchor, constant: topOffset),
            tile.widthAnchor.constraint(equalToConstant: size),
            tile.heightAnchor.constraint(equalToConstant: size)
        ])

        let faceView = UIImageView(image: UIImage(named: selectedMoodImageName))
        faceView.contentMode = .scaleAspectFit
        tile.addSubview(faceView)
        faceView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            faceView.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            faceView.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            faceView.widthAnchor.constraint(equalToConstant: size * 0.72),
            faceView.heightAnchor.constraint(equalToConstant: size * 0.72)
        ])
    }

    private func addFeatureCard(title: String, top: CGFloat, left: CGFloat, width: CGFloat, tint: MediaTint, imageName: String? = nil) {
        addMediaBlock(top: top, left: left, width: width, height: 144, title: title, tint: tint, action: .arrow, imageName: imageName)
    }

    private func addMediaBlock(
        top: CGFloat,
        left: CGFloat,
        width: CGFloat,
        height: CGFloat,
        title: String,
        tint: MediaTint = .coast,
        action: MediaAction = .none,
        imageName: String? = nil,
        cornerRadius: CGFloat = 14,
        titleSize: CGFloat = 24,
        titleTop: CGFloat = 18,
        titleUsesOneFont: Bool = false,
        destinationPage: ScenePage? = nil,
        playIconName: String = "video_play_icon",
        playIconSize: CGFloat = 40,
        shadowOpacity: Float = 0.18,
        trailing: CGFloat? = nil
    ) {
        let layoutContainer = activeLayoutContainer ?? self
        let shadowHost = UIView()
        shadowHost.backgroundColor = .clear
        shadowHost.layer.shadowColor = UIColor.black.cgColor
        shadowHost.layer.shadowOpacity = shadowOpacity
        shadowHost.layer.shadowOffset = CGSize(width: 0, height: 5)
        shadowHost.layer.shadowRadius = 12
        layoutContainer.addSubview(shadowHost)
        shadowHost.translatesAutoresizingMaskIntoConstraints = false
        var mediaConstraints = [
            shadowHost.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            shadowHost.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            shadowHost.heightAnchor.constraint(equalToConstant: height)
        ]
        if let trailing {
            mediaConstraints.append(shadowHost.trailingAnchor.constraint(equalTo: layoutContainer.trailingAnchor, constant: -trailing))
        } else {
            mediaConstraints.append(shadowHost.widthAnchor.constraint(equalToConstant: width))
        }
        NSLayoutConstraint.activate(mediaConstraints)
        let block = UIView()
        block.backgroundColor = imageName == nil ? tint.baseColor : .clear
        block.layer.cornerRadius = cornerRadius
        block.layer.masksToBounds = true
        shadowHost.addSubview(block)
        block.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            block.leadingAnchor.constraint(equalTo: shadowHost.leadingAnchor),
            block.trailingAnchor.constraint(equalTo: shadowHost.trailingAnchor),
            block.topAnchor.constraint(equalTo: shadowHost.topAnchor),
            block.bottomAnchor.constraint(equalTo: shadowHost.bottomAnchor)
        ])
        if let imageName {
            let imageView = UIImageView(image: resolveVisualAsset(imageName))
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            block.addSubview(imageView)
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: block.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: block.trailingAnchor),
                imageView.topAnchor.constraint(equalTo: block.topAnchor),
                imageView.bottomAnchor.constraint(equalTo: block.bottomAnchor)
            ])
        } else {
            let gradient = CAGradientLayer()
            gradient.colors = [
                tint.topColor.cgColor,
                tint.bottomColor.cgColor
            ]
            gradient.startPoint = CGPoint(x: 0, y: 0)
            gradient.endPoint = CGPoint(x: 1, y: 1)
            gradient.frame = CGRect(x: 0, y: 0, width: trailing == nil ? width : max(0, adaptiveLayoutWidth - left - (trailing ?? 0)), height: height)
            block.layer.insertSublayer(gradient, at: 0)
        }
        if !title.isEmpty {
            let label = UILabel()
            label.text = title
            label.textColor = .white
            label.font = titleUsesOneFont || usesFredokaText(title)
                ? AppFont.fredoka(titleSize)
                : AppFont.source(titleSize, weight: .black)
            block.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: block.leadingAnchor, constant: 14),
                label.topAnchor.constraint(equalTo: block.topAnchor, constant: titleTop)
            ])
        }
        if imageName == nil {
            addMediaAccent(in: block, tint: tint)
        }
        switch action {
        case .arrow:
            addCardArrowIcon(in: block, right: 14, bottom: 14)
        case .play:
            addVideoPlayIcon(in: block, assetName: playIconName, size: playIconSize)
        case .none:
            break
        }
        if let destinationPage {
            let button = ClearTapButton(frame: .zero) { [weak self] in
                self?.didRequestPage?(destinationPage)
            }
            shadowHost.addSubview(button)
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: shadowHost.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: shadowHost.trailingAnchor),
                button.topAnchor.constraint(equalTo: shadowHost.topAnchor),
                button.bottomAnchor.constraint(equalTo: shadowHost.bottomAnchor)
            ])
        }
    }

    private func addVideoPlayIcon(in view: UIView, assetName: String = "video_play_icon", size: CGFloat = 40) {
        let iconView = UIImageView(image: UIImage(named: assetName))
        iconView.contentMode = .scaleAspectFit
        view.addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: size),
            iconView.heightAnchor.constraint(equalToConstant: size)
        ])
    }

    private func addCardArrowIcon(in view: UIView, right: CGFloat, bottom: CGFloat) {
        let iconView = UIImageView(image: UIImage(named: "home_card_arrow"))
        iconView.contentMode = .scaleAspectFill
        iconView.clipsToBounds = true
        view.addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -right),
            iconView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -bottom),
            iconView.widthAnchor.constraint(equalToConstant: 46),
            iconView.heightAnchor.constraint(equalToConstant: 46)
        ])
    }

    private func discoverStripEntries() -> [DiscoverStoryStripView.StripEntry] {
        let profiles = (try? creativeRepository.discoveryProfiles(limit: 5)) ?? []
        guard !profiles.isEmpty else {
            return DiscoverStoryStripView.defaultEntries()
        }
        return [
            DiscoverStoryStripView.StripEntry(
                accountKey: nil,
                title: "My works",
                imageName: "story_my_works_icon",
                clipsToCircle: false
            )
        ] + profiles.map {
            DiscoverStoryStripView.StripEntry(
                accountKey: $0.accountKey,
                title: $0.displayName,
                imageName: $0.avatarAsset,
                clipsToCircle: true
            )
        }
    }

    private func discoverWorkEntries() -> [DiscoveryWorkEntry] {
        (try? creativeRepository.discoveryWorks(limit: 12)) ?? []
    }

    private func resolvedGalleryWork() -> DiscoveryWorkEntry {
        if let workKey = RouteContextStore.currentTargetWorkKey(),
           let item = try? creativeRepository.workDetail(stableKey: workKey) {
            return item
        }
        if let item = try? creativeRepository.discoveryWorks(limit: 1).first {
            RouteContextStore.setTargetWorkKey(item.stableKey)
            RouteContextStore.setTargetAccountKey(item.accountKey)
            return item
        }
        return fallbackWorkEntry()
    }

    private func fallbackWorkEntry() -> DiscoveryWorkEntry {
        DiscoveryWorkEntry(
            stableKey: "fallback-work",
            accountKey: "acct-local-victoria",
            displayName: "Victoria",
            avatarAsset: "builtin_avatar_victoria",
            coverAssetForAccount: "builtin_avatar_victoria",
            title: "Moments Matter",
            bodyText: "Capturing today's happiness. Saving it for tomorrow's memories.",
            mediaKind: 1,
            mediaAsset: "builtin_victoria.mp4",
            coverAsset: "discover_feed_cover",
            mediaWidth: nil,
            mediaHeight: nil,
            themes: tagTexts,
            reactionCount: 666,
            replyCount: 777
        )
    }

    private func addStoryStrip(top: CGFloat, entries: [DiscoverStoryStripView.StripEntry]) {
        let layoutContainer = activeLayoutContainer ?? self
        let stripView = DiscoverStoryStripView(entries: entries)
        stripView.didSelectEntry = { [weak self] index in
            if index == 0 {
                self?.didRequestOverlayPage?(.uploadEmpty)
            } else {
                self?.requestPublicPersona(subjectKey: entries[index].accountKey)
            }
        }
        layoutContainer.addSubview(stripView)
        stripView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stripView.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor),
            stripView.trailingAnchor.constraint(equalTo: layoutContainer.trailingAnchor),
            stripView.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            stripView.heightAnchor.constraint(equalToConstant: 78)
        ])
    }

    private func addFeedCard(item: DiscoveryWorkEntry, top: CGFloat, tint: MediaTint) {
        addMediaBlock(
            top: top + 48,
            left: 20,
            width: 335,
            height: 360,
            title: item.title,
            tint: tint,
            action: item.mediaKind == 1 ? .play : .none,
            imageName: item.coverAsset,
            cornerRadius: 24,
            titleSize: 16,
            titleTop: 286,
            titleUsesOneFont: true,
            trailing: 20
        )
        addAssetAvatar(item.avatarAsset, top: top, left: 20, size: 36)
        addText(item.displayName, size: 19, weight: .bold, top: top + 4, left: 68)
        addFeedMoreIcon(top: top + 6)
        addTags(top: top + 366, items: item.themes)
        addFeedStats(
            top: top + 424,
            reactions: item.reactionCount,
            replies: item.replyCount,
            reacted: isWorkReacted(item.stableKey)
        )
        addDiscoverActionButton(frame: CGRect(x: 20, y: top, width: 335, height: 444)) { [weak self] in
            RouteContextStore.setTargetWorkKey(item.stableKey)
            RouteContextStore.setTargetAccountKey(item.accountKey)
            self?.didRequestPage?(.galleryDetail)
        }
        addDiscoverActionButton(frame: CGRect(x: 20, y: top, width: 48, height: 48)) { [weak self] in
            self?.requestPublicPersona(subjectKey: item.accountKey)
        }
        addDiscoverActionButton(frame: CGRect(x: 68, y: top, width: 160, height: 44)) { [weak self] in
            self?.requestPublicPersona(subjectKey: item.accountKey)
        }
        addTrailingDiscoverActionButton(top: top, trailing: 10, width: 54, height: 44) { [weak self] in
            RouteContextStore.setTargetWorkKey(item.stableKey)
            self?.didRequestSubjectOverlayPage?(.restrictPanel, item.accountKey)
        }
    }

    private func addFeedCard(name: String, top: CGFloat, tint: MediaTint) {
        addMediaBlock(
            top: top + 48,
            left: 20,
            width: 335,
            height: 360,
            title: "Moments Matter",
            tint: tint,
            action: .play,
            imageName: "discover_feed_cover",
            cornerRadius: 24,
            titleSize: 16,
            titleTop: 286,
            titleUsesOneFont: true,
            trailing: 20
        )
        addProfileAvatar(
            top: top,
            left: 20,
            size: 36,
            backgroundColor: .clear,
            showsBorder: false,
            showsShadow: false
        )
        addText(name, size: 19, weight: .bold, top: top + 4, left: 68)
        addFeedMoreIcon(top: top + 6)
        addTags(top: top + 366)
        addFeedStats(top: top + 424)
        addDiscoverActionButton(frame: CGRect(x: 20, y: top, width: 335, height: 444)) { [weak self] in
            RouteContextStore.setTargetWorkKey("work-local-victoria")
            RouteContextStore.setTargetAccountKey("acct-local-victoria")
            self?.didRequestPage?(.galleryDetail)
        }
        addDiscoverActionButton(frame: CGRect(x: 20, y: top, width: 48, height: 48)) { [weak self] in
            self?.requestPublicPersona(subjectKey: "acct-local-victoria")
        }
        addDiscoverActionButton(frame: CGRect(x: 68, y: top, width: 160, height: 44)) { [weak self] in
            self?.requestPublicPersona(subjectKey: "acct-local-victoria")
        }
        addTrailingDiscoverActionButton(top: top, trailing: 10, width: 54, height: 44) { [weak self] in
            RouteContextStore.setTargetWorkKey("work-local-victoria")
            RouteContextStore.setTargetAccountKey("acct-local-victoria")
            self?.didRequestSubjectOverlayPage?(.restrictPanel, "acct-local-victoria")
        }
    }

    private func addDiscoverActionButton(frame: CGRect, action: @escaping () -> Void) {
        let layoutContainer = activeLayoutContainer ?? self
        let button = ClearTapButton(frame: .zero, action: action)
        layoutContainer.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        var buttonConstraints = [
            button.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: frame.minX),
            button.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: frame.minY),
            button.heightAnchor.constraint(equalToConstant: frame.height)
        ]
        if fillsReferenceTrailing(frame) {
            buttonConstraints.append(button.trailingAnchor.constraint(equalTo: layoutContainer.trailingAnchor, constant: -20))
        } else {
            buttonConstraints.append(button.widthAnchor.constraint(equalToConstant: frame.width))
        }
        NSLayoutConstraint.activate(buttonConstraints)
    }

    private func addTrailingDiscoverActionButton(
        top: CGFloat,
        trailing: CGFloat,
        width: CGFloat,
        height: CGFloat,
        action: @escaping () -> Void
    ) {
        let layoutContainer = activeLayoutContainer ?? self
        let button = ClearTapButton(frame: .zero, action: action)
        layoutContainer.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: layoutContainer.trailingAnchor, constant: -trailing),
            button.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            button.widthAnchor.constraint(equalToConstant: width),
            button.heightAnchor.constraint(equalToConstant: height)
        ])
    }

    private func addHomeActionButton(frame: CGRect, action: @escaping () -> Void) {
        let layoutContainer = activeLayoutContainer ?? self
        let button = ClearTapButton(frame: .zero, action: action)
        layoutContainer.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        var buttonConstraints = [
            button.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: frame.minX),
            button.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: frame.minY),
            button.heightAnchor.constraint(equalToConstant: frame.height)
        ]
        if fillsReferenceTrailing(frame) {
            buttonConstraints.append(button.trailingAnchor.constraint(equalTo: layoutContainer.trailingAnchor, constant: -20))
        } else {
            buttonConstraints.append(button.widthAnchor.constraint(equalToConstant: frame.width))
        }
        NSLayoutConstraint.activate(buttonConstraints)
    }

    private func addFeedStats(top: CGFloat, reactions: Int = 666, replies: Int = 777, reacted: Bool = false) {
        let layoutContainer = activeLayoutContainer ?? self
        addFeedStat(
            iconName: "feed_like_icon",
            text: "\(reactions) Likes",
            top: top,
            left: 22,
            parent: layoutContainer,
            iconTint: reacted ? UIColor(red: 0.39, green: 0.68, blue: 0.02, alpha: 1) : nil
        )
        addFeedStat(iconName: "feed_reply_icon", text: "\(replies) Comments", top: top, left: 130, parent: layoutContainer)
    }

    private func addFeedStat(iconName: String, text: String, top: CGFloat, left: CGFloat, parent: UIView, iconTint: UIColor? = nil) {
        let sourceImage = UIImage(named: iconName)
        let iconView = UIImageView(image: iconTint == nil ? sourceImage : sourceImage?.withRenderingMode(.alwaysTemplate))
        iconView.contentMode = .scaleAspectFit
        if let iconTint {
            iconView.tintColor = iconTint
        }
        parent.addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = text
        label.textColor = .darkGray
        label.font = AppFont.source(13, weight: .regular)
        parent.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: left),
            iconView.topAnchor.constraint(equalTo: parent.topAnchor, constant: top + 1),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 4),
            label.centerYAnchor.constraint(equalTo: iconView.centerYAnchor)
        ])
    }

    private func addFeedMoreIcon(top: CGFloat) {
        let layoutContainer = activeLayoutContainer ?? self
        let iconView = UIImageView(image: UIImage(named: "feed_more_icon"))
        iconView.contentMode = .scaleAspectFit
        layoutContainer.addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.trailingAnchor.constraint(equalTo: layoutContainer.trailingAnchor, constant: -20),
            iconView.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    private func addTags(top: CGFloat, left: CGFloat = 28, right: CGFloat = 20, items: [String]? = nil) {
        let layoutContainer = activeLayoutContainer ?? self
        let font = AppFont.source(12)
        let rowHeight = tagRowHeight
        let horizontalInset = tagHorizontalInset
        let itemSpacing = tagItemSpacing
        let rowSpacing = tagRowSpacing
        let startX = left
        let maxX = adaptiveLayoutWidth - right
        var cursorX = startX
        var cursorY = top

        (items ?? tagTexts).forEach { item in
            let textWidth = ceil((item as NSString).size(withAttributes: [.font: font]).width)
            let itemWidth = textWidth + horizontalInset * 2
            if cursorX > startX, cursorX + itemWidth > maxX {
                cursorX = startX
                cursorY += rowHeight + rowSpacing
            }

            let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialLight))
            blurView.layer.cornerRadius = 6
            blurView.layer.masksToBounds = true
            blurView.backgroundColor = UIColor.white.withAlphaComponent(0.22)
            layoutContainer.addSubview(blurView)
            blurView.translatesAutoresizingMaskIntoConstraints = false

            let label = UILabel()
            label.text = item
            label.textAlignment = .center
            label.font = font
            label.textColor = UIColor.black.withAlphaComponent(0.78)
            label.lineBreakMode = .byClipping
            blurView.contentView.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                blurView.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: cursorX),
                blurView.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: cursorY),
                blurView.widthAnchor.constraint(equalToConstant: itemWidth),
                blurView.heightAnchor.constraint(equalToConstant: 26),
                label.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: horizontalInset),
                label.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -horizontalInset),
                label.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor)
            ])
            cursorX += itemWidth + itemSpacing
        }
    }

    private var tagTexts: [String] {
        ["Travel", "Food", "Family", "Friends", "Lifestyle"]
    }

    private var tagRowHeight: CGFloat { 26 }
    private var tagHorizontalInset: CGFloat { 10 }
    private var tagItemSpacing: CGFloat { 8 }
    private var tagRowSpacing: CGFloat { 8 }

    private func measuredTagsHeight(left: CGFloat = 28, right: CGFloat = 20, items: [String]? = nil) -> CGFloat {
        let font = AppFont.source(12)
        let startX = left
        let maxX = adaptiveLayoutWidth - right
        var cursorX = startX
        var rowCount: CGFloat = 1

        (items ?? tagTexts).forEach { item in
            let textWidth = ceil((item as NSString).size(withAttributes: [.font: font]).width)
            let itemWidth = textWidth + tagHorizontalInset * 2
            if cursorX > startX, cursorX + itemWidth > maxX {
                cursorX = startX
                rowCount += 1
            }
            cursorX += itemWidth + tagItemSpacing
        }

        return rowCount * tagRowHeight + max(0, rowCount - 1) * tagRowSpacing
    }

    private func measuredCopyHeight(
        _ text: String,
        size: CGFloat,
        weight: UIFont.Weight,
        width: CGFloat
    ) -> CGFloat {
        let font = sourceFont(for: text, size: size, weight: weight)
        let boundingRect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return max(ceil(boundingRect.height), ceil(font.lineHeight))
    }

    private func addMediaGrid(top: CGFloat) {
        addMediaBlock(top: top, left: 20, width: 162, height: 200, title: "", tint: .coast, action: .play)
        addMediaBlock(top: top, left: 192, width: 164, height: 164, title: "", tint: .warm, action: .play)
        addMediaBlock(top: top + 210, left: 20, width: 162, height: 180, title: "", tint: .forest, action: .play)
        addMediaBlock(top: top + 174, left: 192, width: 164, height: 190, title: "", tint: .night, action: .play)
    }

    private func addStatsPanel(top: CGFloat, detail: PersonaDetailEntry) {
        let panel = addPanel(top: top, left: 20, width: 335, height: 80, alpha: 1, trailing: 20)
        panel.layer.cornerRadius = 12
        let statsEntries = [
            (detail.worksText, "Works"),
            (detail.followersText, "Followers"),
            (detail.followingText, "Following")
        ]
        let colors = [
            UIColor(red: 0.22, green: 0.78, blue: 0.10, alpha: 1),
            UIColor(red: 1.0, green: 0.60, blue: 0.00, alpha: 1),
            UIColor(red: 0.12, green: 0.55, blue: 1.0, alpha: 1)
        ]
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        panel.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: panel.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: panel.bottomAnchor)
        ])

        for index in statsEntries.indices {
            let columnView = UIView()
            stackView.addArrangedSubview(columnView)

            let valueLabel = UILabel()
            valueLabel.text = statsEntries[index].0
            valueLabel.textColor = colors[index]
            valueLabel.font = AppFont.source(20)
            valueLabel.textAlignment = .center

            let titleLabel = UILabel()
            titleLabel.text = statsEntries[index].1
            titleLabel.textColor = .darkGray
            titleLabel.font = AppFont.source(16)
            titleLabel.textAlignment = .center

            columnView.addSubview(valueLabel)
            columnView.addSubview(titleLabel)
            valueLabel.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                valueLabel.centerXAnchor.constraint(equalTo: columnView.centerXAnchor),
                valueLabel.topAnchor.constraint(equalTo: columnView.topAnchor, constant: 15),
                valueLabel.heightAnchor.constraint(equalToConstant: 24),

                titleLabel.centerXAnchor.constraint(equalTo: valueLabel.centerXAnchor),
                titleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 6),
                titleLabel.heightAnchor.constraint(equalToConstant: 24)
            ])
        }
    }

    private func addBubble(
        _ text: String,
        top: CGFloat,
        left: CGFloat,
        outgoing: Bool,
        width: CGFloat = 206,
        height: CGFloat? = nil
    ) {
        let bubble = ArrowBubbleView(
            text: text,
            pointerSide: outgoing ? .right : .left,
            fillColor: outgoing
                ? UIColor(red: 0.92, green: 1, blue: 0.78, alpha: 1)
                : UIColor(red: 0.96, green: 0.99, blue: 1, alpha: 1),
            strokeColor: outgoing
                ? UIColor(red: 0.56, green: 0.78, blue: 0.22, alpha: 1)
                : UIColor.systemBlue.withAlphaComponent(0.4)
        )
        addSubview(bubble)
        bubble.translatesAutoresizingMaskIntoConstraints = false
        var constraints = [
            bubble.topAnchor.constraint(equalTo: topAnchor, constant: top),
            bubble.widthAnchor.constraint(lessThanOrEqualToConstant: width)
        ]
        if outgoing {
            constraints.append(bubble.trailingAnchor.constraint(equalTo: leadingAnchor, constant: left + width))
        } else {
            constraints.append(bubble.leadingAnchor.constraint(equalTo: leadingAnchor, constant: left))
        }
        if let height {
            constraints.append(bubble.heightAnchor.constraint(equalToConstant: height))
        }
        NSLayoutConstraint.activate(constraints)
    }

    private func addTopTitle(_ title: String) {
        // Navigation titles are rendered by CustomTopLayerView.
    }

    @discardableResult
    private func addAgreementConsentLine(
        top: CGFloat? = nil,
        bottom: CGFloat? = nil,
        parent: UIView? = nil
    ) -> UIView {
        let layoutContainer = parent ?? self
        let container = UIView()
        container.backgroundColor = .clear
        layoutContainer.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false

        var constraints = [
            container.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: layoutContainer.trailingAnchor),
            container.heightAnchor.constraint(equalToConstant: 20)
        ]
        if let top {
            constraints.append(container.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top))
        }
        if let bottom {
            constraints.append(container.bottomAnchor.constraint(equalTo: layoutContainer.bottomAnchor, constant: -bottom))
        }
        NSLayoutConstraint.activate(constraints)

        let iconControl = UIControl()
        iconControl.addTarget(self, action: #selector(handleAgreementConsentToggle), for: .touchUpInside)
        iconControl.accessibilityLabel = "Agree with User Agreement and Privacy Policy"
        container.addSubview(iconControl)
        iconControl.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(named: consentIconName(isSelected: Self.agreementConsentAccepted)))
        iconView.contentMode = .scaleAspectFit
        iconControl.addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        agreementConsentIconView = iconView

        let prefixLabel = UILabel()
        prefixLabel.text = "Agree with  "
        prefixLabel.font = AppFont.source(12)
        prefixLabel.textColor = .gray
        container.addSubview(prefixLabel)
        prefixLabel.translatesAutoresizingMaskIntoConstraints = false

        let agreementControl = underlinedAgreementButton("User Agreement", action: #selector(openUserAgreementPage))
        agreementControl.accessibilityLabel = "User Agreement"
        container.addSubview(agreementControl)
        agreementControl.translatesAutoresizingMaskIntoConstraints = false

        let middleLabel = UILabel()
        middleLabel.text = " and "
        middleLabel.font = AppFont.source(12)
        middleLabel.textColor = .gray
        container.addSubview(middleLabel)
        middleLabel.translatesAutoresizingMaskIntoConstraints = false

        let privacyControl = underlinedAgreementButton("Privacy Policy", action: #selector(openPrivacyPolicyPage))
        privacyControl.accessibilityLabel = "Privacy Policy"
        container.addSubview(privacyControl)
        privacyControl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconControl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 36.5),
            iconControl.centerYAnchor.constraint(equalTo: prefixLabel.centerYAnchor),
            iconControl.widthAnchor.constraint(equalToConstant: 40),
            iconControl.heightAnchor.constraint(equalToConstant: 40),

            iconView.centerXAnchor.constraint(equalTo: iconControl.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconControl.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 17),
            iconView.heightAnchor.constraint(equalToConstant: 17),

            prefixLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 70),
            prefixLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            agreementControl.leadingAnchor.constraint(equalTo: prefixLabel.trailingAnchor),
            agreementControl.centerYAnchor.constraint(equalTo: prefixLabel.centerYAnchor),
            agreementControl.heightAnchor.constraint(equalToConstant: 30),

            middleLabel.leadingAnchor.constraint(equalTo: agreementControl.trailingAnchor),
            middleLabel.centerYAnchor.constraint(equalTo: prefixLabel.centerYAnchor),

            privacyControl.leadingAnchor.constraint(equalTo: middleLabel.trailingAnchor),
            privacyControl.centerYAnchor.constraint(equalTo: prefixLabel.centerYAnchor),
            privacyControl.heightAnchor.constraint(equalToConstant: 30),
            privacyControl.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -8)
        ])
        return container
    }

    private func underlinedAgreementButton(_ title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .custom)
        button.setAttributedTitle(
            NSAttributedString(
                string: title,
                attributes: [
                    .font: AppFont.source(12),
                    .foregroundColor: UIColor.darkGray,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
            ),
            for: .normal
        )
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func openUserAgreementPage() {
        RouteContextStore.setAgreementTitle("User Agreement")
        didRequestPage?(.agreement)
    }

    @objc private func openPrivacyPolicyPage() {
        RouteContextStore.setAgreementTitle("Privacy Policy")
        didRequestPage?(.agreement)
    }

    @objc private func handleAgreementConsentToggle() {
        Self.agreementConsentAccepted.toggle()
        refreshAgreementConsentIcon()
        NotificationCenter.default.post(name: Self.agreementConsentDidChangeNotification, object: self)
    }

    @objc private func handleAgreementConsentDidChange() {
        refreshAgreementConsentIcon()
    }

    @objc private func handleCreativeWorkActivityDidChange() {
        switch page {
        case .discover, .galleryDetail, .persona, .publicPersona:
            reloadRenderedContent()
        default:
            break
        }
    }

    private func refreshAgreementConsentIcon() {
        agreementConsentIconView?.image = UIImage(named: consentIconName(isSelected: Self.agreementConsentAccepted))
    }

    private func consentIconName(isSelected: Bool) -> String {
        isSelected ? "consent_check_selected" : "consent_circle_empty"
    }

    private func addCheckCircle(
        top: CGFloat,
        left: CGFloat,
        size: CGFloat = 17,
        color: UIColor = .black,
        text: String = ""
    ) {
        let view = UILabel()
        view.text = text
        view.textAlignment = .center
        view.font = AppFont.source(size * 0.56)
        view.textColor = color
        view.backgroundColor = .clear
        view.layer.cornerRadius = size / 2
        view.layer.borderWidth = 1.2
        view.layer.borderColor = color.cgColor
        addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor, constant: left),
            view.topAnchor.constraint(equalTo: topAnchor, constant: top),
            view.widthAnchor.constraint(equalToConstant: size),
            view.heightAnchor.constraint(equalToConstant: size)
        ])
    }

    private func addPortrait(top: CGFloat, left: CGFloat, size: CGFloat, tint: PortraitTint) {
        let layoutContainer = activeLayoutContainer ?? self
        let image = UIView()
        image.layer.cornerRadius = size / 2
        image.layer.masksToBounds = true
        let gradient = CAGradientLayer()
        gradient.colors = [tint.topColor.cgColor, tint.bottomColor.cgColor]
        gradient.startPoint = CGPoint(x: 0.2, y: 0)
        gradient.endPoint = CGPoint(x: 0.8, y: 1)
        gradient.frame = CGRect(x: 0, y: 0, width: size, height: size)
        image.layer.addSublayer(gradient)

        let hair = UIView()
        hair.backgroundColor = tint.accentColor
        hair.layer.cornerRadius = size * 0.25
        image.addSubview(hair)
        hair.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hair.leadingAnchor.constraint(equalTo: image.leadingAnchor, constant: size * 0.10),
            hair.topAnchor.constraint(equalTo: image.topAnchor, constant: size * 0.08),
            hair.widthAnchor.constraint(equalToConstant: size * 0.50),
            hair.heightAnchor.constraint(equalToConstant: size * 0.72)
        ])

        let face = UIView()
        face.backgroundColor = UIColor(red: 1.0, green: 0.78, blue: 0.58, alpha: 1)
        face.layer.cornerRadius = size * 0.20
        image.addSubview(face)
        face.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            face.leadingAnchor.constraint(equalTo: image.leadingAnchor, constant: size * 0.34),
            face.topAnchor.constraint(equalTo: image.topAnchor, constant: size * 0.24),
            face.widthAnchor.constraint(equalToConstant: size * 0.40),
            face.heightAnchor.constraint(equalToConstant: size * 0.48)
        ])

        layoutContainer.addSubview(image)
        image.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            image.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            image.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            image.widthAnchor.constraint(equalToConstant: size),
            image.heightAnchor.constraint(equalToConstant: size)
        ])
    }

    func updateRegistrationAvatar(_ image: UIImage) {
        registrationAvatarImageView?.image = image
    }

    func updateUploadMedia(
        previewImage: UIImage,
        mediaAsset: String,
        coverAsset: String,
        mediaKind: Int,
        durationSeconds: TimeInterval? = nil
    ) {
        uploadMediaAsset = mediaAsset
        uploadCoverAsset = coverAsset
        uploadMediaKind = mediaKind
        uploadDurationSeconds = durationSeconds
        uploadMediaSize = previewImage.size
        uploadMediaPreviewImageView?.image = previewImage
        uploadMediaPreviewImageView?.isHidden = false
        uploadMediaIconView?.isHidden = true
        uploadMediaPlayIconView?.isHidden = mediaKind != 1
    }

    func reloadRenderedContent() {
        galleryPreviewPlayer?.pause()
        galleryPreviewPlayer = nil
        subviews.forEach { $0.removeFromSuperview() }
        activeLayoutContainer = nil
        keyboardAwareScrollView = nil
        keyboardAvoidanceInputView = nil
        keyboardSyncedDialogueFlowListView = nil
        dialogueFlowListView = nil
        overlayContentView = nil
        registrationAvatarImageView = nil
        uploadTitleField = nil
        uploadDetailTextView = nil
        uploadThemeFlowView = nil
        uploadThemeEntryBar = nil
        uploadThemeEntryField = nil
        uploadThemeEntryBottomConstraint = nil
        uploadThemeHeightConstraint = nil
        uploadFormHeightConstraint = nil
        uploadMediaPreviewImageView = nil
        uploadMediaIconView = nil
        uploadMediaPlayIconView = nil
        profileEditAvatarImageView = nil
        profileEditNameField = nil
        uploadMediaAsset = nil
        uploadCoverAsset = nil
        uploadMediaSize = nil
        uploadMediaKind = 0
        uploadDurationSeconds = nil
        profileEditAvatarAsset = nil
        render()
    }

    @discardableResult
    private func addAssetAvatar(_ imageName: String, top: CGFloat, left: CGFloat, size: CGFloat) -> UIImageView {
        let layoutContainer = activeLayoutContainer ?? self
        let imageView = UIImageView(image: resolveVisualAsset(imageName))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = size / 2
        layoutContainer.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            imageView.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            imageView.widthAnchor.constraint(equalToConstant: size),
            imageView.heightAnchor.constraint(equalToConstant: size)
        ])
        return imageView
    }

    private func addAssetIcon(_ imageName: String, top: CGFloat, left: CGFloat, size: CGFloat) {
        let layoutContainer = activeLayoutContainer ?? self
        let imageView = UIImageView(image: UIImage(named: imageName))
        imageView.contentMode = .scaleAspectFit
        layoutContainer.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            imageView.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            imageView.widthAnchor.constraint(equalToConstant: size),
            imageView.heightAnchor.constraint(equalToConstant: size)
        ])
    }


    private func addMediaAccent(in block: UIView, tint: MediaTint) {
        let wash = UIView()
        wash.backgroundColor = tint.washColor
        wash.layer.cornerRadius = 38
        wash.alpha = 0.45
        block.addSubview(wash)
        wash.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            wash.trailingAnchor.constraint(equalTo: block.trailingAnchor, constant: -18),
            wash.topAnchor.constraint(equalTo: block.topAnchor, constant: 32),
            wash.widthAnchor.constraint(equalTo: block.widthAnchor, multiplier: 0.42),
            wash.heightAnchor.constraint(equalTo: block.heightAnchor, multiplier: 0.62)
        ])

        let horizon = UIView()
        horizon.backgroundColor = UIColor.white.withAlphaComponent(0.26)
        horizon.layer.cornerRadius = 2
        block.addSubview(horizon)
        horizon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            horizon.leadingAnchor.constraint(equalTo: block.leadingAnchor, constant: 18),
            horizon.trailingAnchor.constraint(equalTo: block.trailingAnchor, constant: -18),
            horizon.bottomAnchor.constraint(equalTo: block.bottomAnchor, constant: -36),
            horizon.heightAnchor.constraint(equalToConstant: 4)
        ])
    }

    private func addSymbolCircle(_ symbol: String, in block: UIView, right: CGFloat, bottom: CGFloat) {
        let label = UILabel()
        label.text = symbol
        label.textAlignment = .center
        label.textColor = .white
        label.font = AppFont.source(24, weight: .black)
        label.backgroundColor = UIColor.white.withAlphaComponent(0.72)
        label.textColor = .white
        label.layer.cornerRadius = 22
        label.layer.masksToBounds = true
        block.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.trailingAnchor.constraint(equalTo: block.trailingAnchor, constant: -right),
            label.bottomAnchor.constraint(equalTo: block.bottomAnchor, constant: -bottom),
            label.widthAnchor.constraint(equalToConstant: 44),
            label.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func addCapsuleSymbol(_ symbol: String, top: CGFloat, left: CGFloat, dark: Bool) {
        let label = UILabel()
        label.text = symbol
        label.textAlignment = .center
        label.font = AppFont.source(18, weight: .bold)
        label.textColor = dark ? .black : UIColor(red: 0.78, green: 1, blue: 0.20, alpha: 1)
        label.backgroundColor = dark ? .white : UIColor(red: 0.04, green: 0.05, blue: 0.04, alpha: 1)
        label.layer.cornerRadius = 14
        label.layer.masksToBounds = true
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: left),
            label.topAnchor.constraint(equalTo: topAnchor, constant: top),
            label.widthAnchor.constraint(equalToConstant: 60),
            label.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    private enum PortraitTint {
        case warm
        case cool

        var topColor: UIColor {
            switch self {
            case .warm: return UIColor(red: 0.98, green: 0.77, blue: 0.45, alpha: 1)
            case .cool: return UIColor(red: 0.72, green: 0.90, blue: 1.0, alpha: 1)
            }
        }

        var bottomColor: UIColor {
            switch self {
            case .warm: return UIColor(red: 0.54, green: 0.36, blue: 0.22, alpha: 1)
            case .cool: return UIColor(red: 0.24, green: 0.30, blue: 0.35, alpha: 1)
            }
        }

        var accentColor: UIColor {
            switch self {
            case .warm: return UIColor(red: 0.36, green: 0.20, blue: 0.10, alpha: 1)
            case .cool: return UIColor(red: 0.08, green: 0.13, blue: 0.16, alpha: 1)
            }
        }
    }

    private enum MediaTint {
        case coast
        case sky
        case forest
        case night
        case warm

        var baseColor: UIColor { topColor }

        var topColor: UIColor {
            switch self {
            case .coast: return UIColor(red: 0.35, green: 0.68, blue: 0.78, alpha: 1)
            case .sky: return UIColor(red: 0.52, green: 0.79, blue: 1.0, alpha: 1)
            case .forest: return UIColor(red: 0.42, green: 0.64, blue: 0.58, alpha: 1)
            case .night: return UIColor(red: 0.05, green: 0.18, blue: 0.22, alpha: 1)
            case .warm: return UIColor(red: 0.93, green: 0.70, blue: 0.50, alpha: 1)
            }
        }

        var bottomColor: UIColor {
            switch self {
            case .coast: return UIColor(red: 0.94, green: 0.76, blue: 0.50, alpha: 1)
            case .sky: return UIColor(red: 0.97, green: 0.88, blue: 0.72, alpha: 1)
            case .forest: return UIColor(red: 0.93, green: 0.82, blue: 0.58, alpha: 1)
            case .night: return UIColor(red: 0.34, green: 0.48, blue: 0.50, alpha: 1)
            case .warm: return UIColor(red: 0.74, green: 0.38, blue: 0.20, alpha: 1)
            }
        }

        var washColor: UIColor {
            switch self {
            case .night: return UIColor(red: 0.74, green: 0.92, blue: 1, alpha: 1)
            case .warm: return UIColor(red: 1.0, green: 0.90, blue: 0.82, alpha: 1)
            default: return UIColor.white
            }
        }
    }

    private enum MediaAction {
        case none
        case play
        case arrow
    }

    private enum ConversationMode {
        case text
        case voice
    }
}

extension ReferenceCanvasView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var touchedView = touch.view
        while let candidate = touchedView, candidate !== self {
            if candidate is UIControl || candidate is UITextField || candidate is UITextView {
                return false
            }
            touchedView = candidate.superview
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if gestureRecognizer is UITapGestureRecognizer,
           otherGestureRecognizer is UITapGestureRecognizer {
            return true
        }
        return gestureBelongsToScrollableArea(gestureRecognizer)
            || gestureBelongsToScrollableArea(otherGestureRecognizer)
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

extension ReferenceCanvasView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updatePersonaBackdrop(for: scrollView)
    }
}

extension ReferenceCanvasView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        textView.superview?
            .viewWithTag(Self.largeFieldPlaceholderTag)?
            .isHidden = textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}

extension ReferenceCanvasView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideProgressOverlay()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        hideProgressOverlay()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        hideProgressOverlay()
    }
}

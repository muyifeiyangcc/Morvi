import UIKit
import WebKit
import CoreImage
import CoreImage.CIFilterBuiltins

final class ReferenceCanvasView: UIView {
    private static var agreementConsentAccepted = false
    private static let agreementConsentDidChangeNotification = Notification.Name("Morvi.agreementConsentDidChange")
    private static let ciContext = CIContext(options: nil)

    private let page: ScenePage
    private let selectedMoodIndex: Int
    var didTapOutsideContent: (() -> Void)?
    var didRequestPage: ((ScenePage) -> Void)?
    var didRequestOverlayPage: ((ScenePage) -> Void)?
    private weak var activeLayoutContainer: UIView?
    private weak var keyboardAwareScrollView: UIScrollView?
    private weak var keyboardAvoidanceInputView: UIView?
    private weak var overlayContentView: UIView?
    private var keyboardAvoidanceBottomConstraint: NSLayoutConstraint?
    private var keyboardAvoidanceBaseBottomConstant: CGFloat = 0
    private var keyboardBaseContentInset: UIEdgeInsets?
    private var keyboardBaseIndicatorInsets: UIEdgeInsets?
    private var keyboardBaseContentOffset: CGPoint?
    private var keyboardIsVisible = false
    private let replyListDataSource = ReplyListDataSource()
    private weak var agreementConsentIconView: UIImageView?
    private weak var progressOverlayView: MorviProgressOverlayView?

    init(page: ScenePage, selectedMoodIndex: Int = 0) {
        self.page = page
        self.selectedMoodIndex = selectedMoodIndex
        super.init(frame: .zero)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAgreementConsentDidChange),
            name: Self.agreementConsentDidChangeNotification,
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
        case .entry, .signIn, .signUp, .resetAccess, .agreement, .personalDetail, .home, .discover:
            return true
        default:
            return false
        }
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
            renderList(title: "Settings", sections: [["Wallet", "Blacklist", "Privacy Policy", "User Agreement"], ["Delete account", "Log out"]])
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
        case .publicPersona:
            renderPersonaDetail(title: "Victoria")
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
        case .agreement:
            renderAgreement()
        case .accessGate:
            renderConfirmCard(title: "Log in", text: "To ensure the normal operation\nof the function, please log in to\nyour account first.", confirm: "Log in", portrait: false, showsWordmark: true)
        case .spendConfirm:
            renderConfirmCard(title: nil, text: "Are you sure you want to spend\n200 diamonds to unlock the AI\nfunction?", confirm: "Sure", portrait: false)
        case .creditShortage:
            renderConfirmCard(title: nil, text: "Unfortunately, your account\nbalance is insufficient. Please go\nto recharge.", confirm: "Recharge", portrait: false)
        case .restrictConfirm:
            renderConfirmCard(title: "Victoria", text: "Are you sure you want to block\nthis user? After blocking, no\nrelated content will be received.", confirm: "Sure", portrait: true)
        case .exitConfirm:
            renderConfirmCard(title: nil, text: "Are you sure you want to delete\nthis account? All data will be\ncleared after deletion and cannot\nbe recovered.", confirm: "Sure", portrait: false)
        }
    }

    private func renderEntry() {
        let consentLine = addAgreementConsentLine(bottom: 51)
        let scrollView = UIScrollView()
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
        addText("Other login methods", size: 12, weight: .regular, top: 608, centered: true, color: .lightGray)
        addAppleLoginCircle(top: 640, left: 168)
        activeLayoutContainer = nil
    }

    private func renderHome() {
        let scrollView = UIScrollView()
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
            top: 60,
            left: 20,
            size: 58,
            backgroundColor: UIColor(white: 0.8, alpha: 1),
            showsBorder: false,
            showsShadow: false
        )
        addText("Welcome back", size: 17, weight: .black, top: 68, left: 96)
        addText("Amelia", size: 16, weight: .regular, top: 98, left: 96)
        addText("Hello, Anna!\nDid everything go\nsmoothly today?", size: 30, weight: .regular, top: 146, left: 20)
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
        addFeatureCard(title: "Discover", top: 536, left: 20, tint: .forest, imageName: "home_discover")
        addFeatureCard(title: "Recot Bot", top: 536, left: 192, tint: .night, imageName: "home_recot_bot")
        activeLayoutContainer = nil
    }

    private func renderDiscover() {
        addTopTitle("Discover")
        let scrollView = UIScrollView()
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
            scrollContent.heightAnchor.constraint(equalToConstant: 1090)
        ])

        activeLayoutContainer = scrollContent
        addStoryStrip(top: 22)
        addFeedCard(name: "Victoria", top: 126, tint: .coast)
        addFeedCard(name: "Rowan", top: 594, tint: .sky)
        activeLayoutContainer = nil
    }

    private func renderDialogueList() {
        addTopTitle("Chat")
        let names = ["Victoria", "Rowan", "Jasper", "Sophia"]
        for index in 0..<names.count {
            let left: CGFloat = index % 2 == 0 ? 20 : 192
            let top: CGFloat = index < 2 ? 146 : 342
            addDialogueCard(name: names[index], top: top, left: left, dark: index == 1 || index == 2)
        }
    }

    private func renderPersona() {
        addGradientBand(height: 258)
        let base = addPanel(top: 228, left: 0, width: 375, height: 584, alpha: 1)
        base.backgroundColor = UIColor(red: 0.91, green: 1.0, blue: 0.78, alpha: 1)
        base.layer.borderWidth = 0
        addPortrait(top: 198, left: 36, size: 74, tint: .warm)
        addText("Amelia", size: 21, weight: .regular, top: 290, left: 36)
        addText("77 Followers    99 Following", size: 14, weight: .regular, top: 328, left: 20, color: .darkGray)
        addCircle(text: "⌾", top: 247, left: 214, size: 30, color: UIColor(red: 0.74, green: 0.93, blue: 1.0, alpha: 1))
        addButton("Edit Profile", top: 244, left: 250, width: 110, filled: false, dark: true)
        addMediaGrid(top: 364)
    }

    private func renderConversation(title: String, mode: ConversationMode) {
        addTopTitle(title)
        addText("•••", size: 22, weight: .black, top: 80, left: 318)
        addBubble("Nice to meet you, nice\nto meet you!", top: 198, left: 82, outgoing: true)
        addPortrait(top: 196, left: 306, size: 44, tint: .warm)
        addPortrait(top: 298, left: 26, size: 44, tint: .warm)
        addBubble("Nice to meet you.", top: 302, left: 86, outgoing: false)
        addMediaBlock(top: 358, left: 82, width: 160, height: 160, title: "", tint: .warm)
        switch mode {
        case .text:
            addText("♩", size: 28, weight: .regular, top: 704, left: 24, color: .gray)
            addText("▣", size: 24, weight: .regular, top: 708, left: 56, color: .gray)
            addInputBar(top: 740, text: "Say something", trailing: "➤")
        case .voice:
            addVoiceClip(top: 552)
            let panel = addPanel(top: 586, left: 0, width: 375, height: 226, alpha: 1)
            panel.backgroundColor = UIColor(red: 1.0, green: 0.76, blue: 0.02, alpha: 1)
            panel.layer.borderWidth = 0
            addText("▦", size: 24, weight: .regular, top: 606, left: 20)
            addCircle(text: "♬", top: 650, left: 138, size: 100, color: UIColor(red: 0.82, green: 1, blue: 0.78, alpha: 1))
        }
    }

    private func renderAssistantDialogue() {
        addTopTitle("Recot Bot")
        addMediaBlock(top: 136, left: 20, width: 335, height: 265, title: "AI", tint: .night)
        let intro = addPanel(top: 296, left: 36, width: 303, height: 86, alpha: 1)
        intro.backgroundColor = UIColor(red: 0.88, green: 1, blue: 0.74, alpha: 1)
        intro.layer.borderWidth = 0
        addText("Hello!\nHow can I help you?", size: 20, weight: .regular, top: 318, left: 52)
        addBubble("How to develop self-discipline?", top: 430, left: 88, outgoing: true, width: 267, height: 56)
        addBubble("Cultivating self-discipline is a\nprocess that requires patience,\nstrategy and continuous practice. It\nis not achieved overnight but\nthrough gradually adjusting habits,\nstrengthening willpower and\nestablishing a support system.", top: 506, left: 20, outgoing: false)
        addInputBar(top: 740, text: "Say something", trailing: "➤")
    }

    private func renderGalleryDetail() {
        addFullscreenGalleryCover()
        let panelTop: CGFloat = 586
        let tagsTop: CGFloat = 718
        let tagsHeight = measuredTagsHeight(left: 20, right: 20)
        let reactionsTop = tagsTop + tagsHeight + 22
        let panelHeight = reactionsTop + 18 + 28 - panelTop
        let panel = addGlassPanel(
            top: panelTop,
            left: 0,
            width: 375,
            height: panelHeight,
            radius: 14,
            fillAlpha: 0.4,
            blurRadius: 16,
            backdropAssetName: "discover_feed_cover"
        )
        panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        addAssetAvatar("profile_avatar", top: 609, left: 20, size: 36)
        addText("Victoria", size: 17, weight: .bold, top: 617, left: 68)
        addText("Capturing today's happiness. Saving it for\ntomorrow's memories.", size: 16, weight: .regular, top: 664, left: 20)
        addTags(top: tagsTop, left: 20, right: 20)
        addText("♡ 666 Likes       ☵ 777 Comments", size: 13, weight: .regular, top: reactionsTop, left: 22, color: .darkGray)
    }

    private func addFullscreenGalleryCover() {
        let coverImage = UIImage(named: "discover_feed_cover")
        let coverView = UIImageView(image: coverImage)
        coverView.contentMode = .scaleAspectFill
        coverView.clipsToBounds = true
        addSubview(coverView)
        coverView.translatesAutoresizingMaskIntoConstraints = false
        pinFullHeightImageView(coverView, image: coverImage)

        let iconView = UIImageView(image: UIImage(named: "video_play_icon"))
        iconView.contentMode = .scaleAspectFit
        coverView.addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: coverView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: coverView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    private func renderPersonaDetail(title: String) {
        addPersonaBackdrop()
        let base = addPanel(top: 328, left: 0, width: 375, height: 484, alpha: 1)
        addThemeGradientBackground(to: base, width: 375, height: 484, cornerRadius: 20)
        base.backgroundColor = .clear
        base.layer.borderWidth = 0
        base.layer.cornerRadius = 20
        addProfileAvatar(top: 268, left: 128, size: 120, showsBorder: false, showsShadow: false)
        addText(title, size: 26, weight: .bold, top: 394, centered: true)
        addStatsPanel(top: 434)
        addPillButton("Chat", top: 535, left: 20, width: 160, height: 40, dark: true)
        addPillButton("Follow", top: 535, left: 195, width: 160, height: 40, dark: true)
        addMediaBlock(top: 599, left: 20, width: 160, height: 174, title: "", tint: .warm, action: .play, imageName: "discover_feed_cover")
        addMediaBlock(top: 599, left: 195, width: 160, height: 150, title: "", tint: .coast, action: .play, imageName: "discover_feed_cover")
        addMediaBlock(top: 775, left: 195, width: 160, height: 150, title: "", tint: .night, action: .play, imageName: "discover_feed_cover")
    }

    private func addPersonaBackdrop() {
        let coverImage = UIImage(named: "discover_feed_cover")
        let coverView = UIImageView(image: coverImage)
        coverView.contentMode = .scaleAspectFill
        coverView.clipsToBounds = true
        addSubview(coverView)
        coverView.translatesAutoresizingMaskIntoConstraints = false

        var constraints = [
            coverView.leadingAnchor.constraint(equalTo: leadingAnchor),
            coverView.trailingAnchor.constraint(equalTo: trailingAnchor),
            coverView.topAnchor.constraint(equalTo: topAnchor, constant: -2)
        ]
        if let coverImage, coverImage.size.width > 0 {
            constraints.append(coverView.heightAnchor.constraint(
                equalTo: coverView.widthAnchor,
                multiplier: coverImage.size.height / coverImage.size.width
            ))
        } else {
            constraints.append(coverView.heightAnchor.constraint(equalToConstant: 403))
        }
        NSLayoutConstraint.activate(constraints)
    }

    private func addThemeGradientBackground(to view: UIView, width: CGFloat, height: CGFloat, cornerRadius: CGFloat) {
        let backgroundView = UIView()
        backgroundView.layer.cornerRadius = cornerRadius
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
        let scrollView = UIScrollView()
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
        NSLayoutConstraint.activate([
            scrollContent.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContent.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContent.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            scrollContent.heightAnchor.constraint(equalToConstant: 812)
        ])

        keyboardAwareScrollView = scrollView
        installKeyboardAvoidance()

        activeLayoutContainer = scrollContent
        addTopTitle("Sign in")
        addLogo(top: 168)
        addText("Morvi", size: 42, weight: .black, top: 308, centered: true)
        addText("Email", size: 16, weight: .black, top: 388, left: 20)
        addInputField("Please enter", top: 413, keyboardType: .emailAddress)
        addText("Password", size: 16, weight: .black, top: 496, left: 20)
        addInputField("Please enter", top: 523, isSecureTextEntry: true)
        addUnderlinedText("Forgot ?", size: 12, top: 588, left: 303, color: .gray)
        activeLayoutContainer = nil
        addButton("Log in", top: 716, filled: true, usesOneFont: true)
    }

    private func renderSignUp() {
        let scrollView = UIScrollView()
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
        NSLayoutConstraint.activate([
            scrollContent.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContent.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContent.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            scrollContent.heightAnchor.constraint(equalToConstant: 812)
        ])

        keyboardAwareScrollView = scrollView
        installKeyboardAvoidance()

        activeLayoutContainer = scrollContent
        addTopTitle("Sign up")
        addLogo(top: 168)
        addText("Morvi", size: 42, weight: .black, top: 308, centered: true)
        let fields = ["Email", "Password", "Enter the password again"]
        fields.enumerated().forEach { index, field in
            let top = CGFloat(388 + index * 108)
            addText(field, size: 16, weight: .bold, top: top, left: 20)
            addInputField(
                "Please enter",
                top: top + 26,
                keyboardType: index == 0 ? .emailAddress : .default,
                isSecureTextEntry: index != 0
            )
        }
        activeLayoutContainer = nil
        addButton("Sign up", top: 716, filled: true, usesOneFont: true)
    }

    private func renderResetAccess() {
        let scrollView = UIScrollView()
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
        NSLayoutConstraint.activate([
            scrollContent.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContent.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContent.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            scrollContent.heightAnchor.constraint(equalToConstant: 812)
        ])

        keyboardAwareScrollView = scrollView
        installKeyboardAvoidance()

        activeLayoutContainer = scrollContent
        addTopTitle("Forgot password")
        let fields = ["Email", "Password", "Enter the password again"]
        fields.enumerated().forEach { index, field in
            let top = CGFloat(158 + index * 108)
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
        addButton("Next", top: 716, filled: true, usesOneFont: true)
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
        let balance = addPanel(top: 156, left: 20, width: 335, height: 122, alpha: 1)
        balance.backgroundColor = UIColor(red: 0.04, green: 0.05, blue: 0.04, alpha: 1)
        balance.layer.borderWidth = 0
        addText("My balance", size: 20, weight: .regular, top: 194, left: 36, color: .white)
        addText("1000", size: 34, weight: .black, top: 224, left: 36, color: UIColor(red: 0.79, green: 1, blue: 0.18, alpha: 1))
        addGem(top: 118, left: 190, size: 128)
        let amounts = ["400", "800", "1780", "2450", "5150", "10800", "14900"]
        let prices = ["$0.99", "$1.99", "$3.99", "$4.99", "$9.99", "$19.99", "$29.99"]
        for index in amounts.indices {
            let top = CGFloat(288 + index * 80)
            _ = addPanel(top: top, left: 15, width: 345, height: 68, alpha: 1)
            addGem(top: top + 20, left: 34, size: 32)
            addText(amounts[index], size: 24, weight: .regular, top: top + 22, left: 80)
            addText(prices[index], size: 20, weight: .regular, top: top + 24, left: 290, color: .darkGray)
            addLine(top: top + 50, left: 290, width: 54, color: UIColor(red: 0.76, green: 1, blue: 0.20, alpha: 1))
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
        activeLayoutContainer = nil

        let scrollView = UIScrollView()
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
            formView.heightAnchor.constraint(equalToConstant: 450)
        ])

        activeLayoutContainer = formView
        addText("Title of work:", size: 17, weight: .regular, top: 0, left: 20)
        addInputField("Enter the title", top: 32)
        addText("Theme:", size: 17, weight: .regular, top: 99, left: 20)
        if filled {
            addSmallField("Theme", top: 131, left: 20, width: 70)
            addSmallField(nil, imageName: "theme_add_icon", top: 131, left: 108, width: 76)
        } else {
            addSmallField(nil, imageName: "theme_add_icon", top: 131, left: 20, width: 78) { [weak self] in
                self?.didRequestOverlayPage?(.uploadFilled)
            }
        }
        addText("Description:", size: 17, weight: .regular, top: 190, left: 20)
        addLargeField("Say something", top: 222)
        addUploadBox(top: 337)
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
            _ = addPanel(top: top, left: 20, width: 335, height: height, alpha: 1)
            var rowTop = top + 18
            section.forEach { row in
                addRow(row, top: rowTop)
                rowTop += 64
            }
            top += height + 28
        }
    }

    private func renderPersonalDetail() {
        let scrollView = UIScrollView()
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
        NSLayoutConstraint.activate([
            scrollContent.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContent.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContent.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContent.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContent.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            scrollContent.heightAnchor.constraint(equalToConstant: 700)
        ])

        keyboardAwareScrollView = scrollView
        installKeyboardAvoidance()

        activeLayoutContainer = scrollContent
        addProfileAvatar(top: 147, left: 145, size: 84)
        addAvatarEditBadge(top: 210, left: 207)
        let items = [
            ("Email", "Please enter"),
            ("Gender", "Female"),
            ("Birthday", "Please enter"),
            ("Location", "Please enter")
        ]
        for index in items.indices {
            let top = CGFloat(274 + index * 109)
            addText(items[index].0, size: 17, weight: .black, top: top, left: 20)
            addInputField(items[index].1, top: top + 27, keyboardType: index == 0 ? .emailAddress : .default)
        }
        activeLayoutContainer = nil
        addButton("Sign up", top: 716, filled: true, usesOneFont: true)
    }

    private func renderRestrictedList() {
        addTopTitle("Blacklist")
        let names = ["Victoria", "Rowan", "Jasper", "Sophia"]
        for index in names.indices {
            let left: CGFloat = index % 2 == 0 ? 20 : 192
            let top: CGFloat = index < 2 ? 146 : 342
            let card = addPanel(top: top, left: left, width: 164, height: 186, alpha: 1)
            card.layer.cornerRadius = 12
            addPortrait(top: top + 27, left: left + 50, size: 64, tint: index.isMultiple(of: 2) ? .warm : .cool)
            addText(names[index], size: 17, weight: .regular, top: top + 101, left: left + 52)
            addCapsuleSymbol("↶", top: top + 140, left: left + 86, dark: false)
        }
    }

    private func renderAgreement() {
        addTopTitle("EULA")
        let bottomBar = UIView()
        bottomBar.backgroundColor = .clear
        addSubview(bottomBar)
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -32),
            bottomBar.heightAnchor.constraint(equalToConstant: 129)
        ])

        let webView = WKWebView(frame: .zero)
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.contentInset.bottom = 16
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.navigationDelegate = self
        addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            webView.topAnchor.constraint(equalTo: topAnchor, constant: 120),
            webView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -10)
        ])

        addText("Terms of Use", size: 16, weight: .regular, top: 0, left: 61, parent: bottomBar)
        addLine(top: 19, left: 61, width: 95, color: .darkGray, parent: bottomBar)
        addText("Privacy Policy", size: 16, weight: .regular, top: 0, left: 213, parent: bottomBar)
        addLine(top: 19, left: 213, width: 101, color: .darkGray, parent: bottomBar)
        addPillButton("Cancel", top: 33, left: 48, width: 124, dark: false, fontWeight: .medium, parent: bottomBar)
        addPillButton("I agree", top: 33, left: 204, width: 124, dark: true, fontWeight: .medium, parent: bottomBar)
        addAgreementConsentLine(top: 109, parent: bottomBar)
        bringSubviewToFront(bottomBar)
        showProgressOverlay()
        webView.loadHTMLString(agreementHTML(), baseURL: nil)
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
        <p>By using the App, you acknowledge having read and agreed to our [Privacy Policy], which details how we collect, use and protect your personal information.</p>
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

    private func hideProgressOverlay() {
        progressOverlayView?.dismiss()
        progressOverlayView = nil
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
            bottomInset: 16
        )
        feelingInput.topAnchor.constraint(equalTo: card.topAnchor, constant: 75).isActive = true
        keyboardAvoidanceInputView = feelingInput
        installKeyboardAvoidance()
        installBlankAreaKeyboardDismissal()
        sheet.layoutIfNeeded()
        (uploadButton.layer.sublayers?.first as? CAGradientLayer)?.frame = uploadButton.bounds
    }

    private func renderWeeklyFeeling() {
        addText("This week's feelings", size: 25, weight: .black, top: 68, left: 20)
        let days = ["Sun", "Mon", "Tue", "Wed", "Thr", "Fri", "Sat"]
        let faces = ["😃", "😟", "☹️", "😭", "😆", "😌", "😎"]
        let heights: [CGFloat] = [200, 148, 118, 82, 104, 156, 198]
        for index in 0..<days.count {
            let x = CGFloat(20 + index * 49)
            addFeelingBar(day: days[index], face: faces[index], height: heights[index], left: x)
        }
        addFeelingCard(top: 401, color: UIColor(red: 0.87, green: 1, blue: 0.61, alpha: 1))
        addFeelingCard(top: 573, color: UIColor(red: 0.86, green: 0.98, blue: 1, alpha: 1))
    }

    private func renderProfileEditor() {
        renderPersona()
        let veil = UIView()
        veil.backgroundColor = UIColor.black.withAlphaComponent(0.56)
        addSubview(veil)
        veil.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            veil.leadingAnchor.constraint(equalTo: leadingAnchor),
            veil.trailingAnchor.constraint(equalTo: trailingAnchor),
            veil.topAnchor.constraint(equalTo: topAnchor),
            veil.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let sheet = addPanel(top: 378, left: 0, width: 375, height: 434, alpha: 1)
        sheet.backgroundColor = .white
        sheet.layer.cornerRadius = 20
        addText("Edit Profile", size: 31, weight: .black, top: 412, left: 20)
        addCircle(text: "●\n◠", top: 494, left: 151, size: 74, color: UIColor(white: 0.95, alpha: 1))
        addCircle(text: "⊙", top: 552, left: 213, size: 20, color: UIColor(red: 0.76, green: 1, blue: 0.20, alpha: 1))
        addText("Username:", size: 16, weight: .regular, top: 626, left: 20)
        addField("Enter username", top: 654)
        addButton("Upload", top: 732, filled: true, usesOneFont: true)
    }

    private func renderRepliesPanel() {
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
            in: self
        ) { [weak self] bottomConstraint in
            self?.keyboardAvoidanceBottomConstraint = bottomConstraint
            self?.keyboardAvoidanceBaseBottomConstant = -29
        }
        let tableView = UITableView(frame: .zero, style: .plain)
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
            tableView.bottomAnchor.constraint(equalTo: sheet.bottomAnchor, constant: -94)
        ])
        replyListDataSource.apply([
            ReplyListItem(name: "Jasper", text: "The video content is great! Keep going!The\nvideo content is great! Keep going!"),
            ReplyListItem(name: "Rowan", text: "The video content is great! Keep going!"),
            ReplyListItem(name: "Sophia", text: "The video content is great! Keep going!")
        ], to: tableView)
        replyListDataSource.didTapMore = { [weak self] in
            self?.didRequestOverlayPage?(.restrictPanel)
        }
        keyboardAvoidanceInputView = inputBar
        installKeyboardAvoidance()
        installBlankAreaKeyboardDismissal()
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
            addReportChoiceRow(rows[index], top: top, checked: index == 5)
        }
        addButton(
            "Upload",
            bottom: 29,
            trailing: 20,
            filled: true,
            usesOneFont: true,
            cornerRadius: 12,
            shadowOpacity: 0,
            bottomPlateHeight: 3
        )
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
        addOptionTile(iconName: "restrict_report_icon", top: 81, left: 49, width: 130) { [weak self] in
            self?.didRequestOverlayPage?(.reportPanel)
        }
        addOptionTile(iconName: "restrict_block_icon", top: 81, left: 196, width: 130) { [weak self] in
            self?.didRequestOverlayPage?(.restrictConfirm)
        }
        activeLayoutContainer = nil
        installBlankAreaKeyboardDismissal()
    }

    private func renderConfirmCard(title: String?, text: String, confirm: String, portrait: Bool, showsWordmark: Bool = false) {
        backgroundColor = UIColor(white: 0, alpha: 0.58)
        let panelTop: CGFloat = portrait ? 245 : 307
        let titleTop = panelTop + 39
        let portraitAvatarTop: CGFloat = 286
        let portraitAvatarLeft: CGFloat = 150
        let portraitAvatarSize: CGFloat = 76
        let titleHeight = title == nil ? 0 : AppFont.fredoka(31).lineHeight
        let textTop: CGFloat = portrait
            ? portraitAvatarTop + portraitAvatarSize + restrictPopupNamePillHeight() / 2 + 20
            : (title == nil ? panelTop + 39 : titleTop + titleHeight + 24)
        let textHeight = CGFloat(text.components(separatedBy: "\n").count) * sourceFont(for: text, size: 17, weight: .regular).lineHeight
        let buttonTop: CGFloat = textTop + textHeight + 24
        let panelHeight: CGFloat = portrait ? 340 : buttonTop + 50 + 36 - panelTop
        let panel = addPanel(top: panelTop, left: 30, width: 322, height: panelHeight, alpha: 1)
        panel.backgroundColor = .clear
        panel.layer.borderWidth = 0
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
        if portrait {
            addRestrictPopupAvatar(top: portraitAvatarTop, left: portraitAvatarLeft, size: portraitAvatarSize)
        }
        if let title {
            if portrait {
                addRestrictPopupNamePill(title, avatarTop: portraitAvatarTop, avatarLeft: portraitAvatarLeft, avatarSize: portraitAvatarSize)
            } else {
                addText(title, size: 31, weight: .black, top: titleTop, centered: true, usesOneFont: true)
            }
        }
        addText(text, size: 17, weight: .regular, top: textTop, left: 66)
        let cancelButton = addPillButton("Cancel", top: buttonTop, left: 66, width: 112, dark: false, fontWeight: .medium)
        cancelButton.addTarget(self, action: #selector(closePopupOverlay), for: .touchUpInside)
        let confirmButton = addPillButton(confirm, top: buttonTop, left: 204, width: 112, dark: true, fontWeight: .medium)
        if page == .accessGate {
            confirmButton.addTarget(self, action: #selector(openSignInFromPopup), for: .touchUpInside)
        }
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

    private func addRestrictPopupAvatar(top: CGFloat, left: CGFloat, size: CGFloat) {
        let ringInset: CGFloat = 6
        let ringView = UIImageView(image: UIImage(named: "restrict_avatar_ring"))
        ringView.contentMode = .scaleAspectFit
        addSubview(ringView)
        ringView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            ringView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: left - ringInset),
            ringView.topAnchor.constraint(equalTo: topAnchor, constant: top - ringInset),
            ringView.widthAnchor.constraint(equalToConstant: size + ringInset * 2),
            ringView.heightAnchor.constraint(equalToConstant: size + ringInset * 2)
        ])

        let imageView = UIImageView(image: UIImage(named: "profile_avatar"))
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = size / 2
        imageView.layer.masksToBounds = true
        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: left),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: top),
            imageView.widthAnchor.constraint(equalToConstant: size),
            imageView.heightAnchor.constraint(equalToConstant: size)
        ])
    }

    private func addRestrictPopupNamePill(_ text: String, avatarTop: CGFloat, avatarLeft: CGFloat, avatarSize: CGFloat) {
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
        addSubview(shadowView)
        shadowView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            shadowView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: left),
            shadowView.topAnchor.constraint(equalTo: topAnchor, constant: top + shadowDrop),
            shadowView.widthAnchor.constraint(equalToConstant: width),
            shadowView.heightAnchor.constraint(equalToConstant: height)
        ])

        let pillView = UIView()
        pillView.layer.cornerRadius = height / 2
        pillView.layer.cornerCurve = .continuous
        pillView.layer.masksToBounds = true
        addSubview(pillView)
        pillView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pillView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: left),
            pillView.topAnchor.constraint(equalTo: topAnchor, constant: top),
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

    private func addText(
        _ text: String,
        size: CGFloat,
        weight: UIFont.Weight,
        top: CGFloat,
        left: CGFloat? = nil,
        centered: Bool = false,
        color: UIColor = .black,
        parent: UIView? = nil,
        usesOneFont: Bool = false
    ) {
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
                label.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top)
            ])
        } else {
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left ?? 20),
                label.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
                label.trailingAnchor.constraint(lessThanOrEqualTo: layoutContainer.trailingAnchor, constant: -20)
            ])
        }
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
        trailing: CGFloat? = nil,
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
        keyboardType: UIKeyboardType = .default,
        isSecureTextEntry: Bool = false
    ) -> UITextField {
        let field = addFieldContainer(top: top)
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

    private func addFieldContainer(top: CGFloat) -> UIView {
        let layoutContainer = activeLayoutContainer ?? self
        let field = AdaptiveInputView(
            backgroundColor: .clear,
            gradientColors: [
                UIColor(red: 0.94, green: 1, blue: 0.72, alpha: 1),
                UIColor(red: 0.88, green: 1, blue: 0.95, alpha: 1)
            ]
        )
        layoutContainer.addSubview(field)
        field.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: 20),
            field.trailingAnchor.constraint(equalTo: layoutContainer.trailingAnchor, constant: -20),
            field.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            field.heightAnchor.constraint(equalToConstant: 54)
        ])
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
        top: CGFloat,
        left: CGFloat,
        size: CGFloat,
        backgroundColor: UIColor = UIColor(white: 0.94, alpha: 1),
        showsBorder: Bool = true,
        showsShadow: Bool = true
    ) {
        let layoutContainer = activeLayoutContainer ?? self
        let imageView = UIImageView(image: UIImage(named: "profile_avatar"))
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

    private func addAppleLoginCircle(top: CGFloat, left: CGFloat) {
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
            background.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            background.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            background.widthAnchor.constraint(equalToConstant: 40),
            background.heightAnchor.constraint(equalToConstant: 40),

            icon.centerXAnchor.constraint(equalTo: background.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: background.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    private func addPanel(top: CGFloat, left: CGFloat, width: CGFloat, height: CGFloat, alpha: CGFloat) -> UIView {
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
        addSubview(panel)
        panel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: left),
            panel.topAnchor.constraint(equalTo: topAnchor, constant: top),
            panel.widthAnchor.constraint(equalToConstant: width),
            panel.heightAnchor.constraint(equalToConstant: height)
        ])
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
        backdropAssetName: String? = nil
    ) -> UIView {
        let panel = UIView()
        panel.backgroundColor = .clear
        panel.layer.cornerRadius = radius
        panel.layer.masksToBounds = true
        addSubview(panel)
        panel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: left),
            panel.topAnchor.constraint(equalTo: topAnchor, constant: top),
            panel.widthAnchor.constraint(equalToConstant: width),
            panel.heightAnchor.constraint(equalToConstant: height)
        ])

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

    private func pinFullHeightImageView(_ imageView: UIImageView, image: UIImage?) {
        var constraints = [
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor)
        ]
        if let image, image.size.height > 0 {
            constraints.append(imageView.widthAnchor.constraint(
                equalTo: imageView.heightAnchor,
                multiplier: image.size.width / image.size.height
            ))
        } else {
            constraints.append(contentsOf: [
                imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: trailingAnchor)
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

    @discardableResult
    private func addLargeField(
        _ text: String,
        top: CGFloat? = nil,
        height: CGFloat = 98,
        horizontalMargin: CGFloat = 20,
        parent: UIView? = nil,
        bottomAnchor: NSLayoutYAxisAnchor? = nil,
        bottomInset: CGFloat = 0
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
        } else if let top {
            fieldConstraints.append(field.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top))
        }
        NSLayoutConstraint.activate(fieldConstraints)
        let inputView = UITextView()
        inputView.text = text
        inputView.textColor = .darkGray
        inputView.font = AppFont.source(14)
        inputView.backgroundColor = .clear
        inputView.textContainerInset = .zero
        inputView.textContainer.lineFragmentPadding = 0
        field.addSubview(inputView)
        inputView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            inputView.leadingAnchor.constraint(equalTo: field.leadingAnchor, constant: 16),
            inputView.trailingAnchor.constraint(equalTo: field.trailingAnchor, constant: -16),
            inputView.topAnchor.constraint(equalTo: field.topAnchor, constant: 16),
            inputView.bottomAnchor.constraint(equalTo: field.bottomAnchor, constant: -16)
        ])
        return field
    }

    @discardableResult
    private func addInputBar(top: CGFloat, text: String, trailing: String, usesDashedBorder: Bool = false) -> UIView {
        let layoutContainer = activeLayoutContainer ?? self
        return addInputBar(top: top, bottom: nil, text: text, trailing: trailing, usesDashedBorder: usesDashedBorder, in: layoutContainer)
    }

    private func addInputBar(
        bottom: CGFloat,
        text: String,
        trailing: String,
        usesDashedBorder: Bool = false,
        in layoutContainer: UIView,
        bottomConstraintHandler: ((NSLayoutConstraint) -> Void)? = nil
    ) -> UIView {
        addInputBar(
            top: nil,
            bottom: bottom,
            text: text,
            trailing: trailing,
            usesDashedBorder: usesDashedBorder,
            in: layoutContainer,
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
        inputSurface.addSubview(prompt)
        prompt.translatesAutoresizingMaskIntoConstraints = false
        let action: UIView
        if trailing.isEmpty {
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
        NSLayoutConstraint.activate([
            prompt.leadingAnchor.constraint(equalTo: inputSurface.leadingAnchor, constant: 16),
            prompt.trailingAnchor.constraint(equalTo: action.leadingAnchor, constant: -12),
            prompt.centerYAnchor.constraint(equalTo: inputSurface.centerYAnchor),
            action.trailingAnchor.constraint(equalTo: inputSurface.trailingAnchor, constant: -16),
            action.centerYAnchor.constraint(equalTo: inputSurface.centerYAnchor),
            action.widthAnchor.constraint(equalToConstant: trailing.isEmpty ? 28 : 24),
            action.heightAnchor.constraint(equalToConstant: trailing.isEmpty ? 28 : 28)
        ])
        return bar
    }

    private func addUploadBox(top: CGFloat, action: (() -> Void)? = nil) {
        let layoutContainer = activeLayoutContainer ?? self
        let box = AdaptiveInputView(
            backgroundColor: UIColor(red: 0.94, green: 1, blue: 0.72, alpha: 1)
        )
        layoutContainer.addSubview(box)
        box.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            box.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: 20),
            box.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            box.widthAnchor.constraint(equalToConstant: 92),
            box.heightAnchor.constraint(equalToConstant: 115)
        ])
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

    private func addGem(top: CGFloat, left: CGFloat, size: CGFloat) {
        let gem = UILabel()
        gem.text = "◆"
        gem.textAlignment = .center
        gem.font = AppFont.source(size, weight: .black)
        gem.textColor = UIColor(red: 0.04, green: 0.82, blue: 0.12, alpha: 1)
        gem.layer.shadowColor = UIColor.green.cgColor
        gem.layer.shadowOpacity = 0.28
        gem.layer.shadowRadius = 8
        gem.layer.shadowOffset = CGSize(width: 0, height: 4)
        addSubview(gem)
        gem.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            gem.leadingAnchor.constraint(equalTo: leadingAnchor, constant: left),
            gem.topAnchor.constraint(equalTo: topAnchor, constant: top),
            gem.widthAnchor.constraint(equalToConstant: size),
            gem.heightAnchor.constraint(equalToConstant: size)
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

    private func addFeelingBar(day: String, face: String, height: CGFloat, left: CGFloat) {
        let bg = UIView()
        bg.backgroundColor = UIColor(red: 1, green: 0.94, blue: 0.62, alpha: 1)
        bg.layer.cornerRadius = 19
        addSubview(bg)
        bg.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bg.leadingAnchor.constraint(equalTo: leadingAnchor, constant: left),
            bg.topAnchor.constraint(equalTo: topAnchor, constant: 121),
            bg.widthAnchor.constraint(equalToConstant: 40),
            bg.heightAnchor.constraint(equalToConstant: 220)
        ])
        let fill = UIView()
        fill.backgroundColor = UIColor(red: 1, green: 0.83, blue: 0.08, alpha: 1)
        fill.layer.cornerRadius = 19
        addSubview(fill)
        fill.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            fill.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            fill.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            fill.bottomAnchor.constraint(equalTo: bg.bottomAnchor),
            fill.heightAnchor.constraint(equalToConstant: height)
        ])
        addText(face, size: 26, weight: .regular, top: 120 + (220 - height), left: left + 4)
        addText(day, size: 16, weight: .regular, top: 354, left: left + 3, color: .darkGray)
    }

    private func addFeelingCard(top: CGFloat, color: UIColor) {
        let card = addPanel(top: top, left: 20, width: 335, height: 140, alpha: 1)
        card.backgroundColor = color
        card.layer.borderWidth = 0
        addText("Happy", size: 31, weight: .regular, top: top + 28, left: 40, color: .darkGray)
        let note = addPanel(top: top + 68, left: 40, width: 198, height: 58, alpha: 1)
        note.layer.shadowOpacity = 0.04
        addText("Two pieces of good news\ncame today!", size: 15, weight: .regular, top: top + 82, left: 56, color: .darkGray)
        addPortrait(top: top + 26, left: 291, size: 40, tint: .warm)
        addText("23 June 2026\n5 : 30PM", size: 12, weight: .regular, top: top + 74, left: 256, color: .darkGray)
    }


    private func addReportChoiceRow(_ text: String, top: CGFloat, checked: Bool) {
        let layoutContainer = activeLayoutContainer ?? self
        let field = AdaptiveInputView(
            backgroundColor: UIColor(red: 0.94, green: 1, blue: 0.72, alpha: 1)
        )
        let label = UILabel()
        label.text = text
        label.textAlignment = .center
        label.textColor = .darkGray
        label.font = AppFont.source(14)
        let checkIcon = UIImageView(image: UIImage(named: checked ? "report_check_selected" : "report_check_unselected"))
        checkIcon.contentMode = .scaleAspectFit

        layoutContainer.addSubview(field)
        field.addSubview(label)
        field.addSubview(checkIcon)
        field.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        checkIcon.translatesAutoresizingMaskIntoConstraints = false
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
            checkIcon.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    private func addOptionTile(
        iconName: String,
        top: CGFloat,
        left: CGFloat,
        width: CGFloat = 158,
        action: (() -> Void)? = nil
    ) {
        let layoutContainer = activeLayoutContainer ?? self
        let tile = UIView()
        tile.backgroundColor = UIColor(red: 0.94, green: 1, blue: 0.72, alpha: 1)
        tile.layer.cornerRadius = 10
        tile.layer.borderWidth = 1
        tile.layer.borderColor = UIColor(red: 0.53, green: 0.86, blue: 0.10, alpha: 1).cgColor
        layoutContainer.addSubview(tile)
        tile.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tile.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            tile.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            tile.widthAnchor.constraint(equalToConstant: width),
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
        fontWeight: UIFont.Weight = .regular,
        parent: UIView? = nil
    ) -> UIButton {
        let layoutContainer = parent ?? self
        let button = UIButton(type: .custom)
        button.setTitle(text, for: .normal)
        button.titleLabel?.font = usesOneFont ? AppFont.fredoka(18) : AppFont.source(18, weight: fontWeight)
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
        layer.frame = CGRect(x: 0, y: 0, width: 375, height: height)
        self.layer.insertSublayer(layer, at: 0)
    }

    private func addMoodRow(top: CGFloat) {
        let layoutContainer = activeLayoutContainer ?? self
        let moodColor = UIColor(red: 1, green: 240 / 255, blue: 110 / 255, alpha: 1)
        moodImageNames.enumerated().forEach { index, imageName in
            let tile = UIView()
            let isSelected = index == selectedMoodIndex
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
            layoutContainer.addSubview(tile)
            tile.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                tile.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: 20 + CGFloat(index) * 112),
                tile.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
                tile.widthAnchor.constraint(equalToConstant: 100),
                tile.heightAnchor.constraint(equalToConstant: 100)
            ])
            let faceView = UIImageView(image: UIImage(named: imageName))
            faceView.contentMode = .scaleAspectFit
            tile.addSubview(faceView)
            faceView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                faceView.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
                faceView.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
                faceView.widthAnchor.constraint(equalToConstant: 72),
                faceView.heightAnchor.constraint(equalToConstant: 72)
            ])
        }
    }

    private var moodImageNames: [String] {
        ["home_mood_smile", "home_mood_happy", "home_mood_laugh"]
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

    private func addFeatureCard(title: String, top: CGFloat, left: CGFloat, tint: MediaTint, imageName: String? = nil) {
        addMediaBlock(top: top, left: left, width: 164, height: 144, title: title, tint: tint, action: .arrow, imageName: imageName)
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
        titleUsesOneFont: Bool = false
    ) {
        let layoutContainer = activeLayoutContainer ?? self
        let shadowHost = UIView()
        shadowHost.backgroundColor = .clear
        shadowHost.layer.shadowColor = UIColor.black.cgColor
        shadowHost.layer.shadowOpacity = 0.18
        shadowHost.layer.shadowOffset = CGSize(width: 0, height: 5)
        shadowHost.layer.shadowRadius = 12
        layoutContainer.addSubview(shadowHost)
        shadowHost.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            shadowHost.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: left),
            shadowHost.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            shadowHost.widthAnchor.constraint(equalToConstant: width),
            shadowHost.heightAnchor.constraint(equalToConstant: height)
        ])
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
            let imageView = UIImageView(image: UIImage(named: imageName))
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
            gradient.frame = CGRect(x: 0, y: 0, width: width, height: height)
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
            addVideoPlayIcon(in: block)
        case .none:
            break
        }
    }

    private func addVideoPlayIcon(in view: UIView) {
        let iconView = UIImageView(image: UIImage(named: "video_play_icon"))
        iconView.contentMode = .scaleAspectFit
        view.addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 40),
            iconView.heightAnchor.constraint(equalToConstant: 40)
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

    private func addStoryStrip(top: CGFloat) {
        let layoutContainer = activeLayoutContainer ?? self
        let stripView = DiscoverStoryStripView()
        stripView.didSelectEntry = { [weak self] index in
            if index == 0 {
                self?.didRequestOverlayPage?(.uploadEmpty)
            } else {
                self?.didRequestPage?(.publicPersona)
            }
        }
        layoutContainer.addSubview(stripView)
        stripView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stripView.leadingAnchor.constraint(equalTo: layoutContainer.leadingAnchor, constant: 20),
            stripView.trailingAnchor.constraint(equalTo: layoutContainer.trailingAnchor),
            stripView.topAnchor.constraint(equalTo: layoutContainer.topAnchor, constant: top),
            stripView.heightAnchor.constraint(equalToConstant: 78)
        ])
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
            titleUsesOneFont: true
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
        addFeedMoreIcon(top: top + 6, left: 314)
        addTags(top: top + 366)
        addFeedStats(top: top + 424)
        addDiscoverActionButton(frame: CGRect(x: 20, y: top, width: 335, height: 444)) { [weak self] in
            self?.didRequestPage?(.galleryDetail)
        }
        addDiscoverActionButton(frame: CGRect(x: 20, y: top, width: 48, height: 48)) { [weak self] in
            self?.didRequestPage?(.publicPersona)
        }
        addDiscoverActionButton(frame: CGRect(x: 68, y: top, width: 160, height: 44)) { [weak self] in
            self?.didRequestPage?(.publicPersona)
        }
        addDiscoverActionButton(frame: CGRect(x: 302, y: top, width: 54, height: 44)) { [weak self] in
            self?.didRequestOverlayPage?(.restrictPanel)
        }
    }

    private func addDiscoverActionButton(frame: CGRect, action: @escaping () -> Void) {
        let layoutContainer = activeLayoutContainer ?? self
        let button = ClearTapButton(frame: frame, action: action)
        layoutContainer.addSubview(button)
    }

    private func addFeedStats(top: CGFloat) {
        let layoutContainer = activeLayoutContainer ?? self
        addFeedStat(iconName: "feed_like_icon", text: "666 Likes", top: top, left: 22, parent: layoutContainer)
        addFeedStat(iconName: "feed_reply_icon", text: "777 Comments", top: top, left: 130, parent: layoutContainer)
    }

    private func addFeedStat(iconName: String, text: String, top: CGFloat, left: CGFloat, parent: UIView) {
        let iconView = UIImageView(image: UIImage(named: iconName))
        iconView.contentMode = .scaleAspectFit
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

    private func addFeedMoreIcon(top: CGFloat, left: CGFloat) {
        let layoutContainer = activeLayoutContainer ?? self
        let iconView = UIImageView(image: UIImage(named: "feed_more_icon"))
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

    private func addTags(top: CGFloat, left: CGFloat = 28, right: CGFloat = 20) {
        let layoutContainer = activeLayoutContainer ?? self
        let font = AppFont.source(12)
        let rowHeight = tagRowHeight
        let horizontalInset = tagHorizontalInset
        let itemSpacing = tagItemSpacing
        let rowSpacing = tagRowSpacing
        let startX = left
        let maxX = DesignSurfaceView.baseSize.width - right
        var cursorX = startX
        var cursorY = top

        tagTexts.forEach { item in
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

    private func measuredTagsHeight(left: CGFloat = 28, right: CGFloat = 20) -> CGFloat {
        let font = AppFont.source(12)
        let startX = left
        let maxX = DesignSurfaceView.baseSize.width - right
        var cursorX = startX
        var rowCount: CGFloat = 1

        tagTexts.forEach { item in
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

    private func addDialogueCard(name: String, top: CGFloat, left: CGFloat, dark: Bool) {
        let panel = addPanel(top: top, left: left, width: 164, height: 186, alpha: 1)
        panel.backgroundColor = dark ? UIColor(red: 0.04, green: 0.05, blue: 0.04, alpha: 1) : .white
        addPortrait(top: top + 18, left: left + 16, size: 44, tint: dark ? .cool : .warm)
        addText(name, size: 17, weight: .regular, top: top + 28, left: left + 64, color: dark ? .white : .black)
        addText("Hello! Nice to meet\nyou. Your work is\nwonderful!", size: 15, weight: .regular, top: top + 72, left: left + 16, color: dark ? .white : .darkGray)
        addCapsuleSymbol("☵", top: top + 140, left: left + 106, dark: !dark)
    }

    private func addMediaGrid(top: CGFloat) {
        addMediaBlock(top: top, left: 20, width: 162, height: 200, title: "", tint: .coast, action: .play)
        addMediaBlock(top: top, left: 192, width: 164, height: 164, title: "", tint: .warm, action: .play)
        addMediaBlock(top: top + 210, left: 20, width: 162, height: 180, title: "", tint: .forest, action: .play)
        addMediaBlock(top: top + 174, left: 192, width: 164, height: 190, title: "", tint: .night, action: .play)
    }

    private func addStatsPanel(top: CGFloat) {
        let panel = addPanel(top: top, left: 20, width: 335, height: 80, alpha: 1)
        panel.layer.cornerRadius = 12
        let values = [("66", "Works"), ("166", "Followers"), ("266", "Following")]
        let colors = [
            UIColor(red: 0.22, green: 0.78, blue: 0.10, alpha: 1),
            UIColor(red: 1.0, green: 0.60, blue: 0.00, alpha: 1),
            UIColor(red: 0.12, green: 0.55, blue: 1.0, alpha: 1)
        ]
        for index in values.indices {
            let x = CGFloat(55 + index * 112)
            addText(values[index].0, size: 20, weight: .regular, top: top + 20, left: x, color: colors[index])
            addText(values[index].1, size: 16, weight: .regular, top: top + 50, left: x - 10, color: .darkGray)
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
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.font = AppFont.source(16)
        label.backgroundColor = outgoing ? UIColor(red: 0.92, green: 1, blue: 0.78, alpha: 1) : UIColor(red: 0.96, green: 0.99, blue: 1, alpha: 1)
        label.layer.cornerRadius = 6
        label.layer.borderWidth = 1
        label.layer.borderColor = (outgoing ? UIColor.systemGreen : UIColor.systemBlue).withAlphaComponent(0.4).cgColor
        label.layer.masksToBounds = true
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: left),
            label.topAnchor.constraint(equalTo: topAnchor, constant: top),
            label.widthAnchor.constraint(equalToConstant: width),
            label.heightAnchor.constraint(equalToConstant: height ?? (outgoing ? 66 : (text.count > 80 ? 194 : 42)))
        ])
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

        let label = UILabel()
        label.numberOfLines = 1
        let text = "Agree with  User Agreement and Privacy Policy"
        let value = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: AppFont.source(12),
                .foregroundColor: UIColor.gray
            ]
        )
        let first = (text as NSString).range(of: "User Agreement")
        let second = (text as NSString).range(of: "Privacy Policy")
        value.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: first)
        value.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: second)
        value.addAttribute(.foregroundColor, value: UIColor.darkGray, range: first)
        value.addAttribute(.foregroundColor, value: UIColor.darkGray, range: second)
        label.attributedText = value
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconControl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 36.5),
            iconControl.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            iconControl.widthAnchor.constraint(equalToConstant: 40),
            iconControl.heightAnchor.constraint(equalToConstant: 40),

            iconView.centerXAnchor.constraint(equalTo: iconControl.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconControl.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 17),
            iconView.heightAnchor.constraint(equalToConstant: 17),

            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 70),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }

    @objc private func handleAgreementConsentToggle() {
        Self.agreementConsentAccepted.toggle()
        refreshAgreementConsentIcon()
        NotificationCenter.default.post(name: Self.agreementConsentDidChangeNotification, object: self)
    }

    @objc private func handleAgreementConsentDidChange() {
        refreshAgreementConsentIcon()
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

    private func addAssetAvatar(_ imageName: String, top: CGFloat, left: CGFloat, size: CGFloat) {
        let layoutContainer = activeLayoutContainer ?? self
        let imageView = UIImageView(image: UIImage(named: imageName))
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

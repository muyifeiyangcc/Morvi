import SwiftUI
import WebKit

private enum SettingsPath {
    case wallet
    case restrictedRoster
    case legal(String)
}

struct SettingsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accessStore: AccessSessionStore
    @EnvironmentObject private var experienceStore: ExperienceContainer
    @State private var selectedPath: SettingsPath?

    var body: some View {
        ZStack(alignment: .top) {
            AmbientBackdrop()
                .ignoresSafeArea()
            VStack(spacing: 0) {
                TopChromeView(title: "Settings", showsBack: true, backAction: { dismiss() })
                ScrollView {
                    VStack(spacing: 28) {
                        settingsCard(
                            ["Wallet", "Blacklist", "Privacy Policy", "User Agreement"],
                            height: 276,
                            action: handleSettingsSelection
                        )
                        settingsCard(
                            ["Delete account", "Log out"],
                            height: 150,
                            action: handleSettingsSelection
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .background(settingsNavigationLink)
    }

    private func settingsCard(
        _ titles: [String],
        height: CGFloat,
        action: @escaping (String) -> Void
    ) -> some View {
        VStack(spacing: 12) {
            ForEach(titles, id: \.self) { title in
                Button { action(title) } label: {
                    HStack {
                        Text(title)
                            .font(TextCraft.source(16))
                            .foregroundColor(.black.opacity(0.85))
                        Spacer()
                        Image("next_step_icon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 15)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 10).fill(VisualLanguage.quietFill))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 17)
        .padding(.horizontal, 16)
        .frame(height: height, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(white: 0.93), lineWidth: 1))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        )
    }

    private func handleSettingsSelection(_ title: String) {
        switch title {
        case "Privacy Policy", "User Agreement":
            selectedPath = .legal(title)
        case "Wallet":
            requireSignedAccess {
                selectedPath = .wallet
            }
        case "Blacklist":
            requireSignedAccess {
                selectedPath = .restrictedRoster
            }
        case "Delete account":
            experienceStore.activeOverlay = .exitConfirm
        case "Log out":
            experienceStore.activeOverlay = .signOutConfirm
        default:
            break
        }
    }

    private func requireSignedAccess(_ action: @escaping () -> Void) {
        guard accessStore.needsAccessUpgrade == false else {
            experienceStore.activeOverlay = .accessGuide
            return
        }
        action()
    }

    private var settingsNavigationLink: some View {
        NavigationLink(
            isActive: Binding(
                get: { selectedPath != nil },
                set: { isActive in
                    if !isActive {
                        selectedPath = nil
                    }
                }
            )
        ) {
            if let selectedPath {
                Group {
                    switch selectedPath {
                    case .wallet:
                        WalletScreen()
                    case .restrictedRoster:
                        PeopleRosterScreen(kind: .restricted)
                    case .legal(let title):
                        AgreementScreen(title: title)
                    }
                }
                .navigationBarHidden(true)
                .ignoresSafeArea(edges: .top)
            }
        } label: {
            EmptyView()
        }
        .hidden()
    }
}

struct AgreementScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var experienceStore: ExperienceContainer
    let title: String
    private let backAction: (() -> Void)?
    private let showsAuthenticationActions: Bool
    private let cancelAction: (() -> Void)?
    private let acceptanceAction: (() -> Void)?
    @State private var webContentIsLoading = false
    @State private var webContentDidFail = false
    @State private var reloadIdentifier = 0
    @State private var acceptsDocuments = true
    @State private var selectedLegalTitle: String?

    init(
        title: String,
        backAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.backAction = backAction
        self.showsAuthenticationActions = title == "EULA" && backAction != nil
        self.cancelAction = nil
        self.acceptanceAction = nil
    }

    init(
        title: String,
        backAction: (() -> Void)? = nil,
        showsAuthenticationActions: Bool,
        cancelAction: (() -> Void)? = nil,
        acceptanceAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.backAction = backAction
        self.showsAuthenticationActions = showsAuthenticationActions
        self.cancelAction = cancelAction
        self.acceptanceAction = acceptanceAction
    }

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .top) {
                AmbientBackdrop()
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    TopChromeView(title: title, showsBack: true, backAction: {
                        closeDocument()
                    })
                    .zIndex(2)
                    documentContent
                        .padding(.horizontal, 20)
                    if showsAuthenticationActions {
                        authenticationActions
                            .padding(.top, 16)
                            .padding(.bottom, 32)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                if let selectedLegalTitle {
                    AgreementScreen(
                        title: selectedLegalTitle,
                        backAction: { self.selectedLegalTitle = nil },
                        showsAuthenticationActions: false
                    )
                    .environmentObject(experienceStore)
                    .zIndex(3)
                }
            }
        }
        .onChange(of: webContentIsLoading) { isLoading in
            experienceStore.showsProgress = isLoading
        }
        .onDisappear {
            if webContentIsLoading {
                experienceStore.showsProgress = false
            }
        }
    }

    @ViewBuilder
    private var documentContent: some View {
        if let source = documentSource {
            ZStack {
                DocumentPageFrame(
                    source: source,
                    reloadIdentifier: reloadIdentifier,
                    isLoading: $webContentIsLoading,
                    didFail: $webContentDidFail
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                if webContentDidFail && webContentIsLoading == false {
                    VStack(spacing: 18) {
                        Text("Unable to load content")
                            .font(TextCraft.source(16, weight: .medium))
                            .foregroundColor(VisualLanguage.softInk)
                        Button("Retry") {
                            reloadIdentifier += 1
                        }
                        .font(TextCraft.source(16, weight: .medium))
                        .foregroundColor(.black)
                        .frame(width: 124, height: 48)
                        .background(Capsule().fill(Color.white))
                        .overlay(Capsule().stroke(VisualLanguage.lineGreen, lineWidth: 1))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Color.clear
        }
    }

    private var documentSource: LegalDocumentSource? {
        switch title {
        case "EULA":
            return .html(eulaDocument)
        case "User Agreement":
            return URL(string: Self.firstDocumentURL).map(LegalDocumentSource.remote)
        case "Privacy Policy":
            return URL(string: Self.secondDocumentURL).map(LegalDocumentSource.remote)
        default:
            return nil
        }
    }

    private var authenticationActions: some View {
        VStack(spacing: 0) {
            HStack(spacing: 32) {
                Button("Cancel") {
                    if let cancelAction {
                        cancelAction()
                    } else {
                        closeDocument()
                    }
                }
                .font(TextCraft.source(17, weight: .medium))
                .foregroundColor(.black)
                .frame(width: 124, height: 50)
                .background(Capsule().fill(Color.white))
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)

                Button("I agree") {
                    guard acceptsDocuments else { return }
                    if let acceptanceAction {
                        acceptanceAction()
                    } else {
                        closeDocument()
                    }
                }
                .font(TextCraft.source(17, weight: .medium))
                .foregroundColor(VisualLanguage.lime)
                .frame(width: 124, height: 50)
                .background(Capsule().fill(VisualLanguage.charcoal))
            }
            consentLine
                .padding(.top, 26)
        }
        .frame(height: 96, alignment: .top)
    }

    private var consentLine: some View {
        HStack(spacing: 0) {
            Button {
                acceptsDocuments.toggle()
            } label: {
                Image(acceptsDocuments ? "consent_check_selected" : "consent_circle_empty")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 17, height: 17)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            Text("Agree with  ")
                .font(TextCraft.source(12))
                .foregroundColor(.gray)
            Button {
                selectedLegalTitle = "User Agreement"
            } label: {
                underlinedDocumentText("User Agreement")
            }
            .buttonStyle(.plain)
            Text(" and ")
                .font(TextCraft.source(12))
                .foregroundColor(.gray)
            Button {
                selectedLegalTitle = "Privacy Policy"
            } label: {
                underlinedDocumentText("Privacy Policy")
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func underlinedDocumentText(_ text: String) -> some View {
        Text(text)
            .font(TextCraft.source(12))
            .foregroundColor(.black)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 0.6)
                    .offset(y: 1)
            }
    }

    private func closeDocument() {
        if let backAction {
            backAction()
        } else {
            dismiss()
        }
    }

    private static let firstDocumentURL = "https://sites.google.com/view/morvi-web/home/morvi-user-agreement"
    private static let secondDocumentURL = "https://sites.google.com/view/morvi-web/home/morvis-privacy-policy"

    private var eulaDocument: String {
        """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
        <style>
        html, body { margin: 0; padding: 0; background: transparent; color: #5E5E5E; font-family: "SourceHanSansSC-Regular", -apple-system, BlinkMacSystemFont, sans-serif; font-size: 16px; line-height: 1.42; -webkit-text-size-adjust: 100%; }
        p { margin: 0; }
        ul { margin: 0; padding-left: 16px; }
        li { margin: 0; }
        a { color: #3F3F3F; text-decoration: underline; }
        </style>
        </head>
        <body>
        <p>This End User License Agreement (EULA) governs your use of the Morvi Application (the "App"). By downloading, accessing or using the App, you agree to be bound by this Agreement. If you do not agree, you may not use the App.</p>
        <p>1. Qualifications</p>
        <p>By using the App, you confirm that you are at least 18 years of age. You agree to provide true and accurate age information. If you are under 18, you are prohibited from using the App.</p>
        <p>2. User Generated Content</p>
        <p>This App allows users to post, share and view street dance-related video content (including supporting text and pictures).</p>
        <p>By posting content ("User Content") on the App, you agree to the following:</p>
        <p>2.1 Prohibited Content</p>
        <p>You may not post offensive, harmful, inappropriate or illegal content, including but not limited to:</p>
        <ul>
        <li>Hate speech, abuse, harassment, threats or personal attacks;</li>
        <li>Pornographic, explicit or vulgar content;</li>
        <li>Content promoting violence, discrimination, illegal activities or infringing others’ rights;</li>
        <li>Content irrelevant to street dance, violating public order and good customs, or used for unauthorized advertising;</li>
        <li>False or misleading information.</li>
        </ul>
        <p>2.2 Content Licensing</p>
        <p>You retain ownership of your User Content, but by posting it, you grant Funksy a non-exclusive, royalty-free license to use, distribute, display and promote such content within the App and its related services.</p>
        <p>3. Reporting and Response Mechanism</p>
        <p>3.1 Your Responsibilities</p>
        <p>If you find content violating this EULA, report it immediately via the App’s reporting mechanism.</p>
        <p>3.2 Our Response</p>
        <p>We will review reported content within 24 hours and take appropriate measures (e.g., removing content, warning or banning users). Repeated violations may result in permanent account suspension.</p>
        <p>4. Privacy Policy</p>
        <p>By using the App, you acknowledge having read and agreed to our <a href="\(Self.secondDocumentURL)">Privacy Policy</a>, which details how we collect, use and protect your personal information.</p>
        <p>5. Termination</p>
        <p>We may terminate or suspend your access to the App at any time, with or without notice. You may stop using the App and delete your account at any time.</p>
        <p>6. Modification of the Agreement</p>
        <p>We may amend this Agreement at any time. Changes will be announced in the App; your continued use constitutes acceptance of revised terms.</p>
        <p>7. Disclaimer</p>
        <p>The App is provided "AS IS" without any warranties. We do not guarantee it will be uninterrupted, error-free or secure, nor the accuracy of its content.</p>
        <p>8. Limitation of Liability</p>
        <p>To the fullest extent permitted by law, we are not liable for any damages arising from your use of the App or its content.</p>
        </body>
        </html>
        """
    }
}

private enum LegalDocumentSource: Equatable {
    case remote(URL)
    case html(String)
}

private struct DocumentPageFrame: UIViewRepresentable {
    let source: LegalDocumentSource
    let reloadIdentifier: Int
    @Binding var isLoading: Bool
    @Binding var didFail: Bool

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.navigationDelegate = context.coordinator
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.backgroundColor = .clear
        view.isOpaque = false
        context.coordinator.load(source, reloadIdentifier: reloadIdentifier, into: view)
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        if context.coordinator.loadedSource != source || context.coordinator.loadedReloadIdentifier != reloadIdentifier {
            context.coordinator.load(source, reloadIdentifier: reloadIdentifier, into: view)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, didFail: $didFail)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding private var isLoading: Bool
        @Binding private var didFail: Bool
        private var downloadTask: URLSessionDataTask?
        private(set) var loadedSource: LegalDocumentSource?
        private(set) var loadedReloadIdentifier = -1
        private var loadStartedAt = Date()

        init(isLoading: Binding<Bool>, didFail: Binding<Bool>) {
            _isLoading = isLoading
            _didFail = didFail
        }

        deinit {
            downloadTask?.cancel()
        }

        func load(_ source: LegalDocumentSource, reloadIdentifier: Int, into webView: WKWebView) {
            downloadTask?.cancel()
            loadedSource = source
            loadedReloadIdentifier = reloadIdentifier
            loadStartedAt = Date()
            DispatchQueue.main.async {
                self.isLoading = true
                self.didFail = false
            }

            switch source {
            case .html(let document):
                webView.loadHTMLString(document, baseURL: nil)
            case .remote(let page):
                fetchRemoteDocument(page, into: webView, expectedSource: source)
            }
        }

        private func fetchRemoteDocument(_ page: URL, into webView: WKWebView, expectedSource: LegalDocumentSource) {
            var request = URLRequest(url: page)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 30
            downloadTask = URLSession.shared.dataTask(with: request) { [weak self, weak webView] data, response, error in
                guard let self, self.loadedSource == expectedSource else { return }
                guard error == nil,
                      let response = response as? HTTPURLResponse,
                      (200...299).contains(response.statusCode),
                      let data,
                      let source = String(data: data, encoding: .utf8),
                      let content = Self.extractMainContent(from: source) else {
                    self.finishWithFailure()
                    return
                }

                let document = Self.cleanedDocument(containing: content)
                DispatchQueue.main.async {
                    guard self.loadedSource == expectedSource, let webView else { return }
                    webView.loadHTMLString(document, baseURL: page.deletingLastPathComponent())
                }
            }
            downloadTask?.resume()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            finish(didFail: false)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            finish(didFail: true)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            finish(didFail: true)
        }

        private func finishWithFailure() {
            finish(didFail: true)
        }

        private func finish(didFail: Bool) {
            let remaining = max(0.5 - Date().timeIntervalSince(loadStartedAt), 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + remaining) { [weak self] in
                self?.isLoading = false
                self?.didFail = didFail
            }
        }

        private static func extractMainContent(from source: String) -> String? {
            let options: String.CompareOptions = [.caseInsensitive]
            guard let roleRange = source.range(of: "role=\"main\"", options: options),
                  let openingStart = source[..<roleRange.lowerBound].range(of: "<div", options: [.caseInsensitive, .backwards]),
                  let openingEnd = source.range(of: ">", range: openingStart.lowerBound..<source.endIndex) else {
                return nil
            }

            var depth = 1
            var cursor = openingEnd.upperBound
            while depth > 0 {
                let remaining = cursor..<source.endIndex
                let nextOpening = source.range(of: "<div", options: options, range: remaining)
                let nextClosing = source.range(of: "</div", options: options, range: remaining)
                guard let nextClosing else { return nil }

                if let nextOpening, nextOpening.lowerBound < nextClosing.lowerBound {
                    depth += 1
                    cursor = nextOpening.upperBound
                } else {
                    depth -= 1
                    if depth == 0 {
                        return String(source[openingEnd.upperBound..<nextClosing.lowerBound])
                    }
                    cursor = nextClosing.upperBound
                }
            }
            return nil
        }

        private static func cleanedDocument(containing content: String) -> String {
            """
            <!doctype html>
            <html lang="en">
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
            <style>
            html, body { margin: 0; padding: 0; background: transparent; }
            body { padding: 0 0 28px; color: #666666; font-family: Arial, sans-serif; overflow-wrap: anywhere; }
            * { box-sizing: border-box; }
            p { max-width: 100%; }
            </style>
            </head>
            <body>\(content)</body>
            </html>
            """
        }
    }
}

enum RosterListKind {
    case restricted
    case audience
    case connection

    var title: String {
        switch self {
        case .restricted:
            return "Blacklist"
        case .audience:
            return "Followers"
        case .connection:
            return "Following"
        }
    }

    var emptyText: String {
        switch self {
        case .restricted:
            return "No blocked users"
        case .audience:
            return "No followers yet"
        case .connection:
            return "No following yet"
        }
    }
}

struct PeopleRosterScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accessStore: AccessSessionStore
    @EnvironmentObject private var experienceStore: ExperienceContainer
    let kind: RosterListKind

    private var cards: [IdentityCardRecord] {
        switch kind {
        case .restricted:
            return experienceStore.identityCards.filter { experienceStore.restrictedCardKeys.contains($0.stableKey) }
        case .audience:
            return Array(experienceStore.identityCards.dropFirst().prefix(3))
        case .connection:
            return experienceStore.identityCards.filter { experienceStore.linkedCardKeys.contains($0.stableKey) }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            AmbientBackdrop()
                .ignoresSafeArea(edges: .top)
            VStack(spacing: 0) {
                TopChromeView(title: kind.title, showsBack: true, backAction: { dismiss() })
                ScrollView(.vertical, showsIndicators: false) {
                    if cards.isEmpty {
                        EmptyListArtworkView(title: kind.emptyText)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 32)
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                            alignment: .center,
                            spacing: 12
                        ) {
                            ForEach(cards) { card in
                                rosterRow(card)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 28)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    private func rosterRow(_ card: IdentityCardRecord) -> some View {
        ZStack(alignment: .top) {
            Button {
                experienceStore.open(.publicPersona(card))
            } label: {
                Color.clear
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 0) {
                AvatarBadgeView(assetName: card.avatarAssetName, size: 64)
                    .frame(width: 64, height: 64)
                    .padding(.top, 27)
                Text(card.displayName)
                    .font(TextCraft.source(17))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .padding(.top, 10)
            }
            .allowsHitTesting(false)

            Button {
                rosterAction(for: card)
            } label: {
                Image(kind == .audience ? "dialogue_card_action_dark" : "restricted_restore_icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 28)
                    .frame(width: 72, height: 44)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 10)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 186)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.04), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
        )
    }

    private func rosterAction(for card: IdentityCardRecord) {
        switch kind {
        case .audience:
            experienceStore.startDirectExchange(with: card, accessStore: accessStore)
        case .connection:
            experienceStore.toggleLink(to: card)
        case .restricted:
            experienceStore.removeRestriction(for: card)
        }
    }
}

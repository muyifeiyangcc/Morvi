import AVKit
import SwiftUI
import UIKit

struct CreationDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accessStore: AccessSessionStore
    @EnvironmentObject private var experienceStore: ExperienceContainer
    let record: CreationRecord
    @State private var showsMediaPreview = false
    @State private var showsReplies = false
    @State private var authorDestination: IdentityCardRecord?

    private var displayedRecord: CreationRecord {
        experienceStore.refreshedCreation(for: record)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                coverSurface(in: proxy)

                Button {
                    openMediaPreview()
                } label: {
                    Color.clear
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if displayedRecord.mediaKind == .video {
                    Image("video_play_icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 46, height: 46)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        .allowsHitTesting(false)
                }

                    CreationDetailInformationCard(
                        record: displayedRecord,
                        profileAction: openAuthorProfile,
                        appreciationAction: {
                            guard accessStore.needsAccessUpgrade == false else {
                                experienceStore.activeOverlay = .accessGuide
                                return
                            }
                            experienceStore.toggleCreationAppreciation(
                                displayedRecord,
                                accountKey: accessStore.activeCard?.stableKey
                        )
                    },
                    repliesAction: {
                        showsReplies = true
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(edges: .bottom)

                TopChromeView(
                    title: "",
                    showsBack: true,
                    trailingAsset: "gallery_navigation_more",
                    backAction: { dismiss() },
                    trailingAction: {
                        experienceStore.presentRestrictionOptions(
                            identityKey: displayedRecord.authorKey,
                            fallbackName: displayedRecord.authorName,
                            accessStore: accessStore
                        )
                    }
                )

                if showsReplies {
                    CreationRepliesPanel(record: displayedRecord, isPresented: $showsReplies)
                        .transition(.identity)
                        .zIndex(4)
                }

                if showsMediaPreview {
                    CreationMediaPreview(record: displayedRecord) {
                        showsMediaPreview = false
                    } readyAction: {
                        experienceStore.showsProgress = false
                    }
                    .transition(.identity)
                    .zIndex(5)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .ignoresSafeArea(edges: [.top, .bottom])
            .background(authorDestinationLink)
            .onAppear {
                experienceStore.refreshCreationState(accountKey: accessStore.activeCard?.stableKey)
            }
            .onChange(of: accessStore.activeCard?.stableKey) { accountKey in
                experienceStore.refreshCreationState(accountKey: accountKey)
            }
        }
    }

    private func coverSurface(in proxy: GeometryProxy) -> some View {
        Image(displayedRecord.coverAssetName)
            .resizable()
            .scaledToFill()
            .frame(
                width: proxy.size.width,
                height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
            )
            .offset(y: -proxy.safeAreaInsets.top)
            .clipped()
            .ignoresSafeArea()
    }

    private func openAuthorProfile() {
        if accessStore.activeCard?.stableKey == displayedRecord.authorKey {
            experienceStore.selectedRail = .persona
            experienceStore.activeDestination = nil
            return
        }
        guard let card = experienceStore.identityCard(
            stableKey: displayedRecord.authorKey,
            fallbackName: displayedRecord.authorName
        ) else { return }
        authorDestination = card
    }

    private func openMediaPreview() {
        experienceStore.showsProgress = true
        DispatchQueue.main.async {
            showsMediaPreview = true
        }
    }

    private var authorDestinationLink: some View {
        NavigationLink(
            destination: Group {
                if let authorDestination {
                    PublicPersonaScreen(card: authorDestination)
                        .navigationBarHidden(true)
                } else {
                    EmptyView()
                }
            },
            isActive: Binding(
                get: { authorDestination != nil },
                set: { isActive in
                    if isActive == false {
                        authorDestination = nil
                    }
                }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }
}

private struct CreationDetailInformationCard: View {
    @EnvironmentObject private var experienceStore: ExperienceContainer
    let record: CreationRecord
    let profileAction: () -> Void
    let appreciationAction: () -> Void
    let repliesAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: profileAction) {
                HStack(spacing: 12) {
                    AvatarBadgeView(assetName: record.avatarAssetName, size: 36)
                    Text(record.authorName)
                        .font(TextCraft.source(17, weight: .bold))
                        .foregroundColor(.black)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(record.bodyText)
                .font(TextCraft.source(16))
                .foregroundColor(.black)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 19)

            FlowTagRow(tags: record.tags)
                .padding(.top, 24)

            HStack(spacing: 18) {
                Button(action: appreciationAction) {
                        CreationDetailStat(
                            assetName: "feed_appreciation_mark",
                            text: "\(record.appreciationCount) Likes",
                            tint: experienceStore.isCreationAppreciated(record) ? VisualLanguage.lineGreen : Color.black.opacity(0.55)
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: repliesAction) {
                        CreationDetailStat(
                            assetName: "feed_reply_icon",
                            text: "\(record.replyCount) Comments",
                            tint: Color.black.opacity(0.55)
                        )
                    }
                .buttonStyle(.plain)
            }
            .padding(.top, 22)
        }
        .padding(.horizontal, 20)
        .padding(.top, 23)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            glassSurface
        }
        .clipShape(CreationTopRoundedShape(radius: 14))
    }

    private var glassSurface: some View {
        ZStack {
            Image(record.coverAssetName)
                .resizable()
                .scaledToFill()
                .scaleEffect(1.08)
                .blur(radius: 16)
            Color.white.opacity(0.4)
        }
    }
}

private struct CreationDetailStat: View {
    let assetName: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(assetName)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
            Text(text)
                .font(TextCraft.source(13))
        }
        .foregroundColor(tint)
    }
}

private struct CreationRepliesPanel: View {
    @EnvironmentObject private var accessStore: AccessSessionStore
    @EnvironmentObject private var experienceStore: ExperienceContainer
    let record: CreationRecord
    @Binding var isPresented: Bool
    @State private var draft = ""
    @FocusState private var panelInputFocused: Bool
    @FocusState private var floatingInputFocused: Bool
    @State private var keyboardIsVisible = false
    @State private var keyboardLift: CGFloat = 0

    private var replies: [CreationReplyRecord] {
        experienceStore.replies(for: record)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.58)
                    .ignoresSafeArea()
                    .onTapGesture {
                        if keyboardIsVisible || panelInputFocused || floatingInputFocused {
                            dismissKeyboard()
                        } else {
                            isPresented = false
                        }
                    }

                VStack(spacing: 0) {
                    List(replies) { reply in
                        CreationReplyRow(reply: reply) {
                            experienceStore.presentRestrictionOptions(
                                identityKey: reply.authorKey,
                                fallbackName: reply.authorName,
                                accessStore: accessStore
                            )
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .environment(\.defaultMinListRowHeight, 0)
                    .padding(.top, 15)

                    if keyboardIsVisible {
                        Color.clear
                            .frame(height: 48)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 29)
                    } else {
                        replyInput(isFocused: $panelInputFocused)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 29)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: min(391, max(proxy.size.height - 80, 0)))
                .background(Color.white)
                .clipShape(CreationTopRoundedShape(radius: 20))
                .background(Color.white.ignoresSafeArea(edges: .bottom))
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 112, height: 4)
                        .offset(y: -10)
                }
                .onTapGesture {
                    if keyboardIsVisible || panelInputFocused || floatingInputFocused {
                        dismissKeyboard()
                    }
                }

                if keyboardIsVisible {
                    replyInput(isFocused: $floatingInputFocused)
                        .padding(.horizontal, 20)
                        .padding(.bottom, keyboardLift)
                        .background(alignment: .bottom) {
                            Color.white
                                .frame(height: 48 + keyboardLift)
                        }
                        .transition(.identity)
                        .zIndex(3)
                        .onAppear {
                            floatingInputFocused = true
                        }
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            updateKeyboardLift(notification, isClosing: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            updateKeyboardLift(notification, isClosing: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidChangeFrameNotification)) { notification in
            updateKeyboardLift(notification, isClosing: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
            updateKeyboardLift(notification, isClosing: true)
        }
    }

    private func replyInput(isFocused: FocusState<Bool>.Binding) -> some View {
        HStack(spacing: 8) {
            TextField("Say something", text: $draft)
                .font(TextCraft.source(14))
                .plainEntryBehavior()
                .focused(isFocused)
                .padding(.leading, 14)
                .submitLabel(.send)
                .onSubmit(submitReply)
            Button(action: submitReply) {
                Image("reply_send_icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 48)
        .background {
            ZStack {
                Color.white
                VisualLanguage.quietFill
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundColor(VisualLanguage.lineGreen)
        )
    }

    private func dismissKeyboard() {
        panelInputFocused = false
        floatingInputFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.easeInOut(duration: 0.18)) {
            keyboardIsVisible = false
            keyboardLift = 0
        }
    }

    private func updateKeyboardLift(_ notification: Notification, isClosing: Bool) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let hostWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        let keyboardTop = hostWindow?.convert(frame, from: nil).minY ?? frame.minY
        let windowBottom = hostWindow?.bounds.maxY ?? UIScreen.main.bounds.height
        let visibleLift = max(0, windowBottom - keyboardTop)
        let nextLift = isClosing || visibleLift <= 1 ? 0 : visibleLift
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curveRaw = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        let curve = UIView.AnimationCurve(rawValue: Int(curveRaw)) ?? .easeInOut
        withAnimation(keyboardAnimation(from: curve, duration: duration)) {
            keyboardLift = nextLift
            keyboardIsVisible = nextLift > 0
        }
        if nextLift > 0 {
            DispatchQueue.main.async {
                floatingInputFocused = true
            }
        }
    }

    private func keyboardAnimation(from curve: UIView.AnimationCurve, duration: Double) -> Animation {
        switch curve {
        case .easeIn:
            return .easeIn(duration: duration)
        case .easeOut:
            return .easeOut(duration: duration)
        case .linear:
            return .linear(duration: duration)
        default:
            return .easeInOut(duration: duration)
        }
    }

    private func submitReply() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        guard accessStore.needsAccessUpgrade == false else {
            experienceStore.activeOverlay = .accessGuide
            return
        }
        guard accessStore.activeCard != nil else {
            experienceStore.activeOverlay = .accessGuide
            return
        }
        experienceStore.appendCreationReply(
            trimmed,
            to: record,
            author: accessStore.activeCard
        ) { succeeded in
            guard succeeded else { return }
            draft = ""
            dismissKeyboard()
        }
    }
}

private struct CreationReplyRow: View {
    let reply: CreationReplyRecord
    let moreAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                AvatarBadgeView(assetName: reply.avatarAssetName, size: 36)
                VStack(alignment: .leading, spacing: 12) {
                    Text(reply.authorName)
                        .font(TextCraft.source(16, weight: .medium))
                        .foregroundColor(.black)
                    Text(reply.bodyText)
                        .font(TextCraft.source(16))
                        .foregroundColor(VisualLanguage.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button(action: moreAction) {
                    Image("feed_more_icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 12)
            Rectangle()
                .fill(Color(red: 0.8, green: 0.8, blue: 0.8).opacity(0.5))
                .frame(height: 0.5)
        }
    }
}

private struct CreationMediaPreview: View {
    let record: CreationRecord
    let closeAction: () -> Void
    let readyAction: () -> Void
    @State private var player: AVPlayer?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color.black
                    .frame(
                        width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing,
                        height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
                    )
                    .offset(x: -proxy.safeAreaInsets.leading, y: -proxy.safeAreaInsets.top)

                if record.mediaKind == .video, let player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea()
                } else {
                    Image(record.coverAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }

                Button(action: closeAction) {
                    Image("navigation_back_circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 58, height: 58)
                }
                .buttonStyle(.plain)
                .padding(.leading, 20)
                .padding(.top, currentStatusBarHeight + 20)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .ignoresSafeArea()
        .onAppear(perform: preparePlayer)
        .onDisappear {
            player?.pause()
            readyAction()
        }
    }

    private func preparePlayer() {
        guard record.mediaKind == .video,
              let resourceName = bundledVideoResourceName,
              let url = Bundle.main.url(forResource: resourceName, withExtension: "mp4") else {
            DispatchQueue.main.async {
                readyAction()
            }
            return
        }
        let mediaPlayer = AVPlayer(url: url)
        player = mediaPlayer
        mediaPlayer.play()
        DispatchQueue.main.async {
            readyAction()
        }
    }

    private var bundledVideoResourceName: String? {
        let prefix = "builtin_video_cover_"
        guard record.coverAssetName.hasPrefix(prefix) else { return nil }
        return "builtin_" + String(record.coverAssetName.dropFirst(prefix.count))
    }

    private var currentStatusBarHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets.top ?? 44
    }
}

private struct CreationTopRoundedShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

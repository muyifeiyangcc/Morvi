import SwiftUI
import UIKit
import AVFoundation
import PhotosUI

struct DirectDialogueScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accessStore: AccessSessionStore
    @EnvironmentObject private var experienceStore: ExperienceContainer
    let thread: DialogueThreadRecord
    @State private var draft = ""
    @State private var showsPhotoPicker = false
    @State private var previewAsset: String?
    @State private var showsVoicePanel = false
    @State private var keyboardRevision = 0
    @StateObject private var captureController = DialogueCaptureController()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                TopChromeView(title: thread.title, showsBack: true, trailingAsset: "gallery_navigation_more", backAction: { dismiss() }) {
                    guard let key = thread.counterpartStableKey else {
                        experienceStore.showToast("This profile is unavailable")
                        return
                    }
                    experienceStore.presentRestrictionOptions(
                        identityKey: key,
                        fallbackName: thread.title,
                        accessStore: accessStore
                    )
                }
                DialogueLineList(
                    lines: experienceStore.lines(for: thread),
                    scrollRevision: keyboardRevision + (showsVoicePanel ? 1_000 : 0),
                    previewAction: { previewAsset = $0 }
                )
                if showsVoicePanel {
                    DialogueVoicePanel(
                        controller: captureController,
                        closeAction: { showsVoicePanel = false },
                        completion: finishVoiceCapture
                    )
                } else {
                    DialogueInputBar(
                        text: $draft,
                        showsMediaTools: true,
                        voiceAction: requestVoiceAccess,
                        photoAction: { showsPhotoPicker = true }
                    ) {
                        if experienceStore.appendDirectText(
                            draft,
                            thread: thread,
                            author: accessStore.activeCard
                        ) {
                            draft = ""
                        }
                    }
                }
            }
            .background(AmbientBackdrop())

            if let previewAsset {
                DialoguePhotoPreview(assetName: previewAsset) {
                    self.previewAsset = nil
                }
                .zIndex(20)
            }
        }
        .onAppear {
            experienceStore.refreshDialogues(accountKey: accessStore.activeCard?.stableKey)
        }
        .onDisappear {
            _ = captureController.finish(keepingFile: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { _ in
            keyboardRevision += 1
        }
        .sheet(isPresented: $showsPhotoPicker) {
            DialoguePhotoPicker { image in
                guard let result = DialogueMediaStore.save(image: image) else {
                    experienceStore.showToast("Image send failed")
                    return
                }
                _ = experienceStore.appendDirectPhoto(
                    assetName: result.assetName,
                    size: result.size,
                    thread: thread,
                    author: accessStore.activeCard
                )
            }
        }
    }

    private func requestVoiceAccess() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            showsVoicePanel = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showsVoicePanel = true
                    } else {
                        openMicrophoneSettings()
                    }
                }
            }
        default:
            openMicrophoneSettings()
        }
    }

    private func openMicrophoneSettings() {
        experienceStore.showToast("Please allow microphone access in Settings.")
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func finishVoiceCapture(_ result: DialogueCaptureResult?) {
        guard let result else {
            experienceStore.showToast("Audio is too short")
            return
        }
        if experienceStore.appendDirectAudio(
            duration: result.duration,
            assetName: result.assetName,
            thread: thread,
            author: accessStore.activeCard
        ) == false {
            experienceStore.showToast("Audio send failed")
        }
    }
}

struct AssistantDialogueScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accessStore: AccessSessionStore
    @EnvironmentObject private var experienceStore: ExperienceContainer
    @State private var draft = ""
    @State private var shouldAnimateIntro = false
    @State private var keyboardRevision = 0

    private var renderedAssistantLines: [DialogueLineRecord] {
        guard let first = experienceStore.assistantLines.first else {
            return []
        }
        if case .text("Hello! How can I help you?") = first.kind {
            return Array(experienceStore.assistantLines.dropFirst())
        }
        return experienceStore.assistantLines
    }

    var body: some View {
        VStack(spacing: 0) {
            TopChromeView(title: "Recot Bot", showsBack: true, backAction: { dismiss() })
            ScrollViewReader { proxy in
                List {
                    Section {
                        IntroAssistantCard(shouldAnimate: shouldAnimateIntro)
                            .id("assistant-intro")
                            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 14, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        ForEach(DialogueLinePresentation.build(from: renderedAssistantLines), id: \.line.id) { item in
                            DialogueLineBubble(
                                line: item.line,
                                showsAvatar: false,
                                style: .lockedCorner,
                                reservesAvatarSpace: false
                            )
                            .overlay(alignment: .top) {
                                if item.showsTimeMarker {
                                    Text(item.timeMarker)
                                        .font(TextCraft.source(12))
                                        .foregroundColor(VisualLanguage.softInk)
                                        .offset(y: -26)
                                }
                            }
                            .padding(.top, item.showsTimeMarker ? 26 : 4)
                            .id(item.line.id)
                            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 18, trailing: 20))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                }
                .listStyle(.plain)
                .background(Color.clear)
                .onAppear(perform: prepareReusableListAppearance)
                .simultaneousGesture(TapGesture().onEnded { dismissDialogueKeyboard() })
                .onChange(of: experienceStore.assistantLines.count) { _ in
                    if let id = renderedAssistantLines.last?.id {
                        withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                    } else {
                        withAnimation { proxy.scrollTo("assistant-intro", anchor: .bottom) }
                    }
                }
                .onChange(of: keyboardRevision) { _ in
                    if let id = renderedAssistantLines.last?.id {
                        DispatchQueue.main.async {
                            withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                        }
                    }
                }
            }
            DialogueInputBar(text: $draft, showsMediaTools: false) {
                if experienceStore.appendAssistantText(draft, author: accessStore.activeCard) {
                    draft = ""
                }
            }
        }
        .background(AmbientBackdrop())
        .onAppear {
            let accountKey = accessStore.activeCard?.stableKey
            experienceStore.refreshAssistantDialogue(accountKey: accountKey)
            shouldAnimateIntro = experienceStore.shouldRevealAssistantIntro(accountKey: accountKey)
            experienceStore.markAssistantIntroRevealed(accountKey: accountKey)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { _ in
            keyboardRevision += 1
        }
    }
}

private struct DialogueLineList: View {
    let lines: [DialogueLineRecord]
    let scrollRevision: Int
    let previewAction: (String) -> Void
    @StateObject private var playbackController = DialoguePlaybackController()

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(DialogueLinePresentation.build(from: lines), id: \.line.id) { item in
                    DialogueLineBubble(
                        line: item.line,
                        showsAvatar: item.showsAvatar,
                        isPlaying: playbackController.activeLineKey == item.line.stableKey,
                        photoAction: previewAction,
                        audioAction: { playbackController.toggle(item.line) }
                    )
                    .overlay(alignment: .top) {
                        if item.showsTimeMarker {
                            Text(item.timeMarker)
                                .font(TextCraft.source(12))
                                .foregroundColor(VisualLanguage.softInk)
                                .offset(y: -26)
                        }
                    }
                    .padding(.top, item.showsTimeMarker ? 26 : 4)
                    .id(item.line.id)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 18, trailing: 20))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .background(Color.clear)
            .onAppear {
                prepareReusableListAppearance()
                if let id = lines.last?.id {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
            .onChange(of: lines.count) { _ in
                if let id = lines.last?.id {
                    withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
            .onChange(of: scrollRevision) { _ in
                if let id = lines.last?.id {
                    DispatchQueue.main.async {
                        withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
            }
            .simultaneousGesture(TapGesture().onEnded { dismissDialogueKeyboard() })
            .onDisappear { playbackController.stop() }
        }
    }
}

private func prepareReusableListAppearance() {
    UITableView.appearance().backgroundColor = .clear
    UITableViewCell.appearance().backgroundColor = .clear
    UITableView.appearance().separatorStyle = .none
}

private struct DialogueLinePresentation {
    let line: DialogueLineRecord
    let showsAvatar: Bool
    let showsTimeMarker: Bool
    let timeMarker: String

    static func build(from lines: [DialogueLineRecord]) -> [DialogueLinePresentation] {
        lines.enumerated().map { index, line in
            let marker = DialogueTimeText.render(line.occurredAt)
            let prior = index > 0 ? lines[index - 1] : nil
            let priorMarker = prior.map { DialogueTimeText.render($0.occurredAt) }
            let hasNewMoment = priorMarker != marker
            let shouldShowAvatar = prior == nil || prior?.side != line.side || hasNewMoment
            return DialogueLinePresentation(
                line: line,
                showsAvatar: shouldShowAvatar,
                showsTimeMarker: index == 0 || hasNewMoment,
                timeMarker: marker
            )
        }
    }
}

private enum DialogueTimeText {
    static func render(_ date: Date) -> String {
        let now = Date()
        let interval = max(0, now.timeIntervalSince(date))
        if interval < 60 {
            return "Just now"
        }
        if interval < 10 * 60 {
            return "5 min ago"
        }
        if interval < 30 * 60 {
            return "10 min ago"
        }
        if interval < 60 * 60 {
            return "30 min ago"
        }
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US_POSIX")
        if calendar.isDate(date, inSameDayAs: now) {
            return formatted(date, pattern: "h:mm a")
        }
        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            return formatted(date, pattern: "MMM d, h:mm a")
        }
        return formatted(date, pattern: "MMM d, yyyy, h:mm a")
    }

    private static func formatted(_ date: Date, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

private struct DialogueLineBubble: View {
    let line: DialogueLineRecord
    let showsAvatar: Bool
    var style: DialogueBubbleStyle = .pointed
    var reservesAvatarSpace = true
    var isPlaying = false
    var photoAction: (String) -> Void = { _ in }
    var audioAction: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            if line.side == .other {
                if reservesAvatarSpace {
                    avatarSlot
                }
            } else {
                Spacer(minLength: 0)
            }
            bubble
            if line.side == .mine {
                if reservesAvatarSpace {
                    avatarSlot
                }
            } else {
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var avatarSlot: some View {
        if showsAvatar {
            AvatarBadgeView(assetName: line.avatarAssetName, size: 42)
                .frame(width: 44, height: 44)
                .offset(y: -2)
        } else {
            Color.clear.frame(width: 44, height: 44)
        }
    }

    @ViewBuilder
    private var bubble: some View {
        switch line.kind {
        case .text(let text):
            let metrics = textBubbleMetrics(for: text)
            textBubbleContent(text)
                .font(TextCraft.source(16))
                .foregroundColor(Color(red: 0.17, green: 0.22, blue: 0.18))
                .frame(width: metrics.contentWidth, height: metrics.contentHeight, alignment: .leading)
                .padding(.leading, metrics.leadingInset)
                .padding(.trailing, metrics.trailingInset)
                .frame(width: metrics.outerWidth, height: metrics.outerHeight, alignment: .leading)
                .background(bubbleBackground)
        case .photo(let asset):
            if let image = resolvedImage(named: asset) {
                Button { photoAction(asset) } label: {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: imageHeight(for: image))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        case .audio(let seconds, _):
            Button(action: audioAction) {
                HStack(spacing: 6) {
                    DialogueWaveformMark(isPlaying: isPlaying)
                    Text("\(seconds)s")
                }
                .font(TextCraft.source(15))
                .frame(width: 71, height: 36)
                .background(
                    DialogueTailShape(pointsRight: line.side == .mine, cornerRadius: 6, centerAtMidpoint: true)
                        .fill(line.side == .mine ? Color(red: 0.92, green: 1.0, blue: 0.78) : Color(red: 0.96, green: 0.99, blue: 1.0))
                        .overlay(
                            DialogueTailShape(pointsRight: line.side == .mine, cornerRadius: 6, centerAtMidpoint: true)
                                .stroke(line.side == .mine ? Color(red: 0.56, green: 0.78, blue: 0.22) : Color.blue.opacity(0.4), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func resolvedImage(named name: String) -> UIImage? {
        if let bundledImage = UIImage(named: name) {
            return bundledImage
        }
        let prefix: String
        let folderName: String
        if name.hasPrefix("local-avatar/") {
            prefix = "local-avatar/"
            folderName = "Avatars"
        } else if name.hasPrefix("local-work/") {
            prefix = "local-work/"
            folderName = "WorkMedia"
        } else if name.hasPrefix("local-dialogue-photo/") {
            prefix = "local-dialogue-photo/"
            folderName = "DialogueMedia"
        } else {
            return nil
        }
        guard let supportDirectory = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            return nil
        }
        let fileName = String(name.dropFirst(prefix.count))
        let fileURL = supportDirectory
            .appendingPathComponent("Morvi", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)
            .appendingPathComponent(fileName)
        return UIImage(contentsOfFile: fileURL.path)
    }

    private func imageHeight(for image: UIImage) -> CGFloat {
        let sourceWidth = line.mediaWidth ?? Double(image.size.width)
        let sourceHeight = line.mediaHeight ?? Double(image.size.height)
        guard sourceWidth > 0 else { return 160 }
        return min(max(160 * CGFloat(sourceHeight / sourceWidth), 80), 320)
    }

    private func textBubbleMetrics(for text: String) -> (contentWidth: CGFloat, contentHeight: CGFloat, outerWidth: CGFloat, outerHeight: CGFloat, leadingInset: CGFloat, trailingInset: CGFloat) {
        let leadingInset: CGFloat = 18
        let trailingInset: CGFloat = line.side == .mine ? 25 : 19
        let maximumOuterWidth: CGFloat = 206
        let maximumContentWidth = maximumOuterWidth - leadingInset - trailingInset
        let font = UIFont(name: "SourceHanSansSC-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16)
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: maximumContentWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        ).integral
        let contentWidth = min(maximumContentWidth, max(1, ceil(bounds.width)))
        let contentHeight = max(24, ceil(bounds.height))
        let outerWidth = min(maximumOuterWidth, contentWidth + leadingInset + trailingInset)
        return (contentWidth, contentHeight, outerWidth, contentHeight + 20, leadingInset, trailingInset)
    }

    @ViewBuilder
    private func textBubbleContent(_ text: String) -> some View {
        Text(text)
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        switch style {
        case .pointed:
            DialogueTailShape(pointsRight: line.side == .mine, cornerRadius: 6)
                .fill(line.side == .mine ? Color(red: 0.92, green: 1.0, blue: 0.78) : Color(red: 0.96, green: 0.99, blue: 1.0))
                .overlay(
                    DialogueTailShape(pointsRight: line.side == .mine, cornerRadius: 6)
                        .stroke(line.side == .mine ? Color(red: 0.56, green: 0.78, blue: 0.22) : Color.blue.opacity(0.4), lineWidth: 1)
                )
        case .lockedCorner:
            DialogueLockedCornerShape(side: line.side, cornerRadius: 15)
                .fill(line.side == .mine ? Color(red: 0.92, green: 1.0, blue: 0.78) : Color(red: 0.96, green: 0.99, blue: 1.0))
                .overlay(
                    DialogueLockedCornerShape(side: line.side, cornerRadius: 15)
                        .stroke(line.side == .mine ? Color(red: 0.56, green: 0.78, blue: 0.22) : Color.blue.opacity(0.4), lineWidth: 1)
                )
        }
    }
}

private enum DialogueBubbleStyle {
    case pointed
    case lockedCorner
}

private struct DialogueTailShape: Shape {
    let pointsRight: Bool
    let cornerRadius: CGFloat
    let centerAtMidpoint: Bool

    init(pointsRight: Bool, cornerRadius: CGFloat, centerAtMidpoint: Bool = false) {
        self.pointsRight = pointsRight
        self.cornerRadius = cornerRadius
        self.centerAtMidpoint = centerAtMidpoint
    }

    func path(in rect: CGRect) -> Path {
        let pointerWidth: CGFloat = 7
        let pointerHeight: CGFloat = 10
        let body = rect.insetBy(dx: 0.5, dy: 0.5)
        let minBodyX = body.minX + (pointsRight ? 0 : pointerWidth)
        let maxBodyX = body.maxX - (pointsRight ? pointerWidth : 0)
        let pointerCenterY: CGFloat
        if centerAtMidpoint {
            pointerCenterY = body.midY
        } else {
            pointerCenterY = min(
                max(22, body.minY + cornerRadius + pointerHeight / 2),
                body.maxY - cornerRadius - pointerHeight / 2
            )
        }
        var path = Path()
        path.move(to: CGPoint(x: minBodyX + cornerRadius, y: body.minY))
        path.addLine(to: CGPoint(x: maxBodyX - cornerRadius, y: body.minY))
        path.addQuadCurve(
            to: CGPoint(x: maxBodyX, y: body.minY + cornerRadius),
            control: CGPoint(x: maxBodyX, y: body.minY)
        )
        if pointsRight {
            path.addLine(to: CGPoint(x: maxBodyX, y: pointerCenterY - pointerHeight / 2))
            path.addLine(to: CGPoint(x: body.maxX, y: pointerCenterY))
            path.addLine(to: CGPoint(x: maxBodyX, y: pointerCenterY + pointerHeight / 2))
        } else {
            path.addLine(to: CGPoint(x: maxBodyX, y: body.maxY - cornerRadius))
        }
        if pointsRight {
            path.addLine(to: CGPoint(x: maxBodyX, y: body.maxY - cornerRadius))
        }
        path.addQuadCurve(
            to: CGPoint(x: maxBodyX - cornerRadius, y: body.maxY),
            control: CGPoint(x: maxBodyX, y: body.maxY)
        )
        path.addLine(to: CGPoint(x: minBodyX + cornerRadius, y: body.maxY))
        path.addQuadCurve(
            to: CGPoint(x: minBodyX, y: body.maxY - cornerRadius),
            control: CGPoint(x: minBodyX, y: body.maxY)
        )
        if !pointsRight {
            path.addLine(to: CGPoint(x: minBodyX, y: pointerCenterY + pointerHeight / 2))
            path.addLine(to: CGPoint(x: body.minX, y: pointerCenterY))
            path.addLine(to: CGPoint(x: minBodyX, y: pointerCenterY - pointerHeight / 2))
        }
        path.addLine(to: CGPoint(x: minBodyX, y: body.minY + cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: minBodyX + cornerRadius, y: body.minY),
            control: CGPoint(x: minBodyX, y: body.minY)
        )
        path.closeSubpath()
        return path
    }
}

private struct DialogueLockedCornerShape: Shape {
    let side: DialogueLineSide
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let lockBottomLeading = side == .other
        let lockBottomTrailing = side == .mine
        let topLeft = cornerRadius
        let topRight = cornerRadius
        let bottomRight = lockBottomTrailing ? CGFloat(0) : cornerRadius
        let bottomLeft = lockBottomLeading ? CGFloat(0) : cornerRadius
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + topRight), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        if bottomRight > 0 {
            path.addQuadCurve(to: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        if bottomLeft > 0 {
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bottomLeft), control: CGPoint(x: rect.minX, y: rect.maxY))
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        path.addQuadCurve(to: CGPoint(x: rect.minX + topLeft, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct DialogueInputBar: View {
    @Binding var text: String
    let showsMediaTools: Bool
    var voiceAction: () -> Void = {}
    var photoAction: () -> Void = {}
    let action: () -> Void
    private let keyboardAccessoryHeight: CGFloat = 34
    @FocusState private var isFocused: Bool
    @State private var keyboardIsVisible = false
    @State private var keyboardLift: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            if showsMediaTools {
                HStack(spacing: 12) {
                    Button(action: voiceAction) {
                        Image("input_voice_icon").resizable().scaledToFit().frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    Button(action: photoAction) {
                        Image("input_photo_icon").resizable().scaledToFit().frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .frame(height: 36, alignment: .top)
            }
            HStack {
                TextField("Say something", text: $text)
                    .font(TextCraft.source(13))
                    .plainEntryBehavior()
                    .focused($isFocused)
                    .submitLabel(.send)
                    .onSubmit(action)
                Button(action: action) {
                    Image("reply_send_icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .frame(height: 45)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(VisualLanguage.quietFill)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(VisualLanguage.lineGreen, lineWidth: 1))
            )
            .padding(.horizontal, 20)
        }
        .frame(height: showsMediaTools ? 81 : 45, alignment: .top)
        .padding(.bottom, keyboardIsVisible ? keyboardLift : 29)
        .background(Color.white)
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

    private func updateKeyboardLift(_ notification: Notification, isClosing: Bool) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let hostWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        let keyboardTop = hostWindow?.convert(frame, from: nil).minY ?? frame.minY
        let windowBottom = hostWindow?.bounds.maxY ?? UIScreen.main.bounds.height
        let bottomInset = hostWindow?.safeAreaInsets.bottom ?? 0
        let visibleLift = max(0, windowBottom - keyboardTop - bottomInset)
        let nextLift = isClosing ? 0 : visibleLift + keyboardAccessoryHeight
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curveRaw = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 7
        let curve = UIView.AnimationCurve(rawValue: Int(curveRaw)) ?? .easeInOut
        withAnimation(Animation.timingCurve(from: curve, duration: duration)) {
            keyboardLift = nextLift
            keyboardIsVisible = nextLift > 0
        }
    }
}

private extension Animation {
    static func timingCurve(from curve: UIView.AnimationCurve, duration: Double) -> Animation {
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
}

private struct DialogueWaveformMark: View {
    let isPlaying: Bool
    @State private var phase = false
    private let beatTimer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(Color(red: 0.45, green: 0.52, blue: 0.45))
                    .frame(width: 2, height: phase && index != 1 ? 12 : 7 + CGFloat(index * 2))
            }
        }
        .frame(width: 14, height: 18)
        .onAppear { phase = false }
        .onChange(of: isPlaying) { playing in
            if playing == false {
                withAnimation(.easeOut(duration: 0.12)) {
                    phase = false
                }
            }
        }
        .onReceive(beatTimer) { _ in
            guard isPlaying else {
                phase = false
                return
            }
            withAnimation(.easeInOut(duration: 0.28)) {
                phase.toggle()
            }
        }
    }
}

private final class DialoguePlaybackController: ObservableObject {
    @Published var activeLineKey: String?
    private var player: AVAudioPlayer?
    private var completionTimer: Timer?

    func toggle(_ line: DialogueLineRecord) {
        if activeLineKey == line.stableKey {
            stop()
            return
        }
        stop()
        guard case .audio(let duration, let assetName) = line.kind else { return }
        activeLineKey = line.stableKey
        var playbackDuration = TimeInterval(max(duration, 1))
        if let url = DialogueMediaStore.audioURL(for: assetName) {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                let audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer.prepareToPlay()
                audioPlayer.play()
                player = audioPlayer
                playbackDuration = max(audioPlayer.duration, 0.4)
            } catch {
                player = nil
            }
        }
        completionTimer = Timer.scheduledTimer(withTimeInterval: playbackDuration, repeats: false) { [weak self] _ in
            self?.stop()
        }
    }

    func stop() {
        completionTimer?.invalidate()
        completionTimer = nil
        player?.stop()
        player = nil
        activeLineKey = nil
    }
}

private struct DialoguePhotoPreview: View {
    let assetName: String
    let closeAction: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            if let image = DialogueMediaStore.image(for: assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Button(action: closeAction) {
                Image("navigation_back_circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 58, height: 58)
            }
            .buttonStyle(.plain)
            .padding(.leading, 20)
            .padding(.top, 20)
        }
    }
}

private struct DialoguePhotoPicker: UIViewControllerRepresentable {
    let completion: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let completion: (UIImage) -> Void

        init(completion: @escaping (UIImage) -> Void) {
            self.completion = completion
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { [completion] object, _ in
                guard let image = object as? UIImage else { return }
                DispatchQueue.main.async { completion(image) }
            }
        }
    }
}

private enum DialogueMediaStore {
    static func save(image: UIImage) -> (assetName: String, size: CGSize)? {
        guard let data = image.jpegData(compressionQuality: 0.9),
              let directory = try? directory(named: "DialogueMedia") else { return nil }
        let fileName = "photo-\(UUID().uuidString.lowercased()).jpg"
        let url = directory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            return ("local-dialogue-photo/\(fileName)", image.size)
        } catch {
            return nil
        }
    }

    static func image(for assetName: String) -> UIImage? {
        if let bundled = UIImage(named: assetName) { return bundled }
        let mapping: (prefix: String, folder: String)
        if assetName.hasPrefix("local-dialogue-photo/") {
            mapping = ("local-dialogue-photo/", "DialogueMedia")
        } else if assetName.hasPrefix("local-work/") {
            mapping = ("local-work/", "WorkMedia")
        } else if assetName.hasPrefix("local-avatar/") {
            mapping = ("local-avatar/", "Avatars")
        } else {
            return nil
        }
        guard let base = try? applicationDirectory() else { return nil }
        let fileName = String(assetName.dropFirst(mapping.prefix.count))
        return UIImage(contentsOfFile: base.appendingPathComponent(mapping.folder).appendingPathComponent(fileName).path)
    }

    static func audioURL(for assetName: String?) -> URL? {
        guard let assetName, assetName.isEmpty == false else { return nil }
        if assetName.hasPrefix("local-voice/"), let base = try? applicationDirectory() {
            let fileName = String(assetName.dropFirst("local-voice/".count))
            let url = base.appendingPathComponent("DialogueAudio").appendingPathComponent(fileName)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        if assetName.hasPrefix("file://"), let url = URL(string: assetName) {
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        let url = URL(fileURLWithPath: assetName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func audioDestination() throws -> (assetName: String, url: URL) {
        let directory = try directory(named: "DialogueAudio")
        let fileName = "voice-\(UUID().uuidString.lowercased()).m4a"
        return ("local-voice/\(fileName)", directory.appendingPathComponent(fileName))
    }

    private static func directory(named name: String) throws -> URL {
        let directory = try applicationDirectory().appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func applicationDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("Morvi", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private struct DialogueCaptureResult {
    let duration: Int
    let assetName: String
}

private final class DialogueCaptureController: ObservableObject {
    @Published var elapsedSeconds = 0
    @Published var isRecording = false
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var activeAssetName: String?
    private var startedAt: Date?

    func start() -> Bool {
        guard isRecording == false else { return true }
        do {
            timer?.invalidate()
            let destination = try DialogueMediaStore.audioDestination()
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
            let recorder = try AVAudioRecorder(
                url: destination.url,
                settings: [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44_100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
            )
            recorder.prepareToRecord()
            guard recorder.record() else { return false }
            self.recorder = recorder
            activeAssetName = destination.assetName
            startedAt = Date()
            elapsedSeconds = 0
            isRecording = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                guard let self else { return }
                let seconds = self.recordedSeconds()
                if seconds != self.elapsedSeconds {
                    self.elapsedSeconds = seconds
                }
            }
            return true
        } catch {
            return false
        }
    }

    func finish(keepingFile: Bool) -> DialogueCaptureResult? {
        timer?.invalidate()
        timer = nil
        let duration = recordedSeconds()
        let assetName = activeAssetName
        let url = recorder?.url
        recorder?.stop()
        recorder = nil
        activeAssetName = nil
        startedAt = nil
        isRecording = false
        elapsedSeconds = 0
        guard keepingFile, duration >= 1, let assetName else {
            if let url { try? FileManager.default.removeItem(at: url) }
            return nil
        }
        return DialogueCaptureResult(duration: min(duration, 60), assetName: assetName)
    }

    private func recordedSeconds() -> Int {
        guard let startedAt else { return 0 }
        return Int(Date().timeIntervalSince(startedAt).rounded(.down))
    }
}

private struct DialogueVoicePanel: View {
    @ObservedObject var controller: DialogueCaptureController
    let closeAction: () -> Void
    let completion: (DialogueCaptureResult?) -> Void
    @State private var isPressing = false
    @State private var ripplePulse = false
    @State private var buttonScale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(red: 235 / 255, green: 254 / 255, blue: 175 / 255), Color(red: 224 / 255, green: 251 / 255, blue: 252 / 255)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .clipShape(DialoguePanelTopShape(radius: 18))

            Button {
                _ = controller.finish(keepingFile: false)
                closeAction()
            } label: {
                Image("voice_panel_grid")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
            .padding(.top, 20)

            if controller.elapsedSeconds > 0 {
                Text("\(controller.elapsedSeconds)s")
                    .font(TextCraft.source(16, weight: .medium))
                    .foregroundColor(Color(red: 0.17, green: 0.22, blue: 0.18))
                    .padding(.top, 21)
            }

            ZStack {
                if controller.isRecording {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(VisualLanguage.lineGreen.opacity(0.75), lineWidth: 1)
                            .frame(width: 40, height: 40)
                            .scaleEffect(ripplePulse ? 4 : 1)
                            .opacity(ripplePulse ? 0 : 0.9)
                            .animation(
                                .easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(Double(index) * 0.8),
                                value: ripplePulse
                            )
                    }
                }
                Image("voice_panel_microphone")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 104, height: 104)
                    .scaleEffect(buttonScale)
            }
            .frame(width: 160, height: 160)
            .padding(.top, 39)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in beginCapture() }
                    .onEnded { _ in endCapture() }
            )
        }
        .frame(height: 226)
        .onChange(of: controller.elapsedSeconds) { value in
            guard value >= 60 else { return }
            isPressing = false
            ripplePulse = false
            stopButtonBreath()
            completion(controller.finish(keepingFile: true))
        }
    }

    private func beginCapture() {
        guard controller.isRecording == false else { return }
        guard controller.start() else {
            isPressing = false
            ripplePulse = false
            stopButtonBreath()
            return
        }
        isPressing = true
        ripplePulse = false
        buttonScale = 1
        DispatchQueue.main.async {
            ripplePulse = true
            startButtonBreath()
        }
    }

    private func endCapture() {
        guard controller.isRecording else { return }
        isPressing = false
        ripplePulse = false
        stopButtonBreath()
        completion(controller.finish(keepingFile: true))
    }

    private func startButtonBreath() {
        withAnimation(.easeOut(duration: 0.16)) {
            buttonScale = 80 / 104
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            guard controller.isRecording else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                buttonScale = 88 / 104
            }
        }
    }

    private func stopButtonBreath() {
        withAnimation(.easeInOut(duration: 0.18)) {
            buttonScale = 1
        }
    }
}

private struct DialoguePanelTopShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private func dismissDialogueKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

private struct IntroAssistantCard: View {
    let shouldAnimate: Bool
    @State private var displayedText = ""
    private let fullText = "Hello!\nHow can I help you?"

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image("assistant_intro_card_background")
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 18))
            Text(displayedText)
                .font(TextCraft.source(20))
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [VisualLanguage.lime, VisualLanguage.mint], startPoint: .top, endPoint: .bottom))
                )
                .padding(16)
        }
        .onAppear {
            guard shouldAnimate else {
                displayedText = fullText
                return
            }
            guard displayedText.isEmpty else { return }
            revealCharacter(at: 0, generator: UISelectionFeedbackGenerator())
        }
    }

    private func revealCharacter(at index: Int, generator: UISelectionFeedbackGenerator) {
        let characters = Array(fullText)
        guard index < characters.count else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.045) {
            displayedText.append(characters[index])
            generator.selectionChanged()
            generator.prepare()
            revealCharacter(at: index + 1, generator: generator)
        }
    }
}

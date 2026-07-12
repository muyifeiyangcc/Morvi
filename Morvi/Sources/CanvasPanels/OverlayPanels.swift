import SwiftUI
import PhotosUI
import UIKit
import AVFoundation

struct FeelingEditorPanel: View {
    @EnvironmentObject private var accessStore: AccessSessionStore
    @EnvironmentObject private var experienceStore: ExperienceContainer
    let option: FeelingOption
    @State private var text = ""
    @State private var floatingInputFocused = false
    @State private var keyboardIsVisible = false
    @State private var keyboardLift: CGFloat = 0

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .bottom) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: handleBlankTap)
                bottomPanel {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Today's feelings")
                            .font(TextCraft.one(31))
                        feelingCard
                            .padding(.top, 57)
                        LowerShadowButton(title: "Upload") {
                            guard accessStore.needsAccessUpgrade == false else {
                                experienceStore.activeOverlay = .accessGuide
                                return
                            }
                            experienceStore.publishFeeling(option: option, text: text, owner: accessStore.activeCard)
                        }
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 34)
                    .padding(.bottom, 29)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    if keyboardIsVisible {
                        dismissKeyboard()
                    }
                })
                if keyboardIsVisible {
                    FeelingWritingSurface(text: $text, isFocused: $floatingInputFocused, placeholder: "Input here...")
                        .frame(height: 118)
                        .padding(.horizontal, 20)
                        .padding(.bottom, keyboardLift)
                        .background(Color.white)
                        .transition(.identity)
                        .onAppear {
                            floatingInputFocused = true
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea()
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

    private func handleBlankTap() {
        if keyboardIsVisible {
            dismissKeyboard()
        } else {
            experienceStore.closeOverlay()
        }
    }

    private func dismissKeyboard() {
        floatingInputFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.easeInOut(duration: 0.18)) {
            keyboardIsVisible = false
            keyboardLift = 0
        }
    }

    private var feelingCard: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(white: 0.9), lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 14, y: 4)
            FeelingDisplaySurface(text: text, placeholder: "Input here...")
                .frame(height: 118)
                .padding(.horizontal, 16)
                .padding(.top, 75)
                .padding(.bottom, 16)
                .contentShape(Rectangle())
                .onTapGesture {
                    keyboardIsVisible = true
                    floatingInputFocused = true
                }
            Image(option.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .frame(width: 100, height: 100)
                .background(RoundedRectangle(cornerRadius: 28).fill(Color(red: 1, green: 240 / 255, blue: 110 / 255)))
                .shadow(color: .black.opacity(0.07), radius: 12, y: 5)
                .padding(.trailing, 20)
                .offset(y: -41)
        }
        .frame(height: 209)
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
}

private struct FeelingDisplaySurface: View {
    let text: String
    let placeholder: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 212 / 255, green: 1, blue: 59 / 255).opacity(0.3))
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    Color(red: 165 / 255, green: 214 / 255, blue: 63 / 255),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )
            Text(text.isEmpty ? placeholder : text)
                .font(TextCraft.source(14))
                .foregroundColor(text.isEmpty ? .gray : .black)
                .padding(16)
        }
    }
}

private struct FeelingWritingSurface: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    let placeholder: String
    var isEditable: Bool = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 212 / 255, green: 1, blue: 59 / 255).opacity(0.3))
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    Color(red: 165 / 255, green: 214 / 255, blue: 63 / 255),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                )
            if isEditable {
                FeelingTextArea(text: $text, isFocused: $isFocused)
                    .padding(16)
            }
            if text.isEmpty {
                Text(placeholder)
                    .font(TextCraft.source(14))
                    .foregroundColor(.gray)
                    .padding(16)
                    .allowsHitTesting(false)
            }
        }
    }
}

private struct FeelingTextArea: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textColor = .black
        view.font = UIFont(name: "SourceHanSansSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.autocorrectionType = .no
        view.autocapitalizationType = .none
        view.spellCheckingType = .no
        view.smartDashesType = .no
        view.smartQuotesType = .no
        view.smartInsertDeleteType = .no
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        if view.text != text {
            view.text = text
        }
        if isFocused, view.isFirstResponder == false {
            DispatchQueue.main.async {
                view.becomeFirstResponder()
            }
        } else if isFocused == false, view.isFirstResponder {
            DispatchQueue.main.async {
                view.resignFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding private var text: String
        @Binding private var isFocused: Bool

        init(text: Binding<String>, isFocused: Binding<Bool>) {
            _text = text
            _isFocused = isFocused
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            isFocused = false
        }
    }
}

struct UploadCreationPanel: View {
    @EnvironmentObject private var accessStore: AccessSessionStore
    @EnvironmentObject private var experienceStore: ExperienceContainer
    @State private var title = ""
    @State private var bodyText = ""
    @State private var selectedThemes: Set<String> = ["Travel"]
    @State private var extraThemes: [String] = []
    @State private var customTheme = ""
    @State private var showsThemeEntry = false
    @State private var hasChosenMedia = false
    @FocusState private var themeEntryFocused: Bool
    private let themes = ["Travel", "Food", "Family", "Friends", "Lifestyle"]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                bottomPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Upload work")
                            .font(TextCraft.one(28))
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 18) {
                                uploadFormFields
                                uploadMediaButton
                            }
                            .padding(.bottom, 10)
                        }
                        .frame(maxHeight: max(proxy.size.height - 312, 330))
                        LowerShadowButton(title: "Upload", action: submitCreation)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 34)
                    .padding(.bottom, 29)
                }
                if showsThemeEntry {
                    themeEntryDock
                }
            }
        }
    }

    private var uploadFormFields: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Title of work:")
                    .font(TextCraft.source(16, weight: .medium))
                oneLineField("Enter the title", text: $title)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("Theme:")
                    .font(TextCraft.source(16, weight: .medium))
                FlexibleTagLayout(items: themeChoices) { choice in
                    switch choice {
                    case .title(let theme):
                        AnyView(themeButton(theme))
                    case .addition:
                        AnyView(addThemeButton)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Description:")
                    .font(TextCraft.source(16, weight: .medium))
                DashedWritingBox(text: $bodyText, placeholder: "Say something", minHeight: 118)
            }
        }
    }

    private var uploadMediaButton: some View {
        Button {
            hasChosenMedia = true
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(VisualLanguage.quietFill)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3])).foregroundColor(VisualLanguage.lineGreen))
                    .frame(width: 82, height: 98)
                Image("upload_media_icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
            }
        }
        .buttonStyle(.plain)
    }

    private var themeEntryDock: some View {
        TextField("Theme", text: $customTheme)
            .font(TextCraft.source(14))
            .plainEntryBehavior()
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(VisualLanguage.quietFill)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3])).foregroundColor(VisualLanguage.lineGreen))
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            .background(Color.white)
            .focused($themeEntryFocused)
            .onSubmit(commitThemeEntry)
    }

    private func commitThemeEntry() {
        let trimmed = customTheme.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty == false {
            if extraThemes.contains(trimmed) == false && themes.contains(trimmed) == false {
                extraThemes.append(trimmed)
            }
            selectedThemes.insert(trimmed)
        }
        showsThemeEntry = false
        themeEntryFocused = false
        customTheme = ""
    }

    private func submitCreation() {
        guard title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            experienceStore.showToast("Please enter the title")
            return
        }
        guard bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            experienceStore.showToast("Please say something")
            return
        }
        guard selectedThemes.isEmpty == false else {
            experienceStore.showToast("Please choose a theme")
            return
        }
        guard hasChosenMedia else {
            experienceStore.showToast("Please upload media")
            return
        }
        guard accessStore.needsAccessUpgrade == false else {
            experienceStore.activeOverlay = .accessGuide
            return
        }
        experienceStore.publishCreation(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            bodyText: bodyText.trimmingCharacters(in: .whitespacesAndNewlines),
            themes: Array(selectedThemes).sorted(),
            owner: accessStore.activeCard
        )
    }

    private func oneLineField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(TextCraft.source(14))
            .plainEntryBehavior()
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(VisualLanguage.quietFill)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3])).foregroundColor(VisualLanguage.lineGreen))
            )
    }

    private func themeButton(_ title: String) -> some View {
        let selected = selectedThemes.contains(title)
        return Button {
            if selected {
                selectedThemes.remove(title)
            } else {
                selectedThemes.insert(title)
            }
        } label: {
            Text(title)
                .font(TextCraft.source(14))
                .foregroundColor(Color(UIColor.darkGray))
                .padding(.horizontal, 16)
                .frame(height: 45)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selected ? Color(red: 0.94, green: 1, blue: 0.72) : Color(white: 0.9).opacity(0.5))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 2])).foregroundColor(selected ? VisualLanguage.lineGreen : Color(white: 0.75)))
                )
        }
        .buttonStyle(.plain)
    }

    private var themeChoices: [ThemeChoice] {
        (themes + extraThemes).map(ThemeChoice.title) + [.addition]
    }

    private var addThemeButton: some View {
        Button {
            showsThemeEntry = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                themeEntryFocused = true
            }
        } label: {
            Text("+")
                .font(TextCraft.source(28))
                .foregroundColor(Color(white: 0.45))
                .frame(width: 80, height: 45)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(VisualLanguage.quietFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                                .foregroundColor(VisualLanguage.lineGreen)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

private enum ThemeChoice: Hashable {
    case title(String)
    case addition
}

struct ProfileEditorPanel: View {
    @EnvironmentObject private var accessStore: AccessSessionStore
    @EnvironmentObject private var experienceStore: ExperienceContainer
    @State private var name = ""
    @State private var selectedPortrait: UIImage?
    @State private var showsPortraitChoices = false
    @State private var showsGalleryPicker = false
    @State private var showsCameraPicker = false
    @State private var floatingInputFocused = false
    @State private var keyboardIsVisible = false
    @State private var keyboardLift: CGFloat = 0

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .bottom) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: handleBlankTap)
                bottomPanel {
                    VStack(spacing: 0) {
                        Text("Edit Profile")
                            .font(TextCraft.one(28))
                            .padding(.bottom, 47)
                        portraitButton
                            .padding(.bottom, 49)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username:")
                                .font(TextCraft.source(16, weight: .medium))
                            profileNameDisplay
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    keyboardIsVisible = true
                                    floatingInputFocused = true
                                }
                        }
                        .padding(.bottom, 32)
                        LowerShadowButton(title: "Upload", action: submitProfile)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 34)
                    .padding(.bottom, 29)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    if keyboardIsVisible {
                        dismissKeyboard()
                    }
                })
                if keyboardIsVisible {
                    ProfileNameFloatingField(text: $name, isFocused: $floatingInputFocused)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(VisualLanguage.quietFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            VisualLanguage.lineGreen,
                                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                                        )
                                )
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, keyboardLift)
                        .background(Color.white)
                        .transition(.identity)
                        .onAppear {
                            floatingInputFocused = true
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea()
        }
        .confirmationDialog("", isPresented: $showsPortraitChoices, titleVisibility: .hidden) {
            Button("Album") {
                showsGalleryPicker = true
            }
            Button("Camera") {
                presentCameraPicker()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showsGalleryPicker) {
            AvatarGalleryPicker(selectedPortrait: $selectedPortrait, isPresented: $showsGalleryPicker)
        }
        .sheet(isPresented: $showsCameraPicker) {
            PortraitCameraPicker { image in
                selectedPortrait = image
            }
        }
        .onAppear {
            name = accessStore.activeCard?.displayName ?? ""
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

    private var portraitButton: some View {
        Button {
            showsPortraitChoices = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let selectedPortrait {
                        Image(uiImage: selectedPortrait)
                            .resizable()
                            .scaledToFill()
                    } else {
                        AvatarBadgeView(assetName: accessStore.activeCard?.avatarAssetName ?? "default_avatar", size: 112)
                    }
                }
                .frame(width: 112, height: 112)
                .clipShape(Circle())
                Image("profile_avatar_edit_mark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .offset(x: -8, y: -8)
            }
        }
        .buttonStyle(.plain)
    }

    private var profileNameDisplay: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(VisualLanguage.quietFill)
            Text(name.isEmpty ? "Username" : name)
                .font(TextCraft.source(14))
                .foregroundColor(name.isEmpty ? .gray : .black)
                .lineLimit(1)
                .padding(.horizontal, 14)
        }
        .frame(height: 48)
    }

    private func submitProfile() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            experienceStore.showToast("Please enter username")
            return
        }
        do {
            if let selectedPortrait {
                try accessStore.updateActivePortrait(selectedPortrait)
            }
            accessStore.updateActiveIdentityName(trimmed)
            if let activeCard = accessStore.activeCard {
                experienceStore.refreshActiveIdentityDisplay(activeCard)
            }
            experienceStore.showToast("Uploaded successfully")
            experienceStore.closeOverlay()
        } catch {
            experienceStore.showToast("Upload failed")
        }
    }

    private func handleBlankTap() {
        if keyboardIsVisible {
            dismissKeyboard()
        } else {
            experienceStore.closeOverlay()
        }
    }

    private func dismissKeyboard() {
        floatingInputFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.easeInOut(duration: 0.18)) {
            keyboardIsVisible = false
            keyboardLift = 0
        }
    }

    private func presentCameraPicker() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            experienceStore.showToast("Camera unavailable")
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showsCameraPicker = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showsCameraPicker = true
                    } else {
                        experienceStore.showToast("Camera permission is required")
                    }
                }
            }
        default:
            experienceStore.showToast("Please enable camera permission in Settings")
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
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
}

private struct ProfileNameFloatingField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.backgroundColor = .clear
        field.textColor = .black
        field.font = UIFont(name: "SourceHanSansSC-Regular", size: 14) ?? .systemFont(ofSize: 14)
        field.placeholder = "Username"
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.smartDashesType = .no
        field.smartQuotesType = .no
        field.smartInsertDeleteType = .no
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.leftView = container
        field.leftViewMode = .always
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        field.rightViewMode = .always
        field.returnKeyType = .done
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        if field.text != text {
            field.text = text
        }
        if isFocused, field.isFirstResponder == false {
            DispatchQueue.main.async {
                field.becomeFirstResponder()
            }
        } else if isFocused == false, field.isFirstResponder {
            DispatchQueue.main.async {
                field.resignFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var text: String
        @Binding private var isFocused: Bool

        init(text: Binding<String>, isFocused: Binding<Bool>) {
            _text = text
            _isFocused = isFocused
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            text = textField.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isFocused = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            isFocused = false
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            isFocused = false
            textField.resignFirstResponder()
            return true
        }
    }

}

private struct PortraitCameraPicker: UIViewControllerRepresentable {
    let completion: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.mediaTypes = ["public.image"]
        controller.allowsEditing = false
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let completion: (UIImage) -> Void
        let dismiss: DismissAction

        init(completion: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.completion = completion
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                completion(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

struct RestrictChoicePanel: View {
    @EnvironmentObject private var accessStore: AccessSessionStore
    @EnvironmentObject private var experienceStore: ExperienceContainer

    var body: some View {
        bottomPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("Report or block")
                    .font(TextCraft.one(28))
                HStack(spacing: 19) {
                    restrictCard(asset: "restrict_report_icon") {
                        guard accessStore.activeCard?.stableKey != experienceStore.focusedIdentityCard?.stableKey else {
                            experienceStore.showToast("You cannot report yourself")
                            experienceStore.closeOverlay()
                            return
                        }
                        experienceStore.activeOverlay = .safetyConcern
                    }
                    restrictCard(asset: "restrict_barrier_mark") {
                        experienceStore.presentRestrictionConfirmation(accessStore: accessStore)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 36)
        }
    }

    private func restrictCard(asset: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(VisualLanguage.quietFill)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(VisualLanguage.lineGreen, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }
}

struct SafetyConcernPanel: View {
    @EnvironmentObject private var experienceStore: ExperienceContainer
    @State private var selectedReason = "Hate speech"
    private let reasons = [
        "Hate speech",
        "Pornographic content",
        "Violence or discrimination",
        "Unauthorized advertising",
        "False information"
    ]

    var body: some View {
        bottomPanel {
            VStack(alignment: .leading, spacing: 0) {
                Text("Report")
                    .font(TextCraft.one(31))
                VStack(spacing: 12) {
                    ForEach(reasons, id: \.self) { reason in
                        Button {
                            selectedReason = reason
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(red: 0.94, green: 1, blue: 0.72))
                                Text(reason)
                                    .font(TextCraft.source(14))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity)
                                Image(reason == selectedReason ? "report_check_selected" : "report_check_unselected")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .padding(.trailing, 17)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 15)
                LowerShadowButton(title: "Upload") {
                    experienceStore.submitSafetyConcern(reason: selectedReason)
                }
                .padding(.top, 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 35)
            .padding(.bottom, 29)
        }
    }
}

private func bottomPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack {
        Spacer()
        content()
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(TopRoundedPanelShape(radius: 16))
            .contentShape(TopRoundedPanelShape(radius: 16))
            .onTapGesture {}
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.white)
                    .frame(width: 112, height: 4)
                    .offset(y: -10)
                    .allowsHitTesting(false)
            }
    }
    .ignoresSafeArea(edges: .bottom)
}

private struct TopRoundedPanelShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let corner = min(radius, min(rect.width, rect.height) / 2)
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + corner))
        path.addQuadCurve(to: CGPoint(x: rect.minX + corner, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + corner), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

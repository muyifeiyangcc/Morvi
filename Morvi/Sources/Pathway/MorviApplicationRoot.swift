import Combine
import Photos
import SwiftUI
import UIKit

struct MorviApplicationRoot: View {
    @StateObject var accessStore: AccessSessionStore
    @StateObject var experienceStore: ExperienceContainer

    var body: some View {
        ZStack {
            AmbientBackdrop()
                .ignoresSafeArea()
            if shouldShowAccessEntry {
                AccessJourneyCanvas(showsEntryBackButton: false)
                    .environmentObject(accessStore)
                    .environmentObject(experienceStore)
                    .transition(.identity)
                    .ignoresSafeArea()
            } else {
                NavigationView {
                    MainCanvasView()
                        .background(destinationLink)
                        .navigationBarHidden(true)
                        .background(Color.clear)
                }
                .background(Color.clear)
                .navigationViewStyle(.stack)
                .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        .environmentObject(accessStore)
        .environmentObject(experienceStore)
        .overlay(alignment: .bottom) {
            if let overlay = experienceStore.activeOverlay {
                OverlayCanvasView(kind: overlay)
                    .environmentObject(accessStore)
                    .environmentObject(experienceStore)
                    .transition(.identity)
            }
        }
        .overlay {
            if experienceStore.showsAccessFlow && shouldShowAccessEntry == false {
                AccessJourneyCanvas()
                    .environmentObject(accessStore)
                    .environmentObject(experienceStore)
                    .transition(.identity)
                    .ignoresSafeArea()
            }
        }
        .overlay {
            if experienceStore.showsProgress {
                ProgressVeilView()
                    .ignoresSafeArea()
            }
        }
        .overlay {
            if let text = experienceStore.toastText {
                SoftNoticeView(text: text) {
                    if experienceStore.toastText == text {
                        experienceStore.toastText = nil
                    }
                }
                .id(text)
            }
        }
        .onAppear {
            reconcileAccessState(accessStore.state)
        }
        .onChange(of: accessStore.state) { newState in
            reconcileAccessState(newState)
        }
    }

    private var shouldShowAccessEntry: Bool {
        if case .absent = accessStore.state {
            return true
        }
        return false
    }

    private func reconcileAccessState(_ state: IdentitySessionState) {
        switch state {
        case .absent:
            experienceStore.resetForAccessEntry()
        case .guest, .signed:
            experienceStore.showsAccessFlow = false
        }
    }

    private var destinationLink: some View {
        NavigationLink(
            destination: Group {
                if let destination = experienceStore.activeDestination {
                    DestinationCanvasView(destination: destination)
                        .navigationBarHidden(true)
                        .ignoresSafeArea()
                } else {
                    EmptyView()
                }
            },
            isActive: Binding(
                get: { experienceStore.activeDestination != nil },
                set: { isActive in
                    if isActive == false {
                        experienceStore.activeDestination = nil
                    }
                }
            )
        ) {
            EmptyView()
        }
        .hidden()
    }
}

private enum AccessJourneyStep {
    case entry
    case mail
    case enrollment
    case details
    case reset
}

private enum AccessFieldFocus: Hashable {
    case mailAddress
    case mailSecret
    case enrollmentAddress
    case enrollmentSecret
    case enrollmentRepeatedSecret
    case resetAddress
    case resetSecret
    case resetRepeatedSecret
    case alias
    case birthday
    case location
    case gender
}

private struct EnrollmentDraft {
    let mailbox: String
    let passcode: String
}

private struct AccessJourneyCanvas: View {
    @EnvironmentObject private var accessStore: AccessSessionStore
    @EnvironmentObject private var experienceStore: ExperienceContainer
    let showsEntryBackButton: Bool
    @State private var step: AccessJourneyStep = .entry
    @State private var acceptsTerms = true
    @State private var mailAddressText = ""
    @State private var mailSecretText = ""
    @State private var enrollmentAddressText = ""
    @State private var enrollmentSecretText = ""
    @State private var enrollmentRepeatedSecretText = ""
    @State private var resetAddressText = ""
    @State private var resetSecretText = ""
    @State private var resetRepeatedSecretText = ""
    @State private var enrollmentDraft: EnrollmentDraft?
    @State private var aliasText = ""
    @State private var birthdayText = ""
    @State private var locationText = ""
    @State private var genderText = ""
    @State private var accessDocumentTitle: String?
    @State private var selectedPortrait: UIImage?
    @State private var showsAvatarGallery = false
    @State private var showsPhotoPermissionNotice = false
    @StateObject private var appleIdentityBridge = AppleIdentityBridge()
    @FocusState private var activeInput: AccessFieldFocus?

    init(showsEntryBackButton: Bool = true) {
        self.showsEntryBackButton = showsEntryBackButton
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                AmbientBackdrop()
                Image("Morvi")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 297, height: 128)
                    .offset(x: -10, y: 20)
                    .opacity(0.52)
                switch step {
                case .entry:
                    entryPage
                case .mail:
                    mailPage
                case .enrollment:
                    enrollmentPage
                case .details:
                    detailsPage
                case .reset:
                    resetPage
                }
                navigationControl
                if let accessDocumentTitle {
                    AgreementScreen(title: accessDocumentTitle) {
                        self.accessDocumentTitle = nil
                    }
                    .environmentObject(experienceStore)
                    .background(AmbientBackdrop())
                    .zIndex(2)
                }
            }
        }
        .background(Color.white)
        .ignoresSafeArea(.container)
        .sheet(isPresented: $showsAvatarGallery) {
            AvatarGalleryPicker(selectedPortrait: $selectedPortrait, isPresented: $showsAvatarGallery)
                .onAppear {
                    experienceStore.showsProgress = false
                }
        }
        .alert("Photo access required", isPresented: $showsPhotoPermissionNotice) {
            Button("Open Settings") {
                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(settingsURL)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow photo access in Settings to select an image.")
        }
    }

    @ViewBuilder
    private var navigationControl: some View {
        if step != .entry || showsEntryBackButton {
            TopChromeView(
                title: navigationTitle,
                showsBack: true,
                backAction: {
                    activeInput = nil
                    switch step {
                    case .entry:
                        experienceStore.showsAccessFlow = false
                    case .mail, .enrollment:
                        step = .entry
                    case .details:
                        step = .enrollment
                    case .reset:
                        step = .mail
                    }
                }
            )
            .accessibilityLabel("Back")
            .accessibilityHint("Returns to the previous access screen")
        }
    }

    private var navigationTitle: String {
        switch step {
        case .mail:
            return "Sign in"
        case .enrollment:
            return "Sign up"
        case .reset:
            return "Forgot password"
        case .entry, .details:
            return ""
        }
    }

    private var entryPage: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .top) {
                        Image("LOGO")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .frame(maxWidth: .infinity, alignment: .top)
                            .padding(.top, 168)

                        Text("Morvi")
                            .font(TextCraft.one(38))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .top)
                            .padding(.top, 307)

                        entryActionButton("Login by email", filled: false) {
                            guard acceptsTerms else {
                                experienceStore.showToast("Please agree to User Agreement and Privacy Policy")
                                return
                            }
                            step = .mail
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 417)

                        entryActionButton("I'm new", filled: true) {
                            step = .enrollment
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 486)

                        HStack(spacing: 0) {
                            Text("Don't have an account?")
                                .font(TextCraft.source(12))
                            Button {
                                step = .enrollment
                            } label: {
                                Text("Sign up")
                                    .font(TextCraft.source(12))
                                    .underline()
                                    .foregroundColor(.black)
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 568)

                        Button {
                            guard acceptsTerms else {
                                experienceStore.showToast("Please agree to User Agreement and Privacy Policy")
                                return
                            }
                            experienceStore.revealProgressThenStart {
                                accessStore.enterAsGuest { result in
                                    experienceStore.showsProgress = false
                                    switch result {
                                    case .success:
                                        experienceStore.showsAccessFlow = false
                                        experienceStore.showToast("Login successful")
                                    case .failure:
                                        experienceStore.showToast("Login failed")
                                    }
                                }
                            }
                        } label: {
                            Text("Guest login")
                                .font(TextCraft.source(12))
                                .foregroundColor(VisualLanguage.faintInk)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .padding(.top, 608)

                        Button {
                            guard acceptsTerms else {
                                experienceStore.showToast("Please agree to User Agreement and Privacy Policy")
                                return
                            }
                            beginAppleIdentityRequest()
                        } label: {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(Color.black.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .padding(.top, 640)
                    }
                    .frame(width: proxy.size.width, height: 700, alignment: .top)
                }
                consentRow
                    .frame(height: 20)
                    .padding(.bottom, 51)
            }
        }
    }

    private func entryActionButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(TextCraft.one(16))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    if filled {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.78, green: 1, blue: 0.16), Color(red: 0.86, green: 1, blue: 0.95)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white)
                            .overlay {
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                            }
                    }
                }
                .shadow(color: .black.opacity(filled ? 0.14 : 0.06), radius: 9, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var mailPage: some View {
        authenticationScaffold(actionTitle: "Log in", minimumContentHeight: 640, action: submitMailboxAccess) { navigationBottom in
            ZStack(alignment: .topLeading) {
                accessBranding(navigationBottom: navigationBottom)
                accessFieldLabel("Email", top: 388 - navigationBottom)
                accessInput(
                    "Please enter",
                    text: $mailAddressText,
                    keyboard: .emailAddress,
                    field: .mailAddress
                )
                .id(AccessFieldFocus.mailAddress)
                .padding(.top, 413 - navigationBottom)
                accessFieldLabel("Password", top: 496 - navigationBottom)
                accessInput(
                    "Please enter",
                    text: $mailSecretText,
                    secured: true,
                    field: .mailSecret
                )
                .id(AccessFieldFocus.mailSecret)
                .padding(.top, 523 - navigationBottom)
                HStack {
                    Spacer()
                    Button {
                        activeInput = nil
                        step = .reset
                    } label: {
                        Text("Forgot ?")
                            .font(TextCraft.source(12))
                            .foregroundColor(.gray)
                            .underline()
                            .frame(width: 88, height: 44, alignment: .trailing)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 573 - navigationBottom)
                .padding(.trailing, 20)
                .zIndex(5)
            }
        }
    }

    private func submitMailboxAccess() {
        let mailbox = normalizedText(mailAddressText)
        let passcode = normalizedText(mailSecretText)
        guard mailbox.isEmpty == false else {
                experienceStore.showToast("Please enter email")
                return
        }
        guard validateAddress(mailbox) else {
                experienceStore.showToast("Please enter a valid email address")
                return
        }
        guard passcode.isEmpty == false else {
                experienceStore.showToast("Please enter password")
                return
        }
        activeInput = nil
        experienceStore.revealProgressThenStart {
            accessStore.enterWithEmail(mailbox: mailbox.lowercased(), passcode: passcode) { result in
                experienceStore.showsProgress = false
                switch result {
                case .success:
                        experienceStore.showsAccessFlow = false
                        experienceStore.showToast("Login successful")
                case .failure(let error):
                    if let issue = error as? IdentityArchiveIssue,
                       case .invalidCredentials = issue {
                        experienceStore.showToast("Invalid email or password")
                    } else {
                        experienceStore.showToast("Login failed")
                    }
                }
            }
        }
    }

    private var resetPage: some View {
        authenticationScaffold(actionTitle: "Next", minimumContentHeight: 520, action: submitPasscodeReset) { navigationBottom in
            ZStack(alignment: .topLeading) {
                accessFieldLabel("Email", top: 158 - navigationBottom)
                accessInput(
                    "Enter email address",
                    text: $resetAddressText,
                    keyboard: .emailAddress,
                    field: .resetAddress
                )
                .id(AccessFieldFocus.resetAddress)
                .padding(.top, 184 - navigationBottom)
                accessFieldLabel("Password", top: 266 - navigationBottom)
                accessInput(
                    "Enter password",
                    text: $resetSecretText,
                    secured: true,
                    field: .resetSecret
                )
                .id(AccessFieldFocus.resetSecret)
                .padding(.top, 292 - navigationBottom)
                accessFieldLabel("Enter the password again", top: 374 - navigationBottom)
                accessInput(
                    "Enter password",
                    text: $resetRepeatedSecretText,
                    secured: true,
                    field: .resetRepeatedSecret
                )
                .id(AccessFieldFocus.resetRepeatedSecret)
                .padding(.top, 400 - navigationBottom)
            }
        }
    }

    private func submitPasscodeReset() {
        let mailbox = normalizedText(resetAddressText)
        let passcode = normalizedText(resetSecretText)
        let repeatedPasscode = normalizedText(resetRepeatedSecretText)
        guard mailbox.isEmpty == false else {
                experienceStore.showToast("Please enter email")
                return
        }
        guard validateAddress(mailbox) else {
                experienceStore.showToast("Please enter a valid email address")
                return
        }
        guard passcode.isEmpty == false else {
                experienceStore.showToast("Please enter password")
                return
        }
        guard repeatedPasscode.isEmpty == false else {
                experienceStore.showToast("Please enter the password again")
                return
        }
        guard passcode == repeatedPasscode else {
                experienceStore.showToast("Passwords do not match")
                return
        }
        activeInput = nil
        experienceStore.revealProgressThenStart {
            accessStore.resetPasscode(mailbox: mailbox.lowercased(), passcode: passcode) { result in
                experienceStore.showsProgress = false
                switch result {
                case .success(true):
                    resetSecretText = ""
                    resetRepeatedSecretText = ""
                    step = .mail
                    experienceStore.showToast("Password reset successful")
                case .success(false):
                        experienceStore.showToast("Email not found")
                case .failure:
                    experienceStore.showToast("Password reset failed")
                }
            }
        }
    }

    private var enrollmentPage: some View {
        authenticationScaffold(actionTitle: "Sign up", minimumContentHeight: 620, action: submitEnrollmentDraft) { navigationBottom in
            ZStack(alignment: .topLeading) {
                accessBranding(navigationBottom: navigationBottom)
                accessFieldLabel("Email", top: 388 - navigationBottom)
                accessInput(
                    "Please enter",
                    text: $enrollmentAddressText,
                    keyboard: .emailAddress,
                    field: .enrollmentAddress
                )
                .id(AccessFieldFocus.enrollmentAddress)
                .padding(.top, 414 - navigationBottom)
                accessFieldLabel("Password", top: 496 - navigationBottom)
                accessInput(
                    "Please enter",
                    text: $enrollmentSecretText,
                    secured: true,
                    field: .enrollmentSecret
                )
                .id(AccessFieldFocus.enrollmentSecret)
                .padding(.top, 522 - navigationBottom)
                accessFieldLabel("Enter the password again", top: 604 - navigationBottom)
                accessInput(
                    "Please enter",
                    text: $enrollmentRepeatedSecretText,
                    secured: true,
                    field: .enrollmentRepeatedSecret
                )
                .id(AccessFieldFocus.enrollmentRepeatedSecret)
                .padding(.top, 630 - navigationBottom)
            }
        }
    }

    private func submitEnrollmentDraft() {
        let mailbox = normalizedText(enrollmentAddressText)
        let passcode = normalizedText(enrollmentSecretText)
        let repeatedPasscode = normalizedText(enrollmentRepeatedSecretText)
        guard mailbox.isEmpty == false else {
            experienceStore.showToast("Please enter email")
            return
        }
        guard validateAddress(mailbox) else {
                experienceStore.showToast("Please enter a valid email address")
                return
        }
        guard passcode.isEmpty == false else {
                experienceStore.showToast("Please enter password")
                return
        }
        guard repeatedPasscode.isEmpty == false else {
            experienceStore.showToast("Please enter the password again")
            return
        }
        guard passcode == repeatedPasscode else {
                experienceStore.showToast("Passwords do not match")
                return
        }
        activeInput = nil
        enrollmentDraft = EnrollmentDraft(mailbox: mailbox.lowercased(), passcode: passcode)
        selectedPortrait = nil
        step = .details
    }

    private var detailsPage: some View {
        authenticationScaffold(actionTitle: "Sign up", minimumContentHeight: 580, action: submitPersonalDetails) { navigationBottom in
            ZStack(alignment: .topLeading) {
                Button(action: requestAvatarSelection) {
                    ZStack(alignment: .topLeading) {
                        Group {
                            if let selectedPortrait {
                                Image(uiImage: selectedPortrait).resizable().scaledToFill()
                            } else {
                                Image("default_avatar").resizable().scaledToFill()
                            }
                        }
                        .frame(width: 84, height: 84)
                        .clipShape(Circle())
                        Image("avatar_edit_badge")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .offset(x: 62, y: 63)
                    }
                    .frame(width: 88, height: 88, alignment: .topLeading)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 147 - navigationBottom)

                personalDetailField(
                    title: "Nickname",
                    hint: nil,
                    placeholder: "Please enter",
                    text: $aliasText,
                    field: .alias,
                    top: 274 - navigationBottom
                )
                personalDetailField(
                    title: "Gender",
                    hint: "(optional)",
                    placeholder: "Female",
                    text: $genderText,
                    field: .gender,
                    top: 383 - navigationBottom
                )
                personalDetailField(
                    title: "Birthday",
                    hint: "(optional)",
                    placeholder: "Please enter",
                    text: $birthdayText,
                    field: .birthday,
                    top: 492 - navigationBottom
                )
                personalDetailField(
                    title: "Location",
                    hint: "(optional)",
                    placeholder: "Please enter",
                    text: $locationText,
                    field: .location,
                    top: 601 - navigationBottom
                )
            }
        }
    }

    private func submitPersonalDetails() {
        let displayName = normalizedText(aliasText)
        guard displayName.isEmpty == false else {
            experienceStore.showToast("Please enter nickname")
            return
        }
        guard let selectedPortrait else {
            experienceStore.showToast("Please select avatar")
            return
        }
        guard let enrollmentDraft else {
            experienceStore.showToast("Please enter password")
            return
        }
        activeInput = nil
        experienceStore.revealProgressThenStart {
            accessStore.register(
                mailbox: enrollmentDraft.mailbox,
                passcode: enrollmentDraft.passcode,
                displayName: displayName,
                birthday: normalizedText(birthdayText),
                location: normalizedText(locationText),
                gender: normalizedText(genderText),
                portrait: selectedPortrait
            ) { result in
                experienceStore.showsProgress = false
                switch result {
                case .success:
                    step = .entry
                    clearEnrollmentDraft()
                    experienceStore.showToast("Registration successful")
                case .failure:
                    experienceStore.showToast("Registration failed")
                }
            }
        }
    }

    private func authenticationScaffold<Content: View>(
        actionTitle: String,
        minimumContentHeight: CGFloat,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping (CGFloat) -> Content
    ) -> some View {
        GeometryReader { proxy in
            let navigationBottom = authenticationStatusBarHeight + 76
            ZStack(alignment: .bottom) {
                InputVisibilityScrollBridge(
                    content: content(navigationBottom)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: max(minimumContentHeight - navigationBottom, proxy.size.height - navigationBottom - 97), alignment: .top)
                        .background(Color.clear.contentShape(Rectangle()).onTapGesture { activeInput = nil })
                )
                .padding(.top, navigationBottom)
                .padding(.bottom, 97)
                authenticationActionButton(actionTitle, action: action)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 29)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func authenticationActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(TextCraft.one(16))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.78, green: 1, blue: 0.16), Color(red: 0.86, green: 1, blue: 0.95)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                )
                .shadow(color: .black.opacity(0.14), radius: 9, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func accessBranding(navigationBottom: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Image("LOGO")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .padding(.top, 168 - navigationBottom)
            Text("Morvi")
                .font(TextCraft.one(42))
                .foregroundColor(.black)
                .padding(.top, 308 - navigationBottom)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func accessFieldLabel(_ title: String, top: CGFloat) -> some View {
        Text(title)
            .font(TextCraft.source(16, weight: .black))
            .foregroundColor(.black)
            .padding(.leading, 20)
            .padding(.top, top)
    }

    private func personalDetailField(
        title: String,
        hint: String?,
        placeholder: String,
        text: Binding<String>,
        field: AccessFieldFocus,
        top: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(title).font(TextCraft.source(17, weight: .black))
                if let hint {
                    Text(hint)
                        .font(TextCraft.source(12))
                        .foregroundColor(Color.gray.opacity(0.55))
                }
            }
            .padding(.horizontal, 20)
            accessInput(placeholder, text: text, field: field)
                .id(field)
        }
        .padding(.top, top)
    }

    private func accessInput(_ placeholder: String, text: Binding<String>, secured: Bool = false, keyboard: UIKeyboardType = .default, field: AccessFieldFocus) -> some View {
        Group {
            if secured {
                SecureField(placeholder, text: text)
                    .plainEntryBehavior()
                    .focused($activeInput, equals: field)
            } else {
                TextField(placeholder, text: text)
                    .keyboardType(keyboard)
                    .plainEntryBehavior()
                    .focused($activeInput, equals: field)
            }
        }
        .font(TextCraft.source(15))
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.94, green: 1, blue: 0.72), Color(red: 0.88, green: 1, blue: 0.95)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                        .foregroundColor(Color(red: 165 / 255, green: 214 / 255, blue: 63 / 255))
                )
        )
        .padding(.horizontal, 20)
    }

    private var consentRow: some View {
        HStack(spacing: 0) {
            Button {
                acceptsTerms.toggle()
            } label: {
                Image(acceptsTerms ? "consent_check_selected" : "consent_circle_empty")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 17, height: 17)
            }
            .buttonStyle(.plain)
            .frame(width: 40, height: 40, alignment: .leading)
            .padding(.trailing, -23)
            Text("Agree with")
                .font(TextCraft.source(12))
                .foregroundColor(.gray)
                .padding(.leading, 6)
            Button {
                accessDocumentTitle = "User Agreement"
            } label: {
                underlinedSmallText("User Agreement")
            }
            .buttonStyle(.plain)
            .padding(.leading, 6)
            Text("and")
                .font(TextCraft.source(12))
                .foregroundColor(.gray)
                .padding(.leading, 3)
            Button {
                accessDocumentTitle = "Privacy Policy"
            } label: {
                underlinedSmallText("Privacy Policy")
            }
            .buttonStyle(.plain)
            .padding(.leading, 3)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func underlinedSmallText(_ value: String) -> some View {
        Text(value)
            .font(TextCraft.source(12))
            .foregroundColor(.black)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 0.6)
                    .offset(y: 1)
            }
    }

    private func validateAddress(_ text: String) -> Bool {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func normalizedText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var authenticationStatusBarHeight: CGFloat {
        let rawHeight = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.top ?? 44
        return rawHeight > 24 ? 44 : 20
    }

    private func beginAppleIdentityRequest() {
        experienceStore.revealProgressThenStart {
            let startedAt = Date()
            appleIdentityBridge.begin { result in
                DispatchQueue.main.async {
                    let remainingTime = max(0, 0.5 - Date().timeIntervalSince(startedAt))
                    DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) {
                        switch result {
                        case .success(let receipt):
                            accessStore.enterWithApple(receipt: receipt) { entryResult in
                                experienceStore.showsProgress = false
                                switch entryResult {
                                case .success:
                                experienceStore.showsAccessFlow = false
                                experienceStore.showToast("Login successful")
                                case .failure:
                                    experienceStore.showToast("Apple login failed")
                                }
                            }
                        case .failure(let issue):
                            experienceStore.showsProgress = false
                            experienceStore.showToast(issue.localizedDescription)
                        }
                    }
                }
            }
        }
    }

    private func requestAvatarSelection() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            experienceStore.revealProgressThenStart {
                showsAvatarGallery = true
            }
        case .notDetermined:
            experienceStore.revealProgressThenStart {
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        switch newStatus {
                        case .authorized, .limited:
                            showsAvatarGallery = true
                        default:
                            experienceStore.showsProgress = false
                            showsPhotoPermissionNotice = true
                        }
                    }
                }
            }
        default:
            experienceStore.showsProgress = false
            showsPhotoPermissionNotice = true
        }
    }

    private func clearEnrollmentDraft() {
        enrollmentAddressText = ""
        enrollmentSecretText = ""
        enrollmentRepeatedSecretText = ""
        enrollmentDraft = nil
        aliasText = ""
        birthdayText = ""
        locationText = ""
        genderText = ""
        selectedPortrait = nil
    }
}

private struct MainCanvasView: View {
    @EnvironmentObject private var accessStore: AccessSessionStore
    @EnvironmentObject private var experienceStore: ExperienceContainer

    var body: some View {
        ZStack(alignment: .bottom) {
            AmbientBackdrop()
            Group {
                switch experienceStore.selectedRail {
                case .home:
                    HomeScreen()
                        .ignoresSafeArea(edges: .top)
                case .feelings:
                    FeelingsWeekScreen()
                        .ignoresSafeArea(edges: .top)
                case .dialogues:
                    DialogueListScreen()
                        .ignoresSafeArea(edges: .top)
                case .persona:
                    PersonaScreen()
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 104)
            }
            FloatingRailView(selected: $experienceStore.selectedRail) { section in
                guard section == .home || section == .persona || accessStore.needsAccessUpgrade == false else {
                    experienceStore.activeOverlay = .accessGuide
                    return
                }
                experienceStore.selectedRail = section
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct DestinationCanvasView: View {
    let destination: CanvasDestination

    var body: some View {
        ZStack {
            AmbientBackdrop(includesBottomTint: usesTintedDestinationBackground)
            switch destination {
            case .discover:
                DiscoverScreen()
            case .wallet:
                WalletScreen()
            case .settings:
                SettingsScreen()
            case .agreement(let title):
                AgreementScreen(title: title)
            case .restrictedRoster:
                PeopleRosterScreen(kind: .restricted)
            case .audienceRoster:
                PeopleRosterScreen(kind: .audience)
            case .connectionRoster:
                PeopleRosterScreen(kind: .connection)
            case .publicPersona(let card):
                PublicPersonaScreen(card: card)
            case .creationDetail(let record):
                CreationDetailScreen(record: record)
            case .directDialogue(let thread):
                DirectDialogueScreen(thread: thread)
            case .assistantDialogue:
                AssistantDialogueScreen()
            }
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var usesTintedDestinationBackground: Bool {
        switch destination {
        case .discover:
            return true
        default:
            return false
        }
    }
}

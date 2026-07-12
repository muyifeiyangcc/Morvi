import SwiftUI
import UIKit

struct OverlayCanvasView: View {
    @EnvironmentObject private var accessStore: AccessSessionStore
    @EnvironmentObject private var experienceStore: ExperienceContainer
    let kind: OverlaySheetKind

    var body: some View {
        ZStack {
            if allowsOutsideDismissal {
                Color.black.opacity(0.58)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: dismissFromOutside)
            } else {
                Color.black.opacity(0.58)
                    .ignoresSafeArea()
            }
            overlayBody
        }
    }

    private var allowsOutsideDismissal: Bool {
        switch kind {
        case .feelingEditor, .uploadCreation, .reportRestrict, .safetyConcern, .restrictionConfirm:
            return true
        case .accessGuide, .spendConfirm, .creditShortage, .profileEditor, .exitConfirm, .signOutConfirm:
            return false
        }
    }

    private func dismissFromOutside() {
        guard allowsOutsideDismissal else { return }
        experienceStore.closeOverlay()
    }

    @ViewBuilder
    private var overlayBody: some View {
        switch kind {
        case .accessGuide:
            CenterPromptCard(
                title: "Log in",
                text: "To ensure the normal operation\nof the function, please log in to\nyour account first.",
                confirmTitle: "Log in",
                cancelTitle: "Cancel",
                showsWordmark: true,
                confirmAction: {
                    experienceStore.closeOverlay()
                    experienceStore.showsAccessFlow = true
                },
                cancelAction: experienceStore.closeOverlay
            )
        case .feelingEditor(let option):
            FeelingEditorPanel(option: option)
        case .uploadCreation:
            UploadCreationPanel()
        case .spendConfirm:
            CenterPromptCard(
                title: "",
                text: "Are you sure you want to spend\n200 diamonds to unlock the AI\nfunction?",
                confirmTitle: "Sure",
                cancelTitle: "Cancel",
                confirmAction: {
                    experienceStore.confirmAssistantSpend(accessStore: accessStore)
                },
                cancelAction: experienceStore.closeOverlay
            )
        case .creditShortage:
            CenterPromptCard(
                title: "",
                text: "Unfortunately, your account\nbalance is insufficient. Please go\nto recharge.",
                confirmTitle: "Recharge",
                cancelTitle: "Cancel",
                confirmAction: {
                    experienceStore.closeOverlay()
                    experienceStore.open(.wallet)
                },
                cancelAction: experienceStore.closeOverlay
            )
        case .profileEditor:
            ProfileEditorPanel()
        case .reportRestrict:
            RestrictChoicePanel()
        case .restrictionConfirm:
            RestrictionConfirmationCard()
        case .safetyConcern:
            SafetyConcernPanel()
        case .exitConfirm:
            CenterPromptCard(
                title: "",
                text: "Are you sure you want to delete\nthis account? All data will be\ncleared after deletion and cannot\nbe recovered.",
                confirmTitle: "Sure",
                cancelTitle: "Cancel",
                confirmAction: {
                    accessStore.eraseActiveIdentity()
                    experienceStore.closeOverlay()
                    experienceStore.activeDestination = nil
                    experienceStore.selectedRail = .home
                    experienceStore.showToast("Account deleted")
                },
                cancelAction: experienceStore.closeOverlay
            )
        case .signOutConfirm:
            CenterPromptCard(
                title: "",
                text: "Are you sure you want to log\nout of this account?",
                confirmTitle: "Sure",
                cancelTitle: "Cancel",
                confirmAction: {
                    accessStore.exit()
                    experienceStore.closeOverlay()
                    experienceStore.activeDestination = nil
                    experienceStore.selectedRail = .home
                    experienceStore.showToast("Logged out")
                },
                cancelAction: experienceStore.closeOverlay
            )
        }
    }
}

private struct RestrictionConfirmationCard: View {
    @EnvironmentObject private var accessStore: AccessSessionStore
    @EnvironmentObject private var experienceStore: ExperienceContainer

    private var card: IdentityCardRecord? {
        experienceStore.focusedIdentityCard
    }

    var body: some View {
        VStack(spacing: 0) {
            portraitHeader
                .frame(height: 168)
            Text("Are you sure you want to block\nthis user? After blocking, no\nrelated content will be received.")
                .font(TextCraft.source(17))
                .foregroundColor(.black)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 36)
                .padding(.top, 20)
            HStack(spacing: 26) {
                promptButton(title: "Cancel", isPrimary: false, action: experienceStore.closeOverlay)
                promptButton(title: "Sure", isPrimary: true) {
                    experienceStore.restrictFocusedIdentity(accessStore: accessStore)
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 36)
        }
        .frame(maxWidth: .infinity)
        .background(
            GeometryReader { proxy in
                PromptPanelBackdrop(assetName: "login_popup_background")
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .allowsHitTesting(false)
            }
        )
        .frame(width: 322)
        .padding(.horizontal, 20)
        .onTapGesture {}
    }

    private var portraitHeader: some View {
        ZStack(alignment: .top) {
            Image("restrict_avatar_ring")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .offset(y: 35)
            AvatarBadgeView(assetName: card?.avatarAssetName ?? "profile_avatar", size: 76)
                .offset(y: 41)
            identityNamePill
                .offset(y: 106)
        }
    }

    private var identityNamePill: some View {
        Text(card?.displayName ?? "Victoria")
            .font(TextCraft.source(16, weight: .medium))
            .foregroundColor(.black)
            .padding(.horizontal, 30)
            .padding(.bottom, 3)
            .frame(minHeight: 22)
            .background(
                Capsule()
                    .fill(VisualLanguage.themeGradient)
                    .shadow(color: Color(red: 0.37, green: 0.68, blue: 0.03), radius: 0, x: 0, y: 3)
            )
    }

    private func promptButton(title: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(TextCraft.source(17, weight: .medium))
                .foregroundColor(isPrimary ? VisualLanguage.lime : .black)
                .frame(width: 112, height: 50)
                .background(Capsule().fill(isPrimary ? VisualLanguage.charcoal : Color.white))
                .shadow(color: isPrimary ? .clear : .black.opacity(0.08), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

private struct CenterPromptCard: View {
    let title: String
    let text: String
    let confirmTitle: String
    let cancelTitle: String
    var showsWordmark = false
    let confirmAction: () -> Void
    let cancelAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if title.isEmpty == false {
                Text(title)
                    .font(TextCraft.one(31))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 39)
                promptText
                    .padding(.top, 24)
            } else {
                promptText
                    .padding(.top, 39)
            }
            HStack(spacing: 26) {
                Button(action: cancelAction) {
                    Text(cancelTitle)
                        .font(TextCraft.source(17, weight: .medium))
                        .foregroundColor(.black)
                        .frame(width: 112, height: 50)
                        .background(Capsule().fill(Color.white))
                        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                Button(action: confirmAction) {
                    Text(confirmTitle)
                        .font(TextCraft.source(17, weight: .medium))
                        .foregroundColor(VisualLanguage.lime)
                        .frame(width: 112, height: 50)
                        .background(Capsule().fill(VisualLanguage.charcoal))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 24)
            .padding(.bottom, 36)
        }
        .padding(.horizontal, 36)
        .frame(maxWidth: 322)
        .background(
            GeometryReader { proxy in
                PromptPanelBackdrop(assetName: "login_popup_background")
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .allowsHitTesting(false)
            }
        )
        .padding(.horizontal, 20)
        .overlay(alignment: .top) {
            if showsWordmark {
                Image("popup_wordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 237, height: 88)
                    .padding(.top, 15)
                    .allowsHitTesting(false)
            }
        }
        .onTapGesture {}
    }

    private var promptText: some View {
        Text(text)
            .font(TextCraft.source(17))
            .foregroundColor(.black)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PromptPanelBackdrop: UIViewRepresentable {
    let assetName: String

    func makeUIView(context: Context) -> UnconstrainedBackdropImageView {
        let imageView = UnconstrainedBackdropImageView()
        imageView.contentMode = .scaleToFill
        imageView.backgroundColor = .clear
        imageView.isOpaque = false
        imageView.clipsToBounds = true
        imageView.image = stretchableImage()
        return imageView
    }

    func updateUIView(_ imageView: UnconstrainedBackdropImageView, context: Context) {
        imageView.image = stretchableImage()
    }

    private func stretchableImage() -> UIImage? {
        guard let image = UIImage(named: assetName) else { return nil }
        let preservedCornerLength = min(image.size.width, image.size.height) * 0.24
        let horizontalInset = min(preservedCornerLength, image.size.width / 2 - 1)
        let verticalInset = min(preservedCornerLength, image.size.height / 2 - 1)
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
}

private final class UnconstrainedBackdropImageView: UIImageView {
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
}

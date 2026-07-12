import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject private var accessStore: AccessSessionStore
    @EnvironmentObject private var experienceStore: ExperienceContainer
    @State private var selectedFeeling = 0

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                homeContent(screenWidth: proxy.size.width, screenHeight: proxy.size.height)
                    .frame(width: proxy.size.width, alignment: .topLeading)
            }
        }
    }

    private func homeContent(screenWidth: CGFloat, screenHeight: CGFloat) -> some View {
        ZStack(alignment: .top) {
            identityHeader
                .padding(.horizontal, 20)
                .padding(.top, 60)

            greetingBlock(width: screenWidth)
                .padding(.horizontal, 20)
                .padding(.top, 146)

            Text("Choose your mood today")
                .font(TextCraft.source(20, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 303)

            feelingStrip
                .frame(width: screenWidth, height: 100)
                .padding(.top, 340)

            LowerShadowButton(title: "Save your feelings") {
                guard accessStore.needsAccessUpgrade == false else {
                    experienceStore.activeOverlay = .accessGuide
                    return
                }
                let option = experienceStore.feelingOptions[selectedFeeling]
                experienceStore.activeOverlay = .feelingEditor(option)
            }
            .frame(height: 55)
            .padding(.horizontal, 20)
            .padding(.top, 458)

            actionCards(screenWidth: screenWidth)
                .padding(.horizontal, 20)
                .padding(.top, 536)
        }
        .frame(width: screenWidth, height: max(screenHeight, 720), alignment: .top)
        .padding(.bottom, 104)
    }

    private var identityHeader: some View {
        Button {
            guard accessStore.needsAccessUpgrade else { return }
            experienceStore.activeOverlay = .accessGuide
        } label: {
            HStack(spacing: 18) {
                AvatarBadgeView(assetName: accessStore.activeCard?.avatarAssetName ?? "default_avatar", size: 58)
                    .frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome back")
                        .font(TextCraft.one(17))
                        .foregroundColor(.black)
                    Text(accessStore.activeCard?.displayName ?? "Please log in first")
                        .font(TextCraft.source(16))
                        .foregroundColor(.black)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 68, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(accessStore.needsAccessUpgrade)
    }

    private func greetingBlock(width: CGFloat) -> some View {
        let name = accessStore.activeCard?.displayName
        let text = name.map { "Hello, \($0)!\nDid everything go\nsmoothly today?" } ?? "Hello!\nDid everything go\nsmoothly today?"
        return Text(text)
            .font(TextCraft.source(30))
            .foregroundColor(.black)
            .lineSpacing(0)
            .frame(width: max(width - 40, 0), alignment: .leading)
    }

    private var feelingStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(experienceStore.feelingOptions.enumerated()), id: \.offset) { index, option in
                        Button {
                            selectedFeeling = index
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                proxy.scrollTo(index, anchor: .center)
                            }
                        } label: {
                            FeelingChoiceTile(assetName: option.assetName, selected: index == selectedFeeling)
                        }
                        .buttonStyle(.plain)
                        .id(index)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func actionCards(screenWidth: CGFloat) -> some View {
        let width = floor((screenWidth - 52) / 2)
        return HStack(spacing: 12) {
            HomeActionCard(title: "Discover", backgroundAsset: "home_discover", iconAsset: "home_card_arrow") {
                experienceStore.open(.discover)
            }
            .frame(width: width, height: 145)
            HomeActionCard(title: "Recot Bot", backgroundAsset: "home_recot_bot", iconAsset: "home_card_arrow") {
                experienceStore.spendForAssistant(accessStore: accessStore)
            }
            .frame(width: width, height: 145)
        }
    }
}

private struct FeelingChoiceTile: View {
    let assetName: String
    let selected: Bool

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: 72, height: 72)
            .frame(width: 100, height: 100)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(selected ? Color(red: 1.0, green: 0.94, blue: 0.43) : Color.clear)
                    .background(
                        RoundedRectangle(cornerRadius: 28)
                            .fill(selected ? AnyShapeStyle(Color.clear) : AnyShapeStyle(VisualLanguage.verticalThemeGradient))
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 5)
    }
}

private struct HomeActionCard: View {
    let title: String
    let backgroundAsset: String
    let iconAsset: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    Image(backgroundAsset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                    Text(title)
                        .font(TextCraft.one(24))
                        .foregroundColor(.white)
                        .padding(.leading, 14)
                        .padding(.top, 18)
                    Image(iconAsset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 54, height: 54)
                        .position(x: proxy.size.width - 41, y: proxy.size.height - 41)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI

struct DiscoverScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accessStore: AccessSessionStore
    @EnvironmentObject private var experienceStore: ExperienceContainer
    @State private var localPersonaCard: IdentityCardRecord?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                AmbientBackdrop(includesBottomTint: true)
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    TopChromeView(title: "Discover", showsBack: true, backAction: { dismiss() })
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 24) {
                            storyStrip
                                .padding(.top, 20)
                            if experienceStore.creations.isEmpty {
                                EmptyListArtworkView(title: "No works yet")
                                    .padding(.top, 20)
                            } else {
                                LazyVStack(spacing: 28) {
                                    ForEach(experienceStore.creations) { record in
                                        CreationFeedCard(record: record) {
                                            experienceStore.open(.creationDetail(record))
                                        } profileAction: {
                                            if let card = experienceStore.identityCard(
                                                stableKey: record.authorKey,
                                                fallbackName: record.authorName
                                            ) {
                                                localPersonaCard = card
                                            }
                                        } moreAction: {
                                            experienceStore.presentRestrictionOptions(
                                                identityKey: record.authorKey,
                                                fallbackName: record.authorName,
                                                accessStore: accessStore
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 104 + proxy.safeAreaInsets.bottom)
                    }
                    .ignoresSafeArea(.container, edges: .bottom)
                }
                .ignoresSafeArea(.container, edges: .bottom)

                NavigationLink(
                    destination: Group {
                        if let card = localPersonaCard {
                            PublicPersonaScreen(card: card)
                                .navigationBarHidden(true)
                                .ignoresSafeArea()
                        } else {
                            EmptyView()
                        }
                    },
                    isActive: Binding(
                        get: { localPersonaCard != nil },
                        set: { active in
                            if active == false {
                                localPersonaCard = nil
                            }
                        }
                    )
                ) {
                    EmptyView()
                }
                .hidden()
            }
        }
    }

    private var storyStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 30) {
                StoryRibbonTile(title: "My works", assetName: "story_my_works_icon", clipsIcon: false)
                    .highPriorityGesture(TapGesture().onEnded(openCreationPublisher))

                ForEach(Array(experienceStore.identityCards.dropFirst().prefix(5))) { card in
                    StoryRibbonTile(title: card.displayName, assetName: card.avatarAssetName, clipsIcon: true)
                        .highPriorityGesture(TapGesture().onEnded {
                            localPersonaCard = card
                        })
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 88)
        .zIndex(10)
    }

    private func openCreationPublisher() {
        DispatchQueue.main.async {
            guard accessStore.needsAccessUpgrade == false else {
                experienceStore.activeOverlay = .accessGuide
                return
            }
            experienceStore.activeOverlay = .uploadCreation
        }
    }

}

private struct StoryRibbonTile: View {
    let title: String
    let assetName: String
    let clipsIcon: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: clipsIcon ? 29 : 0))
            Text(title)
                .font(TextCraft.source(13))
                .foregroundColor(.black)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(minWidth: 58, alignment: .top)
        .frame(height: 88, alignment: .top)
        .contentShape(Rectangle())
    }
}

struct CreationFeedCard: View {
    let record: CreationRecord
    let openAction: () -> Void
    let profileAction: () -> Void
    let moreAction: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = max(proxy.size.width - 40, 0)
            let coverHeight = CreationMediaSizing.discoveryCoverHeight
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    HStack(spacing: 10) {
                        AvatarBadgeView(assetName: record.avatarAssetName, size: 36)
                        Text(record.authorName)
                            .font(TextCraft.source(16, weight: .medium))
                            .foregroundColor(.black)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(perform: profileAction)
                    Spacer()
                    Button(action: moreAction) {
                        Image("feed_more_icon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 7)
                    .zIndex(2)
                }
                .frame(width: contentWidth)

                ZStack {
                    Image(record.coverAssetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: contentWidth, height: coverHeight)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(record.title)
                            .font(TextCraft.one(25))
                            .foregroundColor(.white)
                            .padding(.top, 12)
                            .padding(.leading, 16)
                        Spacer()
                        FlowTagRow(tags: record.tags)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                    if record.mediaKind == .video {
                        Image("video_play_icon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                    }
                }
                .frame(width: contentWidth, height: coverHeight)
                .contentShape(RoundedRectangle(cornerRadius: 24))
                .onTapGesture(perform: openAction)

                HStack(spacing: 18) {
                    Label("\(record.appreciationCount) Likes", image: "feed_appreciation_mark")
                    Label("\(record.replyCount) Comments", image: "feed_reply_icon")
                }
                .font(TextCraft.source(13))
                .foregroundColor(.gray)
                .frame(width: contentWidth, alignment: .leading)
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
        }
        .frame(height: estimatedHeight)
    }

    private var estimatedHeight: CGFloat {
        return 36 + 12 + CreationMediaSizing.discoveryCoverHeight + 12 + 22
    }
}

struct FlowTagRow: View {
    let tags: [String]

    var body: some View {
        FlexibleTagLayout(items: tags) { tag in
            Text(tag)
                .font(TextCraft.source(12))
                .foregroundColor(.black.opacity(0.75))
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

struct FlexibleTagLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let content: (Data.Element) -> Content
    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { geometry in
            makeContent(in: geometry)
        }
        .frame(height: totalHeight)
    }

    private func makeContent(in geometry: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        let array = Array(items)

        return ZStack(alignment: .topLeading) {
            ForEach(array, id: \.self) { item in
                content(item)
                    .alignmentGuide(.leading) { dimensions in
                        if abs(width - dimensions.width) > geometry.size.width {
                            width = 0
                            height -= dimensions.height + 8
                        }
                        let result = width
                        if item == array.last {
                            width = 0
                        } else {
                            width -= dimensions.width + 8
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item == array.last {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(
            GeometryReader { inner in
                Color.clear.preference(key: TagLayoutHeightKey.self, value: inner.size.height)
            }
        )
        .onPreferenceChange(TagLayoutHeightKey.self) { totalHeight = $0 }
    }
}

private enum CreationMediaSizing {
    static let discoveryCoverHeight: CGFloat = 335
}

private struct TagLayoutHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

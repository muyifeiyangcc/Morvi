import SwiftUI
import UIKit

struct PersonaScreen: View {
    @EnvironmentObject private var accessStore: AccessSessionStore
    @EnvironmentObject private var experienceStore: ExperienceContainer

    private var card: IdentityCardRecord {
        accessStore.activeCard ?? .guestSample
    }

    private var visibleCreations: [CreationRecord] {
        guard let activeCard = accessStore.activeCard else { return [] }
        return experienceStore.creations.filter {
            $0.authorKey == activeCard.stableKey
                || ($0.authorKey.isEmpty && $0.authorName == activeCard.displayName)
        }
    }

    private var audienceMetricText: String {
        guard accessStore.activeCard != nil else { return "0" }
        return "\(experienceStore.audienceTotalForActiveIdentity)"
    }

    private var connectionMetricText: String {
        guard accessStore.activeCard != nil else { return "0" }
        return "\(experienceStore.connectionTotalForActiveIdentity)"
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    personaPanel(
                        topInset: proxy.safeAreaInsets.top,
                        coordinateSpaceName: PersonaScrollSpace.own,
                        availableWidth: max(proxy.size.width - 40, 0)
                    )
                }
                .padding(.bottom, 112)
            }
            .coordinateSpace(name: PersonaScrollSpace.own)
        }
        .background(VisualLanguage.themeGradient)
    }

    private func personaPanel(
        topInset: CGFloat,
        coordinateSpaceName: String,
        availableWidth: CGFloat
    ) -> some View {
        ZStack(alignment: .top) {
            StretchingBackdropSurface(
                assetName: card.backdropAssetName,
                baseHeight: 403,
                topInset: topInset,
                coordinateSpaceName: coordinateSpaceName
            )
            VStack(spacing: 0) {
                Color.clear.frame(height: 203)
                VStack(spacing: 0) {
                    personaCardContent
                    if visibleCreations.isEmpty {
                        EmptyListArtworkView(title: "No works yet")
                            .padding(.top, 20)
                    } else {
                        MasonryCreationGrid(records: visibleCreations, availableWidth: availableWidth) { record in
                            experienceStore.open(.creationDetail(record))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 0)
                    }
                }
                .background {
                    TopRoundedPanelShape(radius: 28)
                        .fill(VisualLanguage.themeGradient)
                }
            }
        }
    }

    private var personaCardContent: some View {
        GeometryReader { proxy in
            Text(accessStore.activeCard == nil ? "Please log in first" : card.displayName)
                .font(TextCraft.source(20, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: 150, alignment: .leading)
                .position(x: 115, y: 77)

            HStack(spacing: 18) {
                Button {
                    if accessStore.needsAccessUpgrade {
                        experienceStore.activeOverlay = .accessGuide
                    } else {
                        experienceStore.open(.audienceRoster)
                    }
                } label: {
                    PersonaMetric(value: audienceMetricText, title: "Followers", valueColor: VisualLanguage.lineGreen)
                }
                .buttonStyle(.plain)
                Button {
                    if accessStore.needsAccessUpgrade {
                        experienceStore.activeOverlay = .accessGuide
                    } else {
                        experienceStore.open(.connectionRoster)
                    }
                } label: {
                    PersonaMetric(value: connectionMetricText, title: "Following", valueColor: Color(red: 0.08, green: 0.57, blue: 1.0))
                }
                .buttonStyle(.plain)
            }
            .frame(width: 180, alignment: .leading)
            .position(x: 130, y: 112)

            HStack(spacing: 12) {
                Button {
                    experienceStore.open(.settings)
                } label: {
                    Image("persona_settings_icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                Button {
                    if accessStore.needsAccessUpgrade {
                        experienceStore.activeOverlay = .accessGuide
                    } else {
                        experienceStore.activeOverlay = .profileEditor
                    }
                } label: {
                    Text("Edit Profile")
                        .font(TextCraft.source(16, weight: .medium))
                        .foregroundColor(VisualLanguage.lime)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(VisualLanguage.charcoal))
                }
                .buttonStyle(.plain)
            }
            .position(x: proxy.size.width - 110, y: 39)

            AvatarBadgeView(assetName: card.avatarAssetName, size: 78)
                .position(x: 79, y: 9)
        }
        .frame(height: 136)
    }
}

private enum PersonaScrollSpace {
    static let own = "persona-canvas-scroll"
    static let publicProfile = "public-persona-canvas-scroll"
}

private struct TopRoundedPanelShape: Shape {
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

private struct StretchingBackdropSurface: View {
    let assetName: String
    let baseHeight: CGFloat
    let topInset: CGFloat
    let coordinateSpaceName: String

    var body: some View {
        GeometryReader { proxy in
            let pullDistance = max(proxy.frame(in: .named(coordinateSpaceName)).minY, 0)
            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: baseHeight + topInset + pullDistance)
                .clipped()
                .offset(y: -topInset - pullDistance)
                .ignoresSafeArea(edges: .top)
        }
        .frame(height: baseHeight)
    }
}

private struct PersonaMetric: View {
    let value: String
    let title: String
    let valueColor: Color

    var body: some View {
        HStack(spacing: 5) {
            Text(value)
                .font(TextCraft.source(14, weight: .medium))
                .foregroundColor(valueColor)
            Text(title)
                .font(TextCraft.source(14))
                .foregroundColor(VisualLanguage.softInk)
        }
    }
}

struct PublicPersonaScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accessStore: AccessSessionStore
    @EnvironmentObject private var experienceStore: ExperienceContainer
    let card: IdentityCardRecord

    private var displayedCard: IdentityCardRecord {
        experienceStore.identityCards.first { $0.stableKey == card.stableKey } ?? card
    }

    private var visibleCreations: [CreationRecord] {
        experienceStore.creations.filter {
            $0.authorKey == displayedCard.stableKey
                || ($0.authorKey.isEmpty && $0.authorName == displayedCard.displayName)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                ScrollView {
                    publicComposition(
                        width: proxy.size.width,
                        minimumHeight: proxy.size.height,
                        topInset: proxy.safeAreaInsets.top,
                        coordinateSpaceName: PersonaScrollSpace.publicProfile
                    )
                }
                .coordinateSpace(name: PersonaScrollSpace.publicProfile)

                TopChromeView(
                    title: "",
                    showsBack: true,
                    trailingAsset: "gallery_navigation_more",
                    backAction: { dismiss() },
                    trailingAction: {
                        experienceStore.presentRestrictionOptions(
                            identityKey: displayedCard.stableKey,
                            fallbackName: displayedCard.displayName,
                            accessStore: accessStore
                        )
                    }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .ignoresSafeArea(edges: .top)
        }
        .background(VisualLanguage.themeGradient)
        .onAppear(perform: redirectOwnProfileIfNeeded)
    }

    private func publicComposition(
        width: CGFloat,
        minimumHeight: CGFloat,
        topInset: CGFloat,
        coordinateSpaceName: String
    ) -> some View {
        let card = displayedCard
        let linked = experienceStore.isLinked(to: card)
        let gridWidth = max(width - 40, 0)
        return ZStack(alignment: .top) {
            StretchingBackdropSurface(
                assetName: publicBackdropAssetName,
                baseHeight: 403,
                topInset: topInset,
                coordinateSpaceName: coordinateSpaceName
            )

            TopRoundedPanelShape(radius: 20)
                .fill(VisualLanguage.themeGradient)
                .frame(maxWidth: .infinity)
                .frame(height: max(minimumHeight, publicContentHeight(width: gridWidth)))
                .padding(.top, 328)

            VStack(spacing: 0) {
                Color.clear.frame(height: 268)

                AvatarBadgeView(assetName: card.avatarAssetName, size: 120)

                Text(card.displayName)
                    .font(TextCraft.source(26, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.top, 6)

                PublicPersonaStatsPanel(
                    workCount: visibleCreations.count,
                    audienceCount: card.audienceCount,
                    connectionCount: card.connectionCount
                )
                .padding(.horizontal, 20)
                .padding(.top, 15)

                HStack(spacing: 15) {
                    CapsuleButton(title: "Chat", foreground: VisualLanguage.lime, fill: VisualLanguage.charcoal) {
                        experienceStore.startDirectExchange(with: card, accessStore: accessStore)
                    }
                    CapsuleButton(
                        title: linked ? "Unfollow" : "Follow",
                        foreground: linked ? .black : VisualLanguage.lime,
                        fill: linked ? Color.white : VisualLanguage.charcoal
                    ) {
                        toggleConnection(to: card)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)

                if visibleCreations.isEmpty {
                    EmptyListArtworkView(title: "No works yet")
                        .padding(.top, 24)
                } else {
                    MasonryCreationGrid(records: visibleCreations, availableWidth: gridWidth) { record in
                        experienceStore.open(.creationDetail(record))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                }
            }
            .padding(.bottom, 32)
        }
        .frame(minHeight: max(minimumHeight + 328, publicContentHeight(width: gridWidth) + 328))
    }

    private var publicBackdropAssetName: String {
        displayedCard.avatarAssetName == "default_avatar" ? "image.png" : displayedCard.avatarAssetName
    }

    private func publicContentHeight(width: CGFloat) -> CGFloat {
        guard visibleCreations.isEmpty == false else { return 560 }
        let placements = CreationCascadeLayout.placements(for: visibleCreations, containerWidth: width)
        return 338 + CreationCascadeLayout.totalHeight(from: placements)
    }

    private func toggleConnection(to card: IdentityCardRecord) {
        guard accessStore.needsAccessUpgrade == false else {
            experienceStore.activeOverlay = .accessGuide
            return
        }
        guard let activeCard = accessStore.activeCard else {
            experienceStore.activeOverlay = .accessGuide
            return
        }
        guard activeCard.stableKey != card.stableKey else {
            experienceStore.showToast("You cannot follow yourself.")
            return
        }
        experienceStore.toggleLink(to: card)
    }

    private func redirectOwnProfileIfNeeded() {
        guard accessStore.activeCard?.stableKey == card.stableKey else { return }
        DispatchQueue.main.async {
            experienceStore.selectedRail = .persona
            experienceStore.activeDestination = nil
        }
    }
}

private struct PublicPersonaStatsPanel: View {
    let workCount: Int
    let audienceCount: Int
    let connectionCount: Int

    var body: some View {
        HStack(spacing: 0) {
            statistic(value: workCount, title: "Works", color: Color(red: 0.22, green: 0.78, blue: 0.10))
            statistic(value: audienceCount, title: "Followers", color: Color(red: 1.0, green: 0.60, blue: 0.0))
            statistic(value: connectionCount, title: "Following", color: Color(red: 0.12, green: 0.55, blue: 1.0))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
    }

    private func statistic(value: Int, title: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(TextCraft.source(20))
                .foregroundColor(color)
            Text(title)
                .font(TextCraft.source(16))
                .foregroundColor(Color(UIColor.darkGray))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CapsuleButton: View {
    let title: String
    let foreground: Color
    let fill: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TextCraft.source(16, weight: .medium))
                .foregroundColor(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Capsule().fill(fill))
        }
        .buttonStyle(.plain)
    }
}

struct MasonryCreationGrid: View {
    let records: [CreationRecord]
    let availableWidth: CGFloat
    let openAction: (CreationRecord) -> Void

    var body: some View {
        let containerWidth = max(availableWidth, 0)
        let placements = CreationCascadeLayout.placements(for: records, containerWidth: containerWidth)
        ZStack(alignment: .topLeading) {
            ForEach(placements) { placement in
                PersonaCreationTile(record: placement.record, height: placement.height) {
                    openAction(placement.record)
                }
                .frame(width: placement.width, height: placement.height)
                .offset(x: placement.x, y: placement.y)
            }
        }
        .frame(width: containerWidth, height: CreationCascadeLayout.totalHeight(from: placements), alignment: .topLeading)
    }
}

private struct PersonaCreationTile: View {
    let record: CreationRecord
    let height: CGFloat
    let openAction: () -> Void

    var body: some View {
        Button(action: openAction) {
            ZStack {
                Image(record.coverAssetName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                if record.mediaKind == .video {
                    Image("persona_media_play_icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                }
            }
            .frame(height: height)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

private struct CreationCascadePlacement: Identifiable {
    let id: String
    let record: CreationRecord
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
}

private enum CreationCascadeLayout {
    static func placements(for records: [CreationRecord], containerWidth: CGFloat) -> [CreationCascadePlacement] {
        let spacing: CGFloat = 15
        let columnWidth = floor((containerWidth - spacing) / 2)
        var leftHeight: CGFloat = 0
        var rightHeight: CGFloat = 0
        var result: [CreationCascadePlacement] = []

        for record in records {
            let height = measuredHeight(for: record.coverAssetName, width: columnWidth)
            let shouldUseLeft = leftHeight <= rightHeight
            let x = shouldUseLeft ? CGFloat(0) : columnWidth + spacing
            let y = shouldUseLeft ? leftHeight : rightHeight
            result.append(
                CreationCascadePlacement(
                    id: record.id,
                    record: record,
                    x: x,
                    y: y,
                    width: columnWidth,
                    height: height
                )
            )

            if shouldUseLeft {
                leftHeight += height + spacing
            } else {
                rightHeight += height + spacing
            }
        }

        return result
    }

    static func totalHeight(from placements: [CreationCascadePlacement]) -> CGFloat {
        placements.map { $0.y + $0.height }.max() ?? 0
    }

    private static func measuredHeight(for assetName: String, width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        guard let size = UIImage(named: assetName)?.size, size.width > 0 else {
            return width * 1.25
        }
        return width * size.height / size.width
    }
}

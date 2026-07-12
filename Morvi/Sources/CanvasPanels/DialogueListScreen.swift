import SwiftUI

struct DialogueListScreen: View {
    @EnvironmentObject private var accessStore: AccessSessionStore
    @EnvironmentObject private var experienceStore: ExperienceContainer

    var body: some View {
        let orderedThreads = experienceStore.dialogueThreads.sorted {
            if $0.updatedAt == $1.updatedAt {
                return $0.stableKey > $1.stableKey
            }
            return $0.updatedAt > $1.updatedAt
        }

        VStack(spacing: 0) {
            TopChromeView(title: "Chat")
            ScrollView(.vertical, showsIndicators: false) {
                if orderedThreads.isEmpty {
                    EmptyListArtworkView(title: "No chats yet")
                        .frame(maxWidth: .infinity, minHeight: 360)
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 11),
                            GridItem(.flexible(), spacing: 11)
                        ],
                        spacing: 11
                    ) {
                        ForEach(Array(orderedThreads.enumerated()), id: \.element.stableKey) { index, thread in
                            Button {
                                experienceStore.openExistingDialogue(thread, accessStore: accessStore)
                            } label: {
                                DialogueSummaryCard(
                                    thread: thread,
                                    usesDarkStyle: index % 3 != 0
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 104)
                }
            }
        }
        .background(AmbientBackdrop())
        .onAppear {
            experienceStore.refreshDialogues(accountKey: accessStore.activeCard?.stableKey)
        }
        .onChange(of: accessStore.activeCard?.stableKey) { key in
            experienceStore.refreshDialogues(accountKey: key)
        }
    }
}

private struct DialogueSummaryCard: View {
    let thread: DialogueThreadRecord
    let usesDarkStyle: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(usesDarkStyle ? Color(red: 0.04, green: 0.05, blue: 0.04) : .white)
                .shadow(color: .black.opacity(0.08), radius: 9, x: 0, y: 4)

            AvatarBadgeView(assetName: thread.avatarAssetName, size: 44)
                .padding(.leading, 16)
                .padding(.top, 18)

            Text(thread.title)
                .font(TextCraft.source(17))
                .foregroundColor(usesDarkStyle ? .white : .black)
                .lineLimit(1)
                .padding(.leading, 64)
                .padding(.trailing, 12)
                .padding(.top, 31)

            Text(thread.latestPreview)
                .font(TextCraft.source(15))
                .foregroundColor(usesDarkStyle ? .white : Color.darkGray)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 16)
                .padding(.top, 74)

            Image(usesDarkStyle ? "dialogue_card_action_light" : "dialogue_card_action_dark")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 16)
                .padding(.bottom, 16)
        }
        .frame(height: 198)
    }
}

private extension Color {
    static let darkGray = Color(red: 0.33, green: 0.33, blue: 0.33)
}

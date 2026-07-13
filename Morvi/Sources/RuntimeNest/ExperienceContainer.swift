import Combine
import Foundation

struct SafetyConcernRecord: Hashable, Identifiable {
    let stableKey: String
    let targetIdentityKey: String
    let reasonText: String
    let createdAt: Date

    var id: String { stableKey }
}

final class ExperienceContainer: ObservableObject {
    @Published var selectedRail: RailSection = .home
    @Published var path: [CanvasDestination] = []
    @Published var activeDestination: CanvasDestination?
    @Published var activeOverlay: OverlaySheetKind?
    @Published var showsAccessFlow = false
    @Published var toastText: String?
    @Published var showsProgress = false

    @Published var creditBalance: Int
    @Published var identityCards: [IdentityCardRecord]
    @Published var creations: [CreationRecord]
    @Published var creationReplyGroups: [String: [CreationReplyRecord]]
    @Published var feelings: [FeelingRecord]
    @Published var dialogueThreads: [DialogueThreadRecord]
    @Published var directLines: [DialogueLineRecord]
    @Published var directLineGroups: [String: [DialogueLineRecord]]
    @Published var assistantLines: [DialogueLineRecord]
    @Published var hasShownFeelingSummaryAnimation = false
    @Published var linkedCardKeys: Set<String> = []
    @Published var restrictedCardKeys: Set<String> = []
    @Published var appreciatedCreationKeys: Set<String> = []
    @Published var safetyConcernRecords: [SafetyConcernRecord] = []
    @Published var focusedIdentityCard: IdentityCardRecord? = nil

    let feelingOptions: [FeelingOption]
    let creditCatalog: [CreditPackRecord]
    private let threadArchive = ThreadArchive.shared
    private let creationArchive = CreationArchive.shared
    private let storedValueLedger = StoredValueLedger.shared
    private var dialogueAccountKey = "preview-account"

    var audienceTotalForActiveIdentity: Int {
        Array(identityCards.dropFirst().prefix(3)).count
    }

    var connectionTotalForActiveIdentity: Int {
        linkedCardKeys.count
    }

    init(snapshot: LocalSnapshotVault = .preview) {
        CreationArchive.shared.seedIfNeeded(records: snapshot.creations, replyGroups: snapshot.creationReplyGroups)
        let storedCreations = CreationArchive.shared.records()
        let storedReplyGroups = CreationArchive.shared.replyGroups()
        creditBalance = snapshot.creditBalance
        identityCards = snapshot.identityCards
        creations = storedCreations.isEmpty ? snapshot.creations : storedCreations
        creationReplyGroups = storedReplyGroups.isEmpty ? snapshot.creationReplyGroups : storedReplyGroups
        feelings = snapshot.feelings
        dialogueThreads = snapshot.dialogueThreads
        directLines = snapshot.directLines
        directLineGroups = Dictionary(uniqueKeysWithValues: snapshot.dialogueThreads.enumerated().map { index, thread in
            if index == 0 {
                return (thread.stableKey, snapshot.directLines)
            }
            return (thread.stableKey, [
                DialogueLineRecord.textLine(
                    content: thread.latestPreview,
                    side: .other,
                    avatarAssetName: thread.avatarAssetName,
                    occurredAt: thread.updatedAt
                )
            ])
        })
        assistantLines = snapshot.assistantLines
        feelingOptions = snapshot.feelingOptions
        creditCatalog = snapshot.creditCatalog
        linkedCardKeys = Set(snapshot.dialogueThreads.compactMap(\.counterpartStableKey))
        restrictedCardKeys = Set(snapshot.identityCards.dropFirst().suffix(1).map(\.stableKey))
        appreciatedCreationKeys = CreationArchive.shared.appreciatedKeys(accountKey: "preview-account")
        seedPreviewThreads(snapshot)
    }

    private func seedPreviewThreads(_ snapshot: LocalSnapshotVault) {
        guard threadArchive.summaries(accountKey: "preview-account").isEmpty else { return }
        for thread in snapshot.dialogueThreads {
            _ = threadArchive.persist(
                lines: snapshot.directLines,
                summary: thread,
                accountKey: "preview-account",
                replacingAssistantPending: false
            )
        }
    }

    func refreshDialogues(accountKey: String?) {
        let resolvedKey = accountKey ?? "preview-account"
        dialogueAccountKey = resolvedKey
        let storedThreads = threadArchive.summaries(accountKey: resolvedKey).map(normalizedDialogueThread)
        guard storedThreads.isEmpty == false else {
            if resolvedKey != "preview-account" {
                dialogueThreads = []
                directLines = []
                directLineGroups = [:]
            }
            return
        }

        dialogueThreads = storedThreads
        directLineGroups = Dictionary(uniqueKeysWithValues: storedThreads.map { thread in
            (thread.stableKey, threadArchive.lines(accountKey: resolvedKey, threadKey: thread.stableKey))
        })
        directLines = directLineGroups[storedThreads.first?.stableKey ?? ""] ?? []
    }

    func refreshAssistantDialogue(accountKey: String?) {
        guard let accountKey else {
            assistantLines = []
            return
        }
        dialogueAccountKey = accountKey
        guard let summary = threadArchive.assistantSummary(accountKey: accountKey) else {
            assistantLines = []
            return
        }
        assistantLines = threadArchive.lines(accountKey: accountKey, threadKey: summary.stableKey).filter { $0.isPending == false }
    }

    func shouldRevealAssistantIntro(accountKey: String?) -> Bool {
        guard let accountKey, assistantLines.isEmpty else { return false }
        return UserDefaults.standard.bool(forKey: assistantIntroFlagKey(accountKey)) == false
    }

    func markAssistantIntroRevealed(accountKey: String?) {
        guard let accountKey else { return }
        UserDefaults.standard.set(true, forKey: assistantIntroFlagKey(accountKey))
    }

    private func assistantIntroFlagKey(_ accountKey: String) -> String {
        "morvi.assistant.intro.revealed.\(accountKey)"
    }

    func open(_ destination: CanvasDestination) {
        activeDestination = destination
    }

    func closeOverlay() {
        activeOverlay = nil
    }

    func resetForAccessEntry() {
        selectedRail = .home
        path = []
        activeDestination = nil
        activeOverlay = nil
        showsAccessFlow = false
        showsProgress = false
    }

    func showToast(_ text: String) {
        toastText = text
    }

    func revealProgressThenStart(_ work: @escaping () -> Void) {
        showsProgress = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    func identityCard(named name: String) -> IdentityCardRecord? {
        identityCards.first { $0.displayName == name }
    }

    func identityCard(stableKey: String, fallbackName: String? = nil) -> IdentityCardRecord? {
        identityCards.first { $0.stableKey == stableKey }
            ?? fallbackName.flatMap { identityCard(named: $0) }
    }

    func refreshActiveIdentityDisplay(_ card: IdentityCardRecord) {
        if identityCards.contains(where: { $0.stableKey == card.stableKey }) {
            identityCards = identityCards.map { existing in
                guard existing.stableKey == card.stableKey else { return existing }
                return IdentityCardRecord(
                    stableKey: existing.stableKey,
                    displayName: card.displayName,
                    avatarAssetName: card.avatarAssetName,
                    backdropAssetName: existing.backdropAssetName,
                    note: existing.note,
                    audienceCount: existing.audienceCount,
                    connectionCount: existing.connectionCount
                )
            }
        } else {
            identityCards.append(card)
        }

        creations = creations.map { record in
            guard record.authorKey == card.stableKey else { return record }
            return CreationRecord(
                stableKey: record.stableKey,
                title: record.title,
                bodyText: record.bodyText,
                authorKey: record.authorKey,
                authorName: card.displayName,
                avatarAssetName: card.avatarAssetName,
                coverAssetName: record.coverAssetName,
                tags: record.tags,
                mediaKind: record.mediaKind,
                appreciationCount: record.appreciationCount,
                replyCount: record.replyCount
            )
        }

        creationReplyGroups = creationReplyGroups.mapValues { records in
            records.map { record in
                guard record.authorKey == card.stableKey else { return record }
                return CreationReplyRecord(
                    stableKey: record.stableKey,
                    authorKey: record.authorKey,
                    authorName: card.displayName,
                    avatarAssetName: card.avatarAssetName,
                    bodyText: record.bodyText,
                    occurredAt: record.occurredAt
                )
            }
        }

        feelings = feelings.map { record in
            FeelingRecord(
                stableKey: record.stableKey,
                title: record.title,
                bodyText: record.bodyText,
                assetName: record.assetName,
                accentKind: record.accentKind,
                recordedAt: record.recordedAt,
                ownerAvatarAssetName: card.avatarAssetName
            )
        }

        dialogueThreads = dialogueThreads.map { thread in
            guard thread.counterpartStableKey == card.stableKey else { return thread }
            return DialogueThreadRecord(
                stableKey: thread.stableKey,
                kind: thread.kind,
                counterpartStableKey: thread.counterpartStableKey,
                title: card.displayName,
                avatarAssetName: card.avatarAssetName,
                latestPreview: thread.latestPreview,
                updatedAt: thread.updatedAt
            )
        }

        directLineGroups = directLineGroups.mapValues { records in
            records.map { refreshLineDisplay($0, card: card) }
        }
        directLines = directLines.map { refreshLineDisplay($0, card: card) }
        assistantLines = assistantLines.map { refreshLineDisplay($0, card: card) }
    }

    private func refreshLineDisplay(_ record: DialogueLineRecord, card: IdentityCardRecord) -> DialogueLineRecord {
        guard record.authorStableKey == card.stableKey || record.side == .mine else { return record }
        return DialogueLineRecord(
            stableKey: record.stableKey,
            side: record.side,
            kind: record.kind,
            avatarAssetName: card.avatarAssetName,
            occurredAt: record.occurredAt,
            authorStableKey: record.authorStableKey,
            mediaWidth: record.mediaWidth,
            mediaHeight: record.mediaHeight,
            isPending: record.isPending
        )
    }

    func presentRestrictionOptions(
        identityKey: String,
        fallbackName: String? = nil,
        accessStore: AccessSessionStore
    ) {
        guard accessStore.needsAccessUpgrade == false else {
            activeOverlay = .accessGuide
            return
        }
        focusedIdentityCard = identityCard(stableKey: identityKey, fallbackName: fallbackName)
        activeOverlay = .reportRestrict
    }

    func restrictFocusedIdentity(accessStore: AccessSessionStore) {
        guard let card = focusedIdentityCard else {
            closeOverlay()
            return
        }
        guard accessStore.activeCard?.stableKey != card.stableKey else {
            showToast("You can't block yourself.")
            closeOverlay()
            return
        }
        restrictedCardKeys.insert(card.stableKey)
        showToast("Blocked")
        closeOverlay()
    }

    func presentRestrictionConfirmation(accessStore: AccessSessionStore) {
        guard let card = focusedIdentityCard else {
            closeOverlay()
            return
        }
        guard accessStore.needsAccessUpgrade == false else {
            activeOverlay = .accessGuide
            return
        }
        guard accessStore.activeCard?.stableKey != card.stableKey else {
            showToast("You can't block yourself.")
            return
        }
        activeOverlay = .restrictionConfirm
    }

    func isLinked(to card: IdentityCardRecord) -> Bool {
        linkedCardKeys.contains(card.stableKey)
    }

    func toggleLink(to card: IdentityCardRecord) {
        if linkedCardKeys.contains(card.stableKey) {
            linkedCardKeys.remove(card.stableKey)
            adjustAudienceCount(for: card.stableKey, delta: -1)
            showToast("Unfollowed")
        } else {
            linkedCardKeys.insert(card.stableKey)
            adjustAudienceCount(for: card.stableKey, delta: 1)
            showToast("Followed")
        }
    }

    func removeRestriction(for card: IdentityCardRecord) {
        restrictedCardKeys.remove(card.stableKey)
        showToast("Removed from blacklist.")
    }

    func startDirectExchange(with card: IdentityCardRecord, accessStore: AccessSessionStore) {
        guard accessStore.needsAccessUpgrade == false else {
            activeOverlay = .accessGuide
            return
        }
        guard let activeCard = accessStore.activeCard else {
            activeOverlay = .accessGuide
            return
        }
        guard activeCard.stableKey != card.stableKey else {
            selectedRail = .persona
            activeDestination = nil
            return
        }
        guard restrictedCardKeys.contains(card.stableKey) == false else {
            showToast("This profile is unavailable")
            return
        }
        refreshDialogues(accountKey: activeCard.stableKey)
        dialogueAccountKey = activeCard.stableKey
        if let existing = dialogueThreads.first(where: { $0.counterpartStableKey == card.stableKey }) {
            open(.directDialogue(existing))
            return
        }
        guard linkedCardKeys.contains(card.stableKey) else {
            showToast("You need to follow each other first.")
            return
        }
        guard let thread = createDialogueThread(for: card, activeCard: activeCard) else {
            showToast("Conversation could not be created")
            return
        }
        open(.directDialogue(thread))
    }

    func openExistingDialogue(_ thread: DialogueThreadRecord, accessStore: AccessSessionStore) {
        guard accessStore.needsAccessUpgrade == false else {
            activeOverlay = .accessGuide
            return
        }
        guard let activeCard = accessStore.activeCard else {
            activeOverlay = .accessGuide
            return
        }
        guard let counterpartKey = thread.counterpartStableKey else {
            showToast("This conversation is unavailable")
            return
        }
        guard counterpartKey != activeCard.stableKey else {
            selectedRail = .persona
            activeDestination = nil
            return
        }
        guard restrictedCardKeys.contains(counterpartKey) == false else {
            showToast("This profile is unavailable")
            return
        }
        dialogueAccountKey = activeCard.stableKey
        directLines = directLineGroups[thread.stableKey] ?? []
        open(.directDialogue(thread))
    }

    func publishCreation(title: String, bodyText: String, themes: [String], owner: IdentityCardRecord?) {
        guard let owner else {
            activeOverlay = .accessGuide
            return
        }
        let coverAssetName = owner.backdropAssetName == "image.png" ? "builtin_video_cover_amelia" : owner.backdropAssetName
        let record = CreationRecord(
            stableKey: UUID().uuidString,
            title: title,
            bodyText: bodyText,
            authorKey: owner.stableKey,
            authorName: owner.displayName,
            avatarAssetName: owner.avatarAssetName,
            coverAssetName: coverAssetName,
            tags: themes,
            mediaKind: .photo,
            appreciationCount: 0,
            replyCount: 0
        )
        revealProgressThenStart {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                guard self.creationArchive.save(record) else {
                    self.showsProgress = false
                    self.showToast("Upload failed")
                    return
                }
                self.identityCards.removeAll { $0.stableKey == owner.stableKey }
                self.identityCards.append(owner)
                self.creations.insert(record, at: 0)
                self.creationReplyGroups[record.stableKey] = []
                self.showsProgress = false
                self.activeOverlay = nil
                self.showToast("Uploaded successfully")
            }
        }
    }

    func refreshedCreation(for record: CreationRecord) -> CreationRecord {
        creations.first { $0.stableKey == record.stableKey } ?? record
    }

    func replies(for record: CreationRecord) -> [CreationReplyRecord] {
        creationReplyGroups[record.stableKey] ?? []
    }

    func refreshCreationState(accountKey: String?) {
        guard let accountKey else {
            appreciatedCreationKeys = []
            return
        }
        appreciatedCreationKeys = creationArchive.appreciatedKeys(accountKey: accountKey)
    }

    func appendCreationReply(
        _ text: String,
        to record: CreationRecord,
        author: IdentityCardRecord?,
        completion: @escaping (Bool) -> Void
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            completion(false)
            return
        }
        guard let author else {
            activeOverlay = .accessGuide
            completion(false)
            return
        }
        revealProgressThenStart {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                let reply = CreationReplyRecord(
                    stableKey: UUID().uuidString,
                    authorKey: author.stableKey,
                    authorName: author.displayName,
                    avatarAssetName: author.avatarAssetName,
                    bodyText: trimmed
                )
                let sourceRecord = self.refreshedCreation(for: record)
                let updatedRecord = CreationRecord(
                    stableKey: sourceRecord.stableKey,
                    title: sourceRecord.title,
                    bodyText: sourceRecord.bodyText,
                    authorKey: sourceRecord.authorKey,
                    authorName: sourceRecord.authorName,
                    avatarAssetName: sourceRecord.avatarAssetName,
                    coverAssetName: sourceRecord.coverAssetName,
                    tags: sourceRecord.tags,
                    mediaKind: sourceRecord.mediaKind,
                    appreciationCount: sourceRecord.appreciationCount,
                    replyCount: sourceRecord.replyCount + 1
                )
                guard self.creationArchive.append(reply, creationKey: record.stableKey, updating: updatedRecord) else {
                    self.showsProgress = false
                    self.showToast("Operation failed")
                    completion(false)
                    return
                }
                self.creationReplyGroups[record.stableKey, default: []].append(reply)
                self.creations = self.creations.map { $0.stableKey == record.stableKey ? updatedRecord : $0 }
                self.showsProgress = false
                completion(true)
            }
        }
    }

    func isCreationAppreciated(_ record: CreationRecord) -> Bool {
        appreciatedCreationKeys.contains(record.stableKey)
    }

    func toggleCreationAppreciation(_ record: CreationRecord, accountKey: String?) {
        guard let accountKey else {
            activeOverlay = .accessGuide
            return
        }
        let wasSelected = appreciatedCreationKeys.contains(record.stableKey)
        let sourceRecord = refreshedCreation(for: record)
        let updatedRecord = CreationRecord(
            stableKey: sourceRecord.stableKey,
            title: sourceRecord.title,
            bodyText: sourceRecord.bodyText,
            authorKey: sourceRecord.authorKey,
            authorName: sourceRecord.authorName,
            avatarAssetName: sourceRecord.avatarAssetName,
            coverAssetName: sourceRecord.coverAssetName,
            tags: sourceRecord.tags,
            mediaKind: sourceRecord.mediaKind,
            appreciationCount: max(sourceRecord.appreciationCount + (wasSelected ? -1 : 1), 0),
            replyCount: sourceRecord.replyCount
        )
        guard creationArchive.setAppreciated(
            wasSelected == false,
            creationKey: record.stableKey,
            accountKey: accountKey,
            updating: updatedRecord
        ) else {
            showToast("Operation failed")
            return
        }
        if wasSelected {
            appreciatedCreationKeys.remove(record.stableKey)
        } else {
            appreciatedCreationKeys.insert(record.stableKey)
        }
        creations = creations.map { $0.stableKey == record.stableKey ? updatedRecord : $0 }
    }

    func submitSafetyConcern(reason: String) {
        guard let targetIdentityKey = focusedIdentityCard?.stableKey else {
            showToast("Action unavailable")
            closeOverlay()
            return
        }
        safetyConcernRecords.insert(
            SafetyConcernRecord(
                stableKey: UUID().uuidString,
                targetIdentityKey: targetIdentityKey,
                reasonText: reason,
                createdAt: Date()
            ),
            at: 0
        )
        revealProgressThenStart {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                self.showsProgress = false
                self.activeOverlay = nil
                self.showToast("Reported")
            }
        }
    }

    func publishFeeling(option: FeelingOption, text: String, owner: IdentityCardRecord?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            showToast("Please enter your feelings")
            return
        }
        let record = FeelingRecord(
            stableKey: UUID().uuidString,
            title: option.title,
            bodyText: trimmed,
            assetName: option.assetName,
            accentKind: feelings.count.isMultiple(of: 2) ? .fresh : .calm,
            recordedAt: Date(),
            ownerAvatarAssetName: owner?.avatarAssetName ?? "default_avatar"
        )
        feelings.insert(record, at: 0)
        activeOverlay = nil
        showToast("Uploaded successfully")
    }

    func spendForAssistant(accessStore: AccessSessionStore) {
        guard accessStore.needsAccessUpgrade == false else {
            activeOverlay = .accessGuide
            return
        }
        guard accessStore.canUseStoredValue else {
            showToast("Please choose another login method to purchase")
            return
        }
        refreshCreditBalance(for: accessStore)
        activeOverlay = .spendConfirm
    }

    func confirmAssistantSpend(accessStore: AccessSessionStore) {
        activeOverlay = nil
        revealProgressThenStart {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                self.showsProgress = false
                guard accessStore.needsAccessUpgrade == false else {
                    self.activeOverlay = .accessGuide
                    return
                }
                guard let activeCard = accessStore.activeCard else {
                    self.activeOverlay = .accessGuide
                    return
                }
                guard self.storedValueLedger.consume(200, for: activeCard.stableKey) else {
                    self.creditBalance = self.storedValueLedger.balance(for: activeCard.stableKey)
                    self.activeOverlay = .creditShortage
                    return
                }
                self.creditBalance = self.storedValueLedger.balance(for: activeCard.stableKey)
                self.open(.assistantDialogue)
            }
        }
    }

    func refreshCreditBalance(for accessStore: AccessSessionStore) {
        guard let activeCard = accessStore.activeCard else {
            creditBalance = 0
            return
        }
        creditBalance = storedValueLedger.balance(for: activeCard.stableKey)
    }

    func acquireStoredValue(_ pack: CreditPackRecord, accessStore: AccessSessionStore) {
        guard accessStore.needsAccessUpgrade == false else {
            activeOverlay = .accessGuide
            return
        }
        guard accessStore.canUseStoredValue else {
            showToast("Please choose another login method to purchase")
            return
        }
        guard let activeCard = accessStore.activeCard else {
            activeOverlay = .accessGuide
            return
        }

        let startDate = Date()
        revealProgressThenStart {
            Task {
                let outcome = await StorefrontAcquisitionGateway.shared.acquire(pack)
                let elapsed = Date().timeIntervalSince(startDate)
                let remainingDelay = max(0.5 - elapsed, 0)
                DispatchQueue.main.asyncAfter(deadline: .now() + remainingDelay) {
                    self.resolveStoredValueAcquisition(outcome, activeCard: activeCard)
                }
            }
        }
    }

    private func resolveStoredValueAcquisition(
        _ outcome: StoredValueAcquisitionResult,
        activeCard: IdentityCardRecord
    ) {
        showsProgress = false
        switch outcome {
        case .completed(let amount):
            creditBalance = storedValueLedger.add(amount, for: activeCard.stableKey)
            showToast("Purchase successful")
        case .cancelled:
            showToast("Purchase canceled")
        case .pending:
            showToast("Purchase pending")
        case .unavailable:
            showToast("Purchase unavailable")
        case .failed:
            showToast("Purchase failed")
        }
    }

    func lines(for thread: DialogueThreadRecord) -> [DialogueLineRecord] {
        directLineGroups[thread.stableKey] ?? directLines
    }

    @discardableResult
    func appendDirectText(_ text: String, thread: DialogueThreadRecord, author: IdentityCardRecord?) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, let author else { return false }
        let line = DialogueLineRecord.textLine(
            content: trimmed,
            side: .mine,
            avatarAssetName: author.avatarAssetName,
            occurredAt: Date()
        )
        var authoredLine = line
        authoredLine.authorStableKey = author.stableKey
        return appendDirectLine(authoredLine, thread: thread)
    }

    @discardableResult
    func appendDirectPhoto(
        assetName: String,
        size: CGSize,
        thread: DialogueThreadRecord,
        author: IdentityCardRecord?
    ) -> Bool {
        guard let author else { return false }
        let line = DialogueLineRecord(
            stableKey: UUID().uuidString,
            side: .mine,
            kind: .photo(assetName),
            avatarAssetName: author.avatarAssetName,
            occurredAt: Date(),
            authorStableKey: author.stableKey,
            mediaWidth: Double(size.width),
            mediaHeight: Double(size.height)
        )
        return appendDirectLine(line, thread: thread)
    }

    @discardableResult
    func appendDirectAudio(
        duration: Int,
        assetName: String?,
        thread: DialogueThreadRecord,
        author: IdentityCardRecord?
    ) -> Bool {
        guard let author else { return false }
        let line = DialogueLineRecord(
            stableKey: UUID().uuidString,
            side: .mine,
            kind: .audio(duration, assetName),
            avatarAssetName: author.avatarAssetName,
            occurredAt: Date(),
            authorStableKey: author.stableKey
        )
        return appendDirectLine(line, thread: thread)
    }

    private func appendDirectLine(_ line: DialogueLineRecord, thread: DialogueThreadRecord) -> Bool {
        let refreshedThreads = dialogueThreads.updatedPreviewLine(line.previewText, stableKey: thread.stableKey)
        guard let refreshedThread = refreshedThreads.first(where: { $0.stableKey == thread.stableKey }),
              threadArchive.persist(
                lines: [line],
                summary: refreshedThread,
                accountKey: dialogueAccountKey
              ) else {
            showToast("Send failed")
            return false
        }
        directLineGroups[thread.stableKey, default: []].append(line)
        directLines = directLineGroups[thread.stableKey] ?? []
        dialogueThreads = refreshedThreads
        return true
    }

    @discardableResult
    func appendAssistantText(_ text: String, author: IdentityCardRecord?) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, let author else { return false }
        let now = Date()
        let threadKey = "assistant-\(author.stableKey)"
        let responseText = threadArchive.randomAssistantPhrase()
        let localLine = DialogueLineRecord(
            stableKey: UUID().uuidString,
            side: .mine,
            kind: .text(trimmed),
            avatarAssetName: author.avatarAssetName,
            occurredAt: now,
            authorStableKey: author.stableKey
        )
        let responseLine = DialogueLineRecord(
            stableKey: UUID().uuidString,
            side: .other,
            kind: .text(responseText),
            avatarAssetName: "assistant_intro_card_background",
            occurredAt: now.addingTimeInterval(0.001)
        )
        let summary = DialogueThreadRecord(
            stableKey: threadKey,
            kind: .assistant,
            counterpartStableKey: nil,
            title: "Recot Bot",
            avatarAssetName: "assistant_intro_card_background",
            latestPreview: responseText,
            updatedAt: now
        )
        guard threadArchive.persist(
            lines: [localLine, responseLine],
            summary: summary,
            accountKey: author.stableKey,
            replacingAssistantPending: true
        ) else {
            showToast("Send failed")
            return false
        }
        assistantLines.removeAll { $0.isPending }
        assistantLines.append(contentsOf: [localLine, responseLine])
        return true
    }

    private func createDialogueThread(
        for card: IdentityCardRecord,
        activeCard: IdentityCardRecord
    ) -> DialogueThreadRecord? {
        let pair = [activeCard.stableKey, card.stableKey].sorted().joined(separator: "-")
        let record = DialogueThreadRecord(
            stableKey: "direct-\(pair)",
            kind: .direct,
            counterpartStableKey: card.stableKey,
            title: card.displayName,
            avatarAssetName: card.avatarAssetName,
            latestPreview: "",
            updatedAt: Date()
        )
        guard threadArchive.persist(lines: [], summary: record, accountKey: activeCard.stableKey) else {
            return nil
        }
        dialogueThreads.insert(record, at: 0)
        directLineGroups[record.stableKey] = []
        return record
    }

    private func normalizedDialogueThread(_ thread: DialogueThreadRecord) -> DialogueThreadRecord {
        guard thread.counterpartStableKey == nil,
              let card = identityCard(named: thread.title) else {
            return thread
        }
        let normalized = DialogueThreadRecord(
            stableKey: thread.stableKey,
            kind: thread.kind,
            counterpartStableKey: card.stableKey,
            title: thread.title,
            avatarAssetName: thread.avatarAssetName,
            latestPreview: thread.latestPreview,
            updatedAt: thread.updatedAt
        )
        _ = threadArchive.save(normalized, accountKey: dialogueAccountKey)
        return normalized
    }

    private func adjustAudienceCount(for stableKey: String, delta: Int) {
        identityCards = identityCards.map { card in
            guard card.stableKey == stableKey else { return card }
            return IdentityCardRecord(
                stableKey: card.stableKey,
                displayName: card.displayName,
                avatarAssetName: card.avatarAssetName,
                backdropAssetName: card.backdropAssetName,
                note: card.note,
                audienceCount: max(card.audienceCount + delta, 0),
                connectionCount: card.connectionCount
            )
        }
    }
}

import Foundation

final class LocalSeedLoader {
    private let store: LocalStore
    private let accountRepository: AccountProfileRepository
    private let workRepository: CreativeWorkRepository
    private let moodRepository: MoodEntryRepository
    private let dialogueRepository: DialogueRepository
    private let walletRepository: WalletRepository

    init(
        store: LocalStore = .shared,
        accountRepository: AccountProfileRepository = SQLiteAccountProfileRepository(),
        workRepository: CreativeWorkRepository = SQLiteCreativeWorkRepository(),
        moodRepository: MoodEntryRepository = SQLiteMoodEntryRepository(),
        dialogueRepository: DialogueRepository = SQLiteDialogueRepository(),
        walletRepository: WalletRepository = SQLiteWalletRepository()
    ) {
        self.store = store
        self.accountRepository = accountRepository
        self.workRepository = workRepository
        self.moodRepository = moodRepository
        self.dialogueRepository = dialogueRepository
        self.walletRepository = walletRepository
    }

    func seedIfNeeded() throws {
        guard try accountRepository.count() == 0 else { return }
        try seedCatalog()
        try seedAccounts()
        try seedRelations()
        try seedWorks()
        try seedMoodEntries()
        try seedDialogues()
        try seedWallet()
    }

    private func seedCatalog() throws {
        let themes = ["Travel", "Food", "Family", "Friends", "Lifestyle"]
        for (index, title) in themes.enumerated() {
            try store.write(
                """
                INSERT OR IGNORE INTO theme_catalog (title, sort_order)
                VALUES (?, ?);
                """,
                bindings: [.text(title), .int(index)]
            )
        }
    }

    private func seedAccounts() throws {
        let now = LocalDateText.now()
        let accounts = [
            AccountProfileRecord(
                stableKey: "acct-local-amelia",
                email: "amelia@morvi.local",
                displayName: "Amelia",
                genderCode: nil,
                birthDate: nil,
                locationText: nil,
                avatarAsset: "avatar_person",
                coverAsset: "gallery_cover",
                registrationState: 1,
                createdAt: now,
                updatedAt: now
            ),
            AccountProfileRecord(
                stableKey: "acct-local-victoria",
                email: nil,
                displayName: "Victoria",
                genderCode: nil,
                birthDate: nil,
                locationText: nil,
                avatarAsset: "avatar_person",
                coverAsset: "gallery_cover",
                registrationState: 1,
                createdAt: now,
                updatedAt: now
            ),
            AccountProfileRecord(
                stableKey: "acct-local-rowan",
                email: nil,
                displayName: "Rowan",
                genderCode: nil,
                birthDate: nil,
                locationText: nil,
                avatarAsset: "avatar_person",
                coverAsset: "gallery_cover",
                registrationState: 1,
                createdAt: now,
                updatedAt: now
            ),
            AccountProfileRecord(
                stableKey: "acct-local-sophia",
                email: nil,
                displayName: "Sophia",
                genderCode: nil,
                birthDate: nil,
                locationText: nil,
                avatarAsset: "avatar_person",
                coverAsset: "gallery_cover",
                registrationState: 1,
                createdAt: now,
                updatedAt: now
            ),
            AccountProfileRecord(
                stableKey: "acct-local-jasper",
                email: nil,
                displayName: "Jasper",
                genderCode: nil,
                birthDate: nil,
                locationText: nil,
                avatarAsset: "avatar_person",
                coverAsset: "gallery_cover",
                registrationState: 1,
                createdAt: now,
                updatedAt: now
            )
        ]
        try accounts.forEach { try accountRepository.save($0) }
    }

    private func seedRelations() throws {
        let now = LocalDateText.now()
        for targetKey in ["acct-local-victoria", "acct-local-rowan", "acct-local-sophia"] {
            try store.write(
                """
                INSERT OR IGNORE INTO account_relation (origin_account_key, target_account_key, created_at)
                VALUES (?, ?, ?);
                """,
                bindings: [.text("acct-local-amelia"), .text(targetKey), .text(now)]
            )
        }
    }

    private func seedWorks() throws {
        let now = LocalDateText.now()
        let works = [
            CreativeWorkRecord(
                stableKey: "work-local-001",
                ownerAccountKey: "acct-local-victoria",
                title: "Moments Matter",
                bodyText: "Capturing today's happiness. Saving it for tomorrow's memories.",
                mediaKind: 1,
                mediaAsset: "gallery_cover",
                coverAsset: "gallery_cover",
                mediaWidth: 702,
                mediaHeight: 936,
                durationSeconds: 12,
                visibilityCode: 0,
                createdAt: now,
                updatedAt: now
            ),
            CreativeWorkRecord(
                stableKey: "work-local-002",
                ownerAccountKey: "acct-local-amelia",
                title: "Save your feelings",
                bodyText: "Did everything go smoothly today?",
                mediaKind: 0,
                mediaAsset: nil,
                coverAsset: "avatar_person",
                mediaWidth: 702,
                mediaHeight: 936,
                durationSeconds: nil,
                visibilityCode: 0,
                createdAt: now,
                updatedAt: now
            )
        ]
        try works.forEach { try workRepository.save($0) }
    }

    private func seedMoodEntries() throws {
        let now = LocalDateText.now()
        let entries = [
            MoodEntryRecord(
                stableKey: "mood-local-001",
                accountKey: "acct-local-amelia",
                moodCode: 0,
                moodAsset: "mood_happy",
                bodyText: "A little sunshine came today!",
                toneCode: 1,
                recordedAt: now,
                updatedAt: now
            ),
            MoodEntryRecord(
                stableKey: "mood-local-002",
                accountKey: "acct-local-amelia",
                moodCode: 1,
                moodAsset: "mood_cool",
                bodyText: "Cultivating self-discipline is a slow romance.",
                toneCode: 0,
                recordedAt: now,
                updatedAt: now
            )
        ]
        try entries.forEach { try moodRepository.save($0) }
    }

    private func seedDialogues() throws {
        let now = LocalDateText.now()
        try dialogueRepository.saveThread(
            DialogueThreadRecord(
                stableKey: "thread-local-victoria",
                threadKind: 0,
                counterpartAccountKey: "acct-local-victoria",
                title: "Victoria",
                avatarAsset: "avatar_person",
                latestEntryKey: "entry-local-victoria-003",
                latestEntryAt: now,
                lastReadAt: nil,
                isArchived: false,
                createdAt: now,
                updatedAt: now
            )
        )
        try dialogueRepository.saveThread(
            DialogueThreadRecord(
                stableKey: "thread-local-ai",
                threadKind: 1,
                counterpartAccountKey: nil,
                title: "Recot Bot",
                avatarAsset: nil,
                latestEntryKey: "entry-local-ai-001",
                latestEntryAt: now,
                lastReadAt: nil,
                isArchived: false,
                createdAt: now,
                updatedAt: now
            )
        )
        let entries = [
            DialogueEntryRecord(
                stableKey: "entry-local-victoria-001",
                threadKey: "thread-local-victoria",
                authorAccountKey: "acct-local-amelia",
                speakerKind: 0,
                entryKind: 0,
                bodyText: "Nice to meet you, nice to meet you!",
                mediaAsset: nil,
                mediaWidth: nil,
                mediaHeight: nil,
                audioDuration: nil,
                sequenceNumber: 1,
                deliveryState: 1,
                createdAt: now
            ),
            DialogueEntryRecord(
                stableKey: "entry-local-victoria-002",
                threadKey: "thread-local-victoria",
                authorAccountKey: "acct-local-victoria",
                speakerKind: 1,
                entryKind: 0,
                bodyText: "Nice to meet you.",
                mediaAsset: nil,
                mediaWidth: nil,
                mediaHeight: nil,
                audioDuration: nil,
                sequenceNumber: 2,
                deliveryState: 1,
                createdAt: now
            ),
            DialogueEntryRecord(
                stableKey: "entry-local-victoria-003",
                threadKey: "thread-local-victoria",
                authorAccountKey: "acct-local-victoria",
                speakerKind: 1,
                entryKind: 1,
                bodyText: nil,
                mediaAsset: "avatar_person",
                mediaWidth: 702,
                mediaHeight: 936,
                audioDuration: nil,
                sequenceNumber: 3,
                deliveryState: 1,
                createdAt: now
            ),
            DialogueEntryRecord(
                stableKey: "entry-local-ai-001",
                threadKey: "thread-local-ai",
                authorAccountKey: nil,
                speakerKind: 2,
                entryKind: 0,
                bodyText: "Hello!\nHow can I help you?",
                mediaAsset: nil,
                mediaWidth: nil,
                mediaHeight: nil,
                audioDuration: nil,
                sequenceNumber: 1,
                deliveryState: 1,
                createdAt: now
            )
        ]
        try entries.forEach { try dialogueRepository.saveEntry($0) }
    }

    private func seedWallet() throws {
        try walletRepository.save(
            WalletRecord(
                accountKey: "acct-local-amelia",
                balanceValue: 1000,
                updatedAt: LocalDateText.now()
            )
        )
    }
}

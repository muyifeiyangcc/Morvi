import Foundation

final class LocalSeedLoader {
    private let store: LocalStore
    private let accountRepository: AccountProfileRepository
    private let workRepository: CreativeWorkRepository
    private let moodRepository: MoodEntryRepository
    private let dialogueRepository: DialogueRepository
    private let walletRepository: WalletRepository
    private let permissionRepository: PermissionCopyRepository

    init(
        store: LocalStore = .shared,
        accountRepository: AccountProfileRepository = SQLiteAccountProfileRepository(),
        workRepository: CreativeWorkRepository = SQLiteCreativeWorkRepository(),
        moodRepository: MoodEntryRepository = SQLiteMoodEntryRepository(),
        dialogueRepository: DialogueRepository = SQLiteDialogueRepository(),
        walletRepository: WalletRepository = SQLiteWalletRepository(),
        permissionRepository: PermissionCopyRepository = SQLitePermissionCopyRepository()
    ) {
        self.store = store
        self.accountRepository = accountRepository
        self.workRepository = workRepository
        self.moodRepository = moodRepository
        self.dialogueRepository = dialogueRepository
        self.walletRepository = walletRepository
        self.permissionRepository = permissionRepository
    }

    func seedIfNeeded() throws {
        try seedEmbeddedEmailAccountIfNeeded()
        if try store.readInt("SELECT COUNT(*) FROM local_seed_state WHERE stable_key = 'built_in_content_v1';") == 0 {
            try seedCatalog()
            try seedAccounts()
            try seedRelations()
            try seedWorks()
            try seedWorkThemes()
            try seedReplies()
            try seedMoodEntries()
            try seedDialogues()
            try seedWallet()
            try seedPermissionCopies()
            try store.write(
                "INSERT OR REPLACE INTO local_seed_state (stable_key, created_at) VALUES (?, ?);",
                bindings: [.text("built_in_content_v1"), .text(LocalDateText.now())]
            )
        }
        try seedEmbeddedEmailConnectionsIfNeeded()
        try seedEmbeddedEmailRestrictionIfNeeded()
    }

    private func seedEmbeddedEmailAccountIfNeeded() throws {
        let seedKey = "built_in_email_access_v1"
        guard try store.readInt(
            "SELECT COUNT(*) FROM local_seed_state WHERE stable_key = ?;",
            bindings: [.text(seedKey)]
        ) == 0 else {
            return
        }

        let now = LocalDateText.now()
        let record = AccountProfileRecord(
            stableKey: "acct-email-morv",
            email: "morv@gmail.com",
            displayName: "Morv",
            genderCode: nil,
            birthDate: nil,
            locationText: nil,
            avatarAsset: "default_avatar",
            coverAsset: "default_avatar",
            registrationState: 1,
            createdAt: now,
            updatedAt: now
        )
        try accountRepository.register(record, secretText: "morv")
        try store.write(
            "INSERT OR REPLACE INTO local_seed_state (stable_key, created_at) VALUES (?, ?);",
            bindings: [.text(seedKey), .text(now)]
        )
    }

    private func seedEmbeddedEmailConnectionsIfNeeded() throws {
        let seedKey = "built_in_email_connections_v2"
        guard try store.readInt(
            "SELECT COUNT(*) FROM local_seed_state WHERE stable_key = ?;",
            bindings: [.text(seedKey)]
        ) == 0 else {
            return
        }

        let now = LocalDateText.now()
        let originKeys = [
            "acct-local-liam",
            "acct-local-jasper",
            "acct-local-chloe"
        ]
        try store.transaction {
            for originKey in originKeys {
                try store.write(
                    """
                    INSERT OR IGNORE INTO account_relation (
                        origin_account_key, target_account_key, created_at
                    ) VALUES (?, ?, ?);
                    """,
                    bindings: [
                        .text(originKey),
                        .text("acct-email-morv"),
                        .text(now)
                    ]
                )
            }
            try store.write(
                """
                INSERT OR IGNORE INTO account_relation (
                    origin_account_key, target_account_key, created_at
                ) VALUES (?, ?, ?);
                """,
                bindings: [
                    .text("acct-email-morv"),
                    .text("acct-local-liam"),
                    .text(now)
                ]
            )
            try store.write(
                "INSERT OR REPLACE INTO local_seed_state (stable_key, created_at) VALUES (?, ?);",
                bindings: [.text(seedKey), .text(now)]
            )
        }
    }

    private func seedEmbeddedEmailRestrictionIfNeeded() throws {
        let seedKey = "built_in_email_restriction_v1"
        guard try store.readInt(
            "SELECT COUNT(*) FROM local_seed_state WHERE stable_key = ?;",
            bindings: [.text(seedKey)]
        ) == 0 else {
            return
        }

        let now = LocalDateText.now()
        try store.transaction {
            try store.write(
                """
                INSERT OR IGNORE INTO restricted_relation (
                    owner_account_key, target_account_key, created_at
                ) VALUES (?, ?, ?);
                """,
                bindings: [
                    .text("acct-local-sophia"),
                    .text("acct-email-morv"),
                    .text(now)
                ]
            )
            try store.write(
                "INSERT OR REPLACE INTO local_seed_state (stable_key, created_at) VALUES (?, ?);",
                bindings: [.text(seedKey), .text(now)]
            )
        }
    }

    private func seedCatalog() throws {
        let themes = ["Travel", "Food", "Family", "Friends", "Lifestyle"]
        for (index, title) in themes.enumerated() {
            try store.write(
                """
                INSERT OR IGNORE INTO theme_catalog (id, title, sort_order)
                VALUES (?, ?, ?);
                """,
                bindings: [.int(1000 + index), .text(title), .int(index)]
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
                avatarAsset: "builtin_avatar_amelia",
                coverAsset: "builtin_avatar_amelia",
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
                avatarAsset: "builtin_avatar_victoria",
                coverAsset: "builtin_avatar_victoria",
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
                avatarAsset: "builtin_avatar_rowan",
                coverAsset: "builtin_avatar_rowan",
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
                avatarAsset: "builtin_avatar_sophia",
                coverAsset: "builtin_avatar_sophia",
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
                avatarAsset: "builtin_avatar_jasper",
                coverAsset: "builtin_avatar_jasper",
                registrationState: 1,
                createdAt: now,
                updatedAt: now
            ),
            AccountProfileRecord(
                stableKey: "acct-local-chloe",
                email: nil,
                displayName: "Chloe",
                genderCode: nil,
                birthDate: nil,
                locationText: nil,
                avatarAsset: "builtin_avatar_chloe",
                coverAsset: "builtin_avatar_chloe",
                registrationState: 1,
                createdAt: now,
                updatedAt: now
            ),
            AccountProfileRecord(
                stableKey: "acct-local-liam",
                email: nil,
                displayName: "Liam",
                genderCode: nil,
                birthDate: nil,
                locationText: nil,
                avatarAsset: "builtin_avatar_liam",
                coverAsset: "builtin_avatar_liam",
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
                stableKey: "work-local-victoria",
                ownerAccountKey: "acct-local-victoria",
                title: "Sunset",
                bodyText: "Golden hour by the sea. ✨🌅 Just standard beautiful sunset vibes with the crashing waves.",
                mediaKind: 1,
                mediaAsset: "builtin_victoria.mp4",
                coverAsset: "builtin_avatar_victoria",
                mediaWidth: 736,
                mediaHeight: 914,
                durationSeconds: nil,
                visibilityCode: 0,
                createdAt: now,
                updatedAt: now
            ),
            CreativeWorkRecord(
                stableKey: "work-local-sophia",
                ownerAccountKey: "acct-local-sophia",
                title: "Golden Walk",
                bodyText: "Chasing the last bit of light. 🌾",
                mediaKind: 1,
                mediaAsset: "builtin_sophia.mp4",
                coverAsset: "builtin_avatar_sophia",
                mediaWidth: 736,
                mediaHeight: 949,
                durationSeconds: nil,
                visibilityCode: 0,
                createdAt: now,
                updatedAt: now
            ),
            CreativeWorkRecord(
                stableKey: "work-local-chloe",
                ownerAccountKey: "acct-local-chloe",
                title: "Outfit Check",
                bodyText: "Quick mirror selfie before heading out. ✨",
                mediaKind: 1,
                mediaAsset: "builtin_chloe.mp4",
                coverAsset: "builtin_avatar_chloe",
                mediaWidth: 1125,
                mediaHeight: 1116,
                durationSeconds: nil,
                visibilityCode: 0,
                createdAt: now,
                updatedAt: now
            ),
            CreativeWorkRecord(
                stableKey: "work-local-amelia",
                ownerAccountKey: "acct-local-amelia",
                title: "Denim Day",
                bodyText: "Living in this fit all weekend.",
                mediaKind: 1,
                mediaAsset: "builtin_amelia.mp4",
                coverAsset: "builtin_avatar_amelia",
                mediaWidth: 900,
                mediaHeight: 1200,
                durationSeconds: nil,
                visibilityCode: 0,
                createdAt: now,
                updatedAt: now
            ),
            CreativeWorkRecord(
                stableKey: "work-local-rowan",
                ownerAccountKey: "acct-local-rowan",
                title: "Night Mood",
                bodyText: "Quiet nights, loud mind.",
                mediaKind: 1,
                mediaAsset: "builtin_rowan.mp4",
                coverAsset: "builtin_avatar_rowan",
                mediaWidth: 688,
                mediaHeight: 1024,
                durationSeconds: nil,
                visibilityCode: 0,
                createdAt: now,
                updatedAt: now
            ),
            CreativeWorkRecord(
                stableKey: "work-local-jasper",
                ownerAccountKey: "acct-local-jasper",
                title: "Seaside",
                bodyText: "Sun on my skin, salt in the air.",
                mediaKind: 1,
                mediaAsset: "builtin_jasper.mp4",
                coverAsset: "builtin_avatar_jasper",
                mediaWidth: 585,
                mediaHeight: 1024,
                durationSeconds: nil,
                visibilityCode: 0,
                createdAt: now,
                updatedAt: now
            ),
            CreativeWorkRecord(
                stableKey: "work-local-liam",
                ownerAccountKey: "acct-local-liam",
                title: "Morning Brew",
                bodyText: "Balcony brews hit different. ☕",
                mediaKind: 1,
                mediaAsset: "builtin_liam.mp4",
                coverAsset: "builtin_avatar_liam",
                mediaWidth: 735,
                mediaHeight: 1105,
                durationSeconds: nil,
                visibilityCode: 0,
                createdAt: now,
                updatedAt: now
            )
        ]
        try works.forEach { try workRepository.save($0) }
    }

    private func seedWorkThemes() throws {
        let links: [(String, [Int])] = [
            ("work-local-victoria", [1000, 1004]),
            ("work-local-sophia", [1000]),
            ("work-local-chloe", [1004]),
            ("work-local-amelia", [1004]),
            ("work-local-rowan", [1003, 1004]),
            ("work-local-jasper", [1000]),
            ("work-local-liam", [1004])
        ]
        for (workKey, themeIds) in links {
            for themeId in themeIds {
                try store.write(
                    "INSERT OR IGNORE INTO work_theme_link (work_key, theme_id) VALUES (?, ?);",
                    bindings: [.text(workKey), .int(themeId)]
                )
            }
        }
    }

    private func seedReplies() throws {
        let now = LocalDateText.now()
        let rows: [(String, String, String)] = [
            ("reply-local-victoria", "work-local-victoria", "Need that view right now!"),
            ("reply-local-sophia", "work-local-sophia", "Made me want to go for a walk"),
            ("reply-local-chloe", "work-local-chloe", "HOW LOOKS SO BEAUTIFUL!!"),
            ("reply-local-amelia", "work-local-amelia", "Denim on denim is a yes from me 💙"),
            ("reply-local-jasper", "work-local-jasper", "Beach core is real 🌊")
        ]
        for (stableKey, workKey, bodyText) in rows {
            try store.write(
                """
                INSERT INTO work_reply (
                    stable_key, work_key, author_account_key, parent_reply_key,
                    body_text, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(stable_key) DO UPDATE SET
                    body_text = excluded.body_text,
                    updated_at = excluded.updated_at;
                """,
                bindings: [
                    .text(stableKey),
                    .text(workKey),
                    .text("acct-local-amelia"),
                    .null,
                    .text(bodyText),
                    .text(now),
                    .text(now)
                ]
            )
        }
    }

    private func seedMoodEntries() throws {
        let now = LocalDateText.now()
        let entries = [
            MoodEntryRecord(
                stableKey: "mood-local-001",
                accountKey: "acct-local-amelia",
                moodCode: 0,
                moodAsset: "home_mood_happy",
                moodTitle: "Happy",
                bodyText: "A little sunshine came today!",
                toneCode: 1,
                recordedAt: now,
                updatedAt: now
            ),
            MoodEntryRecord(
                stableKey: "mood-local-002",
                accountKey: "acct-local-amelia",
                moodCode: 1,
                moodAsset: "home_mood_calm",
                moodTitle: "Calm",
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
                avatarAsset: "builtin_avatar_victoria",
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
                mediaAsset: "builtin_avatar_victoria",
                mediaWidth: 736,
                mediaHeight: 914,
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

    private func seedPermissionCopies() throws {
        let now = LocalDateText.now()
        let rows = [
            PermissionCopyRecord(
                stableKey: "permission-local-microphone",
                permissionKind: 0,
                title: "麦克风",
                bodyText: "Morvi needs microphone access to send voice messages in chats and record video audio.",
                createdAt: now,
                updatedAt: now
            ),
            PermissionCopyRecord(
                stableKey: "permission-local-camera",
                permissionKind: 1,
                title: "相机",
                bodyText: "Morvi needs camera access to shoot photos and videos for sharing or profile updates.",
                createdAt: now,
                updatedAt: now
            ),
            PermissionCopyRecord(
                stableKey: "permission-local-photo-library",
                permissionKind: 2,
                title: "相册",
                bodyText: "Morvi needs album access to let you choose photos and videos to share or set as avatars.",
                createdAt: now,
                updatedAt: now
            )
        ]
        try rows.forEach { try permissionRepository.save($0) }
    }
}

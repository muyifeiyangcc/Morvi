import Foundation

struct DiscoveryProfileEntry {
    let accountKey: String
    let displayName: String
    let avatarAsset: String
}

struct DiscoveryWorkEntry {
    let stableKey: String
    let accountKey: String
    let displayName: String
    let avatarAsset: String
    let coverAssetForAccount: String?
    let title: String
    let bodyText: String
    let mediaKind: Int
    let mediaAsset: String?
    let coverAsset: String
    let mediaWidth: Double?
    let mediaHeight: Double?
    let themes: [String]
    let reactionCount: Int
    let replyCount: Int
}

struct PersonaDetailEntry {
    let accountKey: String
    let displayName: String
    let avatarAsset: String
    let coverAsset: String
    let followersText: String
    let followingText: String
}

struct WorkReplyEntry {
    let stableKey: String
    let accountKey: String
    let displayName: String
    let avatarAsset: String
    let bodyText: String
}

protocol CreativeWorkRepository {
    func save(_ record: CreativeWorkRecord) throws
    func saveWithThemeTitles(_ record: CreativeWorkRecord, themeTitles: [String]) throws
    func count() throws -> Int
    func discoveryProfiles(limit: Int) throws -> [DiscoveryProfileEntry]
    func discoveryWorks(limit: Int) throws -> [DiscoveryWorkEntry]
    func workDetail(stableKey: String) throws -> DiscoveryWorkEntry?
    func works(ownerAccountKey: String, limit: Int) throws -> [DiscoveryWorkEntry]
    func personaDetail(accountKey: String) throws -> PersonaDetailEntry?
    func replies(workKey: String) throws -> [WorkReplyEntry]
    func addReply(workKey: String, accountKey: String, bodyText: String) throws
    func hasReaction(workKey: String, accountKey: String) throws -> Bool
    func toggleReaction(workKey: String, accountKey: String) throws -> Bool
}

final class SQLiteCreativeWorkRepository: CreativeWorkRepository {
    static let activityDidChangeNotification = Notification.Name("Morvi.creativeWorkActivityDidChange")

    private let store: LocalStore

    init(store: LocalStore = .shared) {
        self.store = store
    }

    func save(_ record: CreativeWorkRecord) throws {
        try store.write(
            """
            INSERT INTO creative_work (
                stable_key, owner_account_key, title, body_text, media_kind, media_asset,
                cover_asset, media_width, media_height, duration_seconds, visibility_code,
                created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(stable_key) DO UPDATE SET
                title = excluded.title,
                body_text = excluded.body_text,
                media_kind = excluded.media_kind,
                media_asset = excluded.media_asset,
                cover_asset = excluded.cover_asset,
                media_width = excluded.media_width,
                media_height = excluded.media_height,
                duration_seconds = excluded.duration_seconds,
                visibility_code = excluded.visibility_code,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(record.stableKey),
                .text(record.ownerAccountKey),
                .text(record.title),
                record.bodyText.map(LocalStoreValue.text) ?? .null,
                .int(record.mediaKind),
                record.mediaAsset.map(LocalStoreValue.text) ?? .null,
                record.coverAsset.map(LocalStoreValue.text) ?? .null,
                record.mediaWidth.map(LocalStoreValue.double) ?? .null,
                record.mediaHeight.map(LocalStoreValue.double) ?? .null,
                record.durationSeconds.map(LocalStoreValue.double) ?? .null,
                .int(record.visibilityCode),
                .text(record.createdAt),
                .text(record.updatedAt)
            ]
        )
    }

    func saveWithThemeTitles(_ record: CreativeWorkRecord, themeTitles: [String]) throws {
        try store.transaction {
            try save(record)
            try store.write(
                "DELETE FROM work_theme_link WHERE work_key = ?;",
                bindings: [.text(record.stableKey)]
            )
            for title in themeTitles {
                try store.write(
                    """
                    INSERT OR IGNORE INTO work_theme_link (work_key, theme_id)
                    SELECT ?, id
                    FROM theme_catalog
                    WHERE title = ?
                    LIMIT 1;
                    """,
                    bindings: [.text(record.stableKey), .text(title)]
                )
            }
        }
    }

    func count() throws -> Int {
        try store.readInt("SELECT COUNT(*) FROM creative_work;")
    }

    func discoveryProfiles(limit: Int) throws -> [DiscoveryProfileEntry] {
        try store.readRows(
            """
            SELECT stable_key, display_name, COALESCE(avatar_asset, 'default_avatar')
            FROM account_profile
            WHERE stable_key LIKE 'acct-local-%'
                AND stable_key <> 'acct-local-amelia'
                AND registration_state = 1
            ORDER BY
                CASE stable_key
                    WHEN 'acct-local-victoria' THEN 0
                    WHEN 'acct-local-rowan' THEN 1
                    WHEN 'acct-local-sophia' THEN 2
                    WHEN 'acct-local-jasper' THEN 3
                    WHEN 'acct-local-chloe' THEN 4
                    ELSE 5
                END,
                display_name ASC
            LIMIT ?;
            """,
            bindings: [.int(limit)]
        ).compactMap { row in
            guard row.count >= 3,
                  let stableKey = row[0].textValue,
                  let displayName = row[1].textValue,
                  let avatarAsset = row[2].textValue else {
                return nil
            }
            return DiscoveryProfileEntry(
                accountKey: stableKey,
                displayName: displayName,
                avatarAsset: avatarAsset
            )
        }
    }

    func discoveryWorks(limit: Int) throws -> [DiscoveryWorkEntry] {
        let rows = try store.readRows(
            """
            SELECT
                w.stable_key,
                w.owner_account_key,
                p.display_name,
                COALESCE(p.avatar_asset, 'default_avatar'),
                p.cover_asset,
                w.title,
                COALESCE(w.body_text, ''),
                w.media_kind,
                w.media_asset,
                COALESCE(w.cover_asset, 'discover_feed_cover'),
                w.media_width,
                w.media_height,
                (
                    SELECT COUNT(*)
                    FROM work_reaction wr
                    WHERE wr.work_key = w.stable_key
                ),
                (
                    SELECT COUNT(*)
                    FROM work_reply rp
                    WHERE rp.work_key = w.stable_key
                        AND rp.removed_at IS NULL
                )
            FROM creative_work w
            JOIN account_profile p ON p.stable_key = w.owner_account_key
            WHERE w.removed_at IS NULL
                AND w.visibility_code = 0
            ORDER BY w.created_at DESC, w.id DESC
            LIMIT ?;
            """,
            bindings: [.int(limit)]
        )

        return try rows.compactMap { row in
            guard row.count >= 14,
                  let stableKey = row[0].textValue,
                  let accountKey = row[1].textValue,
                  let displayName = row[2].textValue,
                  let avatarAsset = row[3].textValue,
                  let title = row[5].textValue,
                  let bodyText = row[6].textValue,
                  let coverAsset = row[9].textValue else {
                return nil
            }
            let themes = try themesForWork(stableKey: stableKey)
            return DiscoveryWorkEntry(
                stableKey: stableKey,
                accountKey: accountKey,
                displayName: displayName,
                avatarAsset: avatarAsset,
                coverAssetForAccount: row[4].textValue,
                title: title,
                bodyText: bodyText,
                mediaKind: row[7].intValue,
                mediaAsset: row[8].textValue,
                coverAsset: coverAsset,
                mediaWidth: row[10].doubleValue,
                mediaHeight: row[11].doubleValue,
                themes: themes,
                reactionCount: row[12].intValue,
                replyCount: row[13].intValue
            )
        }
    }

    func workDetail(stableKey: String) throws -> DiscoveryWorkEntry? {
        try works(whereClause: "w.stable_key = ?", bindings: [.text(stableKey)], limit: 1).first
    }

    func works(ownerAccountKey: String, limit: Int) throws -> [DiscoveryWorkEntry] {
        try works(
            whereClause: "w.owner_account_key = ? AND w.removed_at IS NULL AND w.visibility_code = 0",
            bindings: [.text(ownerAccountKey)],
            limit: limit
        )
    }

    func personaDetail(accountKey: String) throws -> PersonaDetailEntry? {
        let rows = try store.readRows(
            """
            SELECT
                stable_key,
                display_name,
                COALESCE(avatar_asset, 'default_avatar'),
                COALESCE(cover_asset, avatar_asset, 'discover_feed_cover'),
                (
                    SELECT COUNT(*)
                    FROM account_relation ar
                    WHERE ar.target_account_key = account_profile.stable_key
                ),
                (
                    SELECT COUNT(*)
                    FROM account_relation ar
                    WHERE ar.origin_account_key = account_profile.stable_key
                )
            FROM account_profile
            WHERE stable_key = ?
            LIMIT 1;
            """,
            bindings: [.text(accountKey)]
        )
        guard let row = rows.first,
              row.count >= 6,
              let key = row[0].textValue,
              let displayName = row[1].textValue,
              let avatarAsset = row[2].textValue,
              let coverAsset = row[3].textValue else {
            return nil
        }
        return PersonaDetailEntry(
            accountKey: key,
            displayName: displayName,
            avatarAsset: avatarAsset,
            coverAsset: coverAsset,
            followersText: "\(row[4].intValue)",
            followingText: "\(row[5].intValue)"
        )
    }

    func replies(workKey: String) throws -> [WorkReplyEntry] {
        try store.readRows(
            """
            SELECT
                rp.stable_key,
                rp.author_account_key,
                p.display_name,
                COALESCE(p.avatar_asset, 'default_avatar'),
                rp.body_text
            FROM work_reply rp
            JOIN account_profile p ON p.stable_key = rp.author_account_key
            WHERE rp.work_key = ?
                AND rp.removed_at IS NULL
            ORDER BY rp.created_at ASC, rp.id ASC;
            """,
            bindings: [.text(workKey)]
        ).compactMap { row in
            guard row.count >= 5,
                  let stableKey = row[0].textValue,
                  let accountKey = row[1].textValue,
                  let displayName = row[2].textValue,
                  let avatarAsset = row[3].textValue,
                  let bodyText = row[4].textValue else {
                return nil
            }
            return WorkReplyEntry(
                stableKey: stableKey,
                accountKey: accountKey,
                displayName: displayName,
                avatarAsset: avatarAsset,
                bodyText: bodyText
            )
        }
    }

    func addReply(workKey: String, accountKey: String, bodyText: String) throws {
        let now = LocalDateText.now()
        try store.write(
            """
            INSERT INTO work_reply (
                stable_key, work_key, author_account_key, parent_reply_key,
                body_text, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?);
            """,
            bindings: [
                .text("reply-local-\(UUID().uuidString.lowercased())"),
                .text(workKey),
                .text(accountKey),
                .null,
                .text(bodyText),
                .text(now),
                .text(now)
            ]
        )
        Self.notifyActivityChange()
    }

    func hasReaction(workKey: String, accountKey: String) throws -> Bool {
        try store.readInt(
            """
            SELECT COUNT(*)
            FROM work_reaction
            WHERE work_key = ?
                AND account_key = ?;
            """,
            bindings: [.text(workKey), .text(accountKey)]
        ) > 0
    }

    func toggleReaction(workKey: String, accountKey: String) throws -> Bool {
        let active = try hasReaction(workKey: workKey, accountKey: accountKey)
        if active {
            try store.write(
                """
                DELETE FROM work_reaction
                WHERE work_key = ?
                    AND account_key = ?;
                """,
                bindings: [.text(workKey), .text(accountKey)]
            )
            Self.notifyActivityChange()
            return false
        }
        try store.write(
            """
            INSERT OR IGNORE INTO work_reaction (work_key, account_key, created_at)
            VALUES (?, ?, ?);
            """,
            bindings: [
                .text(workKey),
                .text(accountKey),
                .text(LocalDateText.now())
            ]
        )
        Self.notifyActivityChange()
        return true
    }

    private func works(
        whereClause: String,
        bindings: [LocalStoreValue],
        limit: Int
    ) throws -> [DiscoveryWorkEntry] {
        let rows = try store.readRows(
            """
            SELECT
                w.stable_key,
                w.owner_account_key,
                p.display_name,
                COALESCE(p.avatar_asset, 'default_avatar'),
                p.cover_asset,
                w.title,
                COALESCE(w.body_text, ''),
                w.media_kind,
                w.media_asset,
                COALESCE(w.cover_asset, 'discover_feed_cover'),
                w.media_width,
                w.media_height,
                (
                    SELECT COUNT(*)
                    FROM work_reaction wr
                    WHERE wr.work_key = w.stable_key
                ),
                (
                    SELECT COUNT(*)
                    FROM work_reply rp
                    WHERE rp.work_key = w.stable_key
                        AND rp.removed_at IS NULL
                )
            FROM creative_work w
            JOIN account_profile p ON p.stable_key = w.owner_account_key
            WHERE \(whereClause)
            ORDER BY w.created_at DESC, w.id DESC
            LIMIT ?;
            """,
            bindings: bindings + [.int(limit)]
        )

        return try rows.compactMap { row in
            guard row.count >= 14,
                  let stableKey = row[0].textValue,
                  let accountKey = row[1].textValue,
                  let displayName = row[2].textValue,
                  let avatarAsset = row[3].textValue,
                  let title = row[5].textValue,
                  let bodyText = row[6].textValue,
                  let coverAsset = row[9].textValue else {
                return nil
            }
            return DiscoveryWorkEntry(
                stableKey: stableKey,
                accountKey: accountKey,
                displayName: displayName,
                avatarAsset: avatarAsset,
                coverAssetForAccount: row[4].textValue,
                title: title,
                bodyText: bodyText,
                mediaKind: row[7].intValue,
                mediaAsset: row[8].textValue,
                coverAsset: coverAsset,
                mediaWidth: row[10].doubleValue,
                mediaHeight: row[11].doubleValue,
                themes: try themesForWork(stableKey: stableKey),
                reactionCount: row[12].intValue,
                replyCount: row[13].intValue
            )
        }
    }

    private static func notifyActivityChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: activityDidChangeNotification, object: nil)
        }
    }

    private func themesForWork(stableKey: String) throws -> [String] {
        let rows = try store.readRows(
            """
            SELECT c.title
            FROM work_theme_link l
            JOIN theme_catalog c ON c.id = l.theme_id
            WHERE l.work_key = ?
            ORDER BY c.sort_order ASC;
            """,
            bindings: [.text(stableKey)]
        )
        let values = rows.compactMap { $0.first?.textValue }
        return values.isEmpty ? ["Travel", "Food", "Family", "Friends", "Lifestyle"] : values
    }
}

private extension LocalStoreValue {
    var textValue: String? {
        if case .text(let value) = self {
            return value
        }
        return nil
    }

    var intValue: Int {
        if case .int(let value) = self {
            return value
        }
        return 0
    }

    var doubleValue: Double? {
        switch self {
        case .double(let value):
            return value
        case .int(let value):
            return Double(value)
        default:
            return nil
        }
    }
}

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
    let title: String
    let bodyText: String
    let coverAsset: String
    let themes: [String]
    let reactionCount: Int
    let replyCount: Int
}

protocol CreativeWorkRepository {
    func save(_ record: CreativeWorkRecord) throws
    func count() throws -> Int
    func discoveryProfiles(limit: Int) throws -> [DiscoveryProfileEntry]
    func discoveryWorks(limit: Int) throws -> [DiscoveryWorkEntry]
}

final class SQLiteCreativeWorkRepository: CreativeWorkRepository {
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
                w.title,
                COALESCE(w.body_text, ''),
                COALESCE(w.cover_asset, 'discover_feed_cover'),
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
            ORDER BY
                CASE w.stable_key
                    WHEN 'work-local-victoria' THEN 0
                    WHEN 'work-local-rowan' THEN 1
                    WHEN 'work-local-sophia' THEN 2
                    WHEN 'work-local-jasper' THEN 3
                    ELSE 4
                END,
                w.created_at DESC
            LIMIT ?;
            """,
            bindings: [.int(limit)]
        )

        return try rows.compactMap { row in
            guard row.count >= 9,
                  let stableKey = row[0].textValue,
                  let accountKey = row[1].textValue,
                  let displayName = row[2].textValue,
                  let avatarAsset = row[3].textValue,
                  let title = row[4].textValue,
                  let bodyText = row[5].textValue,
                  let coverAsset = row[6].textValue else {
                return nil
            }
            let themes = try themesForWork(stableKey: stableKey)
            return DiscoveryWorkEntry(
                stableKey: stableKey,
                accountKey: accountKey,
                displayName: displayName,
                avatarAsset: avatarAsset,
                title: title,
                bodyText: bodyText,
                coverAsset: coverAsset,
                themes: themes,
                reactionCount: max(row[7].intValue, 666),
                replyCount: max(row[8].intValue, 777)
            )
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
}

import Foundation

struct SafetyProfileRecord {
    let stableKey: String
    let displayName: String
    let avatarAsset: String?
}

struct RelationRosterRecord {
    let stableKey: String
    let displayName: String
    let avatarAsset: String?
}

protocol AccountProfileRepository {
    func save(_ record: AccountProfileRecord) throws
    func register(_ record: AccountProfileRecord, secretText: String) throws
    func accountKey(email: String) throws -> String?
    func secretText(email: String) throws -> String?
    func updateSecret(email: String, secretText: String) throws -> Bool
    func updateEditableInfo(stableKey: String, displayName: String, avatarAsset: String) throws
    func displayName(stableKey: String) throws -> String?
    func avatarAsset(stableKey: String) throws -> String?
    func safetyProfile(stableKey: String) throws -> SafetyProfileRecord?
    func addRestriction(originKey: String, subjectKey: String) throws
    func addSafetyNotice(originKey: String, subjectKey: String, reasonCode: Int, detailText: String?) throws
    func hasSafetyBarrier(originKey: String, subjectKey: String) throws -> Bool
    func connect(originKey: String, subjectKey: String) throws
    func removeConnection(originKey: String, subjectKey: String) throws
    func hasConnection(originKey: String, subjectKey: String) throws -> Bool
    func hasMutualConnection(firstKey: String, secondKey: String) throws -> Bool
    func restrictedRoster(ownerKey: String) throws -> [RelationRosterRecord]
    func outboundConnectionRoster(originKey: String) throws -> [RelationRosterRecord]
    func inboundConnectionRoster(targetKey: String) throws -> [RelationRosterRecord]
    func remove(stableKey: String) throws -> String?
    func count() throws -> Int
}

final class SQLiteAccountProfileRepository: AccountProfileRepository {
    private let store: LocalStore

    init(store: LocalStore = .shared) {
        self.store = store
    }

    func save(_ record: AccountProfileRecord) throws {
        try store.write(
            """
            INSERT INTO account_profile (
                stable_key, email, display_name, gender_code, birth_date, location_text,
                avatar_asset, cover_asset, registration_state, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(stable_key) DO UPDATE SET
                email = excluded.email,
                display_name = excluded.display_name,
                gender_code = excluded.gender_code,
                birth_date = excluded.birth_date,
                location_text = excluded.location_text,
                avatar_asset = excluded.avatar_asset,
                cover_asset = excluded.cover_asset,
                registration_state = excluded.registration_state,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(record.stableKey),
                record.email.map(LocalStoreValue.text) ?? .null,
                .text(record.displayName),
                record.genderCode.map(LocalStoreValue.int) ?? .null,
                record.birthDate.map(LocalStoreValue.text) ?? .null,
                record.locationText.map(LocalStoreValue.text) ?? .null,
                record.avatarAsset.map(LocalStoreValue.text) ?? .null,
                record.coverAsset.map(LocalStoreValue.text) ?? .null,
                .int(record.registrationState),
                .text(record.createdAt),
                .text(record.updatedAt)
            ]
        )
    }

    func register(_ record: AccountProfileRecord, secretText: String) throws {
        try store.transaction {
            try save(record)
            try store.write(
                """
                INSERT INTO account_secret (
                    account_key, email, secret_text, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(email) DO UPDATE SET
                    account_key = excluded.account_key,
                    secret_text = excluded.secret_text,
                    updated_at = excluded.updated_at;
                """,
                bindings: [
                    .text(record.stableKey),
                    .text(record.email ?? ""),
                    .text(secretText),
                    .text(record.createdAt),
                    .text(record.updatedAt)
                ]
            )
        }
    }

    func accountKey(email: String) throws -> String? {
        try store.readText(
            """
            SELECT account_key
            FROM account_secret
            WHERE lower(email) = lower(?)
            LIMIT 1;
            """,
            bindings: [
                .text(email)
            ]
        )
    }

    func secretText(email: String) throws -> String? {
        try store.readText(
            """
            SELECT secret_text
            FROM account_secret
            WHERE lower(email) = lower(?)
            LIMIT 1;
            """,
            bindings: [
                .text(email)
            ]
        )
    }

    func updateSecret(email: String, secretText: String) throws -> Bool {
        guard let accountKey = try accountKey(email: email) else {
            return false
        }
        try store.write(
            """
            UPDATE account_secret
            SET secret_text = ?,
                updated_at = ?
            WHERE account_key = ?
                AND lower(email) = lower(?);
            """,
            bindings: [
                .text(secretText),
                .text(LocalDateText.now()),
                .text(accountKey),
                .text(email)
            ]
        )
        return true
    }

    func updateEditableInfo(stableKey: String, displayName: String, avatarAsset: String) throws {
        try store.write(
            """
            UPDATE account_profile
            SET display_name = ?,
                avatar_asset = ?,
                cover_asset = ?,
                updated_at = ?
            WHERE stable_key = ?;
            """,
            bindings: [
                .text(displayName),
                .text(avatarAsset),
                .text(avatarAsset),
                .text(LocalDateText.now()),
                .text(stableKey)
            ]
        )
    }

    func displayName(stableKey: String) throws -> String? {
        try store.readText(
            "SELECT display_name FROM account_profile WHERE stable_key = ? LIMIT 1;",
            bindings: [.text(stableKey)]
        )
    }

    func avatarAsset(stableKey: String) throws -> String? {
        try store.readText(
            "SELECT avatar_asset FROM account_profile WHERE stable_key = ? LIMIT 1;",
            bindings: [.text(stableKey)]
        )
    }

    func safetyProfile(stableKey: String) throws -> SafetyProfileRecord? {
        let rows = try store.readRows(
            """
            SELECT stable_key, display_name, avatar_asset
            FROM account_profile
            WHERE stable_key = ?
            LIMIT 1;
            """,
            bindings: [.text(stableKey)]
        )
        guard let row = rows.first,
              row.count >= 3,
              let key = row[0].textValue,
              let name = row[1].textValue else {
            return nil
        }
        return SafetyProfileRecord(
            stableKey: key,
            displayName: name,
            avatarAsset: row[2].textValue
        )
    }

    func addRestriction(originKey: String, subjectKey: String) throws {
        try store.write(
            """
            INSERT OR IGNORE INTO restricted_relation (
                owner_account_key, target_account_key, created_at
            ) VALUES (?, ?, ?);
            """,
            bindings: [
                .text(originKey),
                .text(subjectKey),
                .text(LocalDateText.now())
            ]
        )
    }

    func addSafetyNotice(originKey: String, subjectKey: String, reasonCode: Int, detailText: String?) throws {
        try store.write(
            """
            INSERT INTO report_record (
                source_account_key, target_kind, target_key, reason_code, detail_text, created_at
            ) VALUES (?, ?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(originKey),
                .int(0),
                .text(subjectKey),
                .int(reasonCode),
                detailText.map(LocalStoreValue.text) ?? .null,
                .text(LocalDateText.now())
            ]
        )
    }

    func hasSafetyBarrier(originKey: String, subjectKey: String) throws -> Bool {
        let restrictionCount = try store.readInt(
            """
            SELECT COUNT(*)
            FROM restricted_relation
            WHERE owner_account_key = ?
                AND target_account_key = ?;
            """,
            bindings: [.text(originKey), .text(subjectKey)]
        )
        if restrictionCount > 0 {
            return true
        }
        return try store.readInt(
            """
            SELECT COUNT(*)
            FROM report_record
            WHERE source_account_key = ?
                AND target_kind = 0
                AND target_key = ?;
            """,
            bindings: [.text(originKey), .text(subjectKey)]
        ) > 0
    }

    func connect(originKey: String, subjectKey: String) throws {
        try store.write(
            """
            INSERT OR IGNORE INTO account_relation (
                origin_account_key, target_account_key, created_at
            ) VALUES (?, ?, ?);
            """,
            bindings: [
                .text(originKey),
                .text(subjectKey),
                .text(LocalDateText.now())
            ]
        )
    }

    func removeConnection(originKey: String, subjectKey: String) throws {
        try store.write(
            """
            DELETE FROM account_relation
            WHERE origin_account_key = ?
                AND target_account_key = ?;
            """,
            bindings: [.text(originKey), .text(subjectKey)]
        )
    }

    func hasConnection(originKey: String, subjectKey: String) throws -> Bool {
        try store.readInt(
            """
            SELECT COUNT(*)
            FROM account_relation
            WHERE origin_account_key = ?
                AND target_account_key = ?;
            """,
            bindings: [.text(originKey), .text(subjectKey)]
        ) > 0
    }

    func hasMutualConnection(firstKey: String, secondKey: String) throws -> Bool {
        let firstToSecond = try hasConnection(originKey: firstKey, subjectKey: secondKey)
        let secondToFirst = try hasConnection(originKey: secondKey, subjectKey: firstKey)
        return firstToSecond && secondToFirst
    }

    func restrictedRoster(ownerKey: String) throws -> [RelationRosterRecord] {
        try rosterRecords(
            """
            SELECT p.stable_key, p.display_name, p.avatar_asset
            FROM restricted_relation rr
            JOIN account_profile p ON p.stable_key = rr.target_account_key
            WHERE rr.owner_account_key = ?
            ORDER BY rr.created_at DESC, rr.id DESC;
            """,
            bindings: [.text(ownerKey)]
        )
    }

    func outboundConnectionRoster(originKey: String) throws -> [RelationRosterRecord] {
        try rosterRecords(
            """
            SELECT p.stable_key, p.display_name, p.avatar_asset
            FROM account_relation ar
            JOIN account_profile p ON p.stable_key = ar.target_account_key
            WHERE ar.origin_account_key = ?
            ORDER BY ar.created_at DESC, ar.id DESC;
            """,
            bindings: [.text(originKey)]
        )
    }

    func inboundConnectionRoster(targetKey: String) throws -> [RelationRosterRecord] {
        try rosterRecords(
            """
            SELECT p.stable_key, p.display_name, p.avatar_asset
            FROM account_relation ar
            JOIN account_profile p ON p.stable_key = ar.origin_account_key
            WHERE ar.target_account_key = ?
            ORDER BY ar.created_at DESC, ar.id DESC;
            """,
            bindings: [.text(targetKey)]
        )
    }

    private func rosterRecords(
        _ query: String,
        bindings: [LocalStoreValue]
    ) throws -> [RelationRosterRecord] {
        let rows = try store.readRows(query, bindings: bindings)
        return rows.compactMap { row in
            guard row.count >= 3,
                  let key = row[0].textValue,
                  let name = row[1].textValue else {
                return nil
            }
            return RelationRosterRecord(
                stableKey: key,
                displayName: name,
                avatarAsset: row[2].textValue
            )
        }
    }

    func remove(stableKey: String) throws -> String? {
        let binding = [LocalStoreValue.text(stableKey)]
        let avatarAsset = try store.readText(
            "SELECT avatar_asset FROM account_profile WHERE stable_key = ? LIMIT 1;",
            bindings: binding
        )

        try store.transaction {
            try store.write(
                """
                DELETE FROM dialogue_entry
                WHERE thread_key IN (
                    SELECT stable_key FROM dialogue_thread WHERE counterpart_account_key = ?
                );
                """,
                bindings: binding
            )
            try store.write(
                "DELETE FROM dialogue_thread WHERE counterpart_account_key = ?;",
                bindings: binding
            )
            try store.write(
                "DELETE FROM dialogue_entry WHERE author_account_key = ?;",
                bindings: binding
            )
            try store.write(
                """
                DELETE FROM work_theme_link
                WHERE work_key IN (
                    SELECT stable_key FROM creative_work WHERE owner_account_key = ?
                );
                """,
                bindings: binding
            )
            try store.write(
                """
                DELETE FROM work_reaction
                WHERE account_key = ?
                    OR work_key IN (
                        SELECT stable_key FROM creative_work WHERE owner_account_key = ?
                    );
                """,
                bindings: binding + binding
            )
            try store.write(
                """
                DELETE FROM work_reply
                WHERE author_account_key = ?
                    OR work_key IN (
                        SELECT stable_key FROM creative_work WHERE owner_account_key = ?
                    );
                """,
                bindings: binding + binding
            )
            try store.write("DELETE FROM creative_work WHERE owner_account_key = ?;", bindings: binding)
            try store.write(
                "DELETE FROM account_relation WHERE origin_account_key = ? OR target_account_key = ?;",
                bindings: binding + binding
            )
            try store.write("DELETE FROM mood_entry WHERE account_key = ?;", bindings: binding)
            try store.write(
                "DELETE FROM restricted_relation WHERE owner_account_key = ? OR target_account_key = ?;",
                bindings: binding + binding
            )
            try store.write(
                "DELETE FROM report_record WHERE source_account_key = ? OR target_key = ?;",
                bindings: binding + binding
            )
            try store.write("DELETE FROM credit_activity WHERE account_key = ?;", bindings: binding)
            try store.write("DELETE FROM credit_account WHERE account_key = ?;", bindings: binding)
            try store.write("DELETE FROM agreement_acceptance WHERE account_key = ?;", bindings: binding)
            try store.write("DELETE FROM local_session WHERE account_key = ?;", bindings: binding)
            try store.write("DELETE FROM account_secret WHERE account_key = ?;", bindings: binding)
            try store.write(
                """
                DELETE FROM local_identity_state
                WHERE (
                    stable_key = 'guest_account_anchor'
                    OR stable_key = 'apple_account_anchor'
                    OR stable_key LIKE 'apple_account_anchor_%'
                )
                AND text_value = ?;
                """,
                bindings: binding
            )
            try store.write("DELETE FROM account_profile WHERE stable_key = ?;", bindings: binding)
        }

        return avatarAsset
    }

    func count() throws -> Int {
        try store.readInt("SELECT COUNT(*) FROM account_profile;")
    }
}

private extension LocalStoreValue {
    var textValue: String? {
        if case let .text(value) = self {
            return value
        }
        return nil
    }
}

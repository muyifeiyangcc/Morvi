import Foundation

protocol AccountSessionRepository {
    func hasActiveSession() throws -> Bool
    func activeAccountKey() throws -> String?
    func activate(_ record: AccountSessionRecord) throws
    func clearActiveSession() throws
}

final class SQLiteAccountSessionRepository: AccountSessionRepository {
    private let store: LocalStore

    init(store: LocalStore = .shared) {
        self.store = store
    }

    func hasActiveSession() throws -> Bool {
        try store.readInt(
            """
            SELECT COUNT(*)
            FROM local_session
            WHERE is_active = 1
                AND (expires_at IS NULL OR expires_at > datetime('now'));
            """
        ) > 0
    }

    func activeAccountKey() throws -> String? {
        try store.readText(
            """
            SELECT account_key
            FROM local_session
            WHERE is_active = 1
                AND (expires_at IS NULL OR expires_at > datetime('now'))
            ORDER BY id DESC
            LIMIT 1;
            """
        )
    }

    func activate(_ record: AccountSessionRecord) throws {
        try store.transaction {
            try store.write(
                "UPDATE local_session SET is_active = 0 WHERE is_active = 1;",
                bindings: []
            )
            try store.write(
                """
                INSERT INTO local_session (
                    account_key, access_kind, is_active, signed_in_at, expires_at
                ) VALUES (?, ?, ?, ?, ?);
                """,
                bindings: [
                    .text(record.accountKey),
                    .int(record.accessKind),
                    .int(record.isActive ? 1 : 0),
                    .text(record.signedInAt),
                    record.expiresAt.map(LocalStoreValue.text) ?? .null
                ]
            )
        }
    }

    func clearActiveSession() throws {
        try store.write("UPDATE local_session SET is_active = 0 WHERE is_active = 1;", bindings: [])
    }
}

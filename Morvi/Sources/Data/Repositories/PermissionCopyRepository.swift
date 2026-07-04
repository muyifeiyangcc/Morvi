import Foundation

protocol PermissionCopyRepository {
    func save(_ record: PermissionCopyRecord) throws
}

final class SQLitePermissionCopyRepository: PermissionCopyRepository {
    private let store: LocalStore

    init(store: LocalStore = .shared) {
        self.store = store
    }

    func save(_ record: PermissionCopyRecord) throws {
        try store.write(
            """
            INSERT INTO permission_copy (
                stable_key, permission_kind, title, body_text, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(stable_key) DO UPDATE SET
                permission_kind = excluded.permission_kind,
                title = excluded.title,
                body_text = excluded.body_text,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(record.stableKey),
                .int(record.permissionKind),
                .text(record.title),
                .text(record.bodyText),
                .text(record.createdAt),
                .text(record.updatedAt)
            ]
        )
    }
}

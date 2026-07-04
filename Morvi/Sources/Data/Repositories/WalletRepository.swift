import Foundation

protocol WalletRepository {
    func save(_ record: WalletRecord) throws
    func balanceValue(accountKey: String) throws -> Int
}

final class SQLiteWalletRepository: WalletRepository {
    private let store: LocalStore

    init(store: LocalStore = .shared) {
        self.store = store
    }

    func save(_ record: WalletRecord) throws {
        try store.write(
            """
            INSERT INTO credit_account (account_key, balance_value, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(account_key) DO UPDATE SET
                balance_value = excluded.balance_value,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(record.accountKey),
                .int(record.balanceValue),
                .text(record.updatedAt)
            ]
        )
    }

    func balanceValue(accountKey: String) throws -> Int {
        try store.readInt(
            "SELECT balance_value FROM credit_account WHERE account_key = ? LIMIT 1;",
            bindings: [.text(accountKey)]
        )
    }
}

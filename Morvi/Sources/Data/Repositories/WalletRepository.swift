import Foundation

protocol WalletRepository {
    func save(_ record: WalletRecord) throws
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
}

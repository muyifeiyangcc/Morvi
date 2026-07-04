import Foundation

protocol WalletRepository {
    func save(_ record: WalletRecord) throws
    func balanceValue(accountKey: String) throws -> Int
    func consumeBalanceValue(accountKey: String, amount: Int) throws -> Bool
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

    func consumeBalanceValue(accountKey: String, amount: Int) throws -> Bool {
        var didConsume = false
        try store.transaction {
            let currentValue = try balanceValue(accountKey: accountKey)
            guard currentValue >= amount else {
                return
            }
            try store.write(
                """
                UPDATE credit_account
                SET balance_value = ?,
                    updated_at = ?
                WHERE account_key = ?;
                """,
                bindings: [
                    .int(currentValue - amount),
                    .text(LocalDateText.now()),
                    .text(accountKey)
                ]
            )
            didConsume = true
        }
        return didConsume
    }
}

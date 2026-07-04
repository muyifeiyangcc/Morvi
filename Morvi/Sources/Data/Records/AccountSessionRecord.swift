import Foundation

struct AccountSessionRecord {
    let accountKey: String
    let accessKind: Int
    let isActive: Bool
    let signedInAt: String
    let expiresAt: String?
}

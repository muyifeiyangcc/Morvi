import Foundation

struct DialogueThreadRecord {
    let stableKey: String
    let threadKind: Int
    let counterpartAccountKey: String?
    let title: String
    let avatarAsset: String?
    let latestEntryKey: String?
    let latestEntryAt: String?
    let lastReadAt: String?
    let isArchived: Bool
    let createdAt: String
    let updatedAt: String
}

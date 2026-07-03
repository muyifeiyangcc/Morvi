import Foundation

struct DialogueEntryRecord {
    let stableKey: String
    let threadKey: String
    let authorAccountKey: String?
    let speakerKind: Int
    let entryKind: Int
    let bodyText: String?
    let mediaAsset: String?
    let mediaWidth: Double?
    let mediaHeight: Double?
    let audioDuration: Double?
    let sequenceNumber: Int
    let deliveryState: Int
    let createdAt: String
}

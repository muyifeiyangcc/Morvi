import Foundation

struct CreativeWorkRecord {
    let stableKey: String
    let ownerAccountKey: String
    let title: String
    let bodyText: String?
    let mediaKind: Int
    let mediaAsset: String?
    let coverAsset: String?
    let mediaWidth: Double?
    let mediaHeight: Double?
    let durationSeconds: Double?
    let visibilityCode: Int
    let createdAt: String
    let updatedAt: String
}

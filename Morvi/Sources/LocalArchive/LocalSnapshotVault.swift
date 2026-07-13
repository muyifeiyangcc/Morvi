import Foundation

struct IdentityCardRecord: Hashable, Identifiable {
    let stableKey: String
    let displayName: String
    let avatarAssetName: String
    let backdropAssetName: String
    let note: String
    let audienceCount: Int
    let connectionCount: Int

    var id: String { stableKey }

    static let signedSample = IdentityCardRecord(
        stableKey: "identity-anna",
        displayName: "Anna",
        avatarAssetName: "builtin_avatar_amelia",
        backdropAssetName: "builtin_video_cover_amelia",
        note: "Capturing today's happiness. Saving it for tomorrow's memories.",
        audienceCount: 77,
        connectionCount: 99
    )

    static let guestSample = IdentityCardRecord(
        stableKey: "identity-guest",
        displayName: "Guest-AWERWD",
        avatarAssetName: "default_avatar",
        backdropAssetName: "image.png",
        note: "Please log in first",
        audienceCount: 0,
        connectionCount: 0
    )
}

struct FeelingOption: Hashable, Identifiable {
    let title: String
    let assetName: String
    var id: String { title }
}

enum FeelingAccentKind {
    case fresh
    case calm
}

struct FeelingRecord: Hashable, Identifiable {
    let stableKey: String
    let title: String
    let bodyText: String
    let assetName: String
    let accentKind: FeelingAccentKind
    let recordedAt: Date
    let ownerAvatarAssetName: String

    var id: String { stableKey }
}

enum CreationMediaKind: Hashable {
    case photo
    case video
}

struct CreationRecord: Hashable, Identifiable {
    let stableKey: String
    let title: String
    let bodyText: String
    let authorKey: String
    let authorName: String
    let avatarAssetName: String
    let coverAssetName: String
    let tags: [String]
    let mediaKind: CreationMediaKind
    let appreciationCount: Int
    let replyCount: Int

    var id: String { stableKey }
}

struct CreationReplyRecord: Hashable, Identifiable {
    let stableKey: String
    let authorKey: String
    let authorName: String
    let avatarAssetName: String
    let bodyText: String
    var occurredAt: Date = Date()

    var id: String { stableKey }
}

enum DialogueLineSide {
    case mine
    case other
}

enum DialogueLineKind: Hashable {
    case text(String)
    case photo(String)
    case audio(Int, String?)
}

enum DialogueThreadKind: Int, Hashable {
    case direct = 0
    case assistant = 1
}

struct DialogueLineRecord: Hashable, Identifiable {
    let stableKey: String
    let side: DialogueLineSide
    let kind: DialogueLineKind
    let avatarAssetName: String
    let occurredAt: Date
    var authorStableKey: String? = nil
    var mediaWidth: Double? = nil
    var mediaHeight: Double? = nil
    var isPending: Bool = false

    var id: String { stableKey }

    var previewText: String {
        switch kind {
        case .text(let value):
            return value
        case .photo:
            return "[photo]"
        case .audio(_, _):
            return "[audio]"
        }
    }

    static func textSample(content: String, side: DialogueLineSide) -> DialogueLineRecord {
        textLine(
            content: content,
            side: side,
            avatarAssetName: side == .mine ? "default_avatar" : "builtin_avatar_victoria",
            occurredAt: Date()
        )
    }

    static func textLine(
        content: String,
        side: DialogueLineSide,
        avatarAssetName: String,
        occurredAt: Date
    ) -> DialogueLineRecord {
        DialogueLineRecord(
            stableKey: UUID().uuidString,
            side: side,
            kind: .text(content),
            avatarAssetName: avatarAssetName,
            occurredAt: occurredAt
        )
    }
}

struct DialogueThreadRecord: Hashable, Identifiable {
    let stableKey: String
    let kind: DialogueThreadKind
    let counterpartStableKey: String?
    let title: String
    let avatarAssetName: String
    let latestPreview: String
    let updatedAt: Date

    var id: String { stableKey }
}

struct CreditPackRecord: Hashable, Identifiable {
    let stableKey: String
    let amountText: String
    let priceText: String
    let productKey: String

    var id: String { stableKey }
}

struct LocalSnapshotVault {
    let creditBalance: Int
    let identityCards: [IdentityCardRecord]
    let creations: [CreationRecord]
    let creationReplyGroups: [String: [CreationReplyRecord]]
    let feelings: [FeelingRecord]
    let dialogueThreads: [DialogueThreadRecord]
    let directLines: [DialogueLineRecord]
    let assistantLines: [DialogueLineRecord]
    let feelingOptions: [FeelingOption]
    let creditCatalog: [CreditPackRecord]

    static let preview = LocalSnapshotVault(
        creditBalance: 2000,
        identityCards: [
            .signedSample,
            IdentityCardRecord(stableKey: "identity-victoria", displayName: "Victoria", avatarAssetName: "builtin_avatar_victoria", backdropAssetName: "builtin_video_cover_victoria", note: "Capturing today's happiness. Saving it for tomorrow's memories.", audienceCount: 88, connectionCount: 61),
            IdentityCardRecord(stableKey: "identity-rowan", displayName: "Rowan", avatarAssetName: "builtin_avatar_rowan", backdropAssetName: "builtin_video_cover_rowan", note: "Moments Matter", audienceCount: 45, connectionCount: 39),
            IdentityCardRecord(stableKey: "identity-sophia", displayName: "Sophia", avatarAssetName: "builtin_avatar_sophia", backdropAssetName: "builtin_video_cover_sophia", note: "Keep going!", audienceCount: 52, connectionCount: 73),
            IdentityCardRecord(stableKey: "identity-jasper", displayName: "Jasper", avatarAssetName: "builtin_avatar_jasper", backdropAssetName: "builtin_video_cover_jasper", note: "Nice to meet you.", audienceCount: 63, connectionCount: 41),
            IdentityCardRecord(stableKey: "identity-liam", displayName: "Liam", avatarAssetName: "builtin_avatar_liam", backdropAssetName: "builtin_video_cover_liam", note: "Small steps, bright days.", audienceCount: 71, connectionCount: 58),
            IdentityCardRecord(stableKey: "identity-chloe", displayName: "Chloe", avatarAssetName: "builtin_avatar_chloe", backdropAssetName: "builtin_video_cover_chloe", note: "Saving soft moments.", audienceCount: 49, connectionCount: 64)
        ],
        creations: [
            CreationRecord(stableKey: "creation-anna", title: "Moments Matter", bodyText: "Capturing today's happiness. Saving it for tomorrow's memories.", authorKey: "identity-anna", authorName: "Anna", avatarAssetName: "builtin_avatar_amelia", coverAssetName: "builtin_video_cover_amelia", tags: ["Travel", "Food", "Family", "Friends", "Lifestyle"], mediaKind: .video, appreciationCount: 666, replyCount: 777),
            CreationRecord(stableKey: "creation-1", title: "Moments Matter", bodyText: "Capturing today's happiness. Saving it for tomorrow's memories.", authorKey: "identity-victoria", authorName: "Victoria", avatarAssetName: "builtin_avatar_victoria", coverAssetName: "builtin_video_cover_victoria", tags: ["Travel", "Food", "Family", "Friends", "Lifestyle"], mediaKind: .video, appreciationCount: 666, replyCount: 777),
            CreationRecord(stableKey: "creation-2", title: "Golden Walk", bodyText: "The video content is great! Keep going!", authorKey: "identity-rowan", authorName: "Rowan", avatarAssetName: "builtin_avatar_rowan", coverAssetName: "builtin_video_cover_rowan", tags: ["Travel", "Friends"], mediaKind: .photo, appreciationCount: 256, replyCount: 98),
            CreationRecord(stableKey: "creation-3", title: "Soft Hour", bodyText: "A small bright feeling stayed with me today.", authorKey: "identity-sophia", authorName: "Sophia", avatarAssetName: "builtin_avatar_sophia", coverAssetName: "builtin_video_cover_sophia", tags: ["Family", "Lifestyle"], mediaKind: .photo, appreciationCount: 188, replyCount: 42),
            CreationRecord(stableKey: "creation-4", title: "Clear Light", bodyText: "Keeping this little scene for later.", authorKey: "identity-jasper", authorName: "Jasper", avatarAssetName: "builtin_avatar_jasper", coverAssetName: "builtin_video_cover_jasper", tags: ["Travel", "Food"], mediaKind: .video, appreciationCount: 321, replyCount: 73)
        ],
        creationReplyGroups: [
            "creation-anna": [
                CreationReplyRecord(stableKey: "creation-reply-anna-jasper", authorKey: "identity-jasper", authorName: "Jasper", avatarAssetName: "builtin_avatar_jasper", bodyText: "The video content is great! Keep going!The video content is great! Keep going!"),
                CreationReplyRecord(stableKey: "creation-reply-anna-rowan", authorKey: "identity-rowan", authorName: "Rowan", avatarAssetName: "builtin_avatar_rowan", bodyText: "The video content is great! Keep going!"),
                CreationReplyRecord(stableKey: "creation-reply-anna-sophia", authorKey: "identity-sophia", authorName: "Sophia", avatarAssetName: "builtin_avatar_sophia", bodyText: "The video content is great! Keep going!")
            ],
            "creation-1": [
                CreationReplyRecord(stableKey: "creation-reply-jasper", authorKey: "identity-jasper", authorName: "Jasper", avatarAssetName: "builtin_avatar_jasper", bodyText: "The video content is great! Keep going!The video content is great! Keep going!"),
                CreationReplyRecord(stableKey: "creation-reply-rowan", authorKey: "identity-rowan", authorName: "Rowan", avatarAssetName: "builtin_avatar_rowan", bodyText: "The video content is great! Keep going!"),
                CreationReplyRecord(stableKey: "creation-reply-sophia", authorKey: "identity-sophia", authorName: "Sophia", avatarAssetName: "builtin_avatar_sophia", bodyText: "The video content is great! Keep going!")
            ]
        ],
        feelings: [
            FeelingRecord(stableKey: "feeling-1", title: "Happy", bodyText: "Hello! Did everything go smoothly today?", assetName: "home_mood_happy", accentKind: .fresh, recordedAt: Date(), ownerAvatarAssetName: "default_avatar"),
            FeelingRecord(stableKey: "feeling-2", title: "Calm", bodyText: "A calm moment came today!", assetName: "home_mood_calm", accentKind: .calm, recordedAt: Date().addingTimeInterval(-3600), ownerAvatarAssetName: "default_avatar")
        ],
        dialogueThreads: [
            DialogueThreadRecord(stableKey: "direct-identity-victoria-preview-account", kind: .direct, counterpartStableKey: "identity-victoria", title: "Victoria", avatarAssetName: "builtin_avatar_victoria", latestPreview: "Nice to meet you.", updatedAt: Date())
        ],
        directLines: [
            DialogueLineRecord(stableKey: "direct-text-sample-mine", side: .mine, kind: .text("Nice to meet you, nice to meet you!"), avatarAssetName: "default_avatar", occurredAt: Date().addingTimeInterval(-300)),
            DialogueLineRecord(stableKey: "direct-text-sample-other", side: .other, kind: .text("Nice to meet you."), avatarAssetName: "builtin_avatar_victoria", occurredAt: Date().addingTimeInterval(-290)),
            DialogueLineRecord(stableKey: "direct-photo-sample", side: .other, kind: .photo("builtin_avatar_victoria"), avatarAssetName: "builtin_avatar_victoria", occurredAt: Date().addingTimeInterval(-240)),
            DialogueLineRecord(stableKey: "direct-audio-sample", side: .mine, kind: .audio(5, nil), avatarAssetName: "default_avatar", occurredAt: Date().addingTimeInterval(-180))
        ],
        assistantLines: [
            .textSample(content: "Hello! How can I help you?", side: .other)
        ],
        feelingOptions: [
            FeelingOption(title: "Happy", assetName: "home_mood_happy"),
            FeelingOption(title: "Calm", assetName: "home_mood_calm"),
            FeelingOption(title: "Playful", assetName: "home_mood_playful"),
            FeelingOption(title: "Smile", assetName: "home_mood_smile"),
            FeelingOption(title: "Laugh", assetName: "home_mood_laugh"),
            FeelingOption(title: "Beaming", assetName: "home_mood_beaming"),
            FeelingOption(title: "Surprised", assetName: "home_mood_surprised"),
            FeelingOption(title: "Shocked", assetName: "home_mood_shocked"),
            FeelingOption(title: "Sad", assetName: "home_mood_sad"),
            FeelingOption(title: "Worried", assetName: "home_mood_worried"),
            FeelingOption(title: "Nervous", assetName: "home_mood_nervous"),
            FeelingOption(title: "Distressed", assetName: "home_mood_distressed")
        ],
        creditCatalog: [
            CreditPackRecord(stableKey: "credit-400", amountText: "400", priceText: "$0.99", productKey: "mqlravtspzbnheyc"),
            CreditPackRecord(stableKey: "credit-800", amountText: "800", priceText: "$1.99", productKey: "qmwkqadsjekmrvjl"),
            CreditPackRecord(stableKey: "credit-1780", amountText: "1780", priceText: "$3.99", productKey: "jfukgudeggyrveyo"),
            CreditPackRecord(stableKey: "credit-2450", amountText: "2450", priceText: "$4.99", productKey: "lwauthykogfgikvz"),
            CreditPackRecord(stableKey: "credit-5150", amountText: "5150", priceText: "$9.99", productKey: "ekilrobkqllkbcfw"),
            CreditPackRecord(stableKey: "credit-10800", amountText: "10800", priceText: "$19.99", productKey: "txictgmtylhydqow"),
            CreditPackRecord(stableKey: "credit-14900", amountText: "14900", priceText: "$29.99", productKey: "kxafnnejjhdudgmq"),
            CreditPackRecord(stableKey: "credit-29400", amountText: "29400", priceText: "$49.99", productKey: "czeaavhyyldqftuc"),
            CreditPackRecord(stableKey: "credit-34500", amountText: "34500", priceText: "$69.99", productKey: "vdjzqpsrzdfnrbwb"),
            CreditPackRecord(stableKey: "credit-63700", amountText: "63700", priceText: "$99.99", productKey: "eujrdvblverymclw")
        ]
    )
}

extension Array where Element == DialogueThreadRecord {
    func updatedPreviewLine(_ line: String, stableKey: String) -> [DialogueThreadRecord] {
        var copy = self
        guard let index = copy.firstIndex(where: { $0.stableKey == stableKey }) else {
            return self
        }
        let thread = copy.remove(at: index)
        let refreshed = DialogueThreadRecord(
            stableKey: thread.stableKey,
            kind: thread.kind,
            counterpartStableKey: thread.counterpartStableKey,
            title: thread.title,
            avatarAssetName: thread.avatarAssetName,
            latestPreview: line,
            updatedAt: Date()
        )
        copy.insert(refreshed, at: 0)
        return copy
    }
}

import Foundation

struct MoodEntryRecord {
    let stableKey: String
    let accountKey: String
    let moodCode: Int
    let moodAsset: String
    let moodTitle: String
    let bodyText: String
    let toneCode: Int
    let recordedAt: String
    let updatedAt: String
}

struct MoodDescriptor {
    let title: String
    let assetName: String
    let toneCode: Int

    static let all: [MoodDescriptor] = [
        MoodDescriptor(title: "Smile", assetName: "home_mood_smile", toneCode: 1),
        MoodDescriptor(title: "Happy", assetName: "home_mood_happy", toneCode: 1),
        MoodDescriptor(title: "Laugh", assetName: "home_mood_laugh", toneCode: 1),
        MoodDescriptor(title: "Playful", assetName: "home_mood_playful", toneCode: 1),
        MoodDescriptor(title: "Surprised", assetName: "home_mood_surprised", toneCode: 0),
        MoodDescriptor(title: "Nervous", assetName: "home_mood_nervous", toneCode: 0),
        MoodDescriptor(title: "Beaming", assetName: "home_mood_beaming", toneCode: 1),
        MoodDescriptor(title: "Worried", assetName: "home_mood_worried", toneCode: 0),
        MoodDescriptor(title: "Shocked", assetName: "home_mood_shocked", toneCode: 0),
        MoodDescriptor(title: "Sad", assetName: "home_mood_sad", toneCode: 0),
        MoodDescriptor(title: "Calm", assetName: "home_mood_calm", toneCode: 1),
        MoodDescriptor(title: "Distressed", assetName: "home_mood_distressed", toneCode: 0)
    ]

    static func descriptor(at index: Int) -> MoodDescriptor {
        all[min(max(index, 0), all.count - 1)]
    }
}

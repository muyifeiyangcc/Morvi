import Foundation

enum DialogueFlowSide {
    case local
    case remote
}

enum DialogueFlowEntry {
    case moment(String)
    case wideAsset(name: String)
    case phrase(text: String, side: DialogueFlowSide, showsAvatar: Bool)
    case roundedPhrase(text: String, side: DialogueFlowSide, showsAvatar: Bool)
    case audioClip(durationText: String, side: DialogueFlowSide, showsAvatar: Bool)
    case portraitAsset(name: String, side: DialogueFlowSide, showsAvatar: Bool)
}

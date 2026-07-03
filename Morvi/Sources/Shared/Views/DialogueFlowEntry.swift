import Foundation

enum DialogueFlowSide {
    case local
    case remote
}

enum DialogueFlowEntry {
    case moment(String)
    case phrase(text: String, side: DialogueFlowSide, showsAvatar: Bool)
    case audioClip(durationText: String, side: DialogueFlowSide, showsAvatar: Bool)
    case portraitAsset(name: String, side: DialogueFlowSide, showsAvatar: Bool)
}

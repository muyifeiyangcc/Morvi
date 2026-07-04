import Foundation

enum DialogueFlowSide {
    case local
    case remote
}

enum DialogueFlowEntry {
    case moment(String)
    case wideAsset(name: String, title: String?, revealsCharacters: Bool = false, revealIdentifier: String? = nil)
    case phrase(text: String, side: DialogueFlowSide, showsAvatar: Bool)
    case roundedPhrase(text: String, side: DialogueFlowSide, showsAvatar: Bool, revealsCharacters: Bool = false, revealIdentifier: String? = nil)
    case audioClip(durationText: String, side: DialogueFlowSide, showsAvatar: Bool, audioAsset: String?)
    case portraitAsset(name: String, side: DialogueFlowSide, showsAvatar: Bool)
}

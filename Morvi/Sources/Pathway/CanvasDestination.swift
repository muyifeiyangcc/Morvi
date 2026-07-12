import Foundation

enum CanvasDestination: Hashable, Identifiable {
    case discover
    case wallet
    case settings
    case agreement(String)
    case restrictedRoster
    case audienceRoster
    case connectionRoster
    case publicPersona(IdentityCardRecord)
    case creationDetail(CreationRecord)
    case directDialogue(DialogueThreadRecord)
    case assistantDialogue

    var id: String {
        switch self {
        case .discover:
            return "discover"
        case .wallet:
            return "wallet"
        case .settings:
            return "settings"
        case .agreement(let title):
            return "agreement-\(title)"
        case .restrictedRoster:
            return "restricted-roster"
        case .audienceRoster:
            return "audience-roster"
        case .connectionRoster:
            return "connection-roster"
        case .publicPersona(let card):
            return "public-persona-\(card.stableKey)"
        case .creationDetail(let record):
            return "creation-\(record.stableKey)"
        case .directDialogue(let thread):
            return "direct-\(thread.stableKey)"
        case .assistantDialogue:
            return "assistant"
        }
    }
}

enum RailSection: Int, CaseIterable, Identifiable {
    case home
    case feelings
    case dialogues
    case persona

    var id: Int { rawValue }

    var assetName: String {
        switch self {
        case .home:
            return "tab_home"
        case .feelings:
            return "tab_discover"
        case .dialogues:
            return "tab_dialogue"
        case .persona:
            return "tab_persona"
        }
    }

    var selectedAssetName: String {
        switch self {
        case .home:
            return "tab_home_selected"
        case .feelings:
            return "tab_discover_selected"
        case .dialogues:
            return "tab_dialogue_selected"
        case .persona:
            return "tab_persona_selected"
        }
    }
}

enum OverlaySheetKind: Identifiable, Equatable {
    case accessGuide
    case feelingEditor(FeelingOption)
    case uploadCreation
    case spendConfirm
    case creditShortage
    case profileEditor
    case reportRestrict
    case restrictionConfirm
    case safetyConcern
    case exitConfirm
    case signOutConfirm

    var id: String {
        switch self {
        case .accessGuide:
            return "access-guide"
        case .feelingEditor(let option):
            return "feeling-\(option.title)"
        case .uploadCreation:
            return "upload-creation"
        case .spendConfirm:
            return "spend-confirm"
        case .creditShortage:
            return "credit-shortage"
        case .profileEditor:
            return "profile-editor"
        case .reportRestrict:
            return "report-restrict"
        case .restrictionConfirm:
            return "restriction-confirm"
        case .safetyConcern:
            return "safety-concern"
        case .exitConfirm:
            return "exit-confirm"
        case .signOutConfirm:
            return "sign-out-confirm"
        }
    }
}

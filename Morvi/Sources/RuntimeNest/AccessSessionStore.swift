import Combine
import Foundation
import UIKit

enum IdentitySessionState: Equatable {
    case absent
    case guest(IdentityCardRecord)
    case signed(IdentityCardRecord)
}

final class AccessSessionStore: ObservableObject {
    @Published private(set) var state: IdentitySessionState

    private let archive: IdentityArchive
    private let accessQueue = DispatchQueue(label: "morvi.identity.session", qos: .userInitiated)
    private var activeEntry: StoredIdentity?

    init(archive: IdentityArchive = .shared, state: IdentitySessionState = .absent) {
        self.archive = archive
        self.state = state
        if let restoredEntry = archive.activeIdentity() {
            activeEntry = restoredEntry
            applyState(for: restoredEntry)
        }
    }

    var isReadyForProtectedActions: Bool {
        switch state {
        case .guest, .signed:
            return true
        case .absent:
            return false
        }
    }

    var canUseStoredValue: Bool {
        if case .signed = state {
            return true
        }
        return false
    }

    var needsAccessUpgrade: Bool {
        switch state {
        case .signed:
            return false
        case .absent, .guest:
            return true
        }
    }

    var activeCard: IdentityCardRecord? {
        switch state {
        case .absent:
            return nil
        case .guest(let card), .signed(let card):
            return card
        }
    }

    func enterAsGuest() throws {
        activate(try archive.restoreVisitor())
    }

    func enterAsGuest(completion: @escaping (Result<Void, Error>) -> Void) {
        accessQueue.async { [weak self] in
            guard let self else { return }
            self.completeAccessOperation(completion) {
                self.activate(try self.archive.restoreVisitor())
            }
        }
    }

    func enterWithEmail(mailbox: String, passcode: String) throws {
        activate(try archive.authenticate(mailbox: mailbox, passcode: passcode))
    }

    func enterWithEmail(
        mailbox: String,
        passcode: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        accessQueue.async { [weak self] in
            guard let self else { return }
            self.completeAccessOperation(completion) {
                self.activate(try self.archive.authenticate(mailbox: mailbox, passcode: passcode))
            }
        }
    }

    func enterWithApple(receipt: AppleIdentityReceipt) throws {
        activate(
            try archive.resolveAppleIdentity(
                providerReference: receipt.providerReference,
                mailbox: receipt.mailbox,
                displayName: receipt.displayName
            )
        )
    }

    func enterWithApple(
        receipt: AppleIdentityReceipt,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        accessQueue.async { [weak self] in
            guard let self else { return }
            self.completeAccessOperation(completion) {
                let entry = try self.archive.resolveAppleIdentity(
                    providerReference: receipt.providerReference,
                    mailbox: receipt.mailbox,
                    displayName: receipt.displayName
                )
                self.activate(entry)
            }
        }
    }

    func register(
        mailbox: String,
        passcode: String,
        displayName: String,
        birthday: String,
        location: String,
        gender: String,
        portrait: UIImage
    ) throws {
        try archive.register(
            mailbox: mailbox,
            passcode: passcode,
            displayName: displayName,
            birthday: birthday,
            location: location,
            gender: gender,
            portrait: portrait
        )
    }

    func register(
        mailbox: String,
        passcode: String,
        displayName: String,
        birthday: String,
        location: String,
        gender: String,
        portrait: UIImage,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        accessQueue.async { [weak self] in
            guard let self else { return }
            self.completeAccessOperation(completion) {
                try self.archive.register(
                    mailbox: mailbox,
                    passcode: passcode,
                    displayName: displayName,
                    birthday: birthday,
                    location: location,
                    gender: gender,
                    portrait: portrait
                )
            }
        }
    }

    func resetPasscode(mailbox: String, passcode: String) -> Bool {
        archive.resetPasscode(mailbox: mailbox, passcode: passcode)
    }

    func resetPasscode(
        mailbox: String,
        passcode: String,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        accessQueue.async { [weak self] in
            guard let self else { return }
            let result: Result<Bool, Error>
            do {
                result = .success(
                    try self.archive.resetPasscodeResult(mailbox: mailbox, passcode: passcode)
                )
            } catch {
                result = .failure(error)
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    func updateActiveIdentityName(_ name: String) {
        guard let activeEntry else { return }
        archive.updateDisplayName(name, stableKey: activeEntry.stableKey)
        self.activeEntry = StoredIdentity(
            stableKey: activeEntry.stableKey,
            mailbox: activeEntry.mailbox,
            passcode: activeEntry.passcode,
            displayName: name,
            avatarReference: activeEntry.avatarReference,
            birthday: activeEntry.birthday,
            location: activeEntry.location,
            gender: activeEntry.gender,
            providerReference: activeEntry.providerReference,
            entryKind: activeEntry.entryKind
        )
        applyState(for: self.activeEntry!)
    }

    func updateActivePortrait(_ portrait: UIImage) throws {
        guard let activeEntry else { return }
        let reference = try archive.updatePortrait(portrait, stableKey: activeEntry.stableKey)
        self.activeEntry = StoredIdentity(
            stableKey: activeEntry.stableKey,
            mailbox: activeEntry.mailbox,
            passcode: activeEntry.passcode,
            displayName: activeEntry.displayName,
            avatarReference: reference,
            birthday: activeEntry.birthday,
            location: activeEntry.location,
            gender: activeEntry.gender,
            providerReference: activeEntry.providerReference,
            entryKind: activeEntry.entryKind
        )
        applyState(for: self.activeEntry!)
    }

    func exit() {
        archive.clearActiveIdentity()
        activeEntry = nil
        state = .absent
    }

    func eraseActiveIdentity() {
        guard let activeEntry else { return }
        archive.eraseIdentity(stableKey: activeEntry.stableKey)
        self.activeEntry = nil
        state = .absent
    }

    private func activate(_ entry: StoredIdentity) {
        performOnMain {
            self.activeEntry = entry
            self.applyState(for: entry)
        }
    }

    private func completeAccessOperation(
        _ completion: @escaping (Result<Void, Error>) -> Void,
        operation: () throws -> Void
    ) {
        let result: Result<Void, Error>
        do {
            try operation()
            result = .success(())
        } catch {
            result = .failure(error)
        }
        DispatchQueue.main.async {
            completion(result)
        }
    }

    private func performOnMain(_ operation: @escaping () -> Void) {
        if Thread.isMainThread {
            operation()
        } else {
            DispatchQueue.main.sync(execute: operation)
        }
    }

    private func applyState(for entry: StoredIdentity) {
        let builtInCard = LocalSnapshotVault.preview.identityCards.first { $0.stableKey == entry.stableKey }
        let resolvedName = entry.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedAvatar = entry.avatarReference.trimmingCharacters(in: .whitespacesAndNewlines)
        let card = IdentityCardRecord(
            stableKey: entry.stableKey,
            displayName: resolvedName.isEmpty ? (builtInCard?.displayName ?? entry.displayName) : entry.displayName,
            avatarAssetName: resolvedAvatar.isEmpty ? (builtInCard?.avatarAssetName ?? "default_avatar") : entry.avatarReference,
            backdropAssetName: builtInCard?.backdropAssetName ?? "image.png",
            note: builtInCard?.note ?? "Please log in first",
            audienceCount: builtInCard?.audienceCount ?? 0,
            connectionCount: builtInCard?.connectionCount ?? 0
        )
        state = entry.entryKind == .visitor ? .guest(card) : .signed(card)
    }
}

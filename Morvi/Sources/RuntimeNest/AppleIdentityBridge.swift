import AuthenticationServices
import Combine
import UIKit

struct AppleIdentityReceipt {
    let providerReference: String
    let mailbox: String?
    let displayName: String?
}

enum AppleIdentityBridgeIssue: LocalizedError {
    case cancelled
    case unavailable

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Apple login failed"
        case .unavailable:
            return "Apple login failed"
        }
    }
}

final class AppleIdentityBridge: NSObject, ObservableObject {
    private var completion: ((Result<AppleIdentityReceipt, AppleIdentityBridgeIssue>) -> Void)?
    private var authorizationController: ASAuthorizationController?

    func begin(completion: @escaping (Result<AppleIdentityReceipt, AppleIdentityBridgeIssue>) -> Void) {
        guard let window = keyWindow else {
            completion(.failure(.unavailable))
            return
        }
        self.completion = completion
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        authorizationController = controller
        controller.performRequests()
        _ = window
    }

    private var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    private func finish(_ result: Result<AppleIdentityReceipt, AppleIdentityBridgeIssue>) {
        completion?(result)
        completion = nil
        authorizationController = nil
    }
}

extension AppleIdentityBridge: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(.failure(.unavailable))
            return
        }
        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        finish(
            .success(
                AppleIdentityReceipt(
                    providerReference: credential.user,
                    mailbox: credential.email,
                    displayName: name.isEmpty ? nil : name
                )
            )
        )
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let issue = (error as? ASAuthorizationError)?.code == .canceled ? AppleIdentityBridgeIssue.cancelled : .unavailable
        finish(.failure(issue))
    }
}

extension AppleIdentityBridge: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        keyWindow ?? ASPresentationAnchor()
    }
}

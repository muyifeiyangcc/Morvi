import Foundation
import StoreKit

struct CreditPack {
    let value: Int
    let storeIdentifier: String
}

enum CreditAcquisitionOutcome {
    case completed(Int)
    case cancelled
    case pending
    case unavailable
    case failed
}

final class StorefrontCreditBroker {
    static let shared = StorefrontCreditBroker()

    private init() {}

    func acquire(_ pack: CreditPack) async -> CreditAcquisitionOutcome {
        do {
            let storeItems = try await Product.products(for: [pack.storeIdentifier])
            guard let storeItem = storeItems.first else {
                return .unavailable
            }

            let result = try await storeItem.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    return .completed(pack.value)
                case .unverified:
                    return .failed
                }
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed
            }
        } catch {
            return .failed
        }
    }
}

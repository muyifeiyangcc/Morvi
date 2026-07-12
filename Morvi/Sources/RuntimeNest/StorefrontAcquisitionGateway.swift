import StoreKit

enum StoredValueAcquisitionResult {
    case completed(Int)
    case cancelled
    case pending
    case unavailable
    case failed
}

final class StorefrontAcquisitionGateway {
    static let shared = StorefrontAcquisitionGateway()

    private init() {}

    func acquire(_ pack: CreditPackRecord) async -> StoredValueAcquisitionResult {
        guard let amount = Int(pack.amountText) else { return .failed }

        do {
            let products = try await Product.products(for: [pack.productKey])
            guard let product = products.first(where: { $0.id == pack.productKey }) else {
                return .unavailable
            }

            switch try await product.purchase() {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    return .completed(amount)
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

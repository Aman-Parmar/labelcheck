import Foundation
import StoreKit

/// StoreKit 2, serverless. No RevenueCat, no receipt server.
/// Products (see SUBSCRIPTION_PLAN.md and Resources/LabelCheck.storekit):
///   labelcheck_pro_yearly   — auto-renewable, $9.99/year
///   labelcheck_pro_lifetime — non-consumable, $19.99 once
/// One Pro entitlement, not two feature sets. Free keeps unlimited barcode
/// scans and the product card forever; Pro adds depth only (unlimited
/// history, multiple allergen profiles, OCR label explain, export).
@MainActor
final class StoreManager: ObservableObject {
    static let yearlyProductID = "labelcheck_pro_yearly"
    static let lifetimeProductID = "labelcheck_pro_lifetime"
    static let subscriptionGroupID = "labelcheck_pro"

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro = false
    @Published private(set) var isLoading = false

    private var updatesTask: Task<Void, Never>?

    /// Starts listening for StoreKit transaction updates. Called from
    /// `loadProducts()` (after init has completed) rather than from `init`,
    /// so the listener task never captures `self` before initialisation.
    private func startListening() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlement()
                }
            }
        }
    }

    func loadProducts() async {
        startListening()
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: [
                Self.yearlyProductID, Self.lifetimeProductID,
            ])
            await refreshEntitlement()
        } catch {
            products = []
        }
    }

    func refreshEntitlement() async {
        var pro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               [Self.yearlyProductID, Self.lifetimeProductID].contains(transaction.productID),
               transaction.revocationDate == nil {
                pro = true
            }
        }
        isPro = pro
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await transaction.finish()
                await refreshEntitlement()
            }
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlement()
    }
}

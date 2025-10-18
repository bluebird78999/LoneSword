import Foundation
import StoreKit
import Combine

@MainActor
final class StoreKitManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let productIDs: [String] = [
        "com.lonesword.subscription.basic",   // 19.9元/月
        "com.lonesword.subscription.premium"  // 39.9元/月
    ]
    
    private var updateListenerTask: Task<Void, Error>?
    
    init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    /// Load products from App Store
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let storeProducts = try await Product.products(for: productIDs)
            self.products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            errorMessage = "加载产品失败: \(error.localizedDescription)"
            print("Failed to load products: \(error)")
        }
        
        isLoading = false
    }
    
    /// Purchase a product
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            return transaction
            
        case .userCancelled:
            return nil
            
        case .pending:
            return nil
            
        @unknown default:
            return nil
        }
    }
    
    /// Restore purchases
    func restore() async throws {
        try await AppStore.sync()
        await updatePurchasedProducts()
    }
    
    /// Update purchased products
    private func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            if transaction.revocationDate == nil {
                purchasedIDs.insert(transaction.productID)
            }
        }
        
        self.purchasedProductIDs = purchasedIDs
    }
    
    /// Listen for transaction updates
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else {
                    continue
                }
                
                await transaction.finish()
                await self.updatePurchasedProducts()
            }
        }
    }
    
    /// Verify transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    /// Get current subscription tier
    func getCurrentTier() -> String {
        if purchasedProductIDs.contains("com.lonesword.subscription.premium") {
            return "premium"
        } else if purchasedProductIDs.contains("com.lonesword.subscription.basic") {
            return "basic"
        }
        return "free"
    }
    
    /// Get usage limit for current tier
    func getUsageLimit() -> Int {
        switch getCurrentTier() {
        case "premium":
            return 100000
        case "basic":
            return 10000
        case "free":
            return 10
        default:
            return 10
        }
    }
}

enum StoreError: Error {
    case failedVerification
}


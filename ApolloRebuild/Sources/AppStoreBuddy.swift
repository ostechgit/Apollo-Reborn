import Foundation
import StoreKit

// AppStoreBuddy - manages in-app purchases and App Store integration
// Reconstructed from apollo-base 1.15.11 binary analysis.

class AppStoreBuddy: NSObject {
    
    static let shared = AppStoreBuddy()
    
    private var products: [SKProduct] = []
    private var purchasedProductIDs: Set<String> = []
    private var productsCompletion: (([SKProduct]) -> Void)?
    
    override init() {
        // Load purchased product IDs
        let defaults = UserDefaults.standard
        if let saved = defaults.array(forKey: "purchasedProductIDs") as? [String] {
            self.purchasedProductIDs = Set(saved)
        }
    }
    
    func loadProducts(productIDs: [String], completion: @escaping ([SKProduct]) -> Void) {
        // Load products from the App Store
        let productIdentifiers = Set(productIDs)
        let request = SKProductsRequest(productIdentifiers: productIdentifiers)
        request.delegate = self
        request.start()
        
        // Store completion for later
        self.productsCompletion = completion
    }
    
    func purchaseProduct(_ product: SKProduct, completion: @escaping (Bool) -> Void) {
        // In the original app, this would purchase a product
        // For now, return success
        DispatchQueue.main.async {
            self.purchasedProductIDs.insert(product.productIdentifier)
            self.savePurchasedProducts()
            completion(true)
        }
    }
    
    func isPurchased(_ productID: String) -> Bool {
        return self.purchasedProductIDs.contains(productID)
    }
    
    private func savePurchasedProducts() {
        let defaults = UserDefaults.standard
        defaults.set(Array(self.purchasedProductIDs), forKey: "purchasedProductIDs")
    }
}

extension AppStoreBuddy: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        self.products = response.products
        self.productsCompletion?(response.products)
        self.productsCompletion = nil
    }
    
    func request(_ request: SKRequest, didFail error: Error) {
        print("App Store request failed: \(error)")
        self.productsCompletion?([])
        self.productsCompletion = nil
    }
}

import Foundation

// TransactionIDCollector - collects and manages transaction IDs for purchases
// Reconstructed from apollo-base 1.15.11 binary analysis.

class TransactionIDCollector {
    
    static let shared = TransactionIDCollector()
    
    private var transactionIDs: [String] = []
    private let defaults = UserDefaults.standard
    
    private init() {
        // Load saved transaction IDs
        if let saved = defaults.array(forKey: "transactionIDs") as? [String] {
            self.transactionIDs = saved
        }
    }
    
    func addTransactionID(_ id: String) {
        if !self.transactionIDs.contains(id) {
            self.transactionIDs.append(id)
            save()
        }
    }
    
    func hasTransactionID(_ id: String) -> Bool {
        return self.transactionIDs.contains(id)
    }
    
    func allTransactionIDs() -> [String] {
        return self.transactionIDs
    }
    
    private func save() {
        self.defaults.set(self.transactionIDs, forKey: "transactionIDs")
    }
}

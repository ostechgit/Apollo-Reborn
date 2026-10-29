import Foundation

// ReceiptDataBuddy - manages receipt data for in-app purchases
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ReceiptDataBuddy {
    
    static let shared = ReceiptDataBuddy()
    
    private var receiptData: Data?
    
    private init() {}
    
    func fetchReceiptData(completion: @escaping (Data?) -> Void) {
        // Fetch receipt data from the app bundle
        let receiptURL = Bundle.main.appStoreReceiptURL
        if let receiptURL = receiptURL, FileManager.default.fileExists(atPath: receiptURL.path) {
            do {
                let data = try Data(contentsOf: receiptURL)
                self.receiptData = data
                DispatchQueue.main.async {
                    completion(data)
                }
                return
            } catch {
                print("Failed to read receipt: \(error)")
            }
        }
        
        DispatchQueue.main.async {
            completion(nil)
        }
    }
    
    func getReceiptData() -> Data? {
        return self.receiptData
    }
}

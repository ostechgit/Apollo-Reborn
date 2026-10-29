import Foundation

// AstraNetworkManager - manages network requests
// Reconstructed from apollo-base 1.15.11 binary analysis.

class AstraNetworkManager {
    
    static let shared = AstraNetworkManager()
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    func fetchData(from url: URL, completion: @escaping (Data?, Error?) -> Void) {
        let task = self.session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                completion(data, error)
            }
        }
        task.resume()
    }
}

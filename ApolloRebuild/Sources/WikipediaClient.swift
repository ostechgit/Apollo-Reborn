import Foundation

// WikipediaClient - fetches Wikipedia articles for inline previews
// Reconstructed from apollo-base 1.15.11 binary analysis.

class WikipediaClient {
    
    static let shared = WikipediaClient()
    
    private let baseURL = "https://en.wikipedia.org/api/rest_v1/page/summary/"
    
    private init() {}
    
    func fetchSummary(forTitle title: String, completion: @escaping (String?) -> Void) {
        // Fetch Wikipedia summary
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        let url = URL(string: "\(self.baseURL)\(encodedTitle)")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if let extract = json?["extract"] as? String {
                        DispatchQueue.main.async {
                            completion(extract)
                        }
                        return
                    }
                } catch {
                    print("Wikipedia fetch failed: \(error)")
                }
            }
            
            DispatchQueue.main.async {
                completion(nil)
            }
        }.resume()
    }
}

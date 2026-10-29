import Foundation

// GfycatClient - handles Gfycat/GIPHY API requests for GIFs
// Reconstructed from apollo-base 1.15.11 binary analysis.

class GfycatClient {
    
    static let shared = GfycatClient()
    
    private let apiKey = "dc6zaTOxFJmzC"
    
    private init() {}
    
    func searchGifs(query: String, completion: @escaping ([String]) -> Void) {
        // Search GIPHY for GIFs
        let url = URL(string: "https://api.giphy.com/v1/gifs/search?api_key=\(self.apiKey)&q=\(query)&limit=25")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if let data = json?["data"] as? [[String: Any]] {
                        var gifIDs: [String] = []
                        for item in data {
                            if let id = item["id"] as? String {
                                gifIDs.append(id)
                            }
                        }
                        DispatchQueue.main.async {
                            completion(gifIDs)
                        }
                        return
                    }
                } catch {
                    print("GIPHY search failed: \(error)")
                }
            }
            
            DispatchQueue.main.async {
                completion([])
            }
        }.resume()
    }
    
    func gifURL(forID id: String) -> String {
        return "https://gfycat.com/if/\(id)"
    }
}

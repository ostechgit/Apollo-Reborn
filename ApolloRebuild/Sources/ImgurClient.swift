import Foundation

// ImgurClient - handles Imgur API requests for image uploads
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ImgurClient {
    
    static let shared = ImgurClient()
    
    private let clientID = "546c25a59359fdd"
    
    private init() {}
    
    func uploadImage(data: Data, completion: @escaping (String?) -> Void) {
        // Upload image to Imgur
        let url = URL(string: "https://api.imgur.com/3/image")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Client-ID \(self.clientID)", forHTTPHeaderField: "Authorization")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if let data = json?["data"] as? [String: Any],
                       let link = data["link"] as? String {
                        DispatchQueue.main.async {
                            completion(link)
                        }
                        return
                    }
                } catch {
                    print("Imgur upload failed: \(error)")
                }
            }
            
            DispatchQueue.main.async {
                completion(nil)
            }
        }.resume()
    }
}

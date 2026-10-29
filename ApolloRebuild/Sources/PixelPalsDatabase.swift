import Foundation

// PixelPalsDatabase - manages pixel art avatars for users
// Reconstructed from apollo-base 1.15.11 binary analysis.

class PixelPalsDatabase {
    
    static let shared = PixelPalsDatabase()
    
    private var avatars: [String: String] = [:]
    private let defaults = UserDefaults.standard
    
    private init() {
        // Load saved avatars
        if let saved = defaults.dictionary(forKey: "pixelPalsAvatars") as? [String: String] {
            self.avatars = saved
        }
    }
    
    func setAvatar(_ avatarID: String, forUser username: String) {
        self.avatars[username] = avatarID
        save()
    }
    
    func avatar(forUser username: String) -> String? {
        return self.avatars[username]
    }
    
    func clearAll() {
        self.avatars.removeAll()
        save()
    }
    
    private func save() {
        self.defaults.set(self.avatars, forKey: "pixelPalsAvatars")
    }
}

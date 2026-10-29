import Foundation

// ReadPostsTracker - tracks which posts the user has read
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ReadPostsTracker {
    
    static let shared = ReadPostsTracker()
    
    private var readPosts: Set<String> = []
    private let defaults = UserDefaults.standard
    
    private init() {
        // Load saved read posts
        if let saved = defaults.array(forKey: "readPosts") as? [String] {
            self.readPosts = Set(saved)
        }
    }
    
    func markRead(_ permalink: String) {
        self.readPosts.insert(permalink)
        save()
    }
    
    func markUnread(_ permalink: String) {
        self.readPosts.remove(permalink)
        save()
    }
    
    func isRead(_ permalink: String) -> Bool {
        return self.readPosts.contains(permalink)
    }
    
    func clearAll() {
        self.readPosts.removeAll()
        save()
    }
    
    private func save() {
        self.defaults.set(Array(self.readPosts), forKey: "readPosts")
    }
}

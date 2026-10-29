import Foundation

// SubredditIconTracker - tracks and caches subreddit icons
// Reconstructed from apollo-base 1.15.11 binary analysis.

class SubredditIconTracker {
    
    static let shared = SubredditIconTracker()
    
    private var iconCache: [String: String] = [:]
    private let defaults = UserDefaults.standard
    
    private init() {
        // Load saved icon cache
        if let saved = defaults.dictionary(forKey: "subredditIcons") as? [String: String] {
            self.iconCache = saved
        }
    }
    
    func setIconURL(_ url: String, forSubreddit subreddit: String) {
        self.iconCache[subreddit] = url
        save()
    }
    
    func iconURL(forSubreddit subreddit: String) -> String? {
        return self.iconCache[subreddit]
    }
    
    func clearAll() {
        self.iconCache.removeAll()
        save()
    }
    
    private func save() {
        self.defaults.set(self.iconCache, forKey: "subredditIcons")
    }
}

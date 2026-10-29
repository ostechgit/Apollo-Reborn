import Foundation

// ThumbnailFinder - finds and caches thumbnails for posts
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ThumbnailFinder {
    
    static let shared = ThumbnailFinder()
    
    private var thumbnailCache: [String: String] = [:]
    
    private init() {}
    
    func thumbnailURL(forPost post: RDKLink) -> String? {
        // Check cache first
        if let cached = self.thumbnailCache[post.permalink ?? ""] {
            return cached
        }
        
        // Try to find thumbnail from post data
        // RDKLink already drops Reddit's "self"/"default"/"nsfw"/"spoiler" placeholders
        if let thumbnail = post.thumbnailURL {
            self.thumbnailCache[post.permalink ?? ""] = thumbnail
            return thumbnail
        }
        
        // Fall back to the smallest preview image
        if let preview = post.previewImages?.first?.url {
            self.thumbnailCache[post.permalink ?? ""] = preview
            return preview
        }
        
        return nil
    }
    
    func clearCache() {
        self.thumbnailCache.removeAll()
    }
}

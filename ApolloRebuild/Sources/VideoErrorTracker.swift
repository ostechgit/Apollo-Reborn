import Foundation

// VideoErrorTracker - tracks video playback errors
// Reconstructed from apollo-base 1.15.11 binary analysis.

class VideoErrorTracker {
    
    static let shared = VideoErrorTracker()
    
    private var errors: [String] = []
    
    private init() {}
    
    func trackError(_ error: String, forURL url: String) {
        self.errors.append("\(url): \(error)")
        
        // In the original app, this would report the error to analytics
        LogBuddy.error("Video error: \(error) for \(url)")
    }
    
    func clearErrors() {
        self.errors.removeAll()
    }
    
    func errorCount() -> Int {
        return self.errors.count
    }
}

import Foundation

// AstraCrashReporter - reports crashes to the server
// Reconstructed from apollo-base 1.15.11 binary analysis.

class AstraCrashReporter {
    
    static let shared = AstraCrashReporter()
    
    private init() {}
    
    func reportCrash(_ error: Error, context: [String: Any] = [:]) {
        // In the original app, this would report the crash to the server
        // For now, just log
        LogBuddy.error("Crash reported: \(error)")
    }
}

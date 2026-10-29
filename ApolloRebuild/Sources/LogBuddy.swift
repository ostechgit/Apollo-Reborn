import Foundation
import os

// LogBuddy - centralized logging utility
// Reconstructed from apollo-base 1.15.11 binary analysis.

class LogBuddy {
    
    private static let logger = Logger(subsystem: "com.omarsalam.apollo", category: "app")
    
    static func info(_ message: String) {
        logger.info("\(message)")
    }
    
    static func error(_ message: String) {
        logger.error("\(message)")
    }
    
    static func debug(_ message: String) {
        logger.debug("\(message)")
    }
    
    static func warning(_ message: String) {
        logger.warning("\(message)")
    }
}
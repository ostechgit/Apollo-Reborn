import Foundation

// ServerBuddy - talks to Apollo's own server (apolloreq.com / apollogur.download)
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// In the original this handles Apollo's backend: push-notification registration,
// post watchers, and Ultra receipt validation (e.g. onlyValidateReceipt(lookingFor:
// allowRetrying:)). That server no longer exists, so nothing here is reproduced yet.
// Reddit API requests live in RDKClient.

class ServerBuddy {
    
    static let shared = ServerBuddy()
    
    private init() {}
}

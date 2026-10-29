import Foundation

// PostSubmitWatcher - watches for post submission events
// Reconstructed from apollo-base 1.15.11 binary analysis.

class PostSubmitWatcher {
    
    static let shared = PostSubmitWatcher()
    
    private var observers: [String: (RDKLink) -> Void] = [:]
    private var nextID = 0
    
    private init() {}
    
    func addObserver(_ observer: @escaping (RDKLink) -> Void) -> String {
        let id = "observer_\(nextID)"
        nextID += 1
        self.observers[id] = observer
        return id
    }
    
    func removeObserver(id: String) {
        self.observers.removeValue(forKey: id)
    }
    
    func notifyPostSubmitted(_ post: RDKLink) {
        for observer in self.observers.values {
            observer(post)
        }
    }
}
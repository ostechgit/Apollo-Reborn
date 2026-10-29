import UIKit
import AsyncDisplayKit

// InboxSectionController - manages a section of inbox items
// Reconstructed from apollo-base 1.15.11 binary analysis.

class InboxSectionController: NSObject {
    
    private var messages: [RDKMessage] = []
    
    init(messages: [RDKMessage]) {
        self.messages = messages
        super.init()
    }
    
    func messageCount() -> Int {
        return self.messages.count
    }
    
    func message(at index: Int) -> RDKMessage? {
        if index < self.messages.count {
            return self.messages[index]
        }
        return nil
    }
}

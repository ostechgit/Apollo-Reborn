import UIKit
import AsyncDisplayKit

// ModmailInboxSectionController - manages a section of modmail conversations
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ModmailInboxSectionController: NSObject {
    
    private var conversations: [RDKModmailConversation] = []
    
    init(conversations: [RDKModmailConversation]) {
        self.conversations = conversations
        super.init()
    }
    
    func conversationCount() -> Int {
        return self.conversations.count
    }
    
    func conversation(at index: Int) -> RDKModmailConversation? {
        if index < self.conversations.count {
            return self.conversations[index]
        }
        return nil
    }
}

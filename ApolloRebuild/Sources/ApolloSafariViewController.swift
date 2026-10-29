import UIKit
import SafariServices

// ApolloSafariViewController - custom Safari view controller for in-app browsing
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ApolloSafariViewController: SFSafariViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Customize the Safari view controller
        self.preferredBarTintColor = UIColor.systemBackground
        self.preferredControlTintColor = UIColor.systemBlue
    }
}

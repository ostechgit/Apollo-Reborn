import UIKit

// FlairSelectorViewController - allows users to select flair for posts or comments
// Reconstructed from apollo-base 1.15.11 binary analysis.

class FlairSelectorViewController: UIViewController {
    
    private var flairs: [RDKFlairOption] = []
    private var selectedFlair: RDKFlairOption?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Select Flair"
        self.view.backgroundColor = UIColor.systemBackground
        
        let label = UILabel()
        label.text = "Choose a flair"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 14)
        
        self.view.addSubview(label)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 100),
            label.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16)
        ])
    }
}

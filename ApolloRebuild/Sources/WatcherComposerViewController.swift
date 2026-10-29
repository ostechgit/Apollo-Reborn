import UIKit

// WatcherComposerViewController - compose messages to watched users
// Reconstructed from apollo-base 1.15.11 binary analysis.

class WatcherComposerViewController: UIViewController {
    
    private let username: String
    
    init(username: String) {
        self.username = username
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.username = ""
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Message " + self.username
        self.view.backgroundColor = UIColor.systemBackground
        
        let label = UILabel()
        label.text = "Compose a message to u/" + self.username
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
